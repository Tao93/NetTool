//
//  StatusBarView.swift
//  NeTool
//
//  Created by Liu, Tao (Toni) on 9/15/18.
//  Copyright © 2018 Liu, Tao (Toni). All rights reserved.
//

import AppKit
import Foundation

open class StatusBarView: NSControl {
    public static let INITIAL_RATE_TEXT = "- - B/S"
    
    var statusItem: NSStatusItem
    // true if users clicked menubar icon, and dropdown menu is shown.
    var clicked: Bool = false
    // dark menu bar & dock style of OS before Mojave.
    var darkMenuBar: Bool = false
    var upRate: String = INITIAL_RATE_TEXT
    var downRate: String = INITIAL_RATE_TEXT
    
    public var speedMonitor: NetSpeedMonitor?
    
    init(statusItem: NSStatusItem, menu: NSMenu?) {
        self.statusItem = statusItem
        super.init(frame: NSMakeRect(0, 0, statusItem.length, NSStatusItem.squareLength))
        self.menu = menu
        
        menu?.delegate = self
        
        darkMenuBar = isDarkMode()
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(change), name:NSNotification.Name(rawValue: "AppleInterfaceThemeChangedNotification"), object: nil)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    open override func draw(_ dirtyRect: NSRect) {
        // draw the background
        statusItem.drawStatusBarBackground(in: dirtyRect, withHighlight: clicked)
        
        // draw up speed string and down speed string.
        
        let textColor = (clicked || darkMenuBar) ? NSColor.white : NSColor.black
        let textAttr = [NSAttributedString.Key.font: NSFont.systemFont(ofSize: 9), NSAttributedString.Key.foregroundColor: textColor]
        
        let upRateStr = NSAttributedString(string: upRate + " ▲", attributes: textAttr)
        let upRateRect = upRateStr.boundingRect(with: NSSize(width: 100, height: 100), options: .usesLineFragmentOrigin)
        upRateStr.draw(at: NSMakePoint(bounds.width - upRateRect.width - 5, 10))
        
        let downRateStr = NSAttributedString(string: downRate+" ▼", attributes: textAttr)
        let downRateRect = downRateStr.boundingRect(with: NSSize(width: 100, height: 100), options: .usesLineFragmentOrigin)
        downRateStr.draw(at: NSMakePoint(bounds.width - downRateRect.width - 5, 0))
    }
    
    
    @objc func change() {
        darkMenuBar = isDarkMode()
        setNeedsDisplay()
    }
    
    func isDarkMode() -> Bool {
        let dict = UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain)
        if let style:AnyObject = dict!["AppleInterfaceStyle"] as AnyObject? {
            if (style as! String).caseInsensitiveCompare("dark") == ComparisonResult.orderedSame {
                return true
            }
        }
        return false
    }
    
    func updateData(up: String, down: String) {
        upRate = up
        downRate = down
        
        // run in the main thread
        DispatchQueue.main.async(execute: {
            self.setNeedsDisplay()
        })
    }
    
    func isMenuShown() -> Bool {
        return self.clicked
    }
}

//action
extension StatusBarView: NSMenuDelegate{
    open override func mouseDown(with theEvent: NSEvent) {
        
        statusItem.popUpMenu(menu!)
    }
    
    public func menuWillOpen(_ menu: NSMenu) {
        setNeedsDisplay()
        self.clicked = true
        
        // fetch the top speed info of the last sample, hence users
        // can see the results once menu is shown, rather than waiting for results of next sapmple.
        DispatchQueue.global().async {
            self.speedMonitor?.updateTopSpeedItems()
        }
    }
    
    public func menuDidClose(_ menu: NSMenu) {
        setNeedsDisplay()
        self.clicked = false
    }
}

