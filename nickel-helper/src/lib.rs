//! `winmux-nickel` evaluates WinMux's Nickel config in a process of its own, so that WinMux
//! never links Nickel. See docs/adr/0001-nickel-helper-process.md.

pub mod convert;
pub mod engine;
pub mod host;
pub mod protocol;
pub mod records;
pub mod rss;

use std::path::PathBuf;

/// The directory that holds the shipped `winmux/` library: `WINMUX_NICKEL_LIBRARY`, else
/// `Contents/Resources/nickel` of the app bundle the helper sits in, else the crate's `nickel`
/// directory next to a cargo `target` directory.
pub fn library_dir() -> Result<PathBuf, String> {
    if let Some(dir) = std::env::var_os("WINMUX_NICKEL_LIBRARY") {
        return Ok(PathBuf::from(dir));
    }
    let exe = std::env::current_exe().and_then(std::fs::canonicalize).map_err(|e| e.to_string())?;
    let candidates = ["../Resources/nickel", "../../nickel"];
    exe.parent()
        .into_iter()
        .flat_map(|dir| candidates.iter().map(move |candidate| dir.join(candidate)))
        .find(|dir| dir.join("winmux/winmux.ncl").is_file())
        .ok_or_else(|| format!("cannot find the winmux Nickel library near {}", exe.display()))
}
