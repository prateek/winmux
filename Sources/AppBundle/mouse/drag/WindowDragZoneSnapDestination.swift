import AppKit

enum ZoneSnapDestinationResolution {
    case allowDefaultDestinations
    case allowWindowDestinationsOnly
    case suppressDefaultDestinations
    case use(WindowDragIntentDestination)
}

@MainActor
func zoneSnapDestinationResolution(
    sourceWindow _: Window,
    targetMonitor: Monitor,
    targetWorkspace: Workspace,
    sourceWorkspace: Workspace?,
    mouseLocation _: CGPoint,
    subject: WindowDragSubject,
    detachOrigin: TabDetachOrigin,
    modifierFlags: CGEventFlags,
    pressedMouseButtons: Int = 0,
) -> ZoneSnapDestinationResolution {
    let inputState = ZoneSnapInputState(
        modifierFlags: modifierFlags,
        pressedMouseButtons: pressedMouseButtons,
    )
    let snapConfig = effectiveZoneSnapConfig(for: targetMonitor)
    guard detachOrigin == .window,
          let zoneId = targetMonitor.zoneId
    else {
        return .allowDefaultDestinations
    }

    switch snapConfig.target {
        case .zone:
            guard shouldActivateZoneSnap(snapConfig, inputState: inputState) else {
                return .suppressDefaultDestinations
            }
            guard targetWorkspace != sourceWorkspace else {
                return .suppressDefaultDestinations
            }

            let previewRect = targetMonitor.visibleRectPaddedByOuterGaps
            let zoneName = targetMonitor.zoneName ?? zoneId
            return .use(WindowDragIntentDestination(
                kind: .moveToZone(zoneId: zoneId, workspaceName: targetWorkspace.name),
                previewRect: previewRect,
                interactionRect: previewRect,
                title: "Snap to \(zoneName)",
                subtitle: "Drop to move this item to the \(zoneName) zone",
                previewStyle: .workspaceMove,
                previewGeometry: .rounded,
                isGroup: subject == .group,
                dropIntentOverlay: WindowDropIntentOverlayModel(
                    targetFrame: previewRect,
                    activeZone: nil,
                    cornerRadius: nil,
                    label: "Whole zone: \(zoneName)",
                    detail: "Drop to move to \(zoneName)",
                ),
            ))
        case .window:
            guard shouldActivateZoneSnap(snapConfig, inputState: inputState) else {
                return .suppressDefaultDestinations
            }
            return .allowWindowDestinationsOnly
    }
}

func shouldActivateZoneSnap(_ config: ZoneSnapConfig, inputState: ZoneSnapInputState) -> Bool {
    switch config.policy {
        case .freeform:
            return false
        case .snapToZone:
            return true
        case .snapOnModifier:
            return zoneSnapModifierIsPressed(config.modifier, in: inputState.modifierFlags)
        case .floatUnlessSnap:
            return zoneSnapActivationInputIsPressed(config, inputState: inputState)
    }
}

func shouldActivateZoneSnap(_ config: ZoneSnapConfig, modifierFlags: CGEventFlags) -> Bool {
    shouldActivateZoneSnap(
        config,
        inputState: ZoneSnapInputState(modifierFlags: modifierFlags, pressedMouseButtons: 0),
    )
}

func zoneSnapModifierIsPressed(_ modifier: NSEvent.ModifierFlags, in eventFlags: CGEventFlags) -> Bool {
    guard !modifier.isEmpty else { return false }
    if modifier.contains(.option), !eventFlags.contains(.maskAlternate) { return false }
    if modifier.contains(.control), !eventFlags.contains(.maskControl) { return false }
    if modifier.contains(.command), !eventFlags.contains(.maskCommand) { return false }
    if modifier.contains(.shift), !eventFlags.contains(.maskShift) { return false }
    return true
}
