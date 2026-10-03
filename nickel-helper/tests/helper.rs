//! Drives the helper the way WinMux does: one JSON request line in, one reply line out.

use std::path::{Path, PathBuf};

use serde_json::{Value, json};
use winmux_nickel::{
    engine::{Engine, Source, evaluate_to_json},
    host::HostValue,
    protocol::Helper,
    records::{Column, FilterContext, Window},
    schema,
};

fn library() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("nickel")
}

fn fixture(name: &str) -> String {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("tests/fixtures").join(name).to_string_lossy().into_owned()
}

fn request(helper: &mut Helper, request: Value) -> Value {
    serde_json::from_str(&helper.handle_line(&request.to_string())).unwrap()
}

fn load_error(config: &str) -> String {
    let mut helper = Helper::new(library());
    let reply = request(&mut helper, json!({ "id": 0, "op": "load", "path": fixture(config) }));
    assert_eq!(reply["ok"], false, "{config} loaded");
    reply["error"].as_str().unwrap().to_owned()
}

fn loaded(config: &str) -> Helper {
    let mut helper = Helper::new(library());
    let reply = request(&mut helper, json!({ "id": 0, "op": "load", "path": fixture(config) }));
    assert_eq!(reply["ok"], true, "{}", reply["error"].as_str().unwrap_or_default());
    helper
}

fn monitor() -> Value {
    json!({ "name": "Built-in Retina Display", "uuid": "37D8832A-2D66-02CA-B9F7-8F30A301B230", "builtin": true })
}

/// A Window record as WinMux sends it.
fn window(bundle_id: &str, class: &str) -> Value {
    json!({
        "id": 42,
        "title": "Inbox",
        "class": class,
        "subrole": "AXStandardWindow",
        "level": 0,
        "hasCloseButton": true,
        "document": "",
        "workspace": "1",
        "project": "default",
        "monitor": monitor(),
        "lastFocusedSeq": 0,
        "app": { "bundleId": bundle_id, "name": "Mail", "pid": 501, "accessory": false, "activationPolicy": "regular" },
    })
}

/// A Filter context with no focused, hovered or previous window.
fn context() -> Value {
    json!({
        "focused": null,
        "mouse": null,
        "previous": null,
        "workspace": { "name": "1", "project": "default" },
        "monitor": monitor(),
        "profile": "default",
    })
}

fn context_focused_on(bundle_id: &str) -> Value {
    let mut ctx = context();
    ctx["focused"] = window(bundle_id, "tiled");
    ctx
}

#[test]
fn load_returns_static_settings_without_functions_and_the_files_read() {
    let mut helper = Helper::new(library());
    let reply = request(&mut helper, json!({ "id": 7, "op": "load", "path": fixture("config.ncl") }));

    assert_eq!(reply["id"], 7);
    assert_eq!(reply["ok"], true, "{}", reply["error"]);
    assert!(reply["rss"].as_u64().unwrap() > 0);
    let config = &reply["result"]["config"];
    assert_eq!(config["lenses"]["everything"]["presentation"], "list");
    assert_eq!(config["lenses"]["mail"]["sort"], json!(["mru"]));
    assert_eq!(config["lenses"]["mail"]["filter"], "lenses.mail.filter", "only the callable path leaves the helper");
    assert_eq!(config["arrive"], "arrive");
    let imports: Vec<&str> = reply["result"]["imports"].as_array().unwrap().iter().map(|p| p.as_str().unwrap()).collect();
    assert!(imports.contains(&fixture("config.ncl").as_str()), "{imports:?}");
    assert!(imports.iter().any(|p| p.ends_with("nickel/winmux/winmux.ncl")), "{imports:?}");
    assert_eq!(reply["result"]["library"], library().to_string_lossy().as_ref());
}

#[test]
fn key_the_contracts_do_not_know_fails_the_load_with_nickels_diagnostic() {
    let mut helper = Helper::new(library());
    let reply = request(&mut helper, json!({ "id": 1, "op": "load", "path": fixture("unknown-key.ncl") }));

    assert_eq!(reply["ok"], false);
    assert!(reply["error"].as_str().unwrap().contains("extra field `gapz`"), "{}", reply["error"]);
}

#[test]
fn setting_the_config_leaves_out_comes_from_the_defaults_it_imports() {
    let mut helper = Helper::new(library());
    let over = request(&mut helper, json!({ "id": 1, "op": "load", "path": fixture("over-defaults.ncl") }));
    let total = request(&mut helper, json!({ "id": 2, "op": "load", "path": fixture("config.ncl") }));

    let config = &over["result"]["config"];
    assert_eq!(config["gaps"]["inner"], json!({ "horizontal": 0, "vertical": 8 }), "{}", over["error"]);
    assert_eq!(config["default-root-container-layout"], "tab-group", "an enum tag comes back as its name");
    assert_eq!(config["mode"]["main"]["binding"]["alt-h"], "focus left");
    assert_eq!(config["gaps"].to_string(), r#"{"inner":{"horizontal":0,"vertical":8},"outer":{"bottom":12,"left":12,"right":12,"top":12}}"#, "whole numbers are written as integers");
    // config.ncl does not import the defaults, so it has only what it sets.
    assert_eq!(total["result"]["config"]["gaps"], json!({ "inner": { "horizontal": 4 } }), "{}", total["error"]);
    assert!(total["result"]["config"].get("mode").is_none());
}

#[test]
fn no_path_loads_the_shipped_defaults() {
    let mut helper = Helper::new(library());
    let reply = request(&mut helper, json!({ "id": 1, "op": "load", "path": null }));

    assert_eq!(reply["ok"], true, "{}", reply["error"]);
    assert!(reply["result"]["config"].is_object());
    let imports = reply["result"]["imports"].as_array().unwrap();
    assert!(imports.iter().any(|p| p.as_str().unwrap().ends_with("nickel/winmux/defaults.ncl")), "{imports:?}");
}

#[test]
fn misspelled_field_fails_the_load_in_the_smoke_run() {
    let mut helper = Helper::new(library());
    let reply = request(&mut helper, json!({ "id": 1, "op": "load", "path": fixture("typo.ncl") }));

    assert_eq!(reply["ok"], false);
    let error = reply["error"].as_str().unwrap();
    assert!(error.contains("filters.mail"), "{error}");
    assert!(error.contains("missing field `bundelId`"), "{error}");
    assert!(error.contains("Did you mean `bundleId`?"), "{error}");
}

#[test]
fn batched_filter_returns_one_match_bit_per_window() {
    let mut helper = loaded("config.ncl");
    let windows: Vec<Value> = (0..50)
        .map(|i| window(if i % 5 == 0 { "com.apple.mail" } else { "com.example.other" }, "tiled"))
        .collect();

    let reply = request(
        &mut helper,
        json!({ "id": 2, "op": "filter", "lens": "mail", "ctx": context(), "windows": windows }),
    );

    assert_eq!(reply["ok"], true, "{}", reply["error"]);
    let bits = reply["result"].as_array().unwrap();
    assert_eq!(bits.len(), 50);
    for (i, bit) in bits.iter().enumerate() {
        assert_eq!(bit.as_bool().unwrap(), i % 5 == 0, "window {i}");
    }
}

#[test]
fn filter_reads_the_context_window() {
    let mut helper = loaded("config.ncl");
    let windows = json!([window("com.apple.mail", "tiled"), window("com.example.other", "tiled")]);

    let reply = request(
        &mut helper,
        json!({ "id": 2, "op": "filter", "lens": "same-app", "ctx": context_focused_on("com.example.other"), "windows": windows }),
    );

    assert_eq!(reply["result"], json!([false, true]), "{}", reply["error"]);
}

#[test]
fn lens_without_a_filter_matches_every_record_and_an_unknown_lens_fails() {
    let mut helper = loaded("config.ncl");
    let windows = json!([window("a", "tiled"), window("b", "tiled")]);

    let all = request(
        &mut helper,
        json!({ "id": 2, "op": "filter", "lens": "everything", "ctx": context(), "windows": windows }),
    );
    let unknown = request(
        &mut helper,
        json!({ "id": 3, "op": "filter", "lens": "nope", "ctx": context(), "windows": windows }),
    );

    assert_eq!(all["result"], json!([true, true]));
    assert_eq!(unknown["ok"], false);
    assert!(unknown["error"].as_str().unwrap().contains("no Lens named `nope`"));
}

#[test]
fn record_missing_a_field_is_rejected_before_any_nickel_runs() {
    // No config is loaded, so a reply about the field proves the record was checked first.
    let mut helper = Helper::new(library());
    let mut window = window("com.apple.mail", "tiled");
    window.as_object_mut().unwrap().remove("title");

    let reply = request(
        &mut helper,
        json!({ "id": 2, "op": "filter", "lens": "mail", "ctx": context(), "windows": [window] }),
    );

    assert_eq!(reply["ok"], false);
    assert!(reply["error"].as_str().unwrap().contains("missing field `title`"), "{}", reply["error"]);
}

#[test]
fn json_string_in_an_enum_field_reaches_nickel_as_an_enum_tag() {
    let mut helper = loaded("config.ncl");
    let windows = json!([window("a", "accessory-popup"), window("b", "tiled")]);

    let reply = request(
        &mut helper,
        json!({ "id": 2, "op": "filter", "lens": "popups", "ctx": context(), "windows": windows }),
    );
    let unknown_tag = request(
        &mut helper,
        json!({ "id": 3, "op": "filter", "lens": "popups", "ctx": context(), "windows": [window("a", "sideways")] }),
    );

    let mut accessory = window("a", "floating");
    accessory["app"]["activationPolicy"] = json!("accessory");
    let policy = request(
        &mut helper,
        json!({ "id": 4, "op": "filter", "lens": "accessory-apps", "ctx": context(), "windows": [accessory, window("b", "floating")] }),
    );
    let floating = request(
        &mut helper,
        json!({ "id": 5, "op": "eval-filter", "filter": "w.class == 'floating", "ctx": context(), "windows": [window("a", "floating"), window("b", "tiled")] }),
    );

    assert_eq!(reply["result"], json!([true, false]), "{}", reply["error"]);
    assert_eq!(policy["result"], json!([true, false]), "{}", policy["error"]);
    assert_eq!(floating["result"], json!([true, false]), "{}", floating["error"]);
    assert_eq!(unknown_tag["ok"], false);
    assert!(unknown_tag["error"].as_str().unwrap().contains("unknown variant `sideways`"), "{}", unknown_tag["error"]);
}

#[test]
fn eval_filter_can_call_a_named_filter() {
    let mut helper = loaded("config.ncl");
    let mut popup_mail = window("com.apple.mail", "tiled");
    popup_mail["hasCloseButton"] = json!(false);
    let windows = json!([window("com.apple.mail", "tiled"), popup_mail, window("com.example.other", "tiled")]);

    let reply = request(
        &mut helper,
        json!({ "id": 2, "op": "eval-filter", "filter": "filters.mail w ctx && w.hasCloseButton", "ctx": context(), "windows": windows }),
    );

    assert_eq!(reply["result"], json!([true, false, false]), "{}", reply["error"]);
}

#[test]
fn eval_filter_reports_a_bad_filter_with_nickels_diagnostic() {
    let mut helper = loaded("config.ncl");

    let reply = request(
        &mut helper,
        json!({ "id": 2, "op": "eval-filter", "filter": "filters.male w ctx", "ctx": context(), "windows": [window("a", "tiled")] }),
    );

    assert_eq!(reply["ok"], false);
    assert!(reply["error"].as_str().unwrap().contains("missing field `male`"), "{}", reply["error"]);
}

#[test]
fn hook_returns_its_result_as_json() {
    let mut helper = loaded("config.ncl");

    let tiled = request(
        &mut helper,
        json!({ "id": 2, "op": "hook", "hook": "arrive", "args": [window("a", "tiled"), context(), []] }),
    );
    let popup = request(
        &mut helper,
        json!({ "id": 3, "op": "hook", "hook": "arrive", "args": [window("a", "accessory-popup"), context(), []] }),
    );

    assert_eq!(tiled["result"], json!({ "workspace": "Inbox", "column": 2 }), "{}", tiled["error"]);
    assert_eq!(popup["result"], json!({ "float": true }));
}

#[test]
fn hook_requests_are_checked_against_the_hooks_arguments() {
    let mut helper = loaded("config.ncl");

    let unknown = request(&mut helper, json!({ "id": 2, "op": "hook", "hook": "depart", "args": [] }));
    let too_few = request(&mut helper, json!({ "id": 3, "op": "hook", "hook": "arrive", "args": [window("a", "tiled")] }));
    let undefined = request(
        &mut helper,
        json!({ "id": 4, "op": "hook", "hook": "columns.place", "args": [window("a", "tiled"), context(), []] }),
    );

    assert!(unknown["error"].as_str().unwrap().contains("no Policy hook named `depart`"));
    assert!(too_few["error"].as_str().unwrap().contains("takes 3 arguments, got 1"));
    assert!(undefined["error"].as_str().unwrap().contains("does not define `columns.place`"));
}

#[test]
fn failed_request_leaves_the_helper_serving() {
    let mut helper = loaded("config.ncl");
    let windows = json!([window("com.apple.mail", "tiled")]);

    let garbage: Value = serde_json::from_str(&helper.handle_line("not json")).unwrap();
    let failed = request(
        &mut helper,
        json!({ "id": 2, "op": "eval-filter", "filter": "w.nope", "ctx": context(), "windows": windows }),
    );
    let next = request(
        &mut helper,
        json!({ "id": 3, "op": "filter", "lens": "mail", "ctx": context(), "windows": windows }),
    );

    assert_eq!(garbage["ok"], false);
    assert_eq!(failed["ok"], false);
    assert_eq!(next["result"], json!([true]));
}

#[test]
fn check_exits_zero_for_a_valid_file_and_two_with_the_diagnostic_for_a_broken_one() {
    let run = |config: &str| {
        std::process::Command::new(env!("CARGO_BIN_EXE_winmux-nickel"))
            .args(["check", &fixture(config)])
            .env("WINMUX_NICKEL_LIBRARY", library())
            .output()
            .unwrap()
    };

    let valid = run("config.ncl");
    let broken = run("typo.ncl");

    assert_eq!(valid.status.code(), Some(0), "{}", String::from_utf8_lossy(&valid.stderr));
    assert_eq!(broken.status.code(), Some(2));
    assert!(String::from_utf8_lossy(&broken.stderr).contains("Did you mean `bundleId`?"));
}

fn run_helper(args: &[&str]) -> std::process::Output {
    std::process::Command::new(env!("CARGO_BIN_EXE_winmux-nickel"))
        .args(args)
        .env("WINMUX_NICKEL_LIBRARY", library())
        .output()
        .unwrap()
}

#[test]
fn convert_writes_a_config_over_the_defaults_that_passes_check() {
    let converted = run_helper(&["convert", &fixture("legacy.toml")]);
    let nickel = String::from_utf8(converted.stdout).unwrap();
    let stderr = String::from_utf8(converted.stderr).unwrap();

    assert_eq!(converted.status.code(), Some(0), "{stderr}");
    assert!(nickel.contains(r#"import "winmux/defaults.ncl""#), "{nickel}");
    assert!(nickel.ends_with("}) | W.Config\n"), "{nickel}");
    assert!(nickel.contains(r#"cmd-1 = ["workspace 1", "mode main"],"#), "{nickel}");
    assert!(nickel.contains(r#""default" = "Home","#), "{nickel}");
    assert!(nickel.contains(r#""my project" = "Work \%{x}","#), "{nickel}");

    let out = std::env::temp_dir().join(format!("winmux-nickel-convert-{}.ncl", std::process::id()));
    std::fs::write(&out, &nickel).unwrap();
    let mut helper = Helper::new(library());
    let reply = request(&mut helper, json!({ "id": 1, "op": "load", "path": out }));
    std::fs::remove_file(&out).unwrap();
    assert_eq!(reply["ok"], true, "{}", reply["error"].as_str().unwrap_or_default());
    let config = &reply["result"]["config"];
    assert_eq!(config["start-at-login"], true);
    assert_eq!(config["gaps"]["inner"], json!({ "horizontal": 4, "vertical": 8 }), "unset settings come from the defaults");
    assert_eq!(config["mode"]["main"]["binding"]["alt-h"], "focus left");
    assert_eq!(config["mode"]["main"]["binding"]["cmd-1"], json!(["workspace 1", "mode main"]));
    assert_eq!(config["mode"]["lens"]["binding"]["esc"], "mode main");
    assert_eq!(config["workspace-sidebar"]["project-labels"]["my project"], "Work %{x}");
}

#[test]
fn convert_leaves_an_on_window_detected_rule_as_a_commented_arrive_branch_and_warns() {
    let converted = run_helper(&["convert", &fixture("legacy.toml")]);
    let nickel = String::from_utf8(converted.stdout).unwrap();
    let stderr = String::from_utf8(converted.stderr).unwrap();

    assert!(stderr.contains("warning: on-window-detected rule 1 is not converted"), "{stderr}");
    assert!(!nickel.contains("\n  on-window-detected"), "{nickel}");
    assert!(
        nickel.contains(
            r#"  #   if w.app.bundleId == "com.apple.mail" && std.string.is_match "(?i)inbox" w.title then { run = ["layout floating"] } else …"#
        ),
        "{nickel}"
    );
}

#[test]
fn convert_of_the_upstream_default_config_passes_check() {
    let converted = run_helper(&["convert", &fixture("upstream-default-config.toml")]);
    let out = std::env::temp_dir().join(format!("winmux-nickel-default-{}.ncl", std::process::id()));
    std::fs::write(&out, &converted.stdout).unwrap();

    let checked = run_helper(&["check", &out.to_string_lossy()]);
    std::fs::remove_file(&out).unwrap();

    assert_eq!(converted.stderr, b"");
    assert_eq!(checked.status.code(), Some(0), "{}", String::from_utf8_lossy(&checked.stderr));
}

#[test]
fn convert_renames_the_setting_reload_on_save_replaced() {
    let toml = std::env::temp_dir().join(format!("winmux-nickel-reload-{}.toml", std::process::id()));
    std::fs::write(&toml, "auto-reload-config = false\n").unwrap();

    let converted = run_helper(&["convert", &toml.to_string_lossy()]);
    std::fs::remove_file(&toml).unwrap();
    let nickel = String::from_utf8(converted.stdout).unwrap();

    assert!(nickel.contains("\n  reload-on-save = false,\n"), "{nickel}");
    assert!(!nickel.contains("auto-reload-config"), "{nickel}");
}

#[test]
fn config_that_sets_the_replaced_setting_fails_to_load() {
    let error = load_error("auto-reload-config.ncl");

    assert!(error.contains("auto-reload-config"), "{error}");
}

#[test]
fn built_in_defaults_file_matches_the_shipped_defaults() {
    let embedded = Path::new(env!("CARGO_MANIFEST_DIR")).join("../resources/default-config.json");
    let printed = run_helper(&["defaults"]);

    assert_eq!(printed.status.code(), Some(0), "{}", String::from_utf8_lossy(&printed.stderr));
    assert_eq!(
        std::fs::read_to_string(&embedded).unwrap(),
        String::from_utf8(printed.stdout).unwrap(),
        "regenerate with `make default-config`"
    );
}

#[test]
fn eval_filter_works_in_a_config_with_no_named_filters() {
    let mut helper = loaded("over-defaults.ncl");
    let mut minimized = window("a", "minimized");
    minimized["workspace"] = json!("2");

    let reply = request(
        &mut helper,
        json!({ "id": 2, "op": "eval-filter", "filter": "w.class == 'minimized && w.workspace == \"2\"", "ctx": context(), "windows": [minimized, window("b", "tiled")] }),
    );

    assert_eq!(reply["result"], json!([true, false]), "{}", reply["error"]);
}

#[test]
fn lens_can_name_a_filter_or_write_one_inline() {
    let mut helper = loaded("config.ncl");
    let mut elsewhere = window("a", "tiled");
    elsewhere["workspace"] = json!("2");
    let windows = json!([window("com.apple.mail", "tiled"), elsewhere]);

    let named = request(&mut helper, json!({ "id": 2, "op": "filter", "lens": "mail", "ctx": context(), "windows": windows }));
    let inline = request(&mut helper, json!({ "id": 3, "op": "filter", "lens": "inline", "ctx": context(), "windows": windows }));

    assert_eq!(named["result"], json!([true, false]), "{}", named["error"]);
    assert_eq!(inline["result"], json!([true, false]), "{}", inline["error"]);
}

#[test]
fn filter_that_reads_every_field_passes_both_smoke_passes() {
    let mut helper = loaded("every-field.ncl");

    let reply = request(
        &mut helper,
        json!({ "id": 2, "op": "filter", "lens": "nope", "ctx": context(), "windows": [] }),
    );

    assert!(reply["error"].as_str().unwrap().contains("no Lens named"), "the helper is serving the config");
}

#[test]
fn context_window_read_without_a_null_guard_fails_the_load() {
    let filter = load_error("unguarded.ncl");
    let hook = load_error("unguarded-hook.ncl");

    assert!(filter.contains("smoke run of `filters.same-app` failed"), "{filter}");
    assert!(filter.contains("ctx.focused"), "{filter}");
    assert!(hook.contains("smoke run of `arrive` failed"), "{hook}");
}

#[test]
fn inline_filter_is_smoke_run_too() {
    let error = load_error("inline-typo.ncl");

    assert!(error.contains("smoke run of `lenses.mail.filter` failed"), "{error}");
    assert!(error.contains("Did you mean `bundleId`?"), "{error}");
}

#[test]
fn filter_that_does_not_return_a_bool_fails_the_load() {
    let error = load_error("not-a-bool.ncl");

    assert!(error.contains("smoke run of `filters.title` failed"), "{error}");
    assert!(error.contains("contract broken"), "{error}");
}

#[test]
fn filter_called_with_swapped_arguments_fails_at_the_field_it_reads() {
    let error = load_error("swapped-arguments.ncl");

    assert!(error.contains("smoke run of `filters.other-mail` failed"), "{error}");
    assert!(error.contains("missing field `app`"), "{error}");
    assert!(error.contains("swapped-arguments.ncl:4"), "the diagnostic points into the config:\n{error}");
    assert!(!error.contains("winmux.ncl"), "and not into the shipped library:\n{error}");
}

#[test]
fn filter_that_takes_one_argument_fails_the_load() {
    let error = load_error("one-argument.ncl");

    assert!(error.contains("smoke run of `filters.everything` failed"), "{error}");
}

#[test]
fn named_filter_that_is_not_a_function_fails_the_load() {
    let error = load_error("not-a-function.ncl");

    assert!(error.contains("expected a function"), "{error}");
    assert!(error.contains("not-a-function.ncl:3"), "{error}");
}

#[test]
fn context_missing_a_window_field_is_rejected() {
    let mut helper = loaded("config.ncl");
    let mut ctx = context();
    ctx.as_object_mut().unwrap().remove("previous");
    let mut focused_without_app = context_focused_on("a");
    focused_without_app["focused"].as_object_mut().unwrap().remove("app");

    let absent = request(&mut helper, json!({ "id": 2, "op": "filter", "lens": "mail", "ctx": ctx, "windows": [] }));
    let nested = request(&mut helper, json!({ "id": 3, "op": "filter", "lens": "mail", "ctx": focused_without_app, "windows": [] }));

    assert!(absent["error"].as_str().unwrap().contains("missing field `previous`"), "{}", absent["error"]);
    assert!(nested["error"].as_str().unwrap().contains("missing field `app`"), "{}", nested["error"]);
}

#[test]
fn schema_prints_the_version_and_every_field() {
    let text = String::from_utf8(run_helper(&["schema"]).stdout).unwrap();
    let json: Value = serde_json::from_slice(&run_helper(&["schema", "--json"]).stdout).unwrap();

    assert!(text.starts_with("contract-version 1\n"), "{text}");
    assert_eq!(json["contract-version"], 1);
    let records = json["records"].as_object().unwrap();
    assert_eq!(records.keys().collect::<Vec<_>>(), ["App", "Column", "FilterContext", "Monitor", "Window", "Workspace"]);
    for (record, fields) in records {
        let section = text.split("\n\n").find(|section| section.starts_with(&format!("{record}\n"))).unwrap_or_else(|| panic!("{record} is missing from:\n{text}"));
        for field in fields.as_array().unwrap() {
            let (name, ty, description) = (field["name"].as_str().unwrap(), field["type"].as_str().unwrap(), field["description"].as_str().unwrap());
            assert!(!description.is_empty(), "{record}.{name} has no description");
            let line = section.lines().find(|line| line.starts_with(&format!("  {name} "))).unwrap_or_else(|| panic!("{record}.{name} is missing"));
            assert!(line.contains(ty), "{line}");
        }
    }
    let field = |record: &str, name: &str| {
        records[record].as_array().unwrap().iter().find(|field| field["name"] == name).unwrap_or_else(|| panic!("{record}.{name}")).clone()
    };
    assert_eq!(field("App", "accessory")["type"], "Bool");
    assert_eq!(field("App", "activationPolicy")["enum"], json!(["regular", "accessory", "prohibited"]));
    assert_eq!(
        field("Window", "class")["enum"],
        json!(["tiled", "floating", "fullscreen", "minimized", "hidden-app", "accessory-popup", "app-popup"])
    );
    assert_eq!(field("FilterContext", "focused")["type"], "Window or null");
    assert!(text.contains("'tiled, 'floating, 'fullscreen, 'minimized, 'hidden-app, 'accessory-popup, 'app-popup"), "{text}");
}

/// A record built from nothing but what `config schema --json` says about it.
fn from_schema(schema: &Value, ty: &str, tags: &Value) -> Value {
    if let Some(inner) = ty.strip_suffix(" or null") {
        return from_schema(schema, inner, tags);
    }
    if let Some(inner) = ty.strip_prefix("Array of ") {
        return json!([from_schema(schema, inner, tags)]);
    }
    match ty {
        "String" => json!("text"),
        "Bool" => json!(false),
        "Number" => json!(3),
        "Enum" => tags.as_array().unwrap().last().unwrap().clone(),
        record => schema["records"][record]
            .as_array()
            .unwrap_or_else(|| panic!("the schema has no record {record}"))
            .iter()
            .map(|field| (field["name"].as_str().unwrap().to_owned(), from_schema(schema, field["type"].as_str().unwrap(), &field["enum"])))
            .collect::<serde_json::Map<_, _>>()
            .into(),
    }
}

#[test]
fn contracts_structs_and_schema_agree_on_every_field() {
    let generated = String::from_utf8(run_helper(&["contract"]).stdout).unwrap();
    let shipped = std::fs::read_to_string(library().join("winmux/contract.ncl")).unwrap();
    assert_eq!(shipped, generated, "regenerate with `make contract`");

    let schema = schema::schema_json();
    for (record, fields) in schema["records"].as_object().unwrap() {
        // The contract and the schema name the same fields.
        let in_contract = evaluate_to_json(&format!(r#"std.record.fields (import "winmux/contract.ncl").{record}"#), &library()).unwrap();
        let mut in_schema: Vec<&str> = fields.as_array().unwrap().iter().map(|field| field["name"].as_str().unwrap()).collect();
        in_schema.sort();
        assert_eq!(in_contract, json!(in_schema), "{record}");
    }

    // A record that holds what the schema lists, and nothing else, is one the structs accept...
    let none = Value::Null;
    let window: Window = serde_json::from_value(from_schema(&schema, "Window", &none)).unwrap();
    let context: FilterContext = serde_json::from_value(from_schema(&schema, "FilterContext", &none)).unwrap();
    let column: Column = serde_json::from_value(from_schema(&schema, "Column", &none)).unwrap();

    // ...and one the contracts accept, in every field.
    let mut engine = Engine::load(Source::Defaults, &library()).unwrap();
    let mut check = |contract: &str, value| {
        let body = format!(r#"let W = import "winmux/winmux.ncl" in std.deep_seq (w | W.{contract}) true"#);
        let function = engine.compile_filter(&body).unwrap();
        if let Err(diagnostic) = engine.call(&function, &[value, FilterContext::synthetic().to_nickel()]) {
            panic!("{contract}:\n{diagnostic}");
        }
    };
    check("Window", window.to_nickel());
    check("FilterContext", context.to_nickel());
    check("FilterContext", FilterContext::synthetic().to_nickel());
    check("Column", column.to_nickel());
    check("Window", Window::synthetic().to_nickel());
}

#[test]
fn shipped_library_declares_contract_version_one() {
    let version = evaluate_to_json(r#"(import "winmux/winmux.ncl").contract-version"#, &library()).unwrap();

    assert_eq!(version, json!(1));
}

#[test]
fn lens_contract_rejects_unknown_fields_sort_and_grid() {
    for body in ["presentation = 'grid", "frozen_thumbnail = 'dimmed", "sort = ['mystery]"] {
        let source = format!("let W = import \"winmux/winmux.ncl\" in {{ lenses.demo = {{ {body} }} }} | W.Config");
        assert!(evaluate_to_json(&source, &library()).is_err(), "accepted {body}");
    }
}

#[test]
fn lens_contract_resolves_defaults_and_key_merge() {
    let source = "let W = import \"winmux/winmux.ncl\" in { lenses.demo = { keys.\"cmd-x\" = \"close\", when.default.enabled = false, when.travel.sort = ['title] } } | W.Config";
    let value = evaluate_to_json(source, &library()).unwrap();
    let lens = &value["lenses"]["demo"];
    assert_eq!(lens["presentation"], "list");
    assert_eq!(lens["sort"], json!(["mru"]));
    assert_eq!(lens["popups"], json!([]));
    assert_eq!(lens["keys"]["enter"], "focus");
    assert_eq!(lens["keys"]["cmd-1"], "move-node-to-workspace 1");
    assert_eq!(lens["keys"]["cmd-x"], "close");
    assert_eq!(lens["when"]["default"]["enabled"], false);
    assert!(lens["when"]["default"].get("sort").is_none());
}

#[test]
fn named_filter_and_default_profile_filter_are_evaluated() {
    let mut helper = loaded("lens-profile.ncl");
    let windows = json!([window("mail", "floating"), window("mail", "tiled")]);
    for (op, field, value) in [("filter", "lens", "demo"), ("eval-filter", "filter", "floating")] {
        let reply = request(&mut helper, json!({"op": op, field: value, "ctx": context(), "windows": windows}));
        assert_eq!(reply["ok"], true, "{reply}");
        assert_eq!(reply["result"], json!([true, false]));
    }
}

#[test]
fn shipped_search_lens_can_override_sort_and_presentation() {
    let value = evaluate_to_json(r#"(import "winmux/defaults.ncl") & { lenses.search = { sort = ['title], presentation = 'strip } }"#, &library()).unwrap();
    assert_eq!(value["lenses"]["search"]["sort"], json!(["title"]));
    assert_eq!(value["lenses"]["search"]["presentation"], "strip");
}

#[test]
fn lens_keys_reject_reserved_navigation_keys_in_base_and_profile() {
    for key in ["esc", "tab", "up", "down", "left", "right", "cmd-tab", "shift-down"] {
        for field in ["keys", "when.default.keys"] {
            let source = format!("let W = import \"winmux/winmux.ncl\" in {{ lenses.demo.{field}.\"{key}\" = \"close\" }} | W.Config");
            let error = evaluate_to_json(&source, &library()).unwrap_err();
            assert!(error.contains("reserved"), "{field}.{key}: {error}");
        }
    }
}

#[test]
fn lens_settings_identify_callable_filters_including_profile_overrides() {
    let mut helper = loaded("lens-profile.ncl");
    let reply = request(&mut helper, json!({"op": "load", "path": fixture("lens-profile.ncl")}));
    let demo = &reply["result"]["config"]["lenses"]["demo"];
    assert_eq!(demo["filter"], "lenses.demo.filter");
    assert_eq!(demo["when"]["default"]["filter"], "lenses.demo.when.default.filter");
    let defaults = request(&mut helper, json!({"op": "load"}));
    assert_eq!(defaults["result"]["config"]["lenses"]["floating"]["filter"], "lenses.floating.filter");
    assert!(defaults["result"]["config"]["lenses"]["search"].get("filter").is_none());
}

#[test]
fn shipped_floating_lens_uses_the_named_overridable_filter() {
    let mut helper = Helper::new(library());
    assert_eq!(request(&mut helper, json!({"op": "load"}))["ok"], true);
    let windows = json!([window("demo", "floating"), window("demo", "tiled"), window("demo", "accessory-popup")]);
    for (op, field) in [("filter", "lens"), ("eval-filter", "filter")] {
        let reply = request(&mut helper, json!({"op": op, field: "floating", "ctx": context(), "windows": windows}));
        assert_eq!(reply["result"], json!([true, false, false]), "{reply}");
    }
    let reply = request(&mut helper, json!({"op": "load", "path": fixture("floating-over-defaults.ncl")}));
    assert_eq!(reply["ok"], true, "{reply}");
    let reply = request(&mut helper, json!({"op": "filter", "lens": "floating", "ctx": context(), "windows": windows}));
    assert_eq!(reply["result"], json!([false, true, false]), "the Lens must use the user's replacement of filters.floating: {reply}");
}

#[test]
fn miniatures_contract_rejects_incompatible_settings_and_dark_backdrop() {
    for body in [
        "presentation = 'miniatures, sections = 'workspace",
        "presentation = 'miniatures, entries = 'window",
        "presentation = 'miniatures, sort = ['mru]",
        "presentation = 'miniatures, miniatures.backdrop.darkness = 0.951",
        "presentation = 'miniatures, miniatures.backdrop.darkness = -0.1",
        "presentation = 'miniatures, miniatures.current-workspace = 'hide",
        "presentation = 'miniatures, when.default.sort = ['title]",
        "when.default = { presentation = 'miniatures, entries = 'app }",
    ] {
        let source = format!("let W = import \"winmux/winmux.ncl\" in {{ lenses.demo = {{ {body} }} }} | W.Config");
        assert!(evaluate_to_json(&source, &library()).is_err(), "accepted {body}");
    }
}

#[test]
fn overview_and_miniatures_profile_resolve_settings() {
    let value = evaluate_to_json(r#"let W = import "winmux/winmux.ncl" in (import "winmux/defaults.ncl") | W.Config"#, &library()).unwrap();
    assert_eq!(value["lenses"]["overview"]["presentation"], "miniatures");
    assert_eq!(value["lenses"]["overview"]["miniatures"]["fit"], "page");
    assert_eq!(value["lenses"]["overview"]["miniatures"]["backdrop"], json!({"darkness":0.6,"blur":true}));
    let source = r#"let W = import "winmux/winmux.ncl" in { lenses.demo = { presentation = 'miniatures, summon-hints = ['label], miniatures.current-workspace = 'hide, when.default.miniatures.fit = 'shrink } } | W.Config"#;
    let value = evaluate_to_json(source, &library()).unwrap();
    assert_eq!(value["lenses"]["demo"]["when"]["default"]["miniatures"]["fit"], "shrink");
}

#[test]
fn miniatures_profile_can_override_base_settings_without_merge_conflicts() {
    let source = r#"let W = import "winmux/winmux.ncl" in { lenses.demo = { presentation = 'list, miniatures.current-workspace = 'highlight, when.default = { presentation = 'miniatures, miniatures.current-workspace = 'hide, summon-hints = ['label] } } } | W.Config"#;
    assert!(evaluate_to_json(source, &library()).is_ok());
    let source = r#"let W = import "winmux/winmux.ncl" in ((import "winmux/defaults.ncl") & { lenses.overview.presentation = 'list }) | W.Config"#;
    let value = evaluate_to_json(source, &library()).unwrap();
    assert_eq!(value["lenses"]["overview"]["presentation"], "list");
}

#[test]
fn miniatures_rejections_include_actionable_message() {
    for (body, message) in [
        ("presentation = 'miniatures, sections = 'workspace", "miniatures rejects sections, entries and sort"),
        ("presentation = 'miniatures, miniatures.current-workspace = 'hide", "current-workspace hide cannot show landing-spot"),
    ] {
        let source = format!("let W = import \"winmux/winmux.ncl\" in {{ lenses.demo = {{ {body} }} }} | W.Config");
        let error = evaluate_to_json(&source, &library()).unwrap_err();
        assert!(error.contains(message), "{error}");
    }
}

#[test]
fn strip_defaults_and_same_app_filter_handle_missing_focus() {
    let mut helper = Helper::new(library());
    let reply = request(&mut helper, json!({"id": 1, "op": "load", "path": null}));
    assert_eq!(reply["ok"], true, "{}", reply["error"]);
    let config = &reply["result"]["config"];
    for name in ["recent", "app-windows"] {
        assert_eq!(config["lenses"][name]["presentation"], "strip");
        assert_eq!(config["lenses"][name]["keys"]["alt-enter"], "summon");
        assert_eq!(config["lenses"][name]["popups"], json!([]));
    }
    assert_eq!(config["mode"]["main"]["binding"]["cmd-tab"], "lens recent");
    assert_eq!(config["mode"]["main"]["binding"]["cmd-shift-tab"], "lens recent");
    assert_eq!(config["mode"]["main"]["binding"]["cmd-backtick"], "lens app-windows");
    for (ctx, expected) in [(context(), json!([false, false])), (context_focused_on("demo"), json!([true, false]))] {
        let filtered = request(&mut helper, json!({"id": 2, "op": "filter", "lens": "app-windows", "ctx": ctx, "windows": [window("demo", "tiled"), window("other", "floating")]}));
        assert_eq!(filtered["ok"], true, "{}", filtered["error"]);
        assert_eq!(filtered["result"], expected);
    }
}

fn columns_load(body: &str) -> Value {
    let dir = std::env::temp_dir().join(format!("winmux-columns-{}-{}", std::process::id(), std::thread::current().name().unwrap_or("test")));
    std::fs::create_dir_all(&dir).unwrap();
    let file = dir.join("config.ncl");
    std::fs::write(&file, format!("let W = import \"winmux/winmux.ncl\" in ((import \"winmux/defaults.ncl\") & {{ {body} }}) | W.Config")).unwrap();
    let mut helper = Helper::new(library());
    let reply = request(&mut helper, json!({"id": 1, "op":"load", "path":file}));
    std::fs::remove_dir_all(dir).unwrap();
    reply
}

#[test]
fn columns_acceptance_defaults_profiles_and_normalization_warning() {
    let reply = columns_load("columns = { count = 3, widths = [2, 3, 5], when.default.count = 3, when.travel.count = 7 }, workspace.Demo.columns = { count = 2, widths = [1, 1], when.default.widths = [1, 3] }");
    assert_eq!(reply["ok"], true, "{}", reply["error"]);
    assert_eq!(reply["result"]["config"]["columns"]["widths"], json!([0.2, 0.3, 0.5]));
    let presets = reply["result"]["config"]["columns"]["width-presets"].as_array().unwrap();
    assert!((presets[0].as_f64().unwrap() - 1.0/3.0).abs() < 1e-8);
    assert_eq!(reply["result"]["warnings"].as_array().unwrap().len(), 3);
}

#[test]
fn columns_reject_presets_at_all_other_paths_and_bad_resolved_lengths() {
    for body in ["workspace.Demo.columns.width-presets = [1/2]", "columns.when.default.width-presets = [1/2]", "workspace.Demo.columns.when.default.width-presets = [1/2]"] {
        let reply = columns_load(body);
        assert_eq!(reply["ok"], false, "{body}");
        assert!(reply["error"].as_str().unwrap().contains("width-presets"));
    }
    for body in ["columns = { count = 3, widths = [1, 1] }", "columns.count = 3, workspace.Demo.columns.widths = [1, 1]"] {
        let reply = columns_load(body);
        assert_eq!(reply["ok"], false, "{body}");
        assert!(reply["error"].as_str().unwrap().contains("length"));
    }
    let reply = columns_load("columns = { count = 2, widths = [1, 1, 1], when.default.count = 3 }");
    assert_eq!(reply["ok"], true, "length is checked after resolution: {}", reply["error"]);
}

#[test]
fn columns_reject_invalid_numbers() {
    for body in ["columns.count = 0", "columns.count = 1.5", "columns.widths = [0, 1]", "columns.width-presets = [1]", "columns.width-presets = []"] {
        assert_eq!(columns_load(body)["ok"], false, "{body}");
    }
}

#[test]
fn columns_normalization_adds_no_keys_to_the_config() {
    let reply = columns_load("workspace.Demo = {}");
    assert_eq!(reply["ok"], true, "{reply}");
    assert_eq!(reply["result"]["config"]["workspace"]["Demo"], json!({}));
}


#[test]
fn default_triggers_import_overrides_and_upstream_conversion() {
    let mut helper = Helper::new(library());
    let defaults = request(&mut helper, json!({"op": "load"}));
    let config = &defaults["result"]["config"];
    assert_eq!(config["mode"]["main"]["binding"]["alt-slash"], "lens search");
    assert_eq!(config["mode"]["main"]["binding"]["alt-semicolon"], "mode lens");
    assert_eq!(config["mode"]["lens"]["binding"], json!({
        "o": ["lens overview", "mode main"], "f": ["lens floating", "mode main"],
        "s": ["lens search", "mode main"], "r": ["lens recent --presentation list", "mode main"], "esc": "mode main"
    }));
    assert_eq!(config["columns"]["count"], "off");
    assert!(config.get("config-version").is_none());
    assert_eq!(config["lenses"].as_object().unwrap().keys().cloned().collect::<Vec<_>>(), ["app-windows", "floating", "overview", "recent", "search"]);
    let imported = loaded_source("import-only", r#"(import "winmux/defaults.ncl") | (import "winmux/winmux.ncl").Config"#);
    assert_eq!(imported, *config);
    let changed = loaded_source("binding-override", r#"((import "winmux/defaults.ncl") & { mode.main.binding.alt-slash = "focus left" }) | (import "winmux/winmux.ncl").Config"#);
    let mut expected = config.clone();
    expected["mode"]["main"]["binding"]["alt-slash"] = json!("focus left");
    assert_eq!(changed, expected);
    let removed = loaded_source("binding-remove", r#"let d = import "winmux/defaults.ncl" in (d & { mode.main.binding | force = std.record.remove "alt-slash" d.mode.main.binding }) | (import "winmux/winmux.ncl").Config"#);
    expected["mode"]["main"]["binding"].as_object_mut().unwrap().remove("alt-slash");
    assert_eq!(removed, expected);

    let converted = run_helper(&["convert", &fixture("upstream-default-config.toml")]);
    assert_eq!(converted.status.code(), Some(0));
    let converted = loaded_source("converted-defaults", &String::from_utf8(converted.stdout).unwrap());
    assert_eq!(converted, *config);
    let upstream = evaluate_to_json(&format!("import {} as 'Toml", winmux_nickel::engine::nickel_string(&fixture("upstream-default-config.toml"))), &library()).unwrap();
    for (key, command) in upstream["mode"]["main"]["binding"].as_object().unwrap() {
        assert_eq!(config["mode"]["main"]["binding"][key], *command, "upstream chord {key}");
    }
    assert_eq!(run_helper(&["check", &library().join("winmux/defaults.ncl").to_string_lossy()]).status.code(), Some(0));
}

fn loaded_source(label: &str, source: &str) -> Value {
    let file = std::env::temp_dir().join(format!("winmux-default-{label}-{}.ncl", std::process::id()));
    std::fs::write(&file, source).unwrap();
    let mut helper = Helper::new(library());
    let reply = request(&mut helper, json!({"op": "load", "path": file}));
    std::fs::remove_file(file).unwrap();
    assert_eq!(reply["ok"], true, "{}", reply["error"]);
    reply["result"]["config"].clone()
}

#[test]
fn config_version_is_rejected_and_converted_away() {
    let source = r#"let W = import "winmux/winmux.ncl" in { config-version = 2 } | W.Config"#;
    let error = evaluate_to_json(source, &library()).unwrap_err();
    assert!(error.contains("config-version"), "{error}");
    let output = run_helper(&["convert", &fixture("upstream-default-config.toml")]);
    assert!(!String::from_utf8(output.stdout).unwrap().contains("config-version"));
}
