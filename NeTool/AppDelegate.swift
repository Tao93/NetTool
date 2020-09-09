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
    let speedMonitor: NetSpeedMonitor
    
    override init() {
        let statusItem = NSStatusBar.system.statusItem(withLength: 72)
        let menu = NSMenu()
        
        menu.addItem(withTitle: "Quit NeTool", action: #selector(menuItemQuitClick), keyEquivalent: "q")
        
        view = StatusBarView(statusItem: statusItem, menu: menu)
        statusItem.view = view
        
        speedMonitor = NetSpeedMonitor(statusBarView: view)
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        speedMonitor.start()
        
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(onWake(notification:)),
            name: NSWorkspace.didWakeNotification, object: nil)

        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(onSleep(notification:)),
            name: NSWorkspace.willSleepNotification, object: nil)
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    @objc func onSleep(notification: NSNotification) {
        print("sleep")
        speedMonitor.stop()
    }
    
    @objc func onWake(notification: NSNotification) {
        print("wake")
        speedMonitor.start()
    }
}

extension AppDelegate {
    @objc func menuItemQuitClick() {
        NSApp.terminate(nil)
    }
}
