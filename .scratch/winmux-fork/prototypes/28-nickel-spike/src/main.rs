use std::time::{Duration, Instant};

use serde_json::json;
use winmux_nickel_spike::{Engine, from_json, to_json};

fn window(i: usize) -> serde_json::Value {
    let apps = [
        ("com.apple.mail", "Mail"),
        ("com.mitchellh.ghostty", "Ghostty"),
        ("com.google.Chrome", "Google Chrome"),
        ("com.tinyspeck.slackmacgap", "Slack"),
        ("com.microsoft.VSCode", "Code"),
    ];
    let (bundle, name) = apps[i % apps.len()];
    json!({
        "id": 1000 + i, "title": format!("Window {i} — some document title"),
        "app": { "bundleId": bundle, "name": name, "pid": 400 + i % 5 },
        "class": if i % 7 == 0 { "'floating" } else { "'tiling" },
        "workspace": format!("{}", i % 4), "project": if i % 2 == 0 { "winmux" } else { "dotfiles" },
        "frame": { "x": 10.5 * i as f64, "y": 20, "w": 800, "h": 600 },
        "lastFocusedSeq": 5000 - i, "tabs": [], "private": false,
    })
}

fn ctx() -> serde_json::Value {
    json!({
        "focused": window(2),
        "workspace": { "name": "2", "project": "winmux" },
        "profile": "'ultrawide",
    })
}

fn cols(empty: bool) -> serde_json::Value {
    json!([
        { "index": 1, "empty": false, "windows": [1000, 1001] },
        { "index": 2, "empty": empty, "windows": [] },
        { "index": 3, "empty": false, "windows": [1003] },
    ])
}

fn median(mut v: Vec<Duration>) -> Duration {
    v.sort();
    v[v.len() / 2]
}

fn us(d: Duration) -> String {
    format!("{:.1} µs", d.as_secs_f64() * 1e6)
}

fn bench(label: &str, engine: &mut Engine, n: usize, mut f: impl FnMut(&mut Engine)) {
    let t = Instant::now();
    f(engine);
    let cold = t.elapsed();
    let mut samples = Vec::with_capacity(n);
    for _ in 0..n {
        let t = Instant::now();
        f(engine);
        samples.push(t.elapsed());
    }
    let max = *samples.iter().max().unwrap();
    println!("{label:<48} first {:>10}   median {:>10}   max {:>10}", us(cold), us(median(samples)), us(max));
}

fn rss_kb() -> u64 {
    let out = std::process::Command::new("ps")
        .args(["-o", "rss=", "-p", &std::process::id().to_string()])
        .output()
        .unwrap();
    String::from_utf8_lossy(&out.stdout).trim().parse().unwrap_or(0)
}

fn run(config: &str, label: &str) {
    println!("\n== {label} ({config})");
    let t = Instant::now();
    let mut e = Engine::load(config).unwrap_or_else(|d| panic!("{d}"));
    println!("{:<48} {:>10}", "load (parse, typecheck, stdlib, WHNF)", us(t.elapsed()));

    let t = Instant::now();
    let same_app = e.lookup("filters.same_app").unwrap();
    let here = e.lookup("filters.here").unwrap();
    let filter_all = e.lookup("filter_all").unwrap();
    let place = e.lookup("columns.place").unwrap();
    let arrive = e.lookup("arrive").unwrap();
    println!("{:<48} {:>10}", "lookup 5 functions", us(t.elapsed()));

    let ws_json: Vec<_> = (0..50).map(window).collect();
    let t = Instant::now();
    let ws: Vec<_> = ws_json.iter().map(from_json).collect();
    let c = from_json(&ctx());
    println!("{:<48} {:>10}", "marshal 50 windows + ctx (JSON -> NickelValue)", us(t.elapsed()));
    let ws_arr = from_json(&serde_json::Value::Array(ws_json.clone()));

    // Sanity: results are right.
    let out = e.call(&filter_all, &[from_json(&json!("here")), ws_arr.clone(), c.clone()]).unwrap();
    println!("  here keeps {} of 50 (one-call variant: {})", ws.iter().filter(|w| e.call(&here, &[(*w).clone(), c.clone()]).unwrap().as_bool().unwrap()).count(), to_json(&out).as_array().unwrap().len());
    let p = e.call(&place, &[from_json(&window(4)), c.clone(), from_json(&cols(true))]).unwrap();
    println!("  place(VSCode, empty col) = {}", to_json(&p));
    let p = e.call(&place, &[from_json(&window(0)), c.clone(), from_json(&cols(false))]).unwrap();
    println!("  place(Mail) = {}", to_json(&p));
    let a = e.call(&arrive, &[from_json(&window(7)), c.clone()]).unwrap();
    println!("  arrive(floating Ghostty) = {}", to_json(&a));

    bench("Filter same_app, 50 per-window calls", &mut e, 200, |e| {
        for w in &ws {
            e.call(&same_app, &[w.clone(), c.clone()]).unwrap();
        }
    });
    bench("Filter here (calls floaters), 50 per-window", &mut e, 200, |e| {
        for w in &ws {
            e.call(&here, &[w.clone(), c.clone()]).unwrap();
        }
    });
    bench("Filter here, one call over 50-window array", &mut e, 200, |e| {
        e.call(&filter_all, &[from_json(&json!("here")), ws_arr.clone(), c.clone()]).unwrap();
    });
    bench("marshal + Filter here per-window (Lens open)", &mut e, 200, |e| {
        let c = from_json(&ctx());
        for wj in &ws_json {
            e.call(&here, &[from_json(wj), c.clone()]).unwrap();
        }
    });
    let w4 = from_json(&window(4));
    let cl = from_json(&cols(false));
    bench("place, one call", &mut e, 1000, |e| {
        e.call(&place, &[w4.clone(), c.clone(), cl.clone()]).unwrap();
    });
    bench("arrive, one call", &mut e, 1000, |e| {
        e.call(&arrive, &[w4.clone(), c.clone()]).unwrap();
    });

    let before = rss_kb();
    for _ in 0..20_000 {
        e.call(&place, &[w4.clone(), c.clone(), cl.clone()]).unwrap();
    }
    println!("RSS before/after 20k place calls: {before} KB -> {} KB", rss_kb());
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let dir = args.get(1).map(String::as_str).unwrap_or("config");
    match args.get(2).map(String::as_str) {
        Some("errors") => errors(dir),
        Some("leak2") => {
            let mut e = Engine::load(&format!("{dir}/leak.ncl")).unwrap();
            let w = from_json(&window(0));
            let mut cj = ctx();
            cj["cols"] = cols(false);
            let c = from_json(&cj);
            for name in ["plain", "rec_out", "let_ref", "rec_ref", "filters.comms", "any_lambda"] {
                let f = e.lookup(name).unwrap();
                let r0 = rss_kb();
                for _ in 0..10_000 {
                    e.call(&f, &[w.clone(), c.clone()]).unwrap();
                }
                println!("{name:<14} {:>8.2} KB/call", (rss_kb() as f64 - r0 as f64) / 10_000.0);
            }
        }
        Some("serve") => {
            // Helper-process variant: one JSON request per stdin line, one reply per stdout line.
            use std::io::{BufRead, Write};
            let mut e = Engine::load(&format!("{dir}/config.ncl")).unwrap_or_else(|d| panic!("{d}"));
            let stdin = std::io::stdin();
            let mut out = std::io::stdout().lock();
            for line in stdin.lock().lines() {
                let line = line.unwrap();
                let v = match winmux_nickel_spike::handle(&mut e, &line) {
                    Ok(v) => json!({ "ok": v }),
                    Err(d) => json!({ "error": d }),
                };
                writeln!(out, "{v}").unwrap();
                out.flush().unwrap();
            }
        }
        Some("leak4") => {
            for cfg in ["config.ncl", "config-nocontract.ncl"] {
                let mut e = Engine::load(&format!("{dir}/{cfg}")).unwrap();
                let here = e.lookup("filters.here").unwrap();
                let same_app = e.lookup("filters.same_app").unwrap();
                let arrive = e.lookup("arrive").unwrap();
                let ws: Vec<_> = (0..50).map(|i| from_json(&window(i))).collect();
                let c = from_json(&ctx());
                for (name, f) in [("here", &here), ("same_app", &same_app), ("arrive", &arrive)] {
                    let r0 = rss_kb();
                    for _ in 0..200 {
                        for w in &ws {
                            e.call(f, &[w.clone(), c.clone()]).unwrap();
                        }
                    }
                    println!("{cfg:<22} {name:<9} {:>7.1} KB per 50-window pass", (rss_kb() - r0) as f64 / 200.0);
                }
            }
        }
        Some("leak3") => {
            let mut e = Engine::load(&format!("{dir}/leak.ncl")).unwrap();
            for name in ["loop_plain", "loop_elem", "loop_untyped"] {
                let f = e.lookup(name).unwrap();
                let r0 = rss_kb();
                e.call(&f, &[from_json(&json!(10_000))]).unwrap();
                let r1 = rss_kb();
                e.call(&f, &[from_json(&json!(10_000))]).unwrap();
                println!("{name:<14} one eval, 10k iterations: +{} KB, again: +{} KB", r1 - r0, rss_kb() - r1);
            }
        }
        Some("leak") => {
            for cfg in ["config.ncl", "config-nocontract.ncl"] {
                let mut e = Engine::load(&format!("{dir}/{cfg}")).unwrap();
                let place = e.lookup("columns.place").unwrap();
                let same_app = e.lookup("filters.same_app").unwrap();
                let w4 = from_json(&window(4));
                let c = from_json(&ctx());
                let cl = from_json(&cols(false));
                let (p0, r0) = (e.pos_count(), rss_kb());
                for _ in 0..5000 {
                    e.call(&place, &[w4.clone(), c.clone(), cl.clone()]).unwrap();
                }
                let (p1, r1) = (e.pos_count(), rss_kb());
                for _ in 0..5000 {
                    e.call(&same_app, &[w4.clone(), c.clone()]).unwrap();
                }
                let (p2, r2) = (e.pos_count(), rss_kb());
                println!("{cfg}: positions {p0} -> {p1} (5k place) -> {p2} (5k same_app); RSS KB {r0} -> {r1} -> {r2}");
                drop(e);
                println!("  RSS after dropping Engine: {} KB", rss_kb());
            }
        }
        Some("toml") => {
            let mut e = Engine::load(&format!("{dir}/toml-import.ncl")).unwrap_or_else(|d| panic!("{d}"));
            let v = e.lookup("workspace").unwrap();
            let full = e.call(&v, &[]).unwrap();
            println!("workspace from TOML import: {}", to_json(&full));
            let g = e.lookup("gaps").unwrap();
            println!("gaps: {}", to_json(&g.value));
        }
        _ => {
            run(&format!("{dir}/config.ncl"), "with | W.Config contracts");
            run(&format!("{dir}/config-nocontract.ncl"), "without the W.Config contract");
        }
    }
}

fn errors(dir: &str) {
    println!("== typo.ncl load");
    let mut e = match Engine::load(&format!("{dir}/typo.ncl")) {
        Ok(e) => e,
        Err(d) => {
            println!("{d}");
            return;
        }
    };
    println!("loaded OK (bodies not run yet)");
    let comms = e.lookup("filters.comms").unwrap();
    let place = e.lookup("columns.place").unwrap();
    println!("\n== smoke-run filters.comms");
    match e.call(&comms, &[from_json(&window(0)), from_json(&ctx())]) {
        Ok(v) => println!("ok {}", to_json(&v)),
        Err(d) => println!("{d}"),
    }
    println!("\n== smoke-run columns.place");
    match e.call(&place, &[from_json(&window(0)), from_json(&ctx()), from_json(&cols(true))]) {
        Ok(v) => println!("ok {}", to_json(&v)),
        Err(d) => println!("{d}"),
    }
    println!("\n== bad host data: window missing `title` into a Filter");
    let mut bad = window(0);
    bad.as_object_mut().unwrap().remove("title");
    match e.call(&comms, &[from_json(&bad), from_json(&ctx())]) {
        Ok(v) => println!("ok {}", to_json(&v)),
        Err(d) => println!("{d}"),
    }
    println!("\n== engine still usable after errors?");
    let mut good = Engine::load(&format!("{dir}/config.ncl")).unwrap();
    let f = good.lookup("filters.comms").unwrap();
    println!("{}", to_json(&good.call(&f, &[from_json(&window(0)), from_json(&ctx())]).unwrap()));
    match e.call(&comms, &[from_json(&window(0)), from_json(&ctx())]) {
        Ok(v) => println!("typo engine again: ok {}", to_json(&v)),
        Err(_) => println!("typo engine again: same error (engine not poisoned)"),
    }
}
