#!/usr/bin/env python3
from pathlib import Path

source = Path.home() / "winmux/.claude/skills/demo/stage.swift"
fixture = source.read_text().replace("let window = NSWindow(", "let window = SlowRecordWindow(")
fixture = fixture.replace("final class Stage:", '''final class SlowRecordWindow: NSWindow {
    override func accessibilityTitle() -> String? {
        if title.hasPrefix("Trial ") {
            Thread.sleep(forTimeInterval: 0.12)
        }
        return super.accessibilityTitle()
    }
}

final class Stage:''')
(Path.home() / "arrive-proof/slow-stage.swift").write_text(fixture)
