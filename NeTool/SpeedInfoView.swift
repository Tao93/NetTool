//
//  SpeedInfoView.swift
//  NeTool
//
//  Created by Liu, Tao (Toni) on 9/9/20.
//  Copyright © 2020 Liu, Tao (Toni). All rights reserved.
//

import AppKit

class SpeedInfoView: NSControl {

    @IBOutlet weak var hintHabel: NSTextField!
    
    @IBOutlet weak var pathLabel0: NSTextField!
    @IBOutlet weak var pathLabel1: NSTextField!
    @IBOutlet weak var pathLabel2: NSTextField!
    @IBOutlet weak var pathLabel3: NSTextField!
    
    @IBOutlet weak var speedLabel0: NSTextField!
    @IBOutlet weak var speedLabel1: NSTextField!
    @IBOutlet weak var speedLabel2: NSTextField!
    @IBOutlet weak var speedLabel3: NSTextField!
    
    var pathLabelArr: Array<NSTextField> = []
    var speedLabelArr: Array<NSTextField> = []
    
    init() {
        
        super.init(frame: NSMakeRect(0, 0, 300, 148))
        
        // load from xib file.
        let newNib = NSNib(nibNamed: "SpeedInfoView", bundle: Bundle(for: type(of: self)))
        newNib!.instantiate(withOwner: self, topLevelObjects: nil)
        
        pathLabelArr = [pathLabel0, pathLabel1, pathLabel2, pathLabel3]
        speedLabelArr = [speedLabel0, speedLabel1, speedLabel2, speedLabel3]
        
        addSubview(hintHabel)
        hintHabel.stringValue = "Click to copy path"
        for label in pathLabelArr {
            addSubview(label)
            label.stringValue = "- - -"
        }
        for label in speedLabelArr {
            addSubview(label)
            label.stringValue = "- - B/S ▲\n- - B/S ▼"
        }
        
        setNeedsDisplay()
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
        
        for label in pathLabelArr {
            if (label.frame.contains(clickLocation)) {
                // copy path to clipborad, then users could use it.
                copyToClipBoard(textToCopy: label.stringValue)
            }
        }
    }
    
    func updateTopSpeedItems(infoArr: Array<SpeedInfo>?) {
        DispatchQueue.main.async {
            if (infoArr != nil) {
                let count = min(infoArr!.count, self.pathLabelArr.count)
                for i in 0...(count - 1) {
                    self.pathLabelArr[i].stringValue = infoArr![i].path
                    self.speedLabelArr[i].stringValue = infoArr![i].upSpeed + " ▲\n" + infoArr![i].downSpeed + " ▼"
                    //self.speedLabelArr[i].stringValue = "440.0 K/S" + " ▲\n" + "1000.8 M/S" + " ▼"
                }
            }
        }
    }
    
    private func copyToClipBoard(textToCopy: String) {
        let pasteBoard = NSPasteboard.general
        pasteBoard.clearContents()
        pasteBoard.setString(textToCopy, forType: .string)
        
        setHintText(new: "Path copied", duration: 2, recoverTo: "Click to copy path")
    }
    
    // new: new hint text to show
    // duration: time seconds the new hint would last.
    // recoverTo: hint text to shown after duration.
    private func setHintText(new: String, duration: Int, recoverTo: String) {
        hintHabel.stringValue = new

        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .seconds(duration), execute: {
            self.hintHabel.stringValue = recoverTo
        })
    }
}

