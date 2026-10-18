import AppKit
import Common

func windowTabBindingTarget(_ binding: HotkeyBinding) -> FocusCmdArgs.TabIndex? {
    guard binding.commands.count == 1,
          let focus = binding.commands.first as? FocusCommand,
          case .tabIndex(let target) = focus.args.target
    else { return nil }
    return target
}

func windowTabHintLabels(bindings: [HotkeyBinding], modifiers: NSEvent.ModifierFlags, childCount: Int, isTabGroup: Bool) -> [Int: String] {
    let candidates = bindings.filter { $0.modifiers == modifiers && windowTabBindingTarget($0) != nil }.sorted {
        let leftIsLast = windowTabBindingTarget($0) == .last
        let rightIsLast = windowTabBindingTarget($1) == .last
        if leftIsLast != rightIsLast { return !leftIsLast }
        return windowTabHintKey($0) < windowTabHintKey($1)
    }
    var labels: [Int: String] = [:]
    for binding in candidates {
        guard let target = windowTabBindingTarget(binding),
              isTabGroup || target == .last,
              let index = resolveTabFocusIndex(target, childCount: childCount),
              labels[index] == nil
        else { continue }
        labels[index] = displayBindingNotation(windowTabHintKey(binding))
    }
    return labels
}

private func windowTabHintKey(_ binding: HotkeyBinding) -> String {
    binding.descriptionWithKeyNotation.split(separator: "-").last.map(String.init) ?? binding.keyCode.description
}
