import Cocoa

let app = NSApplication.shared

// LSUIElement: hide from dock, no main window — menu bar icon only
app.setActivationPolicy(.accessory)

// Minimal main menu — just the app name menu with Quit, nothing else
let mainMenu = NSMenu()
let appMenu = NSMenu()
let appName = ProcessInfo.processInfo.processName
appMenu.addItem(withTitle: "Quit \(appName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
let appMenuItem = NSMenuItem()
appMenuItem.submenu = appMenu
mainMenu.addItem(appMenuItem)
app.mainMenu = mainMenu

// Set delegate and run
let delegate = AppDelegate()
app.delegate = delegate

app.run()
