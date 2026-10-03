//! `winmux-nickel convert`: a one-time translation of a `winmux.toml` into Nickel source.
//!
//! Nickel reads the TOML itself, through an import. This module prints the result as a config
//! that merges the converted settings over the shipped defaults and applies `W.Config`.

use std::path::Path;

use serde_json::Value;

use crate::engine::{Diagnostic, evaluate_to_json, nickel_string};

pub struct Converted {
    pub nickel: String,
    pub warnings: Vec<String>,
}

pub fn convert(toml: &Path, library: &Path) -> Result<Converted, Diagnostic> {
    let path = std::path::absolute(toml).map_err(|e| format!("{}: {e}", toml.display()))?;
    let source = format!("import {} as 'Toml", nickel_string(&path.to_string_lossy()));
    let Value::Object(mut settings) = evaluate_to_json(&source, library)? else {
        return Err(format!("{}: not a TOML table", path.display()));
    };

    // `reload-on-save` replaced this setting.
    if let Some(value) = settings.remove("auto-reload-config") {
        settings.insert("reload-on-save".to_owned(), value);
    }

    let mut warnings = Vec::new();
    let mut rules = String::new();
    if let Some(Value::Array(entries)) = settings.remove("on-window-detected") {
        for (index, entry) in entries.iter().enumerate() {
            let number = index + 1;
            warnings.push(format!(
                "on-window-detected rule {number} is not converted: Policy hooks replace these rules, and it is left as a commented-out `arrive` branch"
            ));
            rules.push_str(&format!("  # on-window-detected rule {number}, as a branch of `arrive = fun w ctx cols => …`:\n"));
            rules.push_str(&format!("  #   {}\n", arrive_branch(entry)));
        }
    }

    // A TOML config replaced the default bindings wholesale, so the converted one must too.
    let defaults = if settings.contains_key("mode") { r#"std.record.remove "mode" defaults"# } else { "defaults" };
    let mut nickel = format!("# Converted from {} by `winmux config convert`.\n", path.display());
    nickel.push_str("let W = import \"winmux/winmux.ncl\" in\n");
    nickel.push_str("let defaults = import \"winmux/defaults.ncl\" in\n");
    if settings.contains_key("mode") {
        nickel.push_str("# Your bindings replace the default ones. To add them to the defaults instead, merge over\n");
        nickel.push_str("# `defaults` itself.\n");
    }
    nickel.push_str(&format!("(({defaults}) & {{\n"));
    write_fields(&settings, 1, &mut nickel);
    nickel.push_str(&rules);
    nickel.push_str("}) | W.Config\n");
    Ok(Converted { nickel, warnings })
}

fn arrive_branch(entry: &Value) -> String {
    let mut conditions = Vec::new();
    if let Some(matcher) = entry.get("if").and_then(Value::as_object) {
        for (key, value) in matcher {
            let Some(text) = value.as_str().map(nickel_string) else {
                conditions.push(format!("# {key} = {value}"));
                continue;
            };
            conditions.push(match key.as_str() {
                "app-id" => format!("w.app.bundleId == {text}"),
                "workspace" => format!("w.workspace == {text}"),
                "app-name-regex-substring" => format!("std.string.is_match {} w.app.name", case_insensitive(value)),
                "window-title-regex-substring" => format!("std.string.is_match {} w.title", case_insensitive(value)),
                _ => format!("# {key} = {text}"),
            });
        }
    }
    let condition = if conditions.is_empty() { "true".to_owned() } else { conditions.join(" && ") };
    let run = entry.get("run").map_or_else(|| "[]".to_owned(), |run| value_inline(&commands(run)));
    format!("if {condition} then {{ run = {run} }} else …")
}

fn case_insensitive(regex: &Value) -> String {
    nickel_string(&format!("(?i){}", regex.as_str().unwrap_or_default()))
}

fn commands(run: &Value) -> Value {
    match run {
        Value::String(_) => Value::Array(vec![run.clone()]),
        other => other.clone(),
    }
}

fn write_fields(fields: &serde_json::Map<String, Value>, depth: usize, out: &mut String) {
    let indent = "  ".repeat(depth);
    for (name, value) in fields {
        match value {
            Value::Object(children) if !children.is_empty() => {
                out.push_str(&format!("{indent}{} = {{\n", field_name(name)));
                write_fields(children, depth + 1, out);
                out.push_str(&format!("{indent}}},\n"));
            }
            value => out.push_str(&format!("{indent}{} = {},\n", field_name(name), value_inline(value))),
        }
    }
}

fn value_inline(value: &Value) -> String {
    match value {
        Value::Null => "null".to_owned(),
        Value::Bool(b) => b.to_string(),
        Value::Number(n) => n.to_string(),
        Value::String(s) => nickel_string(s),
        Value::Array(items) => format!("[{}]", items.iter().map(value_inline).collect::<Vec<_>>().join(", ")),
        Value::Object(fields) => {
            let fields: Vec<String> =
                fields.iter().map(|(name, value)| format!("{} = {}", field_name(name), value_inline(value))).collect();
            if fields.is_empty() { "{}".to_owned() } else { format!("{{ {} }}", fields.join(", ")) }
        }
    }
}

fn field_name(name: &str) -> String {
    const RESERVED: &[&str] = &[
        "if", "then", "else", "let", "in", "fun", "match", "forall", "import", "include", "rec", "null", "true",
        "false", "or", "as", "default", "force", "optional", "priority", "doc", "not_exported", "Dyn", "Number",
        "Bool", "String", "Array",
    ];
    let mut chars = name.trim_start_matches('_').chars();
    let plain = chars.next().is_some_and(|c| c.is_ascii_alphabetic())
        && chars.all(|c| c.is_ascii_alphanumeric() || matches!(c, '_' | '-' | '\''))
        && !RESERVED.contains(&name);
    if plain { name.to_owned() } else { nickel_string(name) }
}
