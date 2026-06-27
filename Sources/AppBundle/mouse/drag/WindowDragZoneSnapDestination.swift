import AppKit

enum ZoneSnapDestinationResolution {
    case allowDefaultDestinations
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
) -> ZoneSnapDestinationResolution {
    let snapConfig = effectiveZoneSnapConfig(for: targetMonitor)
    guard detachOrigin == .window,
          snapConfig.gesture == .drag,
          snapConfig.target == .zone,
          let zoneId = targetMonitor.zoneId
    else {
        return .allowDefaultDestinations
    }

    guard shouldActivateZoneSnap(snapConfig, modifierFlags: modifierFlags) else {
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
        ),
    ))
}

func shouldActivateZoneSnap(_ config: ZoneSnapConfig, modifierFlags: CGEventFlags) -> Bool {
    switch config.policy {
        case .freeform:
            return false
        case .snapToZone:
            return true
        case .snapOnModifier, .floatUnlessSnap:
            return zoneSnapModifierIsPressed(config.modifier, in: modifierFlags)
    }
}

func zoneSnapModifierIsPressed(_ modifier: NSEvent.ModifierFlags, in eventFlags: CGEventFlags) -> Bool {
    guard !modifier.isEmpty else { return false }
    if modifier.contains(.option), !eventFlags.contains(.maskAlternate) { return false }
    if modifier.contains(.control), !eventFlags.contains(.maskControl) { return false }
    if modifier.contains(.command), !eventFlags.contains(.maskCommand) { return false }
    if modifier.contains(.shift), !eventFlags.contains(.maskShift) { return false }
    return true
}
