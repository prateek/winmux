use std::path::PathBuf;
use winmux_nickel::protocol;

fn library() -> PathBuf { PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("nickel") }
fn check(body: &str) -> Result<serde_json::Value, String> {
    static NEXT: std::sync::atomic::AtomicUsize = std::sync::atomic::AtomicUsize::new(0);
    let path = std::env::temp_dir().join(format!("winmux-column-{}-{}.ncl", std::process::id(), NEXT.fetch_add(1, std::sync::atomic::Ordering::Relaxed)));
    std::fs::write(&path, format!("let W = import \"winmux/winmux.ncl\" in {{ {body} }} | W.Config")).unwrap();
    let result = protocol::load(Some(&path), &library()).map(|(_, json)| json);
    let _ = std::fs::remove_file(path);
    result
}

#[test]
fn accepts_all_hooks_and_exports_callable_paths() {
    let loaded = check("arrive = fun w ctx cols => {}, columns = { count = 3, place = fun w ctx cols => { column = 'focused, overflow = 'split }, move-boundary = fun w ctx cols edge => { action = if edge then 'wrap else 'swap } }, workspace.Demo.columns.when.default.place = fun w ctx cols => { column = 2, overflow = 'squeeze }, workspace.\"Dot.name\".columns.place = fun w ctx cols => { column = 1, overflow = 'split }").unwrap();
    assert_eq!(loaded["config"]["arrive"], "arrive");
    assert_eq!(loaded["config"]["workspace"]["Dot.name"]["columns"]["place"], "workspace.\"Dot.name\".columns.place");
    assert_eq!(loaded["config"]["columns"]["place"], "columns.place");
    assert_eq!(loaded["config"]["workspace"]["Demo"]["columns"]["when"]["default"]["place"], "workspace.Demo.columns.when.default.place");
}

#[test]
fn unknown_actions_and_both_smoke_contexts_are_checked() {
    for body in [
        "columns.place = fun w ctx cols => { column = 'focused, overflow = 'unknown }",
        "columns.move-boundary = fun w ctx cols edge => { action = 'unknown }",
        "workspace.A.columns.when.\"B.columns\".place = fun w ctx cols => { column = 1, overflow = 'unknown }, workspace.\"A.columns.when.B\".columns.place = fun w ctx cols => { column = 1, overflow = 'split }",
        "arrive = fun w ctx cols => { float = ctx.focused.app.accessory }",
        "workspace.Demo.columns.place = fun w ctx cols => { column = 'last, overflow = if ctx.previous == null then 'unknown else 'split }",
        "columns.when.default.move-boundary = fun w ctx cols edge => { action = if edge then 'unknown else 'join }",
    ] {
        let error = check(body).unwrap_err();
        assert!(error.contains("smoke run"), "{error}");
    }
}

#[test]
fn hook_result_shapes_and_removed_detection_key_are_checked() {
    for body in [
        "arrive = fun w ctx cols => { float = 1 }",
        "columns.place = fun w ctx cols => { column = 0, overflow = 'split }",
        "columns.place = fun w ctx cols => { column = 1.5, overflow = 'float }",
        "columns.place = fun w ctx cols => { column = 'last }",
        "columns.move-boundary = fun w ctx cols edge => { action = 'join, overflow = 'unknown }",
        "arrive = fun w ctx cols => { run = [1] }",
        "on-window-detected = []",
    ] { assert!(check(body).is_err(), "accepted {body}"); }
}

#[test]
fn removed_detection_key_explains_arrive_migration() {
    let error = check("on-window-detected = []").unwrap_err();
    assert!(error.contains("on-window-detected") && error.contains("arrive"), "{error}");
}
