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

#[test]
fn url_scheme_defaults_on_and_requires_bool() {
    let defaults = evaluate_to_json(r#"import "winmux/defaults.ncl""#, &library()).unwrap();
    assert_eq!(defaults["url-scheme"], true);
    let off = evaluate_to_json(r#"((import "winmux/defaults.ncl") & { url-scheme = false }) | (import "winmux/winmux.ncl").Config"#, &library()).unwrap();
    assert_eq!(off["url-scheme"], false);
    assert!(evaluate_to_json(r#"{ url-scheme = "false" } | (import "winmux/winmux.ncl").Config"#, &library()).is_err());
}

#[test]
fn restore_windows_on_quit_defaults_on_and_requires_bool() {
    let defaults = evaluate_to_json(r#"import "winmux/defaults.ncl""#, &library()).unwrap();
    assert_eq!(defaults["restore-windows-on-quit"], true);
    let off = evaluate_to_json(r#"((import "winmux/defaults.ncl") & { restore-windows-on-quit = false }) | (import "winmux/winmux.ncl").Config"#, &library()).unwrap();
    assert_eq!(off["restore-windows-on-quit"], false);
    assert!(evaluate_to_json(r#"{ restore-windows-on-quit = "false" } | (import "winmux/winmux.ncl").Config"#, &library()).is_err());
}

#[test]
fn empty_command_override_survives_the_default_binding_merge() {
    let value = evaluate_to_json(
        r#"let W = import "winmux/winmux.ncl" in
        ((import "winmux/defaults.ncl") & { mode.main.binding.alt-slash = [] }) | W.Config"#,
        &library(),
    ).unwrap();
    assert_eq!(value["mode"]["main"]["binding"]["alt-slash"], json!([]));
    assert_eq!(value["mode"]["main"]["binding"]["alt-shift-o"], json!("lens overview"));
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
    assert_eq!(config["mode"]["main"]["binding"]["cmd-tab"], "focus right");
    assert!(config["mode"]["main"]["binding"].get("cmd-shift-tab").is_none());
    assert!(config["mode"]["main"]["binding"].get("cmd-backtick").is_none());
    assert_eq!(config["mode"]["main"]["binding"]["alt-shift-o"], "lens overview");
    assert_eq!(config["mode"]["window"]["binding"]["esc"], "mode main");
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
fn lens_contract_rejects_unknown_fields_and_sort() {
    for body in ["frozen_thumbnail = 'dimmed", "sort = ['mystery]"] {
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
fn lens_starts_in_is_optional_and_validated_in_base_and_profiles() {
    let omitted = evaluate_to_json(r#"let W = import "winmux/winmux.ncl" in { lenses.demo = {} } | W.Config"#, &library()).unwrap();
    assert!(omitted["lenses"]["demo"].get("starts-in").is_none());
    for state in ["normal", "search"] {
        for field in ["starts-in", "when.default.starts-in"] {
            let source = format!(r#"let W = import "winmux/winmux.ncl" in {{ lenses.demo.{field} = '{state} }} | W.Config"#);
            let value = evaluate_to_json(&source, &library()).unwrap();
            let lens = &value["lenses"]["demo"];
            assert_eq!(if field == "starts-in" { &lens["starts-in"] } else { &lens["when"]["default"]["starts-in"] }, state);
        }
    }
    for field in ["starts-in", "when.default.starts-in"] {
        for invalid in ["'hold", "'other", "42"] {
            let source = format!(r#"let W = import "winmux/winmux.ncl" in {{ lenses.demo.{field} = {invalid} }} | W.Config"#);
            assert!(evaluate_to_json(&source, &library()).is_err(), "accepted {source}");
        }
    }
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
fn default_main_bindings_are_exactly_the_short_list() {
    let mut helper = Helper::new(library());
    let reply = request(&mut helper, json!({"op": "load", "path": null}));
    assert_eq!(reply["ok"], true);
    let mut expected: std::collections::BTreeSet<String> = [
        "alt-h", "alt-j", "alt-k", "alt-l", "alt-shift-h", "alt-shift-j", "alt-shift-k", "alt-shift-l",
        "alt-shift-t", "alt-shift-m", "alt-slash", "alt-semicolon", "alt-shift-o"
    ].into_iter().map(str::to_owned).collect();
    expected.extend((1..=9).map(|n| format!("ctrl-{n}")));
    expected.extend((1..=9).map(|n| format!("alt-shift-{n}")));
    expected.extend((1..=9).map(|n| format!("alt-{n}")));
    let actual = reply["result"]["config"]["mode"]["main"]["binding"].as_object().unwrap().keys().cloned().collect();
    assert_eq!(expected, actual);
}

#[test]
fn strip_defaults_and_same_app_filter_handle_missing_focus() {
    let mut helper = Helper::new(library());
    let reply = request(&mut helper, json!({"id": 1, "op": "load", "path": null}));
    assert_eq!(reply["ok"], true, "{}", reply["error"]);
    let config = &reply["result"]["config"];
    let recent = &config["lenses"]["recent"];
    assert_eq!(recent["presentation"], "strip");
    assert_eq!(recent["tile"], "picture");
    assert_eq!(recent["grid"]["tile-size"], "same-height");
    assert_eq!(recent["keys"]["alt-enter"], "summon");
    assert_eq!(recent["popups"], json!([]));
    assert!(config["mode"]["main"]["binding"].get("cmd-tab").is_none());
    assert!(config["mode"]["main"]["binding"].get("cmd-shift-tab").is_none());
    assert!(config["mode"]["main"]["binding"].get("cmd-backtick").is_none());
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
    assert_eq!(config["mode"]["main"]["binding"]["alt-semicolon"], "mode window");
    assert_eq!(config["mode"]["window"]["binding"], expected_window_bindings());
    assert!(config["mode"].get("lens").is_none());
    assert_eq!(config["columns"]["count"], "off");
    assert!(config.get("config-version").is_none());
    assert_eq!(config["lenses"].as_object().unwrap().keys().cloned().collect::<Vec<_>>(), ["app-windows", "floating", "overview", "recent", "search", "windows"]);
    let imported = loaded_source("import-only", r#"(import "winmux/defaults.ncl") | (import "winmux/winmux.ncl").Config"#);
    assert_eq!(imported, *config);
    let changed = loaded_source("binding-override", r#"((import "winmux/defaults.ncl") & { mode.main.binding.alt-slash = "focus left" }) | (import "winmux/winmux.ncl").Config"#);
    let mut expected = config.clone();
    expected["mode"]["main"]["binding"]["alt-slash"] = json!("focus left");
    assert_eq!(changed, expected);
    let removed = loaded_source("binding-remove", r#"let d = import "winmux/defaults.ncl" in (d & { mode.main.binding | force = (import "winmux/winmux.ncl").without-bindings ["alt-slash"] d.mode.main.binding }) | (import "winmux/winmux.ncl").Config"#);
    expected["mode"]["main"]["binding"].as_object_mut().unwrap().remove("alt-slash");
    assert_eq!(removed, expected);

    let converted = run_helper(&["convert", &fixture("upstream-default-config.toml")]);
    assert_eq!(converted.status.code(), Some(0));
    let converted = loaded_source("converted-defaults", &String::from_utf8(converted.stdout).unwrap());
    let upstream = evaluate_to_json(&format!("import {} as 'Toml", winmux_nickel::engine::nickel_string(&fixture("upstream-default-config.toml"))), &library()).unwrap();
    let mut expected_conversion = config.clone();
    expected_conversion["mode"]["main"]["binding"] = upstream["mode"]["main"]["binding"].clone();
    for key in ["alt-slash", "alt-semicolon", "alt-shift-o"] {
        expected_conversion["mode"]["main"]["binding"][key] = config["mode"]["main"]["binding"][key].clone();
    }
    assert_eq!(converted, expected_conversion);
    for (key, command) in upstream["mode"]["main"]["binding"].as_object().unwrap() {
        assert_eq!(converted["mode"]["main"]["binding"][key], *command, "upstream chord {key}");
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
fn config_version_is_accepted_and_converted_away() {
    let source = r#"let W = import "winmux/winmux.ncl" in { config-version = 2 } | W.Config"#;
    assert_eq!(loaded_source("old-version", source)["config-version"], 2);
    let output = run_helper(&["convert", &fixture("upstream-default-config.toml")]);
    assert!(!String::from_utf8(output.stdout).unwrap().contains("config-version"));
}

#[test]
fn conversion_infers_legacy_persistent_workspaces_in_source_order_with_warning() {
    for version in ["", "config-version = 1\n"] {
        let file = std::env::temp_dir().join(format!("winmux-infer-{}.toml", std::process::id()));
        std::fs::write(
            &file,
            format!(
                r#"{version}
[mode.main.binding]
z = ["workspace Z", "move-node-to-workspace --focus-follows-window B", "workspace Z"]
a = "workspace A"
[mode.other.binding]
f = "move-node-to-workspace F"
[workspace-to-monitor-force-assignment]
Q = 1
B = 1
"#
            ),
        )
        .unwrap();
        let converted = winmux_nickel::convert::convert(&file, &library()).unwrap();
        assert_eq!(
            loaded_source("inferred", &converted.nickel)["persistent-workspaces"],
            json!(["Z", "B", "A", "F", "Q"])
        );
        assert!(
            converted
                .warnings
                .iter()
                .any(|w| w.contains("Inferred persistent-workspaces")
                    && w.contains("Z")
                    && w.contains("Q")),
            "{:?}",
            converted.warnings
        );
        for explicit in ["config-version = 2\n", "persistent-workspaces = []\n"] {
            let input = std::fs::read_to_string(&file).unwrap();
            std::fs::write(
                &file,
                format!("{explicit}{}", input.replace("config-version = 1\n", "")),
            )
            .unwrap();
            let converted = winmux_nickel::convert::convert(&file, &library()).unwrap();
            assert!(converted.warnings.is_empty());
            assert_eq!(
                loaded_source("not-inferred", &converted.nickel)["persistent-workspaces"],
                json!([])
            );
            std::fs::write(&file, input).unwrap();
        }
        std::fs::remove_file(file).unwrap();
    }
}

#[test]
fn conversion_keeps_only_fork_triggers_and_normalizes_aliases() {
    let file = std::env::temp_dir().join(format!("winmux-modes-{}.toml", std::process::id()));
    std::fs::write(
        &file,
        r#"config-version = 2
[key-mapping.key-notation-to-key-code]
mytab = "tab"
[mode.main.binding]
shift-alt-h = "move left"
shift-cmd-mytab = "focus right"
cmd-tab = "focus left"
shift-alt-o = "focus up"
"#,
    )
    .unwrap();
    let converted = winmux_nickel::convert::convert(&file, &library()).unwrap();
    let config = loaded_source("only-fork", &converted.nickel);
    let bindings = config["mode"]["main"]["binding"].as_object().unwrap();
    assert!(!bindings.contains_key("alt-tab"));
    assert!(!bindings.contains_key("alt-shift-h"));
    assert!(!bindings.contains_key("cmd-shift-tab"));
    assert_eq!(bindings["cmd-tab"], "focus left");
    assert_eq!(bindings["shift-alt-o"], "focus up");
    assert!(!bindings.contains_key("alt-shift-o"));
    assert_eq!(bindings.len(), 6);
    assert!(converted.nickel.contains("# Kept from defaults:"));
    std::fs::write(&file, "config-version = 2").unwrap();
    let converted = winmux_nickel::convert::convert(&file, &library()).unwrap();
    assert_eq!(
        loaded_source("no-modes", &converted.nickel)["mode"],
        loaded_source("whole-defaults", "import \"winmux/defaults.ncl\"")["mode"]
    );
    std::fs::remove_file(file).unwrap();
}


#[test]
fn conversion_deduplicates_remapped_defaults_and_rejects_duplicate_user_chords() {
    let file = std::env::temp_dir().join(format!("winmux-aliases-{}.toml", std::process::id()));
    std::fs::write(&file, r#"config-version = 2
[key-mapping.key-notation-to-key-code]
slash = "semicolon"
[mode.main.binding]
"#).unwrap();
    let converted = winmux_nickel::convert::convert(&file, &library()).unwrap();
    let config = loaded_source("alias-defaults", &converted.nickel);
    let bindings = config["mode"]["main"]["binding"].as_object().unwrap();
    assert!(!bindings.contains_key("cmd-tab"));
    assert!(!bindings.contains_key("cmd-backtick"));
    assert!(bindings.contains_key("alt-slash"));
    assert!(!bindings.contains_key("alt-semicolon"));
    std::fs::write(&file, r#"[mode.main.binding]
shift-alt-h = "move left"
alt-shift-h = "move right"
"#).unwrap();
    assert!(winmux_nickel::convert::convert(&file, &library()).err().unwrap().contains("Binding redeclaration"));
    std::fs::remove_file(file).unwrap();
}

fn converted_toml(label: &str, toml: &str) -> Result<winmux_nickel::convert::Converted, String> {
    let file = std::env::temp_dir().join(format!("winmux-{label}-{}.toml", std::process::id()));
    std::fs::write(&file, toml).unwrap();
    let converted = winmux_nickel::convert::convert(&file, &library());
    std::fs::remove_file(file).unwrap();
    converted
}

#[test]
fn conversion_infers_quoted_names_and_version_zero_and_stays_quiet_when_nothing_is_inferred() {
    let quoted = converted_toml("quoted", "[mode.main.binding]\nm = \"workspace 'My Space'\"\nn = 'move-node-to-workspace \"Two Words\"'\n").unwrap();
    assert_eq!(loaded_source("quoted", &quoted.nickel)["persistent-workspaces"], json!(["My Space", "Two Words"]));

    let zero = converted_toml("zero", "config-version = 0\n[mode.main.binding]\na = \"workspace A\"\n").unwrap();
    assert_eq!(loaded_source("zero", &zero.nickel)["persistent-workspaces"], json!(["A"]));

    let nothing = converted_toml("nothing", "[gaps]\ninner.horizontal = 3\n").unwrap();
    assert!(nothing.warnings.is_empty(), "{:?}", nothing.warnings);
    assert!(!nothing.nickel.contains("persistent-workspaces"), "{}", nothing.nickel);
}

#[test]
fn conversion_requires_a_main_mode_and_leaves_modes_open_to_later_merges() {
    let error = converted_toml("no-main", "[mode.resize.binding]\nh = \"resize width -50\"\n").err().unwrap();
    assert!(error.contains("Please specify 'main' mode"), "{error}");

    let converted = converted_toml("merge", "config-version = 2\n[mode.main.binding]\nalt-h = \"focus left\"\n").unwrap();
    assert!(!converted.nickel.contains("force"), "{}", converted.nickel);
    let extended = converted.nickel.replace("}) | W.Config", "} & { mode.main.binding.alt-x = \"lens search\" }) | W.Config");
    assert_ne!(extended, converted.nickel);
    let bindings = loaded_source("merge", &extended)["mode"]["main"]["binding"].clone();
    assert_eq!(bindings["alt-x"], json!("lens search"));
    assert_eq!(bindings["alt-h"], json!("focus left"));
    assert!(bindings.get("cmd-tab").is_none());
    assert!(bindings.get("alt-tab").is_none());
}

#[test]
fn tile_contract_defaults_overrides_and_miniatures_refusal() {
    for (body, kind) in [("presentation = 'strip, tile = 'text", "text"), ("presentation = 'list, tile = 'card", "card"), ("tile = 'picture, badges = false, when.default.tile = 'text", "picture")] {
        let source = format!("let W = import \"winmux/winmux.ncl\" in {{ lenses.demo = {{ {body} }} }} | W.Config");
        let value = evaluate_to_json(&source, &library()).unwrap();
        assert_eq!(value["lenses"]["demo"]["tile"], kind);
    }
    for body in ["", "presentation = 'miniatures"] {
        let source = format!("let W = import \"winmux/winmux.ncl\" in {{ lenses.demo = {{ {body} }} }} | W.Config");
        let value = evaluate_to_json(&source, &library()).unwrap();
        assert!(value["lenses"]["demo"].get("tile").is_none());
        assert_eq!(value["lenses"]["demo"]["badges"], true);
    }
    for body in ["presentation = 'miniatures, tile = 'card", "presentation = 'miniatures, tile = 'text", "presentation = 'miniatures, when.default.tile = 'card", "tile = 'text, when.default.presentation = 'miniatures"] {
        let source = format!("let W = import \"winmux/winmux.ncl\" in {{ lenses.demo = {{ {body} }} }} | W.Config");
        let error = evaluate_to_json(&source, &library()).unwrap_err();
        assert!(error.contains("tile"), "{error}");
    }
}

#[test]
fn grid_contract_loads_modes_profiles_and_ignored_settings() {
    for mode in ["real", "same-height", "equal"] {
        for presentation in ["grid", "list", "strip", "miniatures"] {
            let source = format!("let W = import \"winmux/winmux.ncl\" in {{ lenses.demo = {{ presentation = '{presentation}, grid.tile-size = '{mode}, when.default.grid.tile-size = 'equal }} }} | W.Config");
            let value = evaluate_to_json(&source, &library()).unwrap();
            assert_eq!(value["lenses"]["demo"]["grid"]["tile-size"], mode);
            assert_eq!(value["lenses"]["demo"]["when"]["default"]["grid"]["tile-size"], "equal");
        }
    }
    let value = evaluate_to_json("let W = import \"winmux/winmux.ncl\" in { lenses.demo = { presentation = 'grid, tile = 'text, entries = 'app, sections = 'workspace } } | W.Config", &library()).unwrap();
    assert_eq!(value["lenses"]["demo"]["grid"]["tile-size"], "real");
    for body in ["grid.tile-size = 'huge", "when.default.grid.tile-size = 'huge", "grid.sections-arrangement = 'spiral"] {
        let source = format!("let W = import \"winmux/winmux.ncl\" in {{ lenses.demo = {{ {body} }} }} | W.Config");
        let error = evaluate_to_json(&source, &library()).unwrap_err();
        assert!(error.contains("tile-size") || error.contains("sections-arrangement"), "{error}");
    }
}

#[test]
fn grid_load_and_check_use_the_real_helper_contract() {
    let mut helper = loaded("grid.ncl");
    let reply = request(&mut helper, json!({"op": "load", "path": fixture("grid.ncl")}));
    assert_eq!(reply["ok"], true, "{reply}");
    let lens = &reply["result"]["config"]["lenses"]["grid"];
    assert_eq!(lens["presentation"], "grid");
    assert_eq!(lens["grid"]["tile-size"], "real");
    assert_eq!(lens["when"]["default"]["grid"]["tile-size"], "equal");
    assert_eq!(run_helper(&["check", &fixture("grid.ncl")]).status.code(), Some(0));
    let invalid = run_helper(&["check", &fixture("grid-invalid.ncl")]);
    assert_eq!(invalid.status.code(), Some(2));
    assert!(String::from_utf8_lossy(&invalid.stderr).contains("tile-size"));
}

#[test]
fn sections_arrangements_and_grouping_key_load_through_helper() {
    for arrangement in ["flow", "rows", "columns"] {
        let source = format!("let W = import \"winmux/winmux.ncl\" in {{ lenses.demo = {{ grid.sections-arrangement = '{arrangement}, when.default.grid.sections-arrangement = 'rows }} }} | W.Config");
        let value = evaluate_to_json(&source, &library()).unwrap();
        assert_eq!(value["lenses"]["demo"]["grid"]["sections-arrangement"], arrangement);
        assert_eq!(value["lenses"]["demo"]["keys"]["cmd-g"], "sections next");
    }
}

#[test]
fn without_bindings_ignores_absent_chords_and_removes_present_ones() {
    let config = loaded_source("safe-binding-removal", r#"
        let W = import "winmux/winmux.ncl" in
        let d = import "winmux/defaults.ncl" in
        (d & { mode.main.binding | force = W.without-bindings
            ["alt-slash", "ctrl-w", "never-a-binding", "alt-slash"] d.mode.main.binding }) | W.Config
    "#);
    let defaults = loaded_source("safe-binding-defaults", r#"(import "winmux/defaults.ncl") | (import "winmux/winmux.ncl").Config"#);
    let mut expected = defaults;
    expected["mode"]["main"]["binding"].as_object_mut().unwrap().remove("alt-slash");
    assert_eq!(config, expected);
}

#[test]
fn check_hints_only_for_missing_chords_removed_from_defaults() {
    for (chord, hint) in [("ctrl-w", true), ("never-a-binding", false), ("alt-slash", false)] {
        let file = std::env::temp_dir().join(format!("winmux-removal-{chord}-{}.ncl", std::process::id()));
        let record = if chord == "alt-slash" { "{}" } else { "d.mode.main.binding" };
        std::fs::write(&file, format!(r#"
            let W = import "winmux/winmux.ncl" in
            let d = import "winmux/defaults.ncl" in
            (d & {{ mode.main.binding | force = std.record.remove "{chord}" {record} }}) | W.Config
        "#)).unwrap();
        let output = run_helper(&["check", &file.to_string_lossy()]);
        std::fs::remove_file(file).unwrap();
        assert_eq!(output.status.code(), Some(2));
        let error = String::from_utf8(output.stderr).unwrap();
        assert!(error.contains(&format!("missing field `{chord}`")), "{error}");
        assert_eq!(error.contains("is no longer a default binding"), hint, "{error}");
        if hint {
            assert!(error.starts_with("ctrl-w is no longer a default binding; delete its removal from your config.\n\nerror:"), "{error}");
        }
    }
}

#[test]
fn removing_old_tenth_tab_binding_has_migration_hint() {
    let file = std::env::temp_dir().join(format!("winmux-removal-alt-0-{}.ncl", std::process::id()));
    std::fs::write(&file, r#"
        let W = import "winmux/winmux.ncl" in
        let defaults = import "winmux/defaults.ncl" in
        (defaults & { mode.main.binding | force = std.record.remove "alt-0" defaults.mode.main.binding }) | W.Config
    "#).unwrap();
    let output = run_helper(&["check", &file.to_string_lossy()]);
    std::fs::remove_file(file).unwrap();
    assert_eq!(output.status.code(), Some(2));
    let error = String::from_utf8(output.stderr).unwrap();
    assert!(error.starts_with("alt-0 is no longer a default binding; delete its removal from your config.\n\nerror:"), "{error}");
}

fn expected_window_bindings() -> Value {
    let mut expected = json!({
        "h": "focus left", "j": "focus down", "k": "focus up", "l": "focus right",
        "c": "find-focus",
        "shift-h": "move left", "shift-j": "move down", "shift-k": "move up", "shift-l": "move right",
        "ctrl-h": "join-with left", "ctrl-j": "join-with down", "ctrl-k": "join-with up", "ctrl-l": "join-with right",
        "n": "focus tab-next", "p": "focus tab-prev", "t": "layout floating tiling", "m": "fullscreen",
        "rightSquareBracket": "project next", "leftSquareBracket": "project prev",
        "w": ["mode main", "lens windows"], "o": ["mode main", "lens overview"], "f": ["mode main", "lens floating"],
        "s": ["mode main", "lens search"], "r": ["mode main", "lens recent --presentation list --tile text"],
        "a": ["mode main", "lens app-windows --presentation list --tile text"], "esc": "mode main", "alt-semicolon": "mode main"
    });
    for n in 1..=9 {
        expected[n.to_string()] = json!(format!("workspace {n}"));
        expected[format!("shift-{n}")] = json!(format!("move-node-to-workspace {n}"));
    }
    expected
}

#[test]
fn window_mode_removal_and_user_lens_mode_compatibility() {
    let removed = loaded_source("remove-window-t", r#"let W = import "winmux/winmux.ncl" in let defaults = import "winmux/defaults.ncl" in (defaults & { mode.window.binding | force = W.without-bindings ["t"] defaults.mode.window.binding }) | W.Config"#);
    let mut expected = expected_window_bindings();
    expected.as_object_mut().unwrap().remove("t");
    assert_eq!(removed["mode"]["window"]["binding"], expected);
    let custom = columns_load("mode.lens.binding.x = \"focus left\"");
    assert_eq!(custom["ok"], true);
    assert_eq!(custom["result"]["config"]["mode"]["lens"]["binding"], json!({"x": "focus left"}));
    let file = std::env::temp_dir().join(format!("winmux-removed-lens-{}.ncl", std::process::id()));
    std::fs::write(&file, r#"let defaults = import "winmux/defaults.ncl" in { mode.main.binding = defaults.mode.lens.binding } | (import "winmux/winmux.ncl").Config"#).unwrap();
    let output = run_helper(&["check", &file.to_string_lossy()]);
    std::fs::remove_file(file).unwrap();
    assert_eq!(output.status.code(), Some(2));
    let diagnostic = String::from_utf8(output.stderr).unwrap();
    assert!(diagnostic.starts_with("The default binding mode lens was renamed to window; use defaults.mode.window.binding."), "{diagnostic}");
    assert!(diagnostic.contains("missing field"), "{diagnostic}");
    let other = std::env::temp_dir().join(format!("winmux-other-lens-{}.ncl", std::process::id()));
    std::fs::write(&other, r#"let defaults = import "winmux/defaults.ncl" in { lenses.search = defaults.lenses.lens } | (import "winmux/winmux.ncl").Config"#).unwrap();
    let output = run_helper(&["check", &other.to_string_lossy()]);
    std::fs::remove_file(other).unwrap();
    let diagnostic = String::from_utf8(output.stderr).unwrap();
    assert!(diagnostic.starts_with("error: missing field"), "{diagnostic}");
}

#[test]
fn find_focus_binding_can_be_removed_by_the_documented_recipe() {
    let removed = loaded_source("remove-window-c", r#"let W = import "winmux/winmux.ncl" in let defaults = import "winmux/defaults.ncl" in (defaults & { mode.window.binding | force = W.without-bindings ["c"] defaults.mode.window.binding }) | W.Config"#);
    let mut expected = expected_window_bindings();
    expected.as_object_mut().unwrap().remove("c");
    assert_eq!(removed["mode"]["window"]["binding"], expected);
}

#[test]
fn conversion_adds_the_windowing_mode_and_its_trigger_together_or_not_at_all() {
    // The TOML's own `window` mode keeps its keys and gains none; nothing new enters it.
    let own_mode = converted_toml("window-own-mode", r#"config-version = 2
[mode.main.binding]
alt-h = "focus left"
[mode.window.binding]
l = "focus up"
"#).unwrap();
    let config = loaded_source("window-own-mode", &own_mode.nickel);
    assert_eq!(config["mode"]["window"]["binding"], json!({"l": "focus up"}));
    assert!(config["mode"]["main"]["binding"].get("alt-semicolon").is_none());
    assert_eq!(config["mode"]["main"]["binding"]["alt-slash"], "lens search");

    // The TOML's own alt-semicolon wins, and no mode is added that nothing enters.
    let own_trigger = converted_toml("window-own-trigger", r#"config-version = 2
[mode.main.binding]
alt-semicolon = "mode lens"
[mode.lens.binding]
x = "focus left"
"#).unwrap();
    let config = loaded_source("window-own-trigger", &own_trigger.nickel);
    let main = config["mode"]["main"]["binding"].as_object().unwrap();
    let triggers: Vec<_> = main.iter().filter(|(key, _)| key.contains("semicolon")).collect();
    assert_eq!(triggers.len(), 1, "{triggers:?}");
    assert_eq!(triggers[0].1, "mode lens");
    assert_eq!(config["mode"]["lens"]["binding"], json!({"x": "focus left"}));
    assert!(config["mode"].get("window").is_none());

    // With neither, both arrive.
    let neither = converted_toml("window-neither", "config-version = 2\n[mode.main.binding]\nalt-h = \"focus left\"\n").unwrap();
    let config = loaded_source("window-neither", &neither.nickel);
    assert_eq!(config["mode"]["main"]["binding"]["alt-semicolon"], "mode window");
    assert_eq!(config["mode"]["window"]["binding"], expected_window_bindings());
    assert!(neither.nickel.contains("windowing mode"));
}

#[test]
fn shipped_recent_picture_strip_allows_cards_back_and_partial_grid_overrides() {
    let cards = loaded_source("cards-back", r#"
        let W = import "winmux/winmux.ncl" in
        ((import "winmux/defaults.ncl") & {
            lenses.recent.tile = 'card,
            lenses.recent.grid.tile-size = 'real,
        }) | W.Config
    "#);
    assert_eq!(cards["lenses"]["recent"]["tile"], "card");
    assert_eq!(cards["lenses"]["recent"]["grid"]["tile-size"], "real");
    let rows = loaded_source("strip-rows", r#"
        let W = import "winmux/winmux.ncl" in
        ((import "winmux/defaults.ncl") & { lenses.recent.grid.sections-arrangement = 'rows }) | W.Config
    "#);
    assert_eq!(rows["lenses"]["recent"]["grid"]["sections-arrangement"], "rows");
    assert_eq!(rows["lenses"]["recent"]["grid"]["tile-size"], "same-height");
    let disabled = loaded_source("disable-recent-with-cards-back", r#"
        let W = import "winmux/winmux.ncl" in
        ((import "winmux/defaults.ncl") & {
            lenses.recent.enabled = false,
            lenses.app-windows.tile = 'card,
            lenses.app-windows.grid.tile-size = 'real,
        }) | W.Config
    "#);
    assert_eq!(disabled["lenses"]["recent"]["enabled"], false);
    assert_eq!(disabled["lenses"]["app-windows"]["tile"], "card");
    assert_eq!(disabled["lenses"]["app-windows"]["grid"]["tile-size"], "real");
}

#[test]
fn shipped_picture_lens_can_override_presentation_to_miniatures() {
    for body in ["lenses.recent.presentation = 'miniatures", "lenses.recent.when.default.presentation = 'miniatures"] {
        let source = format!("let W = import \"winmux/winmux.ncl\" in ((import \"winmux/defaults.ncl\") & {{ {body} }}) | W.Config");
        let value = loaded_source("picture-miniatures", &source);
        assert_eq!(value["lenses"]["recent"]["tile"], "picture");
        let presentation = if body.contains("when.default") { &value["lenses"]["recent"]["when"]["default"]["presentation"] } else { &value["lenses"]["recent"]["presentation"] };
        assert_eq!(presentation, "miniatures");
    }
    for lens in ["{ presentation = 'miniatures, tile = 'picture }", "{ presentation = 'miniatures, when.default.tile = 'picture }"] {
        let source = format!("let W = import \"winmux/winmux.ncl\" in ((import \"winmux/defaults.ncl\") & {{ lenses.plain = {lens} }}) | W.Config");
        let value = loaded_source("plain-picture-miniatures", &source);
        assert_eq!(value["lenses"]["plain"]["presentation"], "miniatures");
    }
    let source = "let W = import \"winmux/winmux.ncl\" in ((import \"winmux/defaults.ncl\") & { lenses.recent.presentation = 'miniatures, lenses.recent.tile = 'card }) | W.Config";
    let error = evaluate_to_json(source, &library()).unwrap_err();
    assert!(error.contains("miniatures rejects tile"), "{error}");
}

#[test]
fn hints_contract_defaults_choices_profiles_and_miniatures() {
    let source = r#"let W = import "winmux/winmux.ncl" in (import "winmux/defaults.ncl") & { lenses.user = {} } | W.Config"#;
    let value = evaluate_to_json(source, &library()).unwrap();
    for lens in ["search", "user"] {
        assert_eq!(value["lenses"][lens]["hints"], "held");
        assert_eq!(value["lenses"][lens]["hints-key"], "alt");
    }
    for hints in ["'held", "'always", "\"held\"", "\"always\""] {
        for key in ["'alt", "'cmd", "'ctrl", "'shift", "\"ctrl\""] {
            let source = format!("let W = import \"winmux/winmux.ncl\" in {{ lenses.demo = {{ presentation = 'miniatures, hints = {hints}, hints-key = {key}, when.default = {{ hints = {hints}, hints-key = {key} }} }} }} | W.Config");
            assert!(evaluate_to_json(&source, &library()).is_ok(), "rejected {hints}, {key}");
        }
    }
    for body in ["hints = 'sometimes", "hints-key = 'option", "when.default.hints-key = 'fn", "presentation = 'miniatures, hints = 'always, miniatures.current-workspace = 'hide"] {
        let source = format!("let W = import \"winmux/winmux.ncl\" in {{ lenses.demo = {{ {body} }} }} | W.Config");
        assert!(evaluate_to_json(&source, &library()).is_err(), "accepted {body}");
    }
}

#[test]
fn peek_defaults_choices_profiles_and_freed_keys() {
    let defaults = evaluate_to_json(r#"let W = import "winmux/winmux.ncl" in (import "winmux/defaults.ncl") | W.Config"#, &library()).unwrap();
    for lens in ["recent", "app-windows", "search", "overview", "floating", "windows"] {
        assert_eq!(defaults["lenses"][lens]["peek"], "zoom");
        assert_eq!(defaults["lenses"][lens]["keys"]["space"], "peek");
        assert_eq!(defaults["lenses"][lens]["keys"]["cmd-y"], "peek");
    }
    let removed = evaluate_to_json(r#"let W = import "winmux/winmux.ncl" in ((import "winmux/defaults.ncl") & { lenses.recent.keys = { space = [], cmd-y = [], cmd-p = "peek" } }) | W.Config"#, &library()).unwrap();
    assert_eq!(removed["lenses"]["recent"]["keys"]["space"], serde_json::json!([]));
    assert_eq!(removed["lenses"]["recent"]["keys"]["cmd-y"], serde_json::json!([]));
    assert_eq!(removed["lenses"]["recent"]["keys"]["cmd-p"], "peek");
    for mode in ["'zoom", "'follow", "\"zoom\"", "\"follow\""] {
        let source = format!(r#"let W = import "winmux/winmux.ncl" in {{ lenses.demo = {{ peek = {mode}, when.default.peek = {mode}, keys = {{ space = [], cmd-y = [], cmd-p = "peek" }} }} }} | W.Config"#);
        let value = evaluate_to_json(&source, &library()).unwrap();
        assert_eq!(value["lenses"]["demo"]["keys"]["space"], serde_json::json!([]));
        assert_eq!(value["lenses"]["demo"]["keys"]["cmd-p"], "peek");
    }
    for body in ["peek = 'other", "when.default.peek = 'other"] {
        let source = format!(r#"let W = import "winmux/winmux.ncl" in {{ lenses.demo = {{ {body} }} }} | W.Config"#);
        assert!(evaluate_to_json(&source, &library()).is_err());
    }
}

#[test]
fn peek_must_run_alone_in_base_and_every_profile() {
    for body in [
        r#"keys.space = ["peek", "close"]"#,
        r#"keys.cmd-p = ["focus", "peek"]"#,
        r#"when.travel.keys.cmd-p = ["peek", "focus"]"#,
    ] {
        let source = format!(r#"let W = import "winmux/winmux.ncl" in {{ lenses.demo = {{ {body} }} }} | W.Config"#);
        let error = evaluate_to_json(&source, &library()).unwrap_err();
        assert!(error.contains("peek runs alone"), "{error}");
    }
    let source = r#"let W = import "winmux/winmux.ncl" in { lenses.demo.keys.cmd-p = ["peek"] } | W.Config"#;
    assert!(evaluate_to_json(source, &library()).is_ok());
}

#[test]
fn lens_release_and_appearance_are_optional_validated_choices_in_all_profiles() {
    let defaults = evaluate_to_json(r#"import "winmux/defaults.ncl""#, &library()).unwrap();
    for lens in ["recent", "search", "floating", "overview", "windows"] {
        assert!(defaults["lenses"][lens].get("on-release").is_none());
        assert!(defaults["lenses"][lens].get("appearance").is_none());
    }
    for release in ["commit", "stay"] {
        for appearance in ["auto", "dark", "light"] {
            let source = format!(r#"let W = import "winmux/winmux.ncl" in {{ lenses.demo = {{ on-release = '{release}, appearance = '{appearance}, when.default = {{ on-release = '{release}, appearance = '{appearance} }} }} }} | W.Config"#);
            let value = evaluate_to_json(&source, &library()).unwrap();
            assert_eq!(value["lenses"]["demo"]["on-release"], release);
            assert_eq!(value["lenses"]["demo"]["appearance"], appearance);
        }
    }
    for field in ["on-release", "appearance"] {
        for profile in ["", "when.default.", "when.travel."] {
            let source = format!(r#"let W = import "winmux/winmux.ncl" in {{ lenses.demo.{profile}{field} = 'invalid }} | W.Config"#);
            assert!(evaluate_to_json(&source, &library()).is_err(), "{source}");
        }
    }
}

#[test]
fn shipped_grids_and_windows_filter_follow_the_contract() {
    let mut helper = Helper::new(library());
    let reply = request(&mut helper, json!({"op": "load"}));
    assert_eq!(reply["ok"], true);
    let lenses = &reply["result"]["config"]["lenses"];
    for name in ["windows", "app-windows", "floating"] {
        assert_eq!(lenses[name]["presentation"], "grid", "{name}");
        assert_eq!(lenses[name]["sort"], json!(["mru"]), "{name}");
        assert_eq!(lenses[name]["sections"], if name == "app-windows" { "none" } else { "workspace" }, "{name}");
        assert_eq!(lenses[name]["grid"]["tile-size"], "real", "{name}");
        assert_eq!(lenses[name]["grid"]["sections-arrangement"], "flow", "{name}");
        assert!(lenses[name].get("tile").is_none(), "{name}");
        assert_eq!(lenses[name]["popups"], json!([]), "{name}");
    }
    assert_eq!(lenses["app-windows"]["on-release"], "commit");
    assert!(lenses["windows"].get("on-release").is_none());
    assert!(lenses["windows"].get("filter").is_none());
    let reply = request(&mut helper, json!({"op": "filter", "lens": "windows", "ctx": context(), "windows": [window("demo", "tiled"), window("other", "floating"), window("hidden", "hidden-app"), window("mini", "minimized")]}));
    assert_eq!(reply["ok"], true, "{reply}");
    assert_eq!(reply["result"], json!([true, true, true, true]));
}

#[test]
fn shipped_defaults_removal_and_presentation_recipes_load() {
    for key in ["t", "w"] {
        let mut helper = Helper::new(library());
        let reply = request(&mut helper, json!({"op": "load", "path": fixture(&format!("without-window-{key}.ncl"))}));
        assert_eq!(reply["ok"], true, "{reply}");
        let mut expected = expected_window_bindings();
        expected.as_object_mut().unwrap().remove(key);
        assert_eq!(reply["result"]["config"]["mode"]["window"]["binding"], expected);
    }
    for (file, lens, field, expected) in [
        ("disable-windows.ncl", "windows", "enabled", json!(false)),
        ("windows-list.ncl", "windows", "presentation", json!("list")),
        ("app-windows-strip.ncl", "app-windows", "presentation", json!("strip")),
        ("app-windows-strip.ncl", "app-windows", "tile", json!("picture")),
    ] {
        let mut helper = Helper::new(library());
        let reply = request(&mut helper, json!({"op": "load", "path": fixture(file)}));
        assert_eq!(reply["ok"], true, "{reply}");
        assert_eq!(reply["result"]["config"]["lenses"][lens][field], expected);
    }
}

#[test]
fn conversion_describes_and_imports_six_lenses_with_or_without_modes() {
    for source in ["", "[mode.main.binding]\nalt-h = \"focus left\"\n"] {
        let converted = converted_toml(if source.is_empty() { "six-no-modes" } else { "six-modes" }, source).unwrap();
        assert!(converted.nickel.contains("six Lenses"), "{}", converted.nickel);
        let config = loaded_source(if source.is_empty() { "six-no-modes" } else { "six-modes" }, &converted.nickel);
        assert_eq!(config["lenses"].as_object().unwrap().keys().cloned().collect::<Vec<_>>(), ["app-windows", "floating", "overview", "recent", "search", "windows"]);
    }
}

#[test]
fn every_lenses_document_nickel_example_loads_as_a_whole_config() {
    let doc = std::fs::read_to_string(Path::new(env!("CARGO_MANIFEST_DIR")).join("../docs/lenses.md")).unwrap();
    let mut block = None;
    let mut count = 0;
    for (index, line) in doc.lines().enumerate() {
        if line.trim() == "```nickel" {
            assert!(block.is_none());
            block = Some((index + 1, String::new()));
        } else if line.trim() == "```" {
            if let Some((start, source)) = block.take() {
                let file = std::env::temp_dir().join(format!("winmux-lenses-doc-{}-{start}.ncl", std::process::id()));
                std::fs::write(&file, source).unwrap();
                let output = run_helper(&["check", &file.to_string_lossy()]);
                std::fs::remove_file(file).unwrap();
                assert!(output.status.success(), "docs/lenses.md:{start}: {}", String::from_utf8_lossy(&output.stderr));
                count += 1;
            }
        } else if let Some((_, source)) = &mut block {
            source.push_str(line);
            source.push('\n');
        }
    }
    assert!(block.is_none(), "unclosed Nickel fence");
    assert!(count > 0, "no Nickel examples found");
}

#[test]
fn removed_detection_message_matches_shared_fixture() {
    assert!(!removal_message().ends_with('\n'), "the fixture ends in exactly one newline");
    assert_eq!(
        winmux_nickel::protocol::ON_WINDOW_DETECTED_REMOVED,
        removal_message(),
    );
}

fn removal_message() -> &'static str {
    include_str!("fixtures/on-window-detected-removed.txt").strip_suffix('\n').unwrap()
}

/// Loads `source` from a file named `name` through the helper protocol and returns the load error.
fn removal_load_error(name: &str, source: &str) -> String {
    let dir = std::env::temp_dir().join(format!("winmux-removal-{}", std::process::id()));
    std::fs::create_dir_all(&dir).unwrap();
    let path = dir.join(name);
    std::fs::write(&path, source).unwrap();
    let mut helper = Helper::new(library());
    let reply = request(&mut helper, json!({"id": 1, "op": "load", "path": path}));
    let _ = std::fs::remove_file(&path);
    assert_eq!(reply["ok"], false, "{name}: {reply}");
    reply["error"].as_str().unwrap().to_owned()
}

#[test]
fn removed_detection_is_the_whole_error_when_the_record_has_the_key() {
    // A plain record, and one whose value would fail to evaluate: the key is read from the record.
    for (name, source) in [("plain.ncl", "{ on-window-detected = [] }"), ("static.ncl", "{ on-window-detected = 1 + true }")] {
        assert_eq!(removal_load_error(name, source), removal_message(), "{name}");
    }
}

#[test]
fn removed_detection_follows_the_contract_diagnostic_after_one_blank_line() {
    for (name, source) in [
        ("contract.ncl", r#"let W = import "winmux/winmux.ncl" in { on-window-detected = [] } | W.Config"#),
        ("two-extra.ncl", r#"let W = import "winmux/winmux.ncl" in { bogus-key = true, on-window-detected = [] } | W.Config"#),
    ] {
        let error = removal_load_error(name, source);
        let message = removal_message();
        assert!(error.contains("extra field"), "{name}: {error}");
        assert_eq!(error.matches(message).count(), 1, "{name}: {error}");
        assert!(error.ends_with(&format!("\n\n{message}")), "{name}: {error}");
        assert!(!error.ends_with(&format!("\n\n\n{message}")), "{name}: {error}");
    }
}

#[test]
fn removed_detection_is_not_appended_when_only_the_text_mentions_the_key() {
    let message = removal_message();
    for (name, source) in [
        ("comment.ncl", "let W = import \"winmux/winmux.ncl\" in\n{ start-at-login = 3, # moved off on-window-detected\n} | W.Config"),
        ("on-window-detected-notes.ncl", r#"let W = import "winmux/winmux.ncl" in { start-at-login = 3 } | W.Config"#),
        ("syntax.ncl", "{ on-window-detected = }"),
    ] {
        let error = removal_load_error(name, source);
        assert!(!error.contains(message), "{name}: {error}");
    }
}

#[test]
fn stderr_diagnostics_add_a_missing_newline_and_preserve_nickels_newlines() {
    let missing = "/nonexistent/winmux-config.ncl";
    let output = run_helper(&["check", missing]);
    assert_eq!(output.status.code(), Some(2));
    let diagnostic = winmux_nickel::protocol::load(Some(Path::new(missing)), &library()).err().unwrap();
    assert!(!diagnostic.ends_with('\n'));
    assert_eq!(String::from_utf8(output.stderr).unwrap(), format!("{diagnostic}\n"));

    let missing = Path::new("/nonexistent/winmux-config.toml");
    let diagnostic = winmux_nickel::convert::convert(missing, &library()).err().unwrap();
    assert!(diagnostic.ends_with('\n'));
    let output = run_helper(&["convert", missing.to_str().unwrap()]);
    assert_eq!(output.status.code(), Some(1));
    assert_eq!(String::from_utf8(output.stderr).unwrap(), diagnostic);

    let missing_library = Path::new("/nonexistent/winmux-library");
    let diagnostic = winmux_nickel::protocol::load(None, missing_library).err().unwrap();
    assert!(diagnostic.ends_with('\n'));
    let output = std::process::Command::new(env!("CARGO_BIN_EXE_winmux-nickel"))
        .arg("defaults")
        .env("WINMUX_NICKEL_LIBRARY", missing_library)
        .output().unwrap();
    assert_eq!(output.status.code(), Some(1));
    assert_eq!(String::from_utf8(output.stderr).unwrap(), diagnostic);
}
