//
//  SpeedInfoView.swift
//  NeTool
//
//  Created by Liu, Tao (Toni) on 9/9/20.
//  Copyright © 2020 Liu, Tao (Toni). All rights reserved.
//

import AppKit

class SpeedInfoView: NSControl {

    var hintLabel: NSTextField!
    
    var pathLabel0: NSTextField!
    var pathLabel1: NSTextField!
    var pathLabel2: NSTextField!
    var pathLabel3: NSTextField!
    
    var speedLabel0: NSTextField!
    var speedLabel1: NSTextField!
    var speedLabel2: NSTextField!
    var speedLabel3: NSTextField!
    
    var pathLabelArr: [NSTextField] = []
    var speedLabelArr: [NSTextField] = []
    var pathArr: [String] = []  // full executable paths for clipboard copy
    
    init() {
        super.init(frame: NSMakeRect(0, 0, 300, 148))
        buildUI()
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func buildUI() {
        // --- Hint label at top ---
        hintLabel = NSTextField(frame: NSMakeRect(18, 130, 200, 16))
        hintLabel.isEditable = false
        hintLabel.isBordered = false
        hintLabel.drawsBackground = false
        hintLabel.font = NSFont.messageFont(ofSize: 11)
        hintLabel.textColor = NSColor.secondaryLabelColor
        hintLabel.stringValue = "Click to copy full path"
        addSubview(hintLabel)
        
        // --- Path labels (left side) ---
        let pathYs: [CGFloat] = [101, 72, 44, 15]
        let pathLabels: [NSTextField] = pathYs.map { y in
            let label = NSTextField(frame: NSMakeRect(18, y, 207, 16))
            label.isEditable = false
            label.isBordered = false
            label.drawsBackground = false
            label.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
            label.textColor = NSColor.labelColor
            label.lineBreakMode = .byTruncatingMiddle
            label.stringValue = "- - -"
            addSubview(label)
            return label
        }
        pathLabel0 = pathLabels[0]
        pathLabel1 = pathLabels[1]
        pathLabel2 = pathLabels[2]
        pathLabel3 = pathLabels[3]
        pathLabelArr = [pathLabel0, pathLabel1, pathLabel2, pathLabel3]
        
        // --- Speed labels (right side, two-line) ---
        let speedYs: [CGFloat] = [98, 69, 41, 12]
        let speedLabels: [NSTextField] = speedYs.map { y in
            let label = NSTextField(frame: NSMakeRect(230, y, 60, 22))
            label.isEditable = false
            label.isBordered = false
            label.drawsBackground = true
            label.backgroundColor = NSColor.unemphasizedSelectedTextBackgroundColor
            label.font = NSFont.labelFont(ofSize: 9)
            label.textColor = NSColor.labelColor
            label.alignment = .right
            label.maximumNumberOfLines = 2
            label.lineBreakMode = .byCharWrapping
            label.stringValue = "- - B/S ▲\n- - B/S ▼"
            addSubview(label)
            return label
        }
        speedLabel0 = speedLabels[0]
        speedLabel1 = speedLabels[1]
        speedLabel2 = speedLabels[2]
        speedLabel3 = speedLabels[3]
        speedLabelArr = [speedLabel0, speedLabel1, speedLabel2, speedLabel3]
    }
    
    open override func draw(_ dirtyRect: NSRect) {
        // draw two divider lines.
        NSColor.gray.set()
        let figure = NSBezierPath()
        figure.lineWidth = 1
        figure.move(to: NSMakePoint(18, 6))
        figure.line(to: NSMakePoint(290, 6))
        figure.stroke()
        
        figure.move(to: NSMakePoint(18, 126))
        figure.line(to: NSMakePoint(290, 126))
        figure.stroke()
    }
    
    override func mouseDown(with event: NSEvent) {
        
        // event.locationInWindow is relative to window, convert that to be relative this view.
        let clickLocation = convert(event.locationInWindow, from: nil)
        
        for (i, label) in pathLabelArr.enumerated() {
            if (label.frame.contains(clickLocation)) {
                // copy full executable path to clipboard
                if i < pathArr.count, !pathArr[i].isEmpty {
                    copyToClipBoard(textToCopy: pathArr[i])
                } else {
                    copyToClipBoard(textToCopy: label.stringValue)
                }
            }
        }
    }
    
    func updateTopSpeedItems(infoArr: Array<SpeedInfo>?) {
        DispatchQueue.main.async {
            if (infoArr != nil) {
                let count = min(infoArr!.count, self.pathLabelArr.count)
                self.pathArr.removeAll()
                for i in 0...(count - 1) {
                    self.pathLabelArr[i].stringValue = infoArr![i].name
                    self.speedLabelArr[i].stringValue = infoArr![i].upSpeed + " ▲\n" + infoArr![i].downSpeed + " ▼"
                    self.pathArr.append(infoArr![i].path)
                }
            }
        }
    }
    
    private func copyToClipBoard(textToCopy: String) {
        let pasteBoard = NSPasteboard.general
        pasteBoard.clearContents()
        pasteBoard.setString(textToCopy, forType: .string)
        
        setHintText(new: "Path copied", duration: 2, recoverTo: "Click to copy full path")
    }
    
    // new: new hint text to show
    // duration: time seconds the new hint would last.
    // recoverTo: hint text to shown after duration.
    private func setHintText(new: String, duration: Int, recoverTo: String) {
        hintLabel.stringValue = new

        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .seconds(duration), execute: {
            self.hintLabel.stringValue = recoverTo
        })
    }
}

