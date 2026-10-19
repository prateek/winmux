import AppKit
let windows=CGWindowListCopyWindowInfo(.optionAll,kCGNullWindowID) as? [[String:Any]] ?? []
let rows=windows.filter { ($0[kCGWindowOwnerName as String] as? String)=="WinMuxApp" }.map { row in
    ["owner": "WinMuxApp", "name": row[kCGWindowName as String] ?? "", "bounds":row[kCGWindowBounds as String] ?? [:],"layer":row[kCGWindowLayer as String] ?? 0] as [String:Any]
}
let result:[String:Any] = ["screens":NSScreen.screens.map{["width":$0.frame.width,"height":$0.frame.height,"scale":$0.backingScaleFactor]},"windows":rows]
print(String(data:try JSONSerialization.data(withJSONObject:result,options:[.prettyPrinted,.sortedKeys]),encoding:.utf8)!)
