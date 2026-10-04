import AppKit
import Common
import Foundation

struct BalanceSizesCommand: Command {
    let args: BalanceSizesCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = true

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        guard let target = args.resolveTargetOrReportError(env, io) else { return false }
        let workspace = target.workspace
        if let columns = workspace.columns {
            if columns.slotCount > columns.count {
                let extra = 1.0 / CGFloat(columns.slotCount)
                columns.widths = columns.declaredWidths.map { $0 * (1 - extra) } + [extra]
            } else {
                columns.widths = columns.declaredWidths
            }
            for child in workspace.rootTilingContainer.children {
                if let container = child as? TilingContainer { balance(container) }
            }
            workspace.enforceColumnInvariant()
        } else {
            balance(workspace.rootTilingContainer)
        }
        return true
    }
}

@MainActor
private func balance(_ parent: TilingContainer) {
    for child in parent.children {
        switch parent.layout {
            case .tiles: child.setWeight(parent.orientation, 1)
            case .tabGroup: break // Do nothing
        }
        if let child = child as? TilingContainer {
            balance(child)
        }
    }
}
