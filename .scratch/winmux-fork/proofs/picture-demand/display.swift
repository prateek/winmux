import AppKit
for screen in NSScreen.screens {
    print("Display: \(Int(screen.frame.width)) × \(Int(screen.frame.height)) points, scale \(screen.backingScaleFactor)")
}

var timebase = mach_timebase_info_data_t()
mach_timebase_info(&timebase)
print("Mach timebase: \(timebase.numer)/\(timebase.denom) ns per tick")
