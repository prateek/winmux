//! The requests WinMux sends, one JSON object per line, and the replies.

use std::path::{Path, PathBuf};

use nickel_lang_core::eval::{Closure, value::NickelValue};
use serde::Deserialize;
use serde_json::{Value, json};

use crate::{
    engine::{Diagnostic, Engine, Source, is_function, to_json},
    host::HostValue,
    records::{self, FilterContext, Window},
};

#[derive(Deserialize)]
#[serde(tag = "op", rename_all = "kebab-case")]
enum Request {
    /// Evaluates a config file, or the shipped defaults when `path` is null.
    Load { path: Option<PathBuf> },
    Filter { lens: String, ctx: FilterContext, windows: Vec<Window> },
    Hook { hook: String, args: Vec<Value> },
    EvalFilter { filter: String, ctx: FilterContext, windows: Vec<Window> },
}

pub struct Helper {
    library: PathBuf,
    engine: Option<Engine>,
}

impl Helper {
    pub fn new(library: PathBuf) -> Helper {
        Helper { library, engine: None }
    }

    /// Answers one request line with one reply line. A failed request leaves the helper serving.
    pub fn handle_line(&mut self, line: &str) -> String {
        let (id, result) = match serde_json::from_str::<Value>(line) {
            Ok(request) => (request.get("id").cloned().unwrap_or(Value::Null), self.handle(request)),
            Err(e) => (Value::Null, Err(format!("request is not JSON: {e}"))),
        };
        let rss = crate::rss::resident_bytes();
        match result {
            Ok(result) => json!({ "id": id, "ok": true, "result": result, "rss": rss }),
            Err(error) => json!({ "id": id, "ok": false, "error": error, "rss": rss }),
        }
        .to_string()
    }

    fn handle(&mut self, request: Value) -> Result<Value, Diagnostic> {
        // Deserialising checks every host record before any Nickel runs.
        let request: Request = serde_json::from_value(request).map_err(|e| format!("bad request: {e}"))?;
        match request {
            Request::Load { path } => {
                let (engine, result) = load(path.as_deref(), &self.library)?;
                self.engine = Some(engine);
                Ok(result)
            }
            Request::Filter { lens, ctx, windows } => {
                let engine = self.engine()?;
                let filter = engine.lookup(&["lenses", &lens, "filter"])?;
                if filter.is_none() && engine.lookup(&["lenses", &lens])?.is_none() {
                    return Err(format!("no Lens named `{lens}`"));
                }
                match_bits(engine, filter.as_ref(), &ctx, &windows)
            }
            Request::EvalFilter { filter, ctx, windows } => {
                let engine = self.engine()?;
                let filter = engine.compile_filter(&filter)?;
                match_bits(engine, Some(&filter), &ctx, &windows)
            }
            Request::Hook { hook, args } => {
                let types = records::hook_args(&hook).ok_or_else(|| format!("no Policy hook named `{hook}`"))?;
                if args.len() != types.len() {
                    return Err(format!("`{hook}` takes {} arguments, got {}", types.len(), args.len()));
                }
                let args = types
                    .iter()
                    .zip(args)
                    .enumerate()
                    .map(|(index, (ty, arg))| ty.to_nickel(arg).map_err(|e| format!("`{hook}` argument {index}: {e}")))
                    .collect::<Result<Vec<_>, _>>()?;
                let engine = self.engine()?;
                let path: Vec<&str> = hook.split('.').collect();
                let function = engine.lookup(&path)?.ok_or_else(|| format!("the config does not define `{hook}`"))?;
                let result = engine.call(&function, &args)?;
                Ok(to_json(&result).unwrap_or(Value::Null))
            }
        }
    }

    fn engine(&mut self) -> Result<&mut Engine, Diagnostic> {
        self.engine.as_mut().ok_or_else(|| "no config is loaded".to_owned())
    }
}

/// Loads a config, checks its contracts and smoke-runs its functions. The result holds the
/// static settings and every file the config was read from.
pub fn load(path: Option<&Path>, library: &Path) -> Result<(Engine, Value), Diagnostic> {
    let source = path.map_or(Source::Defaults, Source::File);
    let mut engine = Engine::load(source, library)?;
    let config = engine.static_json()?;
    smoke_run(&mut engine)?;
    let imports: Vec<String> = engine.imports().iter().map(|p| p.to_string_lossy().into_owned()).collect();
    Ok((engine, json!({ "config": config, "imports": imports })))
}

/// One match bit per window. A Lens without a Filter matches every window.
fn match_bits(
    engine: &mut Engine,
    filter: Option<&Closure>,
    ctx: &FilterContext,
    windows: &[Window],
) -> Result<Value, Diagnostic> {
    let Some(filter) = filter else { return Ok(json!(vec![true; windows.len()])) };
    let ctx = ctx.to_nickel();
    let mut bits = Vec::with_capacity(windows.len());
    for window in windows {
        bits.push(call_filter(engine, filter, window.to_nickel(), ctx.clone())?);
    }
    Ok(json!(bits))
}

fn call_filter(
    engine: &mut Engine,
    filter: &Closure,
    window: NickelValue,
    ctx: NickelValue,
) -> Result<bool, Diagnostic> {
    let result = engine.call(filter, &[window, ctx])?;
    result.as_bool().ok_or_else(|| {
        format!("a Filter must return a Bool, got {}", to_json(&result).unwrap_or(Value::Null))
    })
}

/// Calls every Filter and Policy hook in the config against synthetic, fully populated
/// arguments. Reading a missing field is an error in Nickel, so a misspelled field name fails
/// here, at load, instead of at first use.
fn smoke_run(engine: &mut Engine) -> Result<(), Diagnostic> {
    let mut filters: Vec<(String, Closure)> = Vec::new();
    for name in engine.field_names(&["filters"])? {
        if let Some(filter) = engine.lookup(&["filters", &name])?.filter(|f| is_function(&f.value)) {
            filters.push((format!("filters.{name}"), filter));
        }
    }
    for name in engine.field_names(&["lenses"])? {
        if let Some(filter) = engine.lookup(&["lenses", &name, "filter"])?.filter(|f| is_function(&f.value)) {
            filters.push((format!("lenses.{name}.filter"), filter));
        }
    }
    for pass in records::smoke_passes() {
        for (name, filter) in &filters {
            call_filter(engine, filter, pass.window.clone(), pass.context.clone())
                .map_err(|e| format!("smoke run of `{name}` failed:\n{e}"))?;
        }
    }
    for (hook, types) in records::HOOKS {
        let path: Vec<&str> = hook.split('.').collect();
        let Some(function) = engine.lookup(&path)?.filter(|f| is_function(&f.value)) else { continue };
        for args in records::hook_smoke_passes(types) {
            engine.call(&function, &args).map_err(|e| format!("smoke run of `{hook}` failed:\n{e}"))?;
        }
    }
    Ok(())
}
