@testable import AppBundle
import Common
import XCTest

final class DebugWindowsCmdArgsTest: XCTestCase {
    func testFilterContextIsOffUnlessAskedFor() {
        let plain = parseCmdArgs(["debug-windows", "--window-id", "7"].slice).cmdOrNil as? DebugWindowsCmdArgs
        let withContext = parseCmdArgs(["debug-windows", "--window-id", "7", "--filter-context"].slice).cmdOrNil as? DebugWindowsCmdArgs

        assertEquals(plain?.windowId, 7)
        assertEquals(plain?.filterContext, false)
        assertEquals(withContext?.filterContext, true)
    }
}
