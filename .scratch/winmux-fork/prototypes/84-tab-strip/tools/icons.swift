import AppKit
let apps = ["chrome":"/Applications/Google Chrome.app", "code":"/Applications/Visual Studio Code.app", "ghostty":"/Applications/Ghostty.app"]
for (name,path) in apps {
    let icon = NSWorkspace.shared.icon(forFile:path)
    icon.size=NSSize(width:32,height:32)
    let rep=NSBitmapImageRep(data:icon.tiffRepresentation!)!
    try rep.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:NSHomeDirectory()+"/takes/tab-strip/icon-"+name+".png"))
}
