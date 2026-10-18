#!/bin/bash
# Run in the guest, after vm build. Launch through open for an independent TCC identity.
set -euo pipefail
source_root=${1:-$HOME/winmux}
app=${2:-$HOME/demo/WinMux Setup.app}
binary="$source_root/.build/debug/WinMuxApp"
framework="$source_root/.build/debug/Sparkle.framework"
if [ ! -d "$framework" ]; then
  framework="$source_root/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
fi
test -x "$binary"
test -d "$framework"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Frameworks"
cp "$binary" "$app/Contents/MacOS/WinMuxApp"
ditto "$framework" "$app/Contents/MacOS/Sparkle.framework"
# SPM and Xcode use different framework rpaths; supply both without patching the binary.
ln -sfn ../MacOS/Sparkle.framework "$app/Contents/Frameworks/Sparkle.framework"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.zimengxiong.winmux.debug</string>
<key>CFBundleName</key><string>WinMux</string>
<key>CFBundleDisplayName</key><string>WinMux</string>
<key>CFBundleExecutable</key><string>WinMuxApp</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSUIElement</key><true/>
<key>CFBundleURLTypes</key><array><dict>
<key>CFBundleURLName</key><string>com.zimengxiong.winmux.debug</string>
<key>CFBundleURLSchemes</key><array><string>winmux</string></array>
</dict></array>
</dict></plist>
PLIST
codesign --force --deep --sign - "$app"
printf '%s\n' "$app"
