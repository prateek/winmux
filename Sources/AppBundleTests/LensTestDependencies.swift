@testable import AppBundle
import AppKit
import Common

@MainActor
func testLensLifecycle(emit: @escaping (ServerEvent) -> Void = { _ in }, show: @escaping (LensSession) -> Void = { _ in }, hide: @escaping () -> Void = {}) -> LensLifecycle {
    LensLifecycle(dependencies: .init(evaluate: { _, _, _ in .success([]) }, requestThumbnail: { _, _ in }, closeThumbnails: { _ in }, flags: { .command }), emit: emit, show: show, hide: hide)
}

@MainActor
func ownLens(_ model: LensSession) -> LensLifecycle {
    let owner = testLensLifecycle()
    let ticket = owner.begin(model.name, toggle: false)!
    owner.complete(model, ticket: ticket)
    return owner
}
