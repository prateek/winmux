import Darwin

/// Lens stamps use Mach absolute seconds, excluding sleep. Processes on the
/// same machine share this timebase, and `NSEvent.timestamp` and a Carbon
/// event's time are already on it.
public struct LensTimebase: Sendable {
    public let numerator: UInt32
    public let denominator: UInt32
    public init(numerator: UInt32, denominator: UInt32) {
        self.numerator = numerator
        self.denominator = denominator
    }
    public func seconds(ticks: UInt64) -> Double {
        Double(ticks) * Double(numerator) / Double(denominator) / 1e9
    }
    public static let system: Self = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return Self(numerator: info.numer, denominator: info.denom)
    }()
    public static func now() -> Double { system.seconds(ticks: mach_absolute_time()) }
}
