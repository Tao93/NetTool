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
    
    var statusItem: NSStatusItem
    var clicked: Bool = false
    var darkMenuBar: Bool = false
    var upRate: String = "- - B/S"
    var downRate: String = "- - B/S"
    
    init(statusItem: NSStatusItem, menu: NSMenu?) {
        self.statusItem = statusItem
        super.init(frame: NSMakeRect(0, 0, statusItem.length, 30))
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
}

//action
extension StatusBarView: NSMenuDelegate{
    open override func mouseDown(with theEvent: NSEvent) {
        statusItem.popUpMenu(menu!)
    }
    
    public func menuWillOpen(_ menu: NSMenu) {
        setNeedsDisplay()
    }
    
    public func menuDidClose(_ menu: NSMenu) {
        setNeedsDisplay()
    }
}

