import AppKit
final class Delegate: NSObject, NSApplicationDelegate {
 var windows:[NSWindow]=[]; var labels:[NSTextField]=[]; var last=""; let root="/tmp/winmux9-demo"
 func applicationDidFinishLaunching(_ n:Notification) {
  for i in 1...50 {
   let w=NSWindow(contentRect:NSRect(x:100+(i%8)*30,y:150+(i%5)*30,width:600,height:360),styleMask:[.titled,.closable,.resizable,.miniaturizable],backing:.buffered,defer:false)
   w.isReleasedWhenClosed=false;w.title=String(format:"Demo %02d",i);w.collectionBehavior=[.fullScreenPrimary]
   let v=NSView(frame:w.contentView!.bounds);v.wantsLayer=true;v.layer?.backgroundColor=NSColor(calibratedHue:CGFloat(i%10)/10,saturation:0.65,brightness:0.65,alpha:1).cgColor
   let label=NSTextField(labelWithString:w.title+"\nOwned neutral window");label.font = .monospacedSystemFont(ofSize:32,weight:.medium);label.textColor = .white;label.frame=NSRect(x:24,y:60,width:550,height:230);label.autoresizingMask=[.width,.height];v.addSubview(label);w.contentView=v;windows.append(w);labels.append(label);w.orderFront(nil)
  }
  NSApp.activate(ignoringOtherApps:true)
  Timer.scheduledTimer(withTimeInterval:0.5,repeats:true) { [self] _ in
   for (i,label) in labels.enumerated() {label.stringValue=String(format:"Demo %02d",i+1)+"\nOwned neutral window\n"+Date().formatted(date:.omitted,time:.standard)}
   if let c=try? String(contentsOfFile:root+"/command",encoding:.utf8),c != last {last=c;let p=c.trimmingCharacters(in:.whitespacesAndNewlines).split(separator:" ").map(String.init);guard let command=p.first else{return};if command=="quit"{NSApp.terminate(nil)};if command=="keep",let count=Int(p.last!){for w in windows.dropFirst(count){w.close()}};if command=="fullscreen",let i=Int(p.last!){windows[i-1].toggleFullScreen(nil)};if command=="minimize",let i=Int(p.last!){windows[i-1].miniaturize(nil)};if command=="raise",let i=Int(p.last!){windows[i-1].makeKeyAndOrderFront(nil);NSApp.activate(ignoringOtherApps:true)};if command=="hide"{NSApp.hide(nil)} }
  }
 }
}
let app=NSApplication.shared;app.setActivationPolicy(.regular);let delegate=Delegate();app.delegate=delegate;app.run()
