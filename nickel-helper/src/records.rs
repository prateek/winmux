//! The records WinMux hands to Filters and Policy hooks, and each hook's argument list.
//!
//! These are stand-ins. "Filter contract v1 and `config schema`" replaces `Window` and
//! `FilterContext` with the real records and `smoke_passes` with its two passes, and "Column
//! Policy hooks and Column commands" gives each hook its real arguments. Nothing outside this
//! file names a field of either record.

use nickel_lang_core::eval::value::NickelValue;

use crate::{host::HostValue, host_enum, host_record};

host_enum! {
    pub enum StandInClass { Tiled => "tiled", AccessoryPopup => "accessory-popup" }
}

host_record! {
    pub struct StandInApp { "bundleId" => bundle_id: String }
}

host_record! {
    pub struct StandIn {
        "title" => title: String,
        "private" => private: bool,
        "class" => class: StandInClass,
        "app" => app: StandInApp,
    }
}

pub type Window = StandIn;
pub type FilterContext = StandIn;

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

    fn synthetic(self) -> NickelValue {
        match self {
            HookArg::Window => Window::synthetic().to_nickel(),
            HookArg::FilterContext => FilterContext::synthetic().to_nickel(),
        }
    }
}

/// Every Policy hook, by its path in the config, with the arguments WinMux passes it.
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
    vec![SmokePass { window: Window::synthetic().to_nickel(), context: FilterContext::synthetic().to_nickel() }]
}

/// The arguments a hook is smoke-run with, one list per pass.
pub fn hook_smoke_passes(args: &[HookArg]) -> Vec<Vec<NickelValue>> {
    vec![args.iter().map(|arg| arg.synthetic()).collect()]
}
