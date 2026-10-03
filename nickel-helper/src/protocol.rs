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
    CheckFilter { filter: String },
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
        let request: Request = serde_json::from_value(request).map_err(|e| format!("bad request: {e}"))?;
        match request {
            Request::Load { path } => {
                let (engine, result) = load(path.as_deref(), &self.library)?;
                self.engine = Some(engine);
                Ok(result)
            }
            Request::Filter { lens, ctx, windows } => {
                let engine = self.engine()?;
                let filter = match engine.lookup(&["lenses", &lens, "when", "default", "filter"])? {
                    Some(filter) => Some(filter),
                    None => engine.lookup(&["lenses", &lens, "filter"])?,
                };
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
            Request::CheckFilter { filter } => {
                let engine = self.engine()?;
                let filter = engine.compile_filter(&filter)?;
                for pass in records::smoke_passes() {
                    call_filter(engine, &filter, pass.window, pass.context)?;
                }
                Ok(Value::Null)
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
                let function = engine.lookup_hook(&hook)?.ok_or_else(|| format!("the config does not define `{hook}`"))?;
                let result = engine.call_hook(&function, &args, &hook)?;
                Ok(to_json(&result).unwrap_or(Value::Null))
            }
        }
    }

    fn engine(&mut self) -> Result<&mut Engine, Diagnostic> {
        self.engine.as_mut().ok_or_else(|| "no config is loaded".to_owned())
    }
}

/// Loads a config, checks its contracts and smoke-runs its functions. The result holds the
/// static settings, every file the config was read from, and the directory of the shipped library.
pub fn load(path: Option<&Path>, library: &Path) -> Result<(Engine, Value), Diagnostic> {
    let source = path.map_or(Source::Defaults, Source::File);
    let mut engine = Engine::load(source, library)?;
    let mut config = engine.static_json()?;
    let warnings = normalize_columns(&mut config)?;
    smoke_run(&mut engine)?;
    let imports: Vec<String> = engine.imports().iter().map(|p| p.to_string_lossy().into_owned()).collect();
    Ok((engine, json!({ "config": config, "imports": imports, "library": library.to_string_lossy(), "warnings": warnings })))
}

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
    for name in engine.field_names(&["lenses"])? {
        for profile in engine.field_names(&["lenses", &name, "when"])? {
            if let Some(filter) = engine.lookup(&["lenses", &name, "when", &profile, "filter"])? {
                filters.push((format!("lenses.{name}.when.{profile}.filter"), filter));
            }
        }
    }
    for pass in records::smoke_passes() {
        for (name, filter) in &filters {
            call_filter(engine, filter, pass.window.clone(), pass.context.clone())
                .map_err(|e| format!("smoke run of `{name}` failed:\n{e}"))?;
        }
    }
    for hook in engine.hook_paths()? {
        let types = records::hook_args(&hook).unwrap();
        let Some(function) = engine.lookup_hook(&hook)?.filter(|f| is_function(&f.value)) else { continue };
        for args in records::hook_smoke_passes(types) {
            engine.call_hook(&function, &args, &hook).map_err(|e| format!("smoke run of `{hook}` failed:\n{e}"))?;
        }
    }
    Ok(())
}

fn normalize_columns(config: &mut Value) -> Result<Vec<String>, Diagnostic> {
    // `value["key"]` on a `&mut Value` inserts a null for a missing key, so absent records are skipped.
    fn normalize(record: Option<&mut Value>, path: &str, warnings: &mut Vec<String>) {
        let Some(record) = record else { return };
        if let Some(widths) = record.get_mut("widths").and_then(Value::as_array_mut) {
            let total: f64 = widths.iter().filter_map(Value::as_f64).sum();
            if total > 0.0 && (total - 1.0).abs() > 1e-8 {
                warnings.push(format!("{path}.widths sum to {total}; normalized proportionally to 1"));
                for width in widths { *width = json!(width.as_f64().unwrap() / total); }
            }
        }
        if let Some(profiles) = record.get_mut("when").and_then(Value::as_object_mut) {
            for (name, profile) in profiles { normalize(Some(profile), &format!("{path}.when.{name}"), warnings); }
        }
    }
    fn overlay(base: &mut Value, value: &Value) {
        for key in ["count", "widths"] {
            if let Some(field) = value.get(key) { base[key] = field.clone(); }
        }
    }
    fn validate(value: &Value, path: &str) -> Result<(), Diagnostic> {
        if let Some(count) = value["count"].as_u64() {
            if let Some(widths) = value["widths"].as_array() {
                if widths.len() != count as usize {
                    return Err(format!("{path}.columns.widths length {} differs from resolved count {count}", widths.len()));
                }
            }
        }
        Ok(())
    }
    let mut warnings = Vec::new();
    normalize(config.get_mut("columns"), "columns", &mut warnings);
    let mut base = json!({"count": "off"});
    overlay(&mut base, &config["columns"]);
    overlay(&mut base, &config["columns"]["when"]["default"]);
    validate(&base, "default")?;
    if let Some(workspaces) = config.get_mut("workspace").and_then(Value::as_object_mut) {
        for (name, workspace) in workspaces {
            normalize(workspace.get_mut("columns"), &format!("workspace.{name}.columns"), &mut warnings);
            let mut resolved = base.clone();
            overlay(&mut resolved, &workspace["columns"]);
            overlay(&mut resolved, &workspace["columns"]["when"]["default"]);
            validate(&resolved, &format!("workspace.{name}"))?;
        }
    }
    Ok(warnings)
}
