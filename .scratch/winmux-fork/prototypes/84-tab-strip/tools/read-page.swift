import AppKit
import ApplicationServices
guard let app=NSRunningApplication.runningApplications(withBundleIdentifier:"com.apple.Safari").first else {exit(1)}
func get(_ e:AXUIElement,_ key:String)->CFTypeRef?{var v:CFTypeRef?;AXUIElementCopyAttributeValue(e,key as CFString,&v);return v}
func visit(_ e:AXUIElement,_ depth:Int=0,_ inPage:Bool=false){
 guard depth<45 else{return}
 let role=get(e,kAXRoleAttribute) as? String ?? ""
 let page=inPage || role=="AXWebArea"
 if page && ["AXStaticText","AXButton","AXHeading","AXCheckBox"].contains(role){
  let value=[kAXValueAttribute,kAXTitleAttribute,kAXDescriptionAttribute].compactMap{get(e,$0) as? String}.first{!$0.isEmpty} ?? ""
  if !value.isEmpty{print(role+" | "+value+(role=="AXCheckBox" ? " | \((get(e,kAXValueAttribute) as? NSNumber)?.intValue ?? -1)" : ""))}
 }
 for child in get(e,kAXChildrenAttribute) as? [AXUIElement] ?? []{visit(child,depth+1,page)}
}
visit(AXUIElementCreateApplication(app.processIdentifier))
