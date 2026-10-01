//! Drives the helper the way WinMux does: one JSON request line in, one reply line out.

use std::path::{Path, PathBuf};

use serde_json::{Value, json};
use winmux_nickel::protocol::Helper;

fn library() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("nickel")
}

fn fixture(name: &str) -> String {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("tests/fixtures").join(name).to_string_lossy().into_owned()
}

fn request(helper: &mut Helper, request: Value) -> Value {
    serde_json::from_str(&helper.handle_line(&request.to_string())).unwrap()
}

fn loaded(config: &str) -> Helper {
    let mut helper = Helper::new(library());
    let reply = request(&mut helper, json!({ "id": 0, "op": "load", "path": fixture(config) }));
    assert_eq!(reply["ok"], true, "{}", reply["error"].as_str().unwrap_or_default());
    helper
}

fn record(bundle_id: &str, class: &str) -> Value {
    json!({ "title": "Inbox", "private": false, "class": class, "app": { "bundleId": bundle_id } })
}

#[test]
fn load_returns_static_settings_without_functions_and_the_files_read() {
    let mut helper = Helper::new(library());
    let reply = request(&mut helper, json!({ "id": 7, "op": "load", "path": fixture("config.ncl") }));

    assert_eq!(reply["id"], 7);
    assert_eq!(reply["ok"], true, "{}", reply["error"]);
    assert!(reply["rss"].as_u64().unwrap() > 0);
    let config = &reply["result"]["config"];
    assert_eq!(config["lenses"]["everything"], json!({}));
    assert_eq!(config["lenses"]["mail"], json!({}), "a Lens record comes back minus its function");
    assert!(config.get("arrive").is_none());
    let imports: Vec<&str> = reply["result"]["imports"].as_array().unwrap().iter().map(|p| p.as_str().unwrap()).collect();
    assert!(imports.contains(&fixture("config.ncl").as_str()), "{imports:?}");
    assert!(imports.iter().any(|p| p.ends_with("nickel/winmux/winmux.ncl")), "{imports:?}");
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
fn batched_filter_returns_one_match_bit_per_record() {
    let mut helper = loaded("config.ncl");
    let windows: Vec<Value> = (0..50)
        .map(|i| record(if i % 5 == 0 { "com.apple.mail" } else { "com.example.other" }, "tiled"))
        .collect();

    let reply = request(
        &mut helper,
        json!({ "id": 2, "op": "filter", "lens": "mail", "ctx": record("ctx", "tiled"), "windows": windows }),
    );

    assert_eq!(reply["ok"], true, "{}", reply["error"]);
    let bits = reply["result"].as_array().unwrap();
    assert_eq!(bits.len(), 50);
    for (i, bit) in bits.iter().enumerate() {
        assert_eq!(bit.as_bool().unwrap(), i % 5 == 0, "window {i}");
    }
}

#[test]
fn filter_reads_the_context_record() {
    let mut helper = loaded("config.ncl");
    let windows = json!([record("com.apple.mail", "tiled"), record("com.example.other", "tiled")]);

    let reply = request(
        &mut helper,
        json!({ "id": 2, "op": "filter", "lens": "same-app", "ctx": record("com.example.other", "tiled"), "windows": windows }),
    );

    assert_eq!(reply["result"], json!([false, true]), "{}", reply["error"]);
}

#[test]
fn lens_without_a_filter_matches_every_record_and_an_unknown_lens_fails() {
    let mut helper = loaded("config.ncl");
    let windows = json!([record("a", "tiled"), record("b", "tiled")]);

    let all = request(
        &mut helper,
        json!({ "id": 2, "op": "filter", "lens": "everything", "ctx": record("ctx", "tiled"), "windows": windows }),
    );
    let unknown = request(
        &mut helper,
        json!({ "id": 3, "op": "filter", "lens": "nope", "ctx": record("ctx", "tiled"), "windows": windows }),
    );

    assert_eq!(all["result"], json!([true, true]));
    assert_eq!(unknown["ok"], false);
    assert!(unknown["error"].as_str().unwrap().contains("no Lens named `nope`"));
}

#[test]
fn record_missing_a_field_is_rejected_before_any_nickel_runs() {
    // No config is loaded, so a reply about the field proves the record was checked first.
    let mut helper = Helper::new(library());
    let mut window = record("com.apple.mail", "tiled");
    window.as_object_mut().unwrap().remove("title");

    let reply = request(
        &mut helper,
        json!({ "id": 2, "op": "filter", "lens": "mail", "ctx": record("ctx", "tiled"), "windows": [window] }),
    );

    assert_eq!(reply["ok"], false);
    assert!(reply["error"].as_str().unwrap().contains("missing field `title`"), "{}", reply["error"]);
}

#[test]
fn json_string_in_an_enum_field_reaches_nickel_as_an_enum_tag() {
    let mut helper = loaded("config.ncl");
    let windows = json!([record("a", "accessory-popup"), record("b", "tiled")]);

    let reply = request(
        &mut helper,
        json!({ "id": 2, "op": "filter", "lens": "popups", "ctx": record("ctx", "tiled"), "windows": windows }),
    );
    let unknown_tag = request(
        &mut helper,
        json!({ "id": 3, "op": "filter", "lens": "popups", "ctx": record("ctx", "tiled"), "windows": [record("a", "sideways")] }),
    );

    assert_eq!(reply["result"], json!([true, false]), "{}", reply["error"]);
    assert_eq!(unknown_tag["ok"], false);
    assert!(unknown_tag["error"].as_str().unwrap().contains("unknown variant `sideways`"), "{}", unknown_tag["error"]);
}

#[test]
fn eval_filter_can_call_a_named_filter() {
    let mut helper = loaded("config.ncl");
    let mut private_mail = record("com.apple.mail", "tiled");
    private_mail["private"] = json!(true);
    let windows = json!([record("com.apple.mail", "tiled"), private_mail, record("com.example.other", "tiled")]);

    let reply = request(
        &mut helper,
        json!({ "id": 2, "op": "eval-filter", "filter": "filters.mail w ctx && !w.private", "ctx": record("ctx", "tiled"), "windows": windows }),
    );

    assert_eq!(reply["result"], json!([true, false, false]), "{}", reply["error"]);
}

#[test]
fn eval_filter_reports_a_bad_filter_with_nickels_diagnostic() {
    let mut helper = loaded("config.ncl");

    let reply = request(
        &mut helper,
        json!({ "id": 2, "op": "eval-filter", "filter": "filters.male w ctx", "ctx": record("ctx", "tiled"), "windows": [record("a", "tiled")] }),
    );

    assert_eq!(reply["ok"], false);
    assert!(reply["error"].as_str().unwrap().contains("missing field `male`"), "{}", reply["error"]);
}

#[test]
fn hook_returns_its_result_as_json() {
    let mut helper = loaded("config.ncl");

    let tiled = request(
        &mut helper,
        json!({ "id": 2, "op": "hook", "hook": "arrive", "args": [record("a", "tiled"), record("ctx", "tiled")] }),
    );
    let popup = request(
        &mut helper,
        json!({ "id": 3, "op": "hook", "hook": "arrive", "args": [record("a", "accessory-popup"), record("ctx", "tiled")] }),
    );

    assert_eq!(tiled["result"], json!({ "workspace": "Inbox", "column": 2 }), "{}", tiled["error"]);
    assert_eq!(popup["result"], json!({ "float": true }));
}

#[test]
fn hook_requests_are_checked_against_the_hooks_arguments() {
    let mut helper = loaded("config.ncl");

    let unknown = request(&mut helper, json!({ "id": 2, "op": "hook", "hook": "depart", "args": [] }));
    let too_few = request(&mut helper, json!({ "id": 3, "op": "hook", "hook": "arrive", "args": [record("a", "tiled")] }));
    let undefined = request(
        &mut helper,
        json!({ "id": 4, "op": "hook", "hook": "columns.place", "args": [record("a", "tiled"), record("ctx", "tiled")] }),
    );

    assert!(unknown["error"].as_str().unwrap().contains("no Policy hook named `depart`"));
    assert!(too_few["error"].as_str().unwrap().contains("takes 2 arguments, got 1"));
    assert!(undefined["error"].as_str().unwrap().contains("does not define `columns.place`"));
}

#[test]
fn failed_request_leaves_the_helper_serving() {
    let mut helper = loaded("config.ncl");
    let windows = json!([record("com.apple.mail", "tiled")]);

    let garbage: Value = serde_json::from_str(&helper.handle_line("not json")).unwrap();
    let failed = request(
        &mut helper,
        json!({ "id": 2, "op": "eval-filter", "filter": "w.nope", "ctx": record("ctx", "tiled"), "windows": windows }),
    );
    let next = request(
        &mut helper,
        json!({ "id": 3, "op": "filter", "lens": "mail", "ctx": record("ctx", "tiled"), "windows": windows }),
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
    assert_eq!(
        config["mode"]["main"]["binding"],
        json!({ "alt-h": "focus left", "cmd-1": ["workspace 1", "mode main"] }),
        "the converted bindings replace the default ones, as they did in TOML"
    );
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
    let default_config = Path::new(env!("CARGO_MANIFEST_DIR")).join("../resources/default-config.toml");
    let converted = run_helper(&["convert", &default_config.to_string_lossy()]);
    let out = std::env::temp_dir().join(format!("winmux-nickel-default-{}.ncl", std::process::id()));
    std::fs::write(&out, &converted.stdout).unwrap();

    let checked = run_helper(&["check", &out.to_string_lossy()]);
    std::fs::remove_file(&out).unwrap();

    assert_eq!(converted.stderr, b"");
    assert_eq!(checked.status.code(), Some(0), "{}", String::from_utf8_lossy(&checked.stderr));
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
