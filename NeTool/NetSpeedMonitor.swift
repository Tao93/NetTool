//
//  NetSpeedUtils.swift
//  NeTool
//
//  Created by Liu, Tao (Toni) on 9/15/18.
//  Copyright © 2018 Liu, Tao (Toni). All rights reserved.
//

import Foundation

open class NetSpeedMonitor {
    static let interval: Int = 1
    static let KB: Double = 1024
    static let MB: Double = KB * 1024
    static let GB: Double = MB * 1024
    static let TB: Double = GB * 1024
    static let TOP_ITEM_COUNT = 5;
    
    var upBytesOfLastSecond = 0
    var downBytesOfLastSecond = 0

    var upBytesOfCurSecond = 0
    var downBytesOfCurSecond = 0
    
    var pidsOfLastOutput = Array<String>()
    var pidsOfCurOutput = Array<String>()
    
    var pbArray = Array<ProcessBytes>()
    
    // the last line of last output, but the line is incomplete, hence we save and use it when next output is available.
    var inCompleteLastLineOfLastOutput = ""
    // the length of last header line. a header line starts with word "time", ends with word "bytes_out"
    var lenOflastHeaderLine = 0
    
    var task: Process? = nil
    
    let statusBarView: StatusBarView
    
    init(statusBarView: StatusBarView) {
        self.statusBarView = statusBarView
    }
    
    func start() {
        print("start")
        DispatchQueue.global(qos: .userInteractive).async {
            self.startMonitor()
        }
    }
    
    func stop() {
        print("stop")
        DispatchQueue.global(qos: .userInteractive).async {
            self.stopMonitor()
        }
    }
    
    @objc func startMonitor() {
        print("start monitor")
        
        // Create a Task instance
        task = Process()
        
        // Set the task parameters. we execute the nettop command with specific arguments, which make it
        // continuously output sample data of bytes received and sent by macOS processes.
        task!.launchPath = "/usr/bin/nettop"
        // -x to show real bytes number rather than units like KiB or MiB etc., to calculate more conveniently.
        // -t to include only WiFi and wired network bytes.
        // -J to specify the only columns to be included in output.
        // -P to display per-process summary only, skipping details of open connections.
        // -l to specify number of sample outputs the command would prodoce. 0 means infinite.
        task!.arguments = [
            "-x", "-t", "wifi", "-t", "wired",
            "-J","time,bytes_in,bytes_out",
            "-P", "-l", "0", "-s", "1"]
        
        // Create a Pipe and make the task
        // put all the output there
        let pipe = Pipe()
        task!.standardOutput = pipe
        
        let outputHandle = pipe.fileHandleForReading
        outputHandle.waitForDataInBackgroundAndNotify()
        
        // use data observer to continuously fetch the output data of the shell command.
        var dataAvailable : NSObjectProtocol!
        dataAvailable = NotificationCenter.default.addObserver(
            forName: NSNotification.Name.NSFileHandleDataAvailable,
            object: outputHandle, queue: nil) {  notification -> Void in
                let data = pipe.fileHandleForReading.availableData
                if data.count > 0 {
                    // fetch the sample output data, the following if statement
                    // would be executed continuously.
                    if let str = String(data: data, encoding: String.Encoding.utf8) {
                        self.handleOutput(fetchedData: str)
                    }
                    outputHandle.waitForDataInBackgroundAndNotify()
                } else {
                    NotificationCenter.default.removeObserver(dataAvailable as Any)
                }
        }
        
        // Launch the task
        task!.launch()
        task!.waitUntilExit()
    }
    
    @objc func stopMonitor() {
        print("stop monitor")
        task?.terminate()
        task = nil
        
        // reset the following variables.
        
        upBytesOfLastSecond = 0
        downBytesOfLastSecond = 0
        
        upBytesOfCurSecond = 0
        downBytesOfCurSecond = 0
        
        inCompleteLastLineOfLastOutput = ""
        lenOflastHeaderLine = 0
        
        pidsOfLastOutput.removeAll()
        pidsOfCurOutput.removeAll()
        
        pbArray.removeAll()
        
        self.statusBarView.updateData(up: StatusBarView.INITIAL_RATE_TEXT, down: StatusBarView.INITIAL_RATE_TEXT)
    }
    
    func handleOutput(fetchedData: String) {
        if task == nil {  // terminated, return.
            return
        }
        
        // the original nettop with previous arguments would produce output intervally and neatly.
        // i.e. if you set "-s 1" argument for the command, the output would be produced per second,
        // and each output is just sample of that second.
        // however, each batch of output text we fetched from the data observer might be not one complete sample output.
        
        var validLines = Array<String>()
        // first, split the output into several lines. the 1st line and last line might be incomplete.
        // so we insert the inCompleteLastLineOfLastOutput in front of it, to mke sure 1st line is complete.
        let lines = (inCompleteLastLineOfLastOutput + fetchedData).split(separator: "\n")
        inCompleteLastLineOfLastOutput = ""  // clear after usage.

        for i in 0...(lines.count - 1) {
            let line = lines[i]
            if line.count == 0 {  // skip empty lines.
                continue
            }
            
            if line.starts(with: "time") {
                // if this is a header line and is complete, update the lenOflastHeaderLine
                if String(line).substring(fromIndex: line.count - 3) == "out" {
                    validLines.append(String(line))
                    lenOflastHeaderLine = line.count
                } else {
                    if (i == lines.count - 1) {
                        inCompleteLastLineOfLastOutput = String(line)
                    } else {
                        stopMonitor()
                        startMonitor()
                    }
                }
            } else {
                // condition to check whether the line is complete
                if line.count == lenOflastHeaderLine {
                    validLines.append(String(line))
                } else {
                    if (i == lines.count - 1) {
                        inCompleteLastLineOfLastOutput = String(line)
                    } else {
                        stopMonitor()
                        startMonitor()
                    }
                }
            }
        }
        
        upBytesOfCurSecond = 0;
        downBytesOfCurSecond = 0;
        pidsOfCurOutput.removeAll()
        
        if pbArray.count > 0 {
            for i in 0...(pbArray.count - 1) {
                pbArray[i].upBytes1 = pbArray[i].upBytes2
                pbArray[i].upBytes2 = 0
                pbArray[i].downBytes1 = pbArray[i].downBytes2
                pbArray[i].downBytes2 = 0
            }
        }
        
        // now all lines inside validLines are complete, including the header line.
        for line in validLines {
            handleOneLineOutput(line: line)
        }
        if (upBytesOfLastSecond > 0 && downBytesOfLastSecond > 0) {
            let upStr = NetSpeedMonitor.getSpeedString(bytes1: upBytesOfLastSecond, bytes2: upBytesOfCurSecond)
            let downStr = NetSpeedMonitor.getSpeedString(bytes1: downBytesOfLastSecond, bytes2: downBytesOfCurSecond)
            self.statusBarView.updateData(up: upStr, down: downStr)
        }
        upBytesOfLastSecond = upBytesOfCurSecond
        downBytesOfLastSecond = downBytesOfCurSecond
        
        pbArray.sort(by: {pb1, pb2 in
            (pb1.downBytes2 - pb1.downBytes1) > (pb2.downBytes2 - pb2.downBytes1)
        })
        //print("----")
        //print(pbArray[0].pid + ", " + String(pbArray[0].downBytes2 - pbArray[0].downBytes1))
        //print(pbArray[1].pid + ", " + String(pbArray[1].downBytes2 - pbArray[1].downBytes1))
        //print(pbArray[2].pid + ", " + String(pbArray[2].downBytes2 - pbArray[2].downBytes1))
        
        // check if pids of current output mostly appear in last output.
        // if not so, restart the monitoring.
        if pidsOfLastOutput.count > 0 {
            var appearedCount = 0
            for pid in pidsOfCurOutput {
                if pidsOfLastOutput.contains(pid) {
                    appearedCount += 1
                }
            }
            if pidsOfCurOutput.count - appearedCount > 1 {
                stopMonitor()
                startMonitor()
                return
            }
        }
        pidsOfLastOutput.removeAll()
        for pid in pidsOfCurOutput {
            pidsOfLastOutput.append(pid)
        }
        
        // if dropdown menu is expanded, calculate TOP_ITEM_COUNT processes with top download speed.
        if (true) {
            updateTopSpeedItems()
        }
    }

    func handleOneLineOutput(line: String) {
        if line.starts(with: "time") {  // skip header line.
            return
        }
        
        let lineParts = line.split(separator: " ")
        let downBytes:Int = Int(lineParts[lineParts.count - 2])!
        let upBytes:Int = Int(lineParts[lineParts.count - 1])!
        upBytesOfCurSecond += upBytes
        downBytesOfCurSecond += downBytes
        
        // process name and process id, like "Google Chrome H.1567",  we need to get the pid.
        let pNameAndPid = String(lineParts[lineParts.count - 3])
        let pid = String(pNameAndPid[pNameAndPid.index(after: pNameAndPid.lastIndex(of: ".")!)...])
        let pbIdx = getPbIndexByPid(pid: pid)
        if pbIdx == nil {
            let pb = ProcessBytes(pid: pid, upBytes1: 0, upBytes2: upBytes, downBytes1: 0, downBytes2: downBytes)
            pbArray.append(pb)
        } else {
            pbArray[pbIdx!].upBytes2 = upBytes
            pbArray[pbIdx!].downBytes2 = downBytes
        }
        
        pidsOfCurOutput.append(pid)
    }
    
    static func getSpeedString(bytes1: Int, bytes2: Int) -> String {
        let bytesPerSecond = (Double)((bytes2 - bytes1) / interval)
        if bytesPerSecond < KB/100 {
            return "0 B/S"
        }
        
        var result:Double
        var unit: String
        
        if bytesPerSecond < MB{
            result = bytesPerSecond / KB
            unit = "K/S"
        } else if bytesPerSecond < GB {
            result = bytesPerSecond / MB
            unit = "M/S"
        } else if bytesPerSecond < TB {
            result = bytesPerSecond / GB
            unit = "G/S"
        } else {
            return "MAX /S"
        }
        
        if result < 100 {
            return String(format: "%0.2f ", result) + unit
        } else if result < 999 {
            return String(format: "%0.1f ", result) + unit
        } else {
            return String(format: "%0.0f ", result) + unit
        }
    }
    
    func getPbIndexByPid(pid: String) -> Int? {
        if (pbArray.count > 0) {
            for i in 0...(pbArray.count - 1) {
                if pbArray[i].pid == pid {
                    return i
                }
            }
        }
        return nil
    }
    
    func getTopSpeedInfo() -> Array<SpeedInfo>? {
        if (pbArray.count == 0) {
            return nil
        }
        let pidsTemplate = "%@,%@,%@,%@,%@"
        let pids = String(format: pidsTemplate, pbArray[0].pid, pbArray[1].pid, pbArray[2].pid, pbArray[3].pid, pbArray[4].pid)
        let task = Process()
        task.launchPath = "/bin/ps"
        task.arguments = ["-p", pids]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: String.Encoding.utf8) ?? ""
        let lines = output.split(separator: "\n")
        var result = Array<SpeedInfo>()
        
        let pathStartIdx = String(lines[0]).indexOf(str: "CMD")
        // print("<<<")
        for i in 0...(min(NetSpeedMonitor.TOP_ITEM_COUNT, pbArray.count)  - 1) {
            var line: String? = nil
            for ln in lines {
                if ln.trimmingCharacters(in: .whitespacesAndNewlines).starts(with: pbArray[i].pid) {
                    line = String(ln)
                    break
                }
            }
            if line != nil {
                let idx = line!.range(of: ".app/Contents/")?.lowerBound
                var path: String
                if idx == nil {
                    let wholeCmd = line!.substring(fromIndex: pathStartIdx)
                    let spaceIdx = wholeCmd.indexOf(str: " ")
                    if spaceIdx > 0 {
                        path = wholeCmd.substring(toIndex: spaceIdx)
                    } else {
                        path = wholeCmd
                    }
                } else {
                    let trimedDotApp = String(line![..<idx!]) + ".app"
                    path = String(trimedDotApp[trimedDotApp.index(after: trimedDotApp.lastIndex(of: "/")!)...])
                }
                let info = SpeedInfo(path: path,
                                     upSpeed: NetSpeedMonitor.getSpeedString(bytes1: pbArray[i].upBytes1, bytes2: pbArray[i].upBytes2),
                                     downSpeed: NetSpeedMonitor.getSpeedString(bytes1: pbArray[i].downBytes1, bytes2: pbArray[i].downBytes2))
                result.append(info)
                // print(info.path + ": ")
            }
        }
        return result
    }
    
    func updateTopSpeedItems() {
        let topInfo = getTopSpeedInfo()
        
    }
}

struct ProcessBytes {
    var pid: String
    var upBytes1: Int
    var upBytes2: Int
    var downBytes1: Int
    var downBytes2: Int
}

struct SpeedInfo {
    var path: String
    var upSpeed: String
    var downSpeed: String
}

extension String {

    var length: Int {
        return count
    }

    subscript (i: Int) -> String {
        return self[i ..< i + 1]
    }

    func substring(fromIndex: Int) -> String {
        return self[min(fromIndex, length) ..< length]
    }

    func substring(toIndex: Int) -> String {
        return self[0 ..< max(0, toIndex)]
    }

    subscript (r: Range<Int>) -> String {
        let range = Range(uncheckedBounds: (lower: max(0, min(length, r.lowerBound)),
                                            upper: min(length, max(0, r.upperBound))))
        let start = index(startIndex, offsetBy: range.lowerBound)
        let end = index(start, offsetBy: range.upperBound - range.lowerBound)
        return String(self[start ..< end])
    }
    
    func indexOf(str: String) -> Int {
        return range(of: str)?.lowerBound.utf16Offset(in: self) ?? -1
    }
}
