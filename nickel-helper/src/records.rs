//! Contract version 1: the records WinMux hands to Filters and Policy hooks.
//!
//! This file is the one definition. The Nickel contracts in `nickel/winmux/contract.ncl`, the
//! output of `config schema` and the checks on what WinMux sends are all derived from it, so
//! after changing a record run `make contract`.

use nickel_lang_core::eval::value::NickelValue;

use crate::{
    host::{HostValue, Nullable},
    host_enum, host_record,
};

/// Bumped only when a field is removed or renamed. Adding a field does not bump it.
pub const CONTRACT_VERSION: u32 = 1;

host_enum! {
    pub enum WindowClass {
        Tiled => "tiled",
        Floating => "floating",
        Fullscreen => "fullscreen",
        Minimized => "minimized",
        HiddenApp => "hidden-app",
        AccessoryPopup => "accessory-popup",
        AppPopup => "app-popup",
    }
}

host_enum! {
    pub enum ActivationPolicy { Regular => "regular", Accessory => "accessory", Prohibited => "prohibited" }
}

host_record! {
    pub struct Monitor {
        /// The monitor's name, or "" when unknown.
        "name" => name: String,
        /// The display's UUID, which survives reconnecting it, or "" when unknown.
        "uuid" => uuid: String,
        /// Whether it is the Mac's built-in display.
        "builtin" => builtin: bool,
    }
}

host_record! {
    pub struct App {
        /// The app's bundle identifier, or "" when it has none.
        "bundleId" => bundle_id: String,
        /// The app's name, or "" when unknown.
        "name" => name: String,
        /// The app's process id.
        "pid" => pid: i64,
        /// Whether the app's bundle declares it an Accessory app (LSUIElement). Fixed while the app runs. Always false for now.
        "accessory" => accessory: bool,
        /// The app's activation policy right now. It can change while the app runs. Always 'regular for now.
        "activationPolicy" => activation_policy: ActivationPolicy,
    }
}

host_record! {
    pub struct Window {
        /// WinMux's id for the window.
        "id" => id: i64,
        /// The window's title, or "" when it has none.
        "title" => title: String,
        /// Where the window sits in WinMux's layout. Every window has exactly one class. For now every popup is 'app-popup.
        "class" => class: WindowClass,
        /// The window's accessibility subrole, such as "AXStandardWindow", or "" when unknown.
        "subrole" => subrole: String,
        /// The window's layer in the window server: 0 for a normal window, and 0 when unknown, as for a window that is off screen.
        "level" => level: i64,
        /// Whether the window has a close button.
        "hasCloseButton" => has_close_button: bool,
        /// The document the window shows, as a URL, or "" when it shows none.
        "document" => document: String,
        /// The window's workspace, or "" for a popup. A minimized window reports the workspace it was minimized on.
        "workspace" => workspace: String,
        /// The id of the project the window's workspace belongs to, or "" when the workspace is unknown.
        "project" => project: String,
        /// The monitor showing the window's workspace. Every field is at its unknown value when the window has no workspace on a monitor.
        "monitor" => monitor: Monitor,
        /// The window's place in focus order: higher is more recent, and 0 is not focused since WinMux started.
        "lastFocusedSeq" => last_focused_seq: i64,
        /// The app that owns the window.
        "app" => app: App,
    }
}

host_record! {
    pub struct Workspace {
        /// The workspace's name.
        "name" => name: String,
        /// The id of the project the workspace belongs to.
        "project" => project: String,
    }
}

host_record! {
    pub struct FilterContext {
        /// The focused window, or null when no window is focused.
        "focused" => focused: Nullable<Window>,
        /// The window under the mouse, or null when the mouse is over none.
        "mouse" => mouse: Nullable<Window>,
        /// The window that was focused before the focused one, or null when there is none.
        "previous" => previous: Nullable<Window>,
        /// The focused workspace.
        "workspace" => workspace: Workspace,
        /// The focused monitor.
        "monitor" => monitor: Monitor,
        /// The active Display profile. Always "default" for now.
        "profile" => profile: String,
    }
}

host_record! {
    pub struct Column {
        /// The Column's position, counted from the left.
        "index" => index: i64,
        /// The Column's width, as a fraction of the workspace's width.
        "width" => width: f64,
        /// Whether the Column holds no windows.
        "empty" => empty: bool,
        /// The windows in the Column, top to bottom.
        "windows" => windows: Vec<Window>,
    }
}

/// The two Filter contexts of the smoke run: every context window set, then all three `null`,
/// so a Filter that reads `ctx.focused.app` without a guard fails at load.
fn smoke_contexts() -> [FilterContext; 2] {
    let full = FilterContext::synthetic();
    let empty = FilterContext { focused: Nullable(None), mouse: Nullable(None), previous: Nullable(None), ..full.clone() };
    [full, empty]
}

/// The host type of one hook argument.
#[derive(Debug, Clone, Copy)]
pub enum HookArg {
    Window,
    FilterContext,
}

impl HookArg {
    pub fn to_nickel(self, json: serde_json::Value) -> Result<NickelValue, serde_json::Error> {
        Ok(match self {
            HookArg::Window => serde_json::from_value::<Window>(json)?.to_nickel(),
            HookArg::FilterContext => serde_json::from_value::<FilterContext>(json)?.to_nickel(),
        })
    }

    fn synthetic(self, context: &FilterContext) -> NickelValue {
        match self {
            HookArg::Window => Window::synthetic().to_nickel(),
            HookArg::FilterContext => context.to_nickel(),
        }
    }
}

/// Every Policy hook, by its path in the config, with the arguments WinMux passes it. "Column
/// Policy hooks and Column commands" gives each hook its real arguments.
pub const HOOKS: &[(&str, &[HookArg])] = &[
    ("arrive", &[HookArg::Window, HookArg::FilterContext]),
    ("columns.place", &[HookArg::Window, HookArg::FilterContext]),
    ("columns.move-boundary", &[HookArg::Window, HookArg::FilterContext]),
];

pub fn hook_args(hook: &str) -> Option<&'static [HookArg]> {
    HOOKS.iter().find(|(path, _)| *path == hook).map(|(_, args)| *args)
}

/// One pass of the smoke run: the arguments every Filter is called with.
pub struct SmokePass {
    pub window: NickelValue,
    pub context: NickelValue,
}

pub fn smoke_passes() -> Vec<SmokePass> {
    smoke_contexts()
        .iter()
        .map(|context| SmokePass { window: Window::synthetic().to_nickel(), context: context.to_nickel() })
        .collect()
}

/// The arguments a hook is smoke-run with, one list per pass.
pub fn hook_smoke_passes(args: &[HookArg]) -> Vec<Vec<NickelValue>> {
    smoke_contexts().iter().map(|context| args.iter().map(|arg| arg.synthetic(context)).collect()).collect()
}
