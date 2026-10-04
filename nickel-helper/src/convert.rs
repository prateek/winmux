//! `winmux-nickel convert`: a one-time translation of a `winmux.toml` into Nickel source.
//!
//! Nickel reads the TOML itself, through an import. This module prints the result as a config
//! that merges the converted settings over the shipped defaults and applies `W.Config`.

use std::collections::{BTreeMap, BTreeSet};
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
    if settings.get("config-version").is_none_or(|v| v.as_i64().is_some_and(|n| n <= 1))
        && !settings.contains_key("persistent-workspaces")
    {
        // Nickel's import loses the order the TOML was written in, and that order is the
        // order the workspaces are listed in.
        let input = std::fs::read_to_string(&path).map_err(|e| e.to_string())?;
        let ordered: toml::Value = toml::from_str(&input).map_err(|e| e.to_string())?;
        let workspaces = inferred_workspaces(&ordered);
        if workspaces.as_array().is_some_and(|names| !names.is_empty()) {
            warnings.push(format!(
                "Inferred persistent-workspaces from legacy bindings and force assignments: {}",
                value_inline(&workspaces)
            ));
            settings.insert("persistent-workspaces".to_owned(), workspaces);
        }
    }
    settings.remove("config-version");

    let modes = settings.remove("mode");
    let converted_modes = modes
        .map(|modes| converted_modes(modes, &settings, library))
        .transpose()?;
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

    let mut nickel = format!(
        "# Converted from {} by `winmux config convert`.\n",
        path.display()
    );
    nickel.push_str("let W = import \"winmux/winmux.ncl\" in\n");
    nickel.push_str("let defaults = import \"winmux/defaults.ncl\" in\n");
    if let Some(modes) = converted_modes {
        nickel
            .push_str("# Kept from defaults: the five Lenses, lens mode keys, and main Triggers\n");
        nickel.push_str("# cmd-tab, cmd-shift-tab, cmd-backtick, alt-slash, alt-semicolon only where unbound.\n");
        nickel.push_str("# To drop a kept binding, remove its field below; to drop a Lens, remove it from defaults.lenses before merging.\n");
        nickel.push_str("let converted-modes = {\n");
        write_fields(modes.as_object().unwrap(), 1, &mut nickel);
        nickel.push_str("} in\n((std.record.remove \"mode\" defaults) & {\n  mode = converted-modes,\n");
    } else {
        nickel
            .push_str("# No TOML mode table: kept all default modes, bindings and five Lenses.\n");
        nickel.push_str("# To drop one, remove its field from defaults before merging.\n");
        nickel.push_str("(defaults & {\n");
    }
    write_fields(&settings, 1, &mut nickel);
    nickel.push_str(&rules);
    nickel.push_str("}) | W.Config\n");
    Ok(Converted { nickel, warnings })
}

const FORK_TRIGGERS: &[&str] = &[
    "cmd-tab",
    "cmd-shift-tab",
    "cmd-backtick",
    "alt-slash",
    "alt-semicolon",
];

fn converted_modes(
    mut modes: Value,
    settings: &serde_json::Map<String, Value>,
    library: &Path,
) -> Result<Value, Diagnostic> {
    let mapping = key_mapping(settings);
    let defaults = evaluate_to_json("(import \"winmux/defaults.ncl\").mode", library)?;
    let Some(table) = modes.as_object_mut() else {
        return Err("mode must be a table".to_owned());
    };
    if !table.contains_key("main") {
        return Err("mode: Please specify 'main' mode".to_owned());
    }
    for (name, mode) in table.iter() {
        let mut seen = BTreeSet::new();
        if let Some(bindings) = mode.get("binding").and_then(Value::as_object) {
            for chord in bindings.keys() {
                if !seen.insert(chord_identity(chord, &mapping)) {
                    return Err(format!(
                        "mode.{name}.binding: Binding redeclaration for '{chord}'"
                    ));
                }
            }
        }
    }
    let mut add = |mode: &str, defaults: Vec<(&str, Value)>| {
        let bindings = table
            .entry(mode.to_owned())
            .or_insert_with(|| serde_json::json!({}))
            .as_object_mut()
            .and_then(|m| {
                m.entry("binding")
                    .or_insert_with(|| serde_json::json!({}))
                    .as_object_mut()
            });
        if let Some(bindings) = bindings {
            let mut bound: BTreeSet<_> = bindings
                .keys()
                .map(|key| chord_identity(key, &mapping))
                .collect();
            for (chord, command) in defaults {
                if bound.insert(chord_identity(chord, &mapping)) {
                    bindings.insert(chord.to_owned(), command);
                }
            }
        }
    };
    add(
        "main",
        FORK_TRIGGERS
            .iter()
            .map(|key| (*key, defaults["main"]["binding"][key].clone()))
            .collect(),
    );
    add(
        "lens",
        defaults["lens"]["binding"]
            .as_object()
            .unwrap()
            .iter()
            .map(|(key, cmd)| (key.as_str(), cmd.clone()))
            .collect(),
    );
    Ok(modes)
}

fn key_mapping(settings: &serde_json::Map<String, Value>) -> BTreeMap<String, String> {
    let mut mapping = BTreeMap::new();
    let config = settings.get("key-mapping");
    let preset = config
        .and_then(|v| v.get("preset"))
        .and_then(Value::as_str)
        .unwrap_or("qwerty");
    let overrides: &[(&str, &str)] = match preset {
        "dvorak" => &[
            ("leftSquareBracket", "minus"),
            ("rightSquareBracket", "equal"),
            ("quote", "q"),
            ("comma", "w"),
            ("period", "e"),
            ("p", "r"),
            ("y", "t"),
            ("f", "y"),
            ("g", "u"),
            ("c", "i"),
            ("r", "o"),
            ("l", "p"),
            ("slash", "leftSquareBracket"),
            ("equal", "rightSquareBracket"),
            ("backslash", "backslash"),
            ("a", "a"),
            ("o", "s"),
            ("e", "d"),
            ("u", "f"),
            ("i", "g"),
            ("d", "h"),
            ("h", "j"),
            ("t", "k"),
            ("n", "l"),
            ("s", "semicolon"),
            ("minus", "quote"),
            ("semicolon", "z"),
            ("q", "x"),
            ("j", "c"),
            ("k", "v"),
            ("x", "b"),
            ("b", "n"),
            ("m", "m"),
            ("w", "comma"),
            ("v", "period"),
            ("z", "slash"),
        ],
        "colemak" => &[
            ("q", "q"),
            ("w", "w"),
            ("f", "e"),
            ("p", "r"),
            ("g", "t"),
            ("j", "y"),
            ("l", "u"),
            ("u", "i"),
            ("y", "o"),
            ("semicolon", "p"),
            ("leftSquareBracket", "leftSquareBracket"),
            ("rightSquareBracket", "rightSquareBracket"),
            ("backslash", "backslash"),
            ("a", "a"),
            ("r", "s"),
            ("s", "d"),
            ("t", "f"),
            ("d", "g"),
            ("h", "h"),
            ("n", "j"),
            ("e", "k"),
            ("i", "l"),
            ("o", "semicolon"),
            ("quote", "quote"),
            ("z", "z"),
            ("x", "x"),
            ("c", "c"),
            ("v", "v"),
            ("b", "b"),
            ("k", "n"),
            ("m", "m"),
            ("comma", "comma"),
            ("period", "period"),
            ("slash", "slash"),
        ],
        _ => &[],
    };
    for (notation, physical) in overrides {
        mapping.insert((*notation).to_owned(), (*physical).to_owned());
    }
    if let Some(aliases) = config
        .and_then(|v| v.get("key-notation-to-key-code"))
        .and_then(Value::as_object)
    {
        for (notation, code) in aliases {
            if let Some(code) = code.as_str() {
                mapping.insert(notation.clone(), code.to_owned());
            }
        }
    }
    mapping
}

fn chord_identity(chord: &str, mapping: &BTreeMap<String, String>) -> String {
    let parts: Vec<_> = chord.split('-').filter(|part| !part.is_empty()).collect();
    let Some(key) = parts.last() else {
        return chord.to_owned();
    };
    let mut modifiers = BTreeSet::new();
    for modifier in &parts[..parts.len() - 1] {
        if !["alt", "ctrl", "cmd", "shift"].contains(modifier) {
            return chord.to_owned();
        }
        modifiers.insert(*modifier);
    }
    format!(
        "{}:{}",
        modifiers.into_iter().collect::<Vec<_>>().join("-"),
        mapping.get(*key).map(String::as_str).unwrap_or(key)
    )
}

fn inferred_workspaces(settings: &toml::Value) -> Value {
    let mut names = Vec::new();
    let mut add = |name: &str| {
        if !names.iter().any(|n| n == name) {
            names.push(name.to_owned());
        }
    };
    if let Some(modes) = settings.get("mode").and_then(toml::Value::as_table) {
        for mode in modes.values() {
            if let Some(bindings) = mode.get("binding").and_then(toml::Value::as_table) {
                for binding in bindings.values() {
                    let commands: Vec<_> = match binding {
                        toml::Value::String(cmd) => vec![cmd.as_str()],
                        toml::Value::Array(cmds) => {
                            cmds.iter().filter_map(toml::Value::as_str).collect()
                        }
                        _ => vec![],
                    };
                    for command in commands {
                        let parts = split_args(command);
                        if matches!(
                            parts.first().map(String::as_str),
                            Some("workspace" | "move-node-to-workspace")
                        ) {
                            let mut args = parts.iter().skip(1);
                            while let Some(part) = args.next() {
                                if part == "--window-id" {
                                    args.next();
                                    continue;
                                }
                                if !part.starts_with("--") {
                                    if !["next", "prev"].contains(&part.as_str()) {
                                        add(part);
                                    }
                                    break;
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    if let Some(assignments) = settings
        .get("workspace-to-monitor-force-assignment")
        .and_then(toml::Value::as_table)
    {
        for name in assignments.keys() {
            add(name);
        }
    }
    serde_json::json!(names)
}

/// Splits a command the way the Swift parser's `splitArgs` does: on whitespace, with a quoted
/// run kept as one argument.
fn split_args(command: &str) -> Vec<String> {
    let mut args = Vec::new();
    let mut current = String::new();
    let mut quote = None;
    let mut started = false;
    for ch in command.chars() {
        match quote {
            Some(open) if ch == open => quote = None,
            Some(_) => current.push(ch),
            None if ch == '\'' || ch == '"' => {
                quote = Some(ch);
                started = true;
            }
            None if ch.is_whitespace() => {
                if started {
                    args.push(std::mem::take(&mut current));
                    started = false;
                }
            }
            None => {
                current.push(ch);
                started = true;
            }
        }
    }
    if started {
        args.push(current);
    }
    args
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
