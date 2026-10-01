//! Throwaway spike: hold an evaluated Nickel config and call its functions with host data.
//!
//! Pattern (same as `nickel-lang` 2.2's `Context::eval_expr_shallow`): one `VmContext` lives as
//! long as the loaded config. Values it returns are closurized, so a function value pulled out of
//! the config can be applied later with `Term::app` and evaluated by a fresh `VirtualMachine` over
//! the same context, without re-parsing or re-typechecking anything.

use std::{ffi::OsString, io::Cursor, path::PathBuf};

use nickel_lang_core::{
    cache::{CacheHub, InputFormat, SourcePath},
    error::{Error as CoreError, NullReporter, report::report_as_str},
    eval::{
        Closure, VirtualMachine, VmContext,
        cache::CacheImpl,
        value::{Array, NickelValue, ValueContentRef},
    },
    identifier::{Ident, LocIdent},
    term::{Term, record::RecordData},
};

pub struct Engine {
    ctx: VmContext<CacheHub, CacheImpl>,
    config: Closure,
}

/// A value together with the environment its free variables live in. Function values pulled out
/// of a contract-checked config need that environment (e.g. stdlib contract internals), so the
/// Engine hands out Closures, never bare values.
pub type Held = Closure;

pub type Diagnostic = String;

impl Engine {
    /// Parse, typecheck, apply contracts, and evaluate the config to WHNF.
    pub fn load(path: &str) -> Result<Engine, Diagnostic> {
        let src = std::fs::read_to_string(path).map_err(|e| e.to_string())?;
        let mut ctx = VmContext::new(CacheHub::new(), std::io::sink(), NullReporter {});
        let dir: PathBuf = PathBuf::from(path).parent().unwrap().to_path_buf();
        ctx.import_resolver
            .sources
            .add_import_paths(std::iter::once(OsString::from(dir)));
        let file_id = ctx
            .import_resolver
            .sources
            .add_source(
                SourcePath::Path(PathBuf::from(path), InputFormat::Nickel),
                Cursor::new(src),
            )
            .map_err(|e| e.to_string())?;
        let prepared = match ctx.prepare_eval(file_id) {
            Ok(v) => v,
            Err(e) => return Err(Self::report(&mut ctx, e)),
        };
        let r = VirtualMachine::new(&mut ctx).eval_closure(prepared.into());
        let config = match r {
            Ok(v) => v,
            Err(e) => return Err(Self::report(&mut ctx, e.into())),
        };
        Ok(Engine { ctx, config })
    }

    /// Diagnostic only: number of spans in the position table (it is append-only).
    pub fn pos_count(&self) -> usize {
        format!("{:?}", self.ctx.pos_table).matches("RawSpan").count()
    }

    fn report(ctx: &mut VmContext<CacheHub, CacheImpl>, e: CoreError) -> Diagnostic {
        let mut files = ctx.import_resolver.sources.files().clone();
        report_as_str(&mut files, e, nickel_lang_core::error::report::ColorOpt::Never)
    }

    /// Walk a dotted path through records, forcing each step to WHNF. The result is a closurized
    /// value that stays valid for this Engine's lifetime.
    pub fn lookup(&mut self, path: &str) -> Result<Held, Diagnostic> {
        let mut cur = self.config.clone();
        for seg in path.split('.') {
            let rec = cur
                .value
                .as_record()
                .ok_or_else(|| format!("`{seg}`: not a record"))?;
            let field = rec
                .get(LocIdent::from(Ident::new(seg)))
                .ok_or_else(|| format!("missing field `{seg}`"))?
                .value_with_pending_contracts()
                .ok_or_else(|| format!("field `{seg}` has no value"))?;
            cur = self.whnf(Closure { value: field, env: cur.env.clone() })?;
        }
        Ok(cur)
    }

    pub fn whnf(&mut self, c: Closure) -> Result<Held, Diagnostic> {
        let r = VirtualMachine::new(&mut self.ctx).eval_closure(c);
        match r {
            Ok(v) => Ok(v),
            Err(e) => Err(Self::report(&mut self.ctx, e.into())),
        }
    }

    /// Apply `f` to `args` and evaluate the result fully.
    /// Host-built args are closed (no free variables), so evaluating the application in the
    /// function's own environment is sound.
    pub fn call(&mut self, f: &Held, args: &[NickelValue]) -> Result<NickelValue, Diagnostic> {
        let mut term = f.value.clone();
        for a in args {
            term = NickelValue::term_posless(Term::app(term, a.clone()));
        }
        let c = Closure { value: term, env: f.env.clone() };
        let r = VirtualMachine::new(&mut self.ctx)
            .eval_full_closure(c)
            .map(|c| c.value);
        match r {
            Ok(v) => Ok(v),
            Err(e) => Err(Self::report(&mut self.ctx, e.into())),
        }
    }
}

/// Host data in. Spike convention: a JSON string starting with `'` becomes an enum tag. A real
/// binding knows which fields are enums from the typed record it receives.
pub fn from_json(j: &serde_json::Value) -> NickelValue {
    use serde_json::Value as J;
    match j {
        J::Null => NickelValue::null(),
        J::Bool(b) => NickelValue::bool_value_posless(*b),
        J::Number(n) => {
            if let Some(i) = n.as_i64() {
                NickelValue::number_posless(i)
            } else {
                // Nickel numbers are exact rationals; floats convert exactly.
                let f = n.as_f64().unwrap();
                NickelValue::number_posless(
                    nickel_lang_core::term::Number::try_from(f).unwrap(),
                )
            }
        }
        J::String(s) => match s.strip_prefix('\'') {
            Some(tag) => NickelValue::enum_tag_posless(LocIdent::from(Ident::new(tag))),
            None => NickelValue::string_posless(s.as_str()),
        },
        J::Array(xs) => NickelValue::array_posless(
            xs.iter().map(from_json).collect::<Array>(),
            Vec::new(),
        ),
        J::Object(m) => NickelValue::record_posless(RecordData::with_field_values(
            m.iter()
                .map(|(k, v)| (LocIdent::from(Ident::new(k)), from_json(v))),
        )),
    }
}

/// Fully evaluated value out. Enum tags come back as `'tag` strings.
pub fn to_json(v: &NickelValue) -> serde_json::Value {
    use serde_json::Value as J;
    match v.content_ref() {
        ValueContentRef::Null => J::Null,
        ValueContentRef::Bool(b) => J::Bool(b),
        ValueContentRef::Number(n) => {
            let f = f64::rounding_from(n, malachite_rounding()).0;
            serde_json::json!(f)
        }
        ValueContentRef::String(s) => J::String(s.to_string()),
        ValueContentRef::EnumVariant(ev) => J::String(format!("'{}", ev.tag.label())),
        ValueContentRef::Array(a) => J::Array(a.iter().map(to_json).collect()),
        ValueContentRef::Record(r) => {
            let mut m = serde_json::Map::new();
            if let Some(data) = r.into_opt() {
                for (k, f) in data.fields.iter() {
                    if let Some(v) = &f.value {
                        m.insert(k.label().to_string(), to_json(v));
                    }
                }
            }
            J::Object(m)
        }
        _ => J::String(format!("<unevaluated: {v:?}>")),
    }
}

use nickel_lang_core::term::RoundingFrom;
fn malachite_rounding() -> nickel_lang_core::term::RoundingMode {
    nickel_lang_core::term::RoundingMode::Nearest
}

// ---- C ABI used by the Swift caller (JSON in, JSON out). -------------------------------------

use std::ffi::{CStr, CString, c_char};

fn reply(r: Result<serde_json::Value, Diagnostic>) -> *mut c_char {
    let v = match r {
        Ok(v) => serde_json::json!({ "ok": v }),
        Err(d) => serde_json::json!({ "error": d }),
    };
    CString::new(v.to_string()).unwrap().into_raw()
}

#[unsafe(no_mangle)]
pub extern "C" fn wm_load(path: *const c_char, err: *mut *mut c_char) -> *mut Engine {
    let path = unsafe { CStr::from_ptr(path) }.to_str().unwrap();
    match Engine::load(path) {
        Ok(e) => Box::into_raw(Box::new(e)),
        Err(d) => {
            unsafe { *err = reply(Err(d)) };
            std::ptr::null_mut()
        }
    }
}

/// `request` is `{"fn": "filters.here", "args": [...]}` or, for one call per window,
/// `{"fn": ..., "each": [w, ...], "rest": [ctx, ...]}` which returns an array of results.
#[unsafe(no_mangle)]
pub extern "C" fn wm_call(e: *mut Engine, request: *const c_char) -> *mut c_char {
    let e = unsafe { &mut *e };
    let req = unsafe { CStr::from_ptr(request) }.to_str().unwrap();
    reply(handle(e, req))
}

pub fn handle(e: &mut Engine, req: &str) -> Result<serde_json::Value, Diagnostic> {
    let req: serde_json::Value = serde_json::from_str(req).map_err(|x| x.to_string())?;
    let f = e.lookup(req["fn"].as_str().ok_or("fn missing")?)?;
    if let Some(each) = req["each"].as_array() {
        let rest: Vec<_> = req["rest"].as_array().map(|r| r.iter().map(from_json).collect()).unwrap_or_default();
        let mut out = Vec::with_capacity(each.len());
        for w in each {
            let mut args = vec![from_json(w)];
            args.extend(rest.iter().cloned());
            out.push(to_json(&e.call(&f, &args)?));
        }
        return Ok(serde_json::Value::Array(out));
    }
    let args: Vec<_> = req["args"].as_array().map(|a| a.iter().map(from_json).collect()).unwrap_or_default();
    Ok(to_json(&e.call(&f, &args)?))
}

#[unsafe(no_mangle)]
pub extern "C" fn wm_free_string(s: *mut c_char) {
    if !s.is_null() {
        drop(unsafe { CString::from_raw(s) });
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn wm_free(e: *mut Engine) {
    if !e.is_null() {
        drop(unsafe { Box::from_raw(e) });
    }
}
