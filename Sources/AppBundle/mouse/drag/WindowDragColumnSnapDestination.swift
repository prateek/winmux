import AppKit

enum ColumnSnapDestinationResolution {
    case allowDefaultDestinations
    case allowWindowDestinationsOnly
    case suppressDefaultDestinations
    case use(WindowDragIntentDestination)
}

@MainActor
func columnSnapDestinationResolution(
    sourceWindow _: Window,
    targetMonitor: Monitor,
    targetWorkspace: Workspace,
    sourceWorkspace: Workspace?,
    mouseLocation _: CGPoint,
    subject: WindowDragSubject,
    detachOrigin: TabDetachOrigin,
    modifierFlags: CGEventFlags,
    pressedMouseButtons: Int = 0,
) -> ColumnSnapDestinationResolution {
    let inputState = ColumnSnapInputState(
        modifierFlags: modifierFlags,
        pressedMouseButtons: pressedMouseButtons,
    )
    let snapConfig = effectiveColumnSnapConfig(for: targetMonitor)
    guard detachOrigin == .window,
          let columnId = targetMonitor.columnId
    else {
        return .allowDefaultDestinations
    }

    switch snapConfig.target {
        case .column:
            guard shouldActivateColumnSnap(snapConfig, inputState: inputState) else {
                return .suppressDefaultDestinations
            }
            guard targetWorkspace != sourceWorkspace else {
                return .suppressDefaultDestinations
            }

            let previewRect = targetMonitor.visibleRectPaddedByOuterGaps
            let columnName = targetMonitor.columnName ?? columnId
            return .use(WindowDragIntentDestination(
                kind: .moveToZone(columnId: columnId, workspaceName: targetWorkspace.name),
                previewRect: previewRect,
                interactionRect: previewRect,
                title: "Snap to \(columnName)",
                subtitle: "Drop to move this item to the \(columnName) column",
                previewStyle: .workspaceMove,
                previewGeometry: .rounded,
                isGroup: subject == .group,
                dropIntentOverlay: WindowDropIntentOverlayModel(
                    targetFrame: previewRect,
                    activeZone: nil,
                    cornerRadius: nil,
                    label: "Whole column: \(columnName)",
                    detail: "Drop to move to \(columnName)",
                ),
            ))
        case .window:
            guard shouldActivateColumnSnap(snapConfig, inputState: inputState) else {
                return .suppressDefaultDestinations
            }
            return .allowWindowDestinationsOnly
    }
}

func shouldActivateColumnSnap(_ config: ColumnSnapConfig, inputState: ColumnSnapInputState) -> Bool {
    switch config.policy {
        case .freeform:
            return false
        case .snapToColumn:
            return true
        case .snapOnModifier:
            return columnSnapModifierIsPressed(config.modifier, in: inputState.modifierFlags)
        case .floatUnlessSnap:
            return columnSnapActivationInputIsPressed(config, inputState: inputState)
    }
}

func shouldActivateColumnSnap(_ config: ColumnSnapConfig, modifierFlags: CGEventFlags) -> Bool {
    shouldActivateColumnSnap(
        config,
        inputState: ColumnSnapInputState(modifierFlags: modifierFlags, pressedMouseButtons: 0),
    )
}

func columnSnapModifierIsPressed(_ modifier: NSEvent.ModifierFlags, in eventFlags: CGEventFlags) -> Bool {
    guard !modifier.isEmpty else { return false }
    if modifier.contains(.option), !eventFlags.contains(.maskAlternate) { return false }
    if modifier.contains(.control), !eventFlags.contains(.maskControl) { return false }
    if modifier.contains(.command), !eventFlags.contains(.maskCommand) { return false }
    if modifier.contains(.shift), !eventFlags.contains(.maskShift) { return false }
    return true
}
