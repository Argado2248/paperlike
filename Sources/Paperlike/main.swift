import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// Menu bar only. Info.plist also sets LSUIElement for the bundled build;
// this covers `swift run` where there is no bundle.
app.setActivationPolicy(.accessory)
app.run()
