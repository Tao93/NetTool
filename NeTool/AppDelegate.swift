//
//  AppDelegate.swift
//  NeTool
//
//  Created by Liu, Tao (Toni) on 9/15/18.
//  Copyright © 2018 Liu, Tao (Toni). All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    let view: StatusBarView
    
    override init() {
        let statusItem = NSStatusBar.system.statusItem(withLength: 72)
        let menu = NSMenu()
        
        menu.addItem(withTitle: "Quit NeTool", action: #selector(menuItemQuitClick), keyEquivalent: "q")
        
        view = StatusBarView(statusItem: statusItem, menu: menu)
        statusItem.view = view
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        NetSpeedMonitor(statusBarView: view).startMonitor()
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
}

extension AppDelegate {
    @objc func menuItemQuitClick() {
        NSApp.terminate(nil)
    }
}
