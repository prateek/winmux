# Owned Accessory and Dock window demo

`demo.swift` is the source used for the Accessory defaults live run. Compile it into an app
bundle with `swiftc demo.swift -o <app>/Contents/MacOS/<executable>`. The bundle declares its
executable, identifier and name in Info.plist. Use `LSUIElement = true` for the Accessory app;
omit it for the ordinary Dock app. Pass a neutral scratch directory as the executable's first
argument, or use `/tmp/winmux10-demo`.

The app reads `<scratch>/command`. Each changed command runs once:

- `standard`: a closable standard window with an enabled fullscreen button, regular policy.
- `dialog`: the same standard shape with no AX close button, regular policy.
- `popup`: a standard window with no AX close button, accessory policy.
- `app-popup`: an AXUnknown popup, regular policy.
- `background`: cover the existing window with a neutral backdrop, for the Enter raise check.
- `accessory` / `regular`: change policy without replacing the window, for live Filter checks.
- `raise`: raise the most recently created window.
- `quit`: close the owned app.

The close-button-less window overrides `accessibilityCloseButton()`; omitting `.closable`
alone still exposes a disabled AX button. This is a controlled popup fixture, not a browser
with saved credentials. Follow the handoff's Live runs notes before starting WinMux or recording.
