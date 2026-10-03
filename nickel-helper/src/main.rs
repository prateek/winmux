use std::{
    io::{BufRead, Write},
    path::Path,
    process::ExitCode,
};

use winmux_nickel::{convert, library_dir, protocol, schema};

const USAGE: &str =
    "usage: winmux-nickel serve | check [<file>] | convert <file> | schema [--json] | defaults | contract";

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let args: Vec<&str> = args.iter().map(String::as_str).collect();
    // These three print what is compiled in, so they work without the shipped library.
    match args.as_slice() {
        ["schema"] => return print(&schema::schema_text()),
        ["schema", "--json"] => return print(&format!("{:#}\n", schema::schema_json())),
        // The source of nickel/winmux/contract.ncl. Regenerate it after changing a record.
        ["contract"] => return print(&schema::nickel_contracts()),
        _ => {}
    }
    let library = match library_dir() {
        Ok(library) => library,
        Err(e) => {
            eprintln!("{e}");
            return ExitCode::from(1);
        }
    };
    match args.as_slice() {
        ["serve"] => serve(protocol::Helper::new(library)),
        ["check", file] => check(Some(Path::new(file)), &library),
        ["check"] => check(None, &library),
        // The static settings of the shipped defaults: what WinMux falls back to without a helper.
        ["defaults"] => match protocol::load(None, &library) {
            Ok((_, result)) => {
                println!("{:#}", result["config"]);
                ExitCode::SUCCESS
            }
            Err(diagnostic) => {
                eprint!("{diagnostic}");
                ExitCode::from(1)
            }
        },
        ["convert", file] => match convert::convert(Path::new(file), &library) {
            Ok(converted) => {
                for warning in converted.warnings {
                    eprintln!("warning: {warning}");
                }
                print!("{}", converted.nickel);
                ExitCode::SUCCESS
            }
            Err(diagnostic) => {
                eprint!("{diagnostic}");
                ExitCode::from(1)
            }
        },
        _ => {
            eprintln!("{USAGE}");
            ExitCode::from(2)
        }
    }
}

fn print(text: &str) -> ExitCode {
    print!("{text}");
    ExitCode::SUCCESS
}

fn check(file: Option<&Path>, library: &Path) -> ExitCode {
    match protocol::load(file, library) {
        Ok((_, result)) => {
            if let Some(warnings) = result["warnings"].as_array() {
                for warning in warnings { eprintln!("warning: {}", warning.as_str().unwrap_or_default()); }
            }
            ExitCode::SUCCESS
        },
        Err(diagnostic) => {
            eprint!("{diagnostic}");
            ExitCode::from(2)
        }
    }
}

fn serve(mut helper: protocol::Helper) -> ExitCode {
    let mut out = std::io::stdout().lock();
    for line in std::io::stdin().lock().lines() {
        let Ok(line) = line else { break };
        if writeln!(out, "{}", helper.handle_line(&line)).and_then(|()| out.flush()).is_err() {
            break;
        }
    }
    ExitCode::SUCCESS
}
