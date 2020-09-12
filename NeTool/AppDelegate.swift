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
    
    let speedMonitor: NetSpeedMonitor
    
    override init() {
        let statusItem = NSStatusBar.system.statusItem(withLength: 72)
        let menu = NSMenu()
        
        // the menu item to show apps with top net speed (sum of upload and download)
        let menuItem = NSMenuItem()
        menuItem.view = SpeedInfoView()
        menu.addItem(menuItem)
        
        // the menu item to quit app.
        menu.addItem(withTitle: "Quit NeTool", action: #selector(menuItemQuitClick), keyEquivalent: "q")
        
        // the view for menuBar icon
        let menuBarIconView = StatusBarView(statusItem: statusItem, menu: menu)
        statusItem.view = menuBarIconView
        
        // logic class to monitor net speed.
        speedMonitor = NetSpeedMonitor(statusBarView: menuBarIconView, speedInfoView: menuItem.view as! SpeedInfoView)
        menuBarIconView.speedMonitor = speedMonitor
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        //
        speedMonitor.start()
        
        // observer event of system sleep and wake.
        // we would pause monitoring on sleep, and resume monitoring on wake.
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(onWake(notification:)),
            name: NSWorkspace.didWakeNotification, object: nil)

        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(onSleep(notification:)),
            name: NSWorkspace.willSleepNotification, object: nil)
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        
    }
    
    @objc func onSleep(notification: NSNotification) {
        speedMonitor.stop()
    }
    
    @objc func onWake(notification: NSNotification) {
        speedMonitor.start()
    }
}

extension AppDelegate {
    @objc func menuItemQuitClick() {
        NSApp.terminate(nil)
    }
}
