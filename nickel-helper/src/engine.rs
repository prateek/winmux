//! Holds one evaluated config and calls its functions.
//!
//! One `VmContext` lives as long as the loaded config. A function pulled out of the config is
//! kept as a `Closure` (value plus environment), because a function wrapped by a function
//! contract refers to that environment; applying it later evaluates `Term::app` over the same
//! context without parsing anything again.

use std::{
    collections::BTreeSet,
    ffi::OsString,
    io::Cursor,
    path::{Path, PathBuf},
};

use nickel_lang_core::{
    cache::{CacheHub, InputFormat, SourcePath},
    error::{
        Error as CoreError, NullReporter,
        report::{ColorOpt, report_as_str},
    },
    eval::{
        Closure, VirtualMachine, VmContext,
        cache::CacheImpl,
        value::{NickelValue, ValueContentRef},
    },
    files::FileId,
    identifier::{Ident, LocIdent},
    term::{RoundingFrom, RoundingMode, Term},
};

/// Nickel's own diagnostic text, as the `nickel` CLI prints it.
pub type Diagnostic = String;

pub enum Source<'a> {
    File(&'a Path),
    /// The shipped defaults, loaded as the config when the user has no config file.
    Defaults,
}

const DEFAULTS_EXPR: &str = r#"(import "winmux/defaults.ncl") | (import "winmux/winmux.ncl").Config"#;

pub struct Engine {
    ctx: VmContext<CacheHub, CacheImpl>,
    config: Closure,
    main: FileId,
    /// Nickel source that denotes the loaded config, for sources compiled after the load.
    config_expr: String,
    compiled_filters: usize,
}

impl Engine {
    /// Parses, typechecks and evaluates the config to weak head normal form. `library` is the
    /// directory that holds `winmux/`, so a config can import `winmux/winmux.ncl`.
    pub fn load(source: Source, library: &Path) -> Result<Engine, Diagnostic> {
        let mut ctx = VmContext::new(CacheHub::new(), std::io::sink(), NullReporter {});
        ctx.import_resolver.sources.add_import_paths(std::iter::once(OsString::from(library)));
        let (main, config_expr) = match source {
            Source::File(path) => {
                let path = std::path::absolute(path).map_err(|e| format!("{}: {e}", path.display()))?;
                let text = std::fs::read_to_string(&path).map_err(|e| format!("{}: {e}", path.display()))?;
                let expr = format!("import {}", nickel_string(&path.to_string_lossy()));
                let id = ctx
                    .import_resolver
                    .sources
                    .add_source(SourcePath::Path(path, InputFormat::Nickel), Cursor::new(text))
                    .map_err(|e| e.to_string())?;
                (id, expr)
            }
            Source::Defaults => {
                let id = ctx
                    .import_resolver
                    .sources
                    .add_string(SourcePath::Generated("defaults".to_owned()), DEFAULTS_EXPR.to_owned());
                (id, format!("({DEFAULTS_EXPR})"))
            }
        };
        let config = Self::evaluate(&mut ctx, main)?;
        Ok(Engine { ctx, config, main, config_expr, compiled_filters: 0 })
    }

    fn evaluate(ctx: &mut VmContext<CacheHub, CacheImpl>, file: FileId) -> Result<Closure, Diagnostic> {
        let prepared = match ctx.prepare_eval(file) {
            Ok(value) => value,
            Err(e) => return Err(Self::report(ctx, e)),
        };
        let result = VirtualMachine::new(ctx).eval_closure(prepared.into());
        result.map_err(|e| Self::report(ctx, e.into()))
    }

    fn report(ctx: &mut VmContext<CacheHub, CacheImpl>, error: CoreError) -> Diagnostic {
        let mut files = ctx.import_resolver.sources.files().clone();
        report_as_str(&mut files, error, ColorOpt::Never)
    }

    /// The whole config, fully evaluated, without its functions. Evaluating it applies every
    /// contract, so a wrong type or an unknown key fails here.
    pub fn static_json(&mut self) -> Result<serde_json::Value, Diagnostic> {
        let result = VirtualMachine::new(&mut self.ctx).eval_full_closure(self.config.clone());
        match result {
            Ok(closure) => Ok(to_json(&closure.value).unwrap_or(serde_json::Value::Null)),
            Err(e) => Err(Self::report(&mut self.ctx, e.into())),
        }
    }

    /// The config file and every file it imports, directly or not.
    pub fn imports(&self) -> Vec<PathBuf> {
        let mut seen = BTreeSet::from([self.main]);
        let mut queue = vec![self.main];
        while let Some(file) = queue.pop() {
            for imported in self.ctx.import_resolver.import_data.imports(file) {
                if seen.insert(imported) {
                    queue.push(imported);
                }
            }
        }
        let mut paths: Vec<PathBuf> = seen
            .into_iter()
            .map(|file| PathBuf::from(self.ctx.import_resolver.sources.name(file)))
            .filter(|path| path.is_absolute())
            .collect();
        paths.sort();
        paths
    }

    /// Walks `path` through the config's records, forcing each step. `None` means a field on
    /// the path is absent.
    pub fn lookup(&mut self, path: &[&str]) -> Result<Option<Closure>, Diagnostic> {
        let mut current = self.config.clone();
        for segment in path {
            let Some(record) = current.value.as_record() else { return Ok(None) };
            let Some(data) = record.into_opt() else { return Ok(None) };
            let Some(field) = data.fields.get(&LocIdent::from(Ident::new(*segment))) else { return Ok(None) };
            let Some(value) = field.value_with_pending_contracts() else { return Ok(None) };
            current = self.whnf(Closure { value, env: current.env.clone() })?;
        }
        Ok(Some(current))
    }

    /// The names of the fields of the record at `path`, or nothing if there is no record there.
    pub fn field_names(&mut self, path: &[&str]) -> Result<Vec<String>, Diagnostic> {
        let Some(closure) = self.lookup(path)? else { return Ok(Vec::new()) };
        let Some(record) = closure.value.as_record() else { return Ok(Vec::new()) };
        let Some(data) = record.into_opt() else { return Ok(Vec::new()) };
        let mut names: Vec<String> = data.fields.keys().map(|name| name.label().to_owned()).collect();
        names.sort();
        Ok(names)
    }

    fn whnf(&mut self, closure: Closure) -> Result<Closure, Diagnostic> {
        let result = VirtualMachine::new(&mut self.ctx).eval_closure(closure);
        result.map_err(|e| Self::report(&mut self.ctx, e.into()))
    }

    /// Applies `function` to `args` and evaluates the result fully. Host-built arguments have no
    /// free variables, so evaluating the application in the function's environment is sound.
    pub fn call(&mut self, function: &Closure, args: &[NickelValue]) -> Result<NickelValue, Diagnostic> {
        let mut term = function.value.clone();
        for arg in args {
            term = NickelValue::term_posless(Term::app(term, arg.clone()));
        }
        let closure = Closure { value: term, env: function.env.clone() };
        let result = VirtualMachine::new(&mut self.ctx).eval_full_closure(closure);
        match result {
            Ok(closure) => Ok(closure.value),
            Err(e) => Err(Self::report(&mut self.ctx, e.into())),
        }
    }

    /// Compiles a Filter given as the text of a function body, with `w` and `ctx` bound and the
    /// config's named Filters bound as `filters`.
    pub fn compile_filter(&mut self, body: &str) -> Result<Closure, Diagnostic> {
        self.compiled_filters += 1;
        let source = format!(
            "let filters = ({}).filters in\nfun w ctx =>\n{body}\n",
            self.config_expr
        );
        let file = self
            .ctx
            .import_resolver
            .sources
            .add_string(SourcePath::Generated(format!("filter {}", self.compiled_filters)), source);
        Self::evaluate(&mut self.ctx, file)
    }
}

pub fn is_function(value: &NickelValue) -> bool {
    value.type_of() == Some("Function")
}

/// Writes `text` as a Nickel string literal.
pub fn nickel_string(text: &str) -> String {
    let mut out = String::with_capacity(text.len() + 2);
    out.push('"');
    let mut chars = text.chars().peekable();
    while let Some(c) = chars.next() {
        match c {
            '"' => out.push_str("\\\""),
            '\\' => out.push_str("\\\\"),
            '\n' => out.push_str("\\n"),
            '\r' => out.push_str("\\r"),
            '\t' => out.push_str("\\t"),
            // `%{` starts an interpolation.
            '%' if chars.peek() == Some(&'{') => out.push_str("\\%"),
            c => out.push(c),
        }
    }
    out.push('"');
    out
}

/// A fully evaluated value as JSON. Functions and other values JSON cannot carry come back as
/// `None`, and a record or array leaves them out. An enum tag becomes its name.
pub fn to_json(value: &NickelValue) -> Option<serde_json::Value> {
    use serde_json::Value as J;
    Some(match value.content_ref() {
        ValueContentRef::Null => J::Null,
        ValueContentRef::Bool(b) => J::Bool(b),
        ValueContentRef::Number(n) => {
            // WinMux reads whole numbers as integers, so `10` must not come out as `10.0`.
            match i64::try_from(n) {
                Ok(integer) => serde_json::json!(integer),
                Err(_) => serde_json::json!(f64::rounding_from(n, RoundingMode::Nearest).0),
            }
        }
        ValueContentRef::String(s) => J::String(s.to_string()),
        ValueContentRef::EnumVariant(variant) if variant.arg.is_none() => J::String(variant.tag.label().to_owned()),
        ValueContentRef::Array(array) => J::Array(array.iter().filter_map(to_json).collect()),
        ValueContentRef::Record(record) => {
            let mut map = serde_json::Map::new();
            if let Some(data) = record.into_opt() {
                for (name, field) in data.fields.iter() {
                    if field.metadata.not_exported() {
                        continue;
                    }
                    if let Some(json) = field.value.as_ref().and_then(to_json) {
                        map.insert(name.label().to_owned(), json);
                    }
                }
            }
            J::Object(map)
        }
        _ => return None,
    })
}
