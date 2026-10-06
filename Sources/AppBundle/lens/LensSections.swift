struct LensSectionIdentity: Equatable {
    let key: String
    let label: String
    let current: Bool
}

struct LensSection<Entry> {
    let key: String
    let label: String?
    let current: Bool
    let entries: [Entry]
}

func lensSections<Entry>(_ entries: [Entry], grouping: String, identities: [LensSectionIdentity],
                         key: (Entry) -> String, label: (Entry) -> String) -> [LensSection<Entry>] {
    guard !entries.isEmpty else { return [] }
    if grouping == "none" { return [LensSection(key: "", label: nil, current: false, entries: entries)] }
    var buckets: [String: [Entry]] = [:]
    var incoming: [String] = []
    for entry in entries {
        let value = key(entry)
        if buckets[value] == nil { incoming.append(value) }
        buckets[value, default: []].append(entry)
    }
    let known = identities.filter { buckets[$0.key] != nil && !$0.key.isEmpty }
    let ordered = known.filter(\.current) + known.filter { !$0.current }
    let knownKeys = Set(ordered.map(\.key))
    let keys = grouping == "app" ? incoming : ordered.map(\.key) + incoming.filter { !knownKeys.contains($0) && !$0.isEmpty } + (buckets[""] == nil ? [] : [""])
    return keys.map { value in
        let identity = ordered.first { $0.key == value }
        let entries = buckets[value]!
        return LensSection(key: value,
                           label: value.isEmpty && grouping != "app" ? "No \(grouping)" : identity?.label ?? label(entries[0]),
                           current: grouping != "app" && identity?.current == true, entries: entries)
    }
}

func lensAppIdentity(bundleId: String, pid: Int) -> String {
    bundleId.isEmpty ? "pid:\(pid)" : bundleId
}
