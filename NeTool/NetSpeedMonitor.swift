//
//  NetSpeedUtils.swift
//  NeTool
//
//  Created by Liu, Tao (Toni) on 9/15/18.
//  Copyright © 2018 Liu, Tao (Toni). All rights reserved.
//

import Foundation

open class NetSpeedMonitor {
    static let interval: Double = 1.6
    static let KB: Double = 1024
    static let MB: Double = KB * 1024
    static let GB: Double = MB * 1024
    static let TB: Double = GB * 1024
    
    var preBytesIn: Double = -1
    var preBytesOut: Double = -1
    
    var lastIn = 0
    var lastOut = 0
    var curIn = 0
    var curOut = 0
    
    let statusBarView: StatusBarView
    
    init(statusBarView: StatusBarView) {
        self.statusBarView = statusBarView
    }
    
    func startMonitor() {
        Thread(target: self, selector: #selector(startTimer), object: nil).start()
    }
    
    @objc func startTimer() {
        Timer.scheduledTimer(timeInterval: NetSpeedMonitor.interval, target: self, selector: #selector(sampleBytes), userInfo: nil, repeats: true)
        RunLoop.current.run()
    }
    
    @objc func sampleBytes() {
        // Create a Task instance
        let task = Process()
        
        // Set the task parameters
        task.launchPath = "/usr/bin/nettop"
        task.arguments = ["-x", "-t", "wifi", "-t", "wired", "-k", "interface,state,rx_dupe,rx_ooo,re-tx,rtt_avg,rcvsize,tx_win,tc_class,tc_mgt,cc_algo,P,C,R,W", "-P", "-l", "1"]
        
        // Create a Pipe and make the task
        // put all the output there
        let pipe = Pipe()
        task.standardOutput = pipe
        
        // Launch the task
        task.launch()
        
        // Get the data
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: String.Encoding.utf8) ?? ""
        handleNetWorkData(string: output)
    }
    
    func handleNetWorkData(string: String) {
        
        let lines = string.split(separator: "\n")
        curIn = 0
        curOut = 0
        for line in lines {
            if line.count == 0 || line.starts(with: "time") {
                continue
            }
            let lineParts = line.split(separator:" ")
            let linePartsLen = lineParts.count
            let inBytes:Int = Int(lineParts[linePartsLen-2])!
            let outBytes:Int = Int(lineParts[linePartsLen-1])!
            curIn += inBytes
            curOut += outBytes
        }
        if lastIn > 0 && lastOut > 0 {
            let upStr = NetSpeedMonitor.getSpeedString(bytesPerSecond: ((Double)(curOut-lastOut) / NetSpeedMonitor.interval))
            let downStr = NetSpeedMonitor.getSpeedString(bytesPerSecond: ((Double)(curIn-lastIn) / NetSpeedMonitor.interval))
            self.statusBarView.updateData(up: upStr, down: downStr)
        }
        lastIn = curIn
        lastOut = curOut
    }
    
    static func getSpeedString(bytesPerSecond: Double) -> String {
        if bytesPerSecond < KB/100 {
            return "0 B/S"
        }
        
        var result:Double
        var unit: String
        
        if bytesPerSecond < MB{
            result = bytesPerSecond / KB
            unit = " K/S"
        } else if bytesPerSecond < GB {
            result = bytesPerSecond / MB
            unit = " M/S"
        } else if bytesPerSecond < TB {
            result = bytesPerSecond / GB
            unit = " G/S"
        } else {
            return "MAX  /S"
        }
        
        if result < 100 {
            return String(format: "%0.2f ", result) + unit
        } else if result < 999 {
            return String(format: "%0.1f ", result) + unit
        } else {
            return String(format: "%0.0f ", result) + unit
        }
    }
}
