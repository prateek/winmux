use std::{
    io::{BufRead, Write},
    path::Path,
    process::ExitCode,
};

use winmux_nickel::{library_dir, protocol};

const USAGE: &str = "usage: winmux-nickel serve | check <file>";

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
