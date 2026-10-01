use std::{
    io::{BufRead, Write},
    path::Path,
    process::ExitCode,
};

use winmux_nickel::{convert, library_dir, protocol};

const USAGE: &str = "usage: winmux-nickel serve | check <file> | convert <file> | defaults";

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let args: Vec<&str> = args.iter().map(String::as_str).collect();
    let library = match library_dir() {
        Ok(library) => library,
        Err(e) => {
            eprintln!("{e}");
            return ExitCode::from(1);
        }
    };
    match args.as_slice() {
        ["serve"] => serve(protocol::Helper::new(library)),
        ["check", file] => match protocol::load(Some(Path::new(file)), &library) {
            Ok(_) => ExitCode::SUCCESS,
            Err(diagnostic) => {
                eprint!("{diagnostic}");
                ExitCode::from(2)
            }
        },
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

/// One request per stdin line, one reply per stdout line, in order, until stdin closes.
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
