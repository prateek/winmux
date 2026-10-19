import Common

@MainActor
func windowDragSourcePreviewItem(window: Window, subject: WindowDragSubject, frame: Rect) -> WindowResizePreviewItem? {
    guard frame.width > 0, frame.height > 0 else { return nil }
    guard let source = dragSubjectNode(for: window, subject: subject) else { return nil }
    if subject.isGroup,
       let tabGroup = source as? TilingContainer,
       tabGroup.usesWindowTabBehavior
    {
        return WindowResizePreviewItem(tabGroup: tabGroup, rect: frame, drawsFrameOnly: true)
    }
    return WindowResizePreviewItem(window: window, rect: frame)
}

@MainActor
func windowResizeUsesActiveTabGroupChrome(window: Window) -> Bool {
    guard let tabGroup = window.nearestWindowTabGroup,
          tabGroup.usesWindowTabBehavior,
          tabGroup.tabActiveWindow == window
    else { return false }
    return true
}
