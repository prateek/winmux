import Foundation

struct SceneBlockColumn: Equatable {
    let id: String
    let name: String?
    let width: Double
    let color: String?
}

/// Renders a `[scene.<name>]` block from a live column arrangement, the text `scene new` appends
/// to the config. Widths are normalized to sum to 1.0 so the block parses cleanly.
func renderSceneConfigBlock(
    name: String,
    display: Int,
    defaultColumn: String?,
    columns: [SceneBlockColumn],
) -> String {
    var lines = [
        "[scene.\(name)]",
        "display = \(display)",
    ]
    if let defaultColumn {
        lines.append("default-column = \(tomlBasicString(defaultColumn))")
    }
    lines.append("columns = [")
    let normalizedWidths = normalizedZoneLayoutWidths(columns.map(\.width))
    for (column, width) in zip(columns, normalizedWidths) {
        var fields = ["id = \(tomlBasicString(column.id))"]
        if let columnName = column.name {
            fields.append("name = \(tomlBasicString(columnName))")
        }
        fields.append("width = \(formatTomlFloat(width))")
        if let color = column.color {
            fields.append("color = \(tomlBasicString(color))")
        }
        lines.append("    { \(fields.joined(separator: ", ")) },")
    }
    lines.append("]")
    return lines.joined(separator: "\n")
}
