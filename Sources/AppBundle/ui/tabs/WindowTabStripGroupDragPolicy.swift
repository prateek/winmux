@MainActor
func shouldPromoteTabStripDragToGroup(windowId: UInt32, containerIdentity: UInt64) -> Bool {
    if shouldContinueCurrentGroupDrag(windowId: windowId, subject: .group(containerIdentity)) {
        return true
    }
    guard let window = Window.get(byId: windowId) else { return false }
    let isOptionPressed = currentSessionModifierFlags().contains(.maskAlternate)
    return shouldPromoteWindowDragToTabGroupDrag(
        isOptionPressed: isOptionPressed,
        isTabbedWindow: isWindowInDraggableTabGroup(window),
    )
}

@MainActor
func shouldAllowTabStripChromeGroupDrag(windowId: UInt32, containerIdentity: UInt64) -> Bool {
    if shouldContinueCurrentGroupDrag(windowId: windowId, subject: .group(containerIdentity)) {
        return true
    }
    guard Window.get(byId: windowId) != nil,
          let container = workspaceSidebarLiveContainer(containerIdentity) else { return false }
    return container.usesWindowTabBehavior && container.children.count > 1
}
