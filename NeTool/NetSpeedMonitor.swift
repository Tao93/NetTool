//
//  NetSpeedUtils.swift
//  NeTool
//
//  Created by Liu, Tao (Toni) on 9/15/18.
//  Copyright © 2018 Liu, Tao (Toni). All rights reserved.
//

import AppKit
import Darwin
import Foundation

open class NetSpeedMonitor {
    static let interval: Int = 1400
    static let KB: Double = 1024
    static let MB: Double = KB * 1024
    static let GB: Double = MB * 1024
    static let TB: Double = GB * 1024
    static let TOP_ITEM_COUNT = 5;
    
    // sum of upload bytes by all apps in last sample data.
    var upBytesOfLast = 0
    var downBytesOfLast = 0

    // sum of upload bytes by all apps in current sample data.
    var upBytesOfCur = 0
    var downBytesOfCur = 0
    
    // process ids of apps appeared in last sample data.
    var pidsOfLastOutput = Array<String>()
    var pidsOfCurOutput = Array<String>()
    
    // stores info of bytes and speed of multiple apps.
    var pbArray = Array<ProcessBytes>()


    // timer to periodiclly execute nettop command.
    var timer: DispatchSourceTimer? = nil
    
    let statusBarView: StatusBarView
    let speedInfoView: SpeedInfoView
    
    init(statusBarView: StatusBarView, speedInfoView: SpeedInfoView) {
        self.statusBarView = statusBarView
        self.speedInfoView = speedInfoView
    }
    
    func start() {
        if (timer != nil) {
            timer?.resume()
            return
        }
        
        timer = DispatchSource.makeTimerSource(flags: [], queue: DispatchQueue.global())
        timer?.schedule(
            deadline: .now(),
            repeating: DispatchTimeInterval.milliseconds(NetSpeedMonitor.interval),
            leeway: DispatchTimeInterval.milliseconds(NetSpeedMonitor.interval))
        timer?.setEventHandler {
            // Create a Task instance
            let task = Process()
            task.launchPath = "/usr/bin/nettop"
            // -x to get value with Byte as unit, rather than MB, GB etc.
            // -t wifi -t wired to choose type of network interface we want.
            // -J to pick columns of output we want.
            // -l 1 to get only one sample data.
            task.arguments = [
            "-x", "-t", "wifi", "-t", "wired", "-J","time,bytes_in,bytes_out", "-P", "-l", "1"]
            let pipe = Pipe()
            task.standardOutput = pipe
            // Launch the task
            task.launch()
            
            // Get the data
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if #available(macOS 10.15, *) {
                do {
                    try pipe.fileHandleForReading.close()
                } catch { }
            } else {
                pipe.fileHandleForReading.closeFile()
            }
            let output = String(data: data, encoding: String.Encoding.utf8) ?? ""
            self.handleOutput(fetchedData: output)
        }
        timer?.resume()
    }
    
    func stop() {
        timer?.suspend()
        
        // reset the following variables.
        
        upBytesOfLast = 0
        downBytesOfLast = 0
        
        upBytesOfCur = 0
        downBytesOfCur = 0
        
        pidsOfLastOutput.removeAll()
        pidsOfCurOutput.removeAll()
        
        pbArray.removeAll()
        
        self.statusBarView.updateData(up: StatusBarView.initialRateText, down: StatusBarView.initialRateText)
    }
    
    // Parse a single nettop -l 1 sample output.
    func handleOutput(fetchedData: String) {
        let allLines = fetchedData.split(separator: "\n")
        var validLines: [String] = []

        for ln in allLines {
            let line = String(ln)
            if line.isEmpty { continue }
            if line.hasPrefix("time") {
                // header line — skip for -l 1, but record its length for completeness
                if line.hasSuffix("out") {
                    validLines.append(line)
                }
            } else {
                // data lines are complete in -l 1 mode
                validLines.append(line)
            }
        }
        
        // clear
        upBytesOfCur = 0;
        downBytesOfCur = 0;
        pidsOfCurOutput.removeAll()
        
        if pbArray.count > 0 {
            // iterate for each pbArray element.
            for i in 0...(pbArray.count - 1) {
                pbArray[i].upBytes1 = pbArray[i].upBytes2
                pbArray[i].upBytes2 = 0
                pbArray[i].downBytes1 = pbArray[i].downBytes2
                pbArray[i].downBytes2 = 0
            }
        }
        
        // now all lines inside validLines are complete, including the header line. handle them.
        for line in validLines {
            handleOneLineOutput(line: line)
        }
        // update the menubar icon.
        if (upBytesOfLast > 0 && downBytesOfLast > 0) {
            let upStr = NetSpeedMonitor.getSpeedString(bytes1: upBytesOfLast, bytes2: upBytesOfCur)
            let downStr = NetSpeedMonitor.getSpeedString(bytes1: downBytesOfLast, bytes2: downBytesOfCur)
            self.statusBarView.updateData(up: upStr, down: downStr)
        }
        // iterate.
        upBytesOfLast = upBytesOfCur
        downBytesOfLast = downBytesOfCur
        
        // sort by sum of up & down bytes.
        pbArray.sort(by: {pb1, pb2 in
            (pb1.downBytes2 - pb1.downBytes1 + pb1.upBytes2 - pb1.upBytes1) >
                (pb2.downBytes2 - pb2.downBytes1 + pb2.upBytes2 - pb2.upBytes1)
        })
        
        // check if pids of current output mostly appear in last output.
        // if not so, restart the monitoring.
        if pidsOfLastOutput.count > 0 {
            var appearedCount = 0
            for pid in pidsOfCurOutput {
                if pidsOfLastOutput.contains(pid) {
                    appearedCount += 1
                }
            }
            // more than 3 process not appear in last sample
            if pidsOfCurOutput.count - appearedCount > 3 {
                // unexpected output
            }
        }
        
        // iterate
        pidsOfLastOutput.removeAll()
        for pid in pidsOfCurOutput {
            pidsOfLastOutput.append(pid)
        }
        
        // if dropdown menu is expanded, calculate TOP_ITEM_COUNT processes with top download speed.
        if statusBarView.isMenuOpen {
            updateTopSpeedItems()
        }
    }

    // header line is like "time          bytes_in       bytes_out"
    // other lines are like "16:59:11.290649 UserEventAgent.104     313206          431240", which contains time, process name, process id, bytes downloaded and bytes uploaded.
    func handleOneLineOutput(line: String) {
        if line.starts(with: "time") {  // skip header line.
            return
        }
        
        let lineParts = line.split(separator: " ")
        let downBytes:Int = Int(lineParts[lineParts.count - 2])!
        let upBytes:Int = Int(lineParts[lineParts.count - 1])!
        upBytesOfCur += upBytes
        downBytesOfCur += downBytes
        
        // process name and process id, like "Google Chrome H.1567",  we need to get the pid.
        let pNameAndPid = String(lineParts[lineParts.count - 3])
        let pid = String(pNameAndPid[pNameAndPid.index(after: pNameAndPid.lastIndex(of: ".")!)...])
        let pbIdx = getPbIndexByPid(pid: pid)
        // check whether there is already a ProcessBytes object for this process.
        if pbIdx == nil {
            // no, then create a new one.
            let pb = ProcessBytes(pid: pid, upBytes1: 0, upBytes2: upBytes, downBytes1: 0, downBytes2: downBytes)
            pbArray.append(pb)
        } else {
            pbArray[pbIdx!].upBytes2 = upBytes
            pbArray[pbIdx!].downBytes2 = downBytes
        }
        // store the process id
        pidsOfCurOutput.append(pid)
    }
    
    // bytes1: accumulated bytes of last sample
    // bytes2: accumulated bytes of current sample
    static func getSpeedString(bytes1: Int, bytes2: Int) -> String {
        let bytesPerSecond = (bytes2 - bytes1) * 1000 / interval
        
        var result:Double
        var unit: String
        
        if (bytesPerSecond < 10) {
            return "0 B/S"
        } else if bytesPerSecond < 1000 {
            return String(bytesPerSecond) + " B/S"
        }
        let bytesPerSecondDouble = (Double)(bytesPerSecond)
        if bytesPerSecondDouble < 1000 * KB {
            result = bytesPerSecondDouble / KB
            unit = "K/S"
        } else if bytesPerSecondDouble < 1000 * MB {
            result = bytesPerSecondDouble / MB
            unit = "M/S"
        } else if bytesPerSecondDouble < 1000 * GB {
            result = bytesPerSecondDouble / GB
            unit = "G/S"
        } else {
            return "MAX /S"
        }
        
        if result < 100 {
            // keep at most 2 decimals.
            return String((result * 100).rounded() / 100) + " " + unit
        } else {
            // keep at most 1 decimal.
            return String((result * 10).rounded() / 10) + " " + unit
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

    /// Get the process name from a PID using libproc (for non-NSRunningApplication processes).
    static func processName(for pid: Int32) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        let ret = proc_name(pid, &buffer, UInt32(MAXPATHLEN))
        guard ret > 0 else { return nil }
        return String(cString: buffer)
    }

    /// Get the executable path for a PID using libproc.
    static func processPath(for pid: Int32) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        let ret = proc_pidpath(pid, &buffer, UInt32(MAXPATHLEN))
        guard ret > 0 else { return nil }
        return String(cString: buffer)
    }

    /// Extract a human-readable app name from a process executable path.
    /// e.g. /Applications/Safari.app/Contents/MacOS/Safari → "Safari.app"
    ///      /usr/sbin/mDNSResponder → "mDNSResponder"
    static func appName(from path: String) -> String {
        // For .app bundles: find ".app/Contents/" and take "XXX.app"
        if let contentsRange = path.range(of: ".app/Contents/", options: .caseInsensitive) {
            let trimmed = String(path[..<contentsRange.lowerBound]) + ".app"
            if let slashIdx = trimmed.lastIndex(of: "/") {
                return String(trimmed[trimmed.index(after: slashIdx)...])
            }
            return trimmed
        }

        // For non-bundle processes: take the executable name,
        // truncating at the first space (command may include arguments)
        let name = (path as NSString).lastPathComponent
        if let spaceIdx = name.firstIndex(of: " ") {
            return String(name[..<spaceIdx])
        }
        return name
    }

    // get an array of SpeedInfo objects which represent apps with top net speed
    func getTopSpeedInfo() -> [SpeedInfo]? {
        guard pbArray.count >= NetSpeedMonitor.TOP_ITEM_COUNT else { return nil }

        let topN = min(NetSpeedMonitor.TOP_ITEM_COUNT, pbArray.count)
        var result: [SpeedInfo] = []

        for i in 0..<topN {
            let pid = Int32(pbArray[i].pid) ?? -1
            var name: String
            let execPath = Self.processPath(for: pid) ?? ""

            if let app = NSRunningApplication(processIdentifier: pid),
               let localizedName = app.localizedName, !localizedName.isEmpty {
                name = localizedName
            } else if !execPath.isEmpty {
                // Fallback: extract app name from .app bundle path
                name = Self.appName(from: execPath)
            } else if let procName = Self.processName(for: pid) {
                // Last fallback: libproc process name
                name = procName
            } else {
                name = String(pid)
            }

            let info = SpeedInfo(
                name: name,
                path: execPath,
                upSpeed: NetSpeedMonitor.getSpeedString(bytes1: pbArray[i].upBytes1, bytes2: pbArray[i].upBytes2),
                downSpeed: NetSpeedMonitor.getSpeedString(bytes1: pbArray[i].downBytes1, bytes2: pbArray[i].downBytes2))
            result.append(info)
        }
        return result
    }
    
    func updateTopSpeedItems() {
        let topInfo = getTopSpeedInfo()
        self.speedInfoView.updateTopSpeedItems(infoArr: topInfo)
    }
}

struct ProcessBytes {
    var pid: String
    // accumulated upload bytes of this process in last sample
    var upBytes1: Int
    // accumulated upload bytes of this process in current sample
    var upBytes2: Int
    var downBytes1: Int
    var downBytes2: Int
}

struct SpeedInfo {
    // app name (via NSRunningApplication)
    var name: String
    // full executable path (via proc_pidpath)
    var path: String
    // upload speed string
    var upSpeed: String
    var downSpeed: String
}
