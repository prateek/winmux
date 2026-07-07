@testable import AppBundle
import Common

@MainActor
func testDisplayLayoutConfig(
    monitor: MonitorDescription = .sequenceNumber(1),
    layoutId: String = "test-layout",
    defaultZone: String? = "main",
    columns: [ColumnConfig],
) -> DisplayLayoutConfig {
    config.columnLayouts.removeAll { $0.id == layoutId }
    config.columnLayouts.append(ColumnLayoutConfig(
        id: layoutId,
        layout: .columns,
        defaultZone: defaultZone,
        columns: columns,
    ))
    return DisplayLayoutConfig(monitor: monitor, layoutPreset: layoutId)
}
