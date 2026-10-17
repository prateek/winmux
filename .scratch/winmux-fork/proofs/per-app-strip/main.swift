import AppKit

// Only the window-free Tile model and production packer are linked into this measuring tool.
final class WindowThumbnail {}
struct TileControlAvailability {}

let input = URL(fileURLWithPath: CommandLine.arguments[1])
let world = try JSONSerialization.jsonObject(with: Data(contentsOf: input)) as! [String: Any]
let inventory = world["inventory"] as! [String: Any]
let windows = inventory["windows"] as! [[String: Any]]
let ordered = windows.sorted {
    let a = $0["appName"] as! String, b = $1["appName"] as! String
    return a == b ? ($0["windowId"] as! Int) < ($1["windowId"] as! Int) : a.lowercased() < b.lowercased()
}
let grouped = Dictionary(grouping: windows, by: { $0["pid"] as! Int })
let sequences = try String(contentsOfFile: CommandLine.arguments[2], encoding: .utf8).split(separator: "\n").reduce(into: [Int: Int]()) { result, line in
    let fields = line.split(separator: " ").compactMap { Int($0) }
    if fields.count == 2 { result[fields[0]] = fields[1] }
}
var seen = Set<Int>()
let representatives = ordered.filter { seen.insert($0["pid"] as! Int).inserted }.map { first in
    grouped[first["pid"] as! Int]!.max {
        let a = $0["windowId"] as! Int, b = $1["windowId"] as! Int
        return sequences[a, default: 0] == sequences[b, default: 0] ? a > b : sequences[a, default: 0] < sequences[b, default: 0]
    }!
}
let entries: [GridLayout.Entry] = representatives.map { window in
    let name = window["appName"] as! String
    let frame = window["frame"] as! [String: Any]
    let size = CGSize(width: frame["width"] as! Double, height: frame["height"] as! Double)
    let workspace = window["workspace"] as! String
    let tile = TileEntry(title: name, appName: name, aspect: size.width / size.height, realSize: size,
                         badges: TileBadges(workspaceLabel: workspace, onFocusedWorkspace: workspace == "1", floating: window["layout"] as? String == "floating"),
                         appCount: grouped[window["pid"] as! Int]!.count)
    #if HEAD
    let width = tile.cardBarWidth(badges: true)
    print("BAR \(name): \(width), chips \(tile.chips(enabled: true))")
    return GridLayout.Entry(aspect: tile.aspect, realSize: size, kind: .card, barWidth: width)
    #else
    return GridLayout.Entry(aspect: tile.aspect, realSize: size, kind: .card)
    #endif
}
func pack(_ entries: [GridLayout.Entry], sizing: GridLayout.Sizing = .strip) -> GridLayout {
    GridLayout(sections: [.init(label: nil, current: false, entries: entries)], visibleSize: NSScreen.main!.visibleFrame.size, tileSize: "real", sizing: sizing)
}
func describe(_ name: String, _ layout: GridLayout) {
    print("\(name): rows=\(Set(layout.tiles.map { $0.frame.minY }).count) rowHeight=\(layout.rowHeight) scale=\(layout.tileScale) panel=\(layout.panelSize)")
    for (window, tile) in zip(representatives, layout.tiles) { print("  \(window["appName"]!): \(tile.frame)") }
}
describe("strip", pack(entries))
#if HEAD
for count in 1...entries.count {
    let layout = pack(Array(entries.prefix(count)))
    if Set(layout.tiles.map { $0.frame.minY }).count > 1 { print("FIRST WRAP \(count)"); break }
}
let capped = GridLayout.Sizing(rowHeightCap: 88, readableHeight: 88, honoursAccessoryWindow: true, horizontalChrome: 88, top: 26, bottom: 64, minimumWidth: 418, emptyHeight: 90)
describe("88-point cap (not built)", pack(entries, sizing: capped))
var cheaper = entries
for index in cheaper.indices {
    let count = grouped[representatives[index]["pid"] as! Int]!.count
    let countText = "\(count) \(count == 1 ? "window" : "windows")"
    let font = NSFont.systemFont(ofSize: 12, weight: .semibold)
    cheaper[index].barWidth -= ceil((countText as NSString).size(withAttributes: [.font: font]).width) - ceil(("\(count)" as NSString).size(withAttributes: [.font: font]).width)
    print("BARE NUMBER BAR \(representatives[index]["appName"]!): \(cheaper[index].barWidth)")
}
describe("bare count (not built)", pack(cheaper))
#endif
