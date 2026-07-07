import Foundation

enum ColumnLayoutConfigEditTarget: Equatable {
    case inlineZones(index: Int)
    case namedLayout(id: String)
}

struct ColumnLayoutConfigWidthChange: Equatable {
    let columnId: String
    let oldWidth: Double
    let newWidth: Double
}

struct ColumnLayoutConfigEditResult: Equatable {
    let updatedText: String
    let changes: [ColumnLayoutConfigWidthChange]
}

func updateColumnLayoutWidthsInConfigText(
    _ configText: String,
    target: ColumnLayoutConfigEditTarget,
    widthsByColumnId: [String: Double],
) -> Result<ColumnLayoutConfigEditResult, String> {
    let tableName: String
    let blockIndexResult: Result<Int, String>
    switch target {
        case .inlineZones(let index):
            tableName = "zones"
            blockIndexResult = .success(index)
        case .namedLayout(let id):
            tableName = "zone-layouts"
            blockIndexResult = columnLayoutBlockIndex(in: configText, layoutId: id)
    }
    guard case .success(let targetBlockIndex) = blockIndexResult else {
        if case .failure(let message) = blockIndexResult {
            return .failure(message)
        }
        return .failure("Unable to resolve zone layout target")
    }

    let lineSeparator = configText.contains("\r\n") ? "\r\n" : "\n"
    var lines = configText.components(separatedBy: lineSeparator)
    let blocks = arrayTableBlocks(named: tableName, in: lines)
    guard blocks.indices.contains(targetBlockIndex) else {
        return .failure("Cannot find [[\(tableName)]] block at index \(targetBlockIndex)")
    }

    switch updateColumnsBlock(
        in: &lines,
        block: blocks[targetBlockIndex],
        widthsByColumnId: widthsByColumnId,
    ) {
        case .success(let changes):
            return .success(ColumnLayoutConfigEditResult(updatedText: lines.joined(separator: lineSeparator), changes: changes))
        case .failure(let message):
            return .failure(message)
    }
}

private struct TomlTableBlock {
    let start: Int
    let end: Int
}

private func columnLayoutBlockIndex(in configText: String, layoutId: String) -> Result<Int, String> {
    let lineSeparator = configText.contains("\r\n") ? "\r\n" : "\n"
    let lines = configText.components(separatedBy: lineSeparator)
    let blocks = arrayTableBlocks(named: "zone-layouts", in: lines)
    for (index, block) in blocks.enumerated() {
        for lineIndex in (block.start + 1)..<block.end {
            guard tomlAssignmentKey(in: lines[lineIndex]) == "id",
                  let valueRange = tomlAssignmentValueRange(for: "id", in: lines[lineIndex]),
                  parseTomlStringLiteral(String(lines[lineIndex][valueRange]).trimmingCharacters(in: .whitespaces)) == layoutId
            else { continue }
            return .success(index)
        }
    }
    return .failure("Cannot find [[zone-layouts]] with id '\(layoutId)'")
}

private func arrayTableBlocks(named tableName: String, in lines: [String]) -> [TomlTableBlock] {
    let starts = lines.indices.filter { lineIndex in
        lines[lineIndex].trimmingCharacters(in: .whitespacesAndNewlines) == "[[\(tableName)]]"
    }
    return starts.enumerated().map { offset, start in
        let nextStart = lines[(start + 1)...].firstIndex(where: isTomlTableHeader) ?? lines.endIndex
        let nextSameTableStart = offset + 1 < starts.count ? starts[offset + 1] : lines.endIndex
        return TomlTableBlock(start: start, end: min(nextStart, nextSameTableStart))
    }
}

private func updateColumnsBlock(
    in lines: inout [String],
    block: TomlTableBlock,
    widthsByColumnId: [String: Double],
) -> Result<[ColumnLayoutConfigWidthChange], String> {
    guard let columnsStart = ((block.start + 1)..<block.end).first(where: { tomlAssignmentKey(in: lines[$0]) == "columns" }) else {
        return .failure("Target zone layout has no columns array")
    }
    guard stripTomlInlineComment(String(lines[columnsStart])).contains("[") else {
        return .failure("Target columns assignment is not an array")
    }
    guard !stripTomlInlineComment(String(lines[columnsStart])).contains("]") else {
        return .failure("Single-line columns arrays are not supported by layout persistence yet")
    }
    guard let columnsEnd = ((columnsStart + 1)..<block.end).first(where: { lineIndex in
        stripTomlInlineComment(String(lines[lineIndex])).trimmingCharacters(in: .whitespaces).hasPrefix("]")
    }) else {
        return .failure("Target columns array is missing a closing bracket")
    }

    var seenColumnIds: [String] = []
    var replacements: [(lineIndex: Int, line: String, change: ColumnLayoutConfigWidthChange)] = []
    for lineIndex in (columnsStart + 1)..<columnsEnd {
        let line = lines[lineIndex]
        guard let columnId = tomlInlineTableStringValue(for: "id", in: line) else { continue }
        guard !seenColumnIds.contains(columnId) else {
            return .failure("Target columns array contains duplicated zone id '\(columnId)'")
        }
        seenColumnIds.append(columnId)
        guard let newWidth = widthsByColumnId[columnId] else {
            return .failure("Target columns array contains zone id '\(columnId)' that is not active in the runtime layout")
        }
        guard let oldWidthRange = tomlAssignmentValueRange(for: "width", in: line),
              let oldWidth = Double(String(line[oldWidthRange]).trimmingCharacters(in: .whitespaces))
        else {
            return .failure("Target column '\(columnId)' is missing an editable width value")
        }
        let renderedWidth = formatTomlFloat(newWidth)
        var updatedLine = line
        updatedLine.replaceSubrange(oldWidthRange, with: renderedWidth)
        replacements.append((
            lineIndex: lineIndex,
            line: updatedLine,
            change: ColumnLayoutConfigWidthChange(columnId: columnId, oldWidth: oldWidth, newWidth: newWidth)
        ))
    }

    let missingIds = Set(widthsByColumnId.keys).subtracting(seenColumnIds).sorted()
    guard missingIds.isEmpty else {
        return .failure("Target columns array is missing active runtime zone ids: \(missingIds.joined(separator: ", "))")
    }

    for replacement in replacements {
        lines[replacement.lineIndex] = replacement.line
    }
    return .success(replacements.map(\.change))
}

private func tomlInlineTableStringValue(for key: String, in line: String) -> String? {
    guard let range = tomlAssignmentValueRange(for: key, in: line) else { return nil }
    return parseTomlStringLiteral(String(line[range]).trimmingCharacters(in: .whitespaces))
}

private func tomlAssignmentKey(in line: String) -> String? {
    let stripped = stripTomlInlineComment(line).trimmingCharacters(in: .whitespacesAndNewlines)
    guard !stripped.isEmpty, !stripped.hasPrefix("#"), let equals = stripped.firstIndex(of: "=") else { return nil }
    return String(stripped[..<equals]).trimmingCharacters(in: .whitespaces)
}

private func tomlAssignmentValueRange(for key: String, in line: String) -> Range<String.Index>? {
    var index = line.startIndex
    var inSingle = false
    var inDouble = false
    var escaped = false
    while index < line.endIndex {
        let char = line[index]
        if escaped {
            escaped = false
            index = line.index(after: index)
            continue
        }
        if inDouble, char == "\\" {
            escaped = true
            index = line.index(after: index)
            continue
        }
        if char == "\"" && !inSingle {
            inDouble.toggle()
        } else if char == "'" && !inDouble {
            inSingle.toggle()
        } else if char == "#", !inSingle, !inDouble {
            return nil
        } else if !inSingle, !inDouble, keyStarts(at: index, key: key, in: line) {
            var cursor = line.index(index, offsetBy: key.count)
            while cursor < line.endIndex, line[cursor].isWhitespace {
                cursor = line.index(after: cursor)
            }
            guard cursor < line.endIndex, line[cursor] == "=" else {
                index = line.index(after: index)
                continue
            }
            cursor = line.index(after: cursor)
            while cursor < line.endIndex, line[cursor].isWhitespace {
                cursor = line.index(after: cursor)
            }
            let valueStart = cursor
            var valueEnd = cursor
            var valueInSingle = false
            var valueInDouble = false
            var valueEscaped = false
            while valueEnd < line.endIndex {
                let valueChar = line[valueEnd]
                if valueEscaped {
                    valueEscaped = false
                    valueEnd = line.index(after: valueEnd)
                    continue
                }
                if valueInDouble, valueChar == "\\" {
                    valueEscaped = true
                    valueEnd = line.index(after: valueEnd)
                    continue
                }
                if valueChar == "\"" && !valueInSingle {
                    valueInDouble.toggle()
                } else if valueChar == "'" && !valueInDouble {
                    valueInSingle.toggle()
                } else if !valueInSingle, !valueInDouble, [",", "}", "#"].contains(valueChar) {
                    break
                }
                valueEnd = line.index(after: valueEnd)
            }
            while valueEnd > valueStart, line[line.index(before: valueEnd)].isWhitespace {
                valueEnd = line.index(before: valueEnd)
            }
            return valueStart..<valueEnd
        }
        index = line.index(after: index)
    }
    return nil
}

private func keyStarts(at index: String.Index, key: String, in line: String) -> Bool {
    guard line[index...].hasPrefix(key) else { return false }
    let keyEnd = line.index(index, offsetBy: key.count)
    if index > line.startIndex {
        let previous = line[line.index(before: index)]
        guard previous.isWhitespace || previous == "{" || previous == "," else { return false }
    }
    guard keyEnd == line.endIndex || line[keyEnd].isWhitespace || line[keyEnd] == "=" else { return false }
    return true
}

private func stripTomlInlineComment(_ raw: String) -> String {
    var result = ""
    var inSingle = false
    var inDouble = false
    var escaped = false
    for char in raw {
        if escaped {
            result.append(char)
            escaped = false
            continue
        }
        if inDouble, char == "\\" {
            result.append(char)
            escaped = true
            continue
        }
        if char == "\"" && !inSingle {
            inDouble.toggle()
        } else if char == "'" && !inDouble {
            inSingle.toggle()
        } else if char == "#", !inSingle, !inDouble {
            break
        }
        result.append(char)
    }
    return result
}

private func parseTomlStringLiteral(_ rawValue: String) -> String? {
    guard rawValue.count >= 2 else { return nil }
    if rawValue.first == "'", rawValue.last == "'" {
        return String(rawValue.dropFirst().dropLast())
    }
    guard rawValue.first == "\"", rawValue.last == "\"" else { return nil }
    let inner = rawValue.dropFirst().dropLast()
    var result = ""
    var escaped = false
    for char in inner {
        if escaped {
            switch char {
                case "\\":
                    result.append("\\")
                case "\"":
                    result.append("\"")
                case "n":
                    result.append("\n")
                case "r":
                    result.append("\r")
                case "t":
                    result.append("\t")
                default:
                    result.append(char)
            }
            escaped = false
            continue
        }
        if char == "\\" {
            escaped = true
        } else {
            result.append(char)
        }
    }
    return escaped ? nil : result
}

private func isTomlTableHeader(_ line: String) -> Bool {
    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
    return (trimmed.hasPrefix("[[") && trimmed.hasSuffix("]]")) ||
        (trimmed.hasPrefix("[") && trimmed.hasSuffix("]"))
}
