//
//  NetSpeedUtils.swift
//  NeTool
//
//  Created by Liu, Tao (Toni) on 9/15/18.
//  Copyright © 2018 Liu, Tao (Toni). All rights reserved.
//

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
    
    // the following 2 are for using "-l 0" argument of nettop command, which means the command
    // would continuously output sample data, and we only execute this command once, and continuously
    // consume the data.
    // but currently we still use "-l 1" due to stability problem.
    // the last line of last output, but the line is incomplete, hence we save and use it when next output is available.
    var inCompleteLastLineOfLastOutput = ""
    // the length of last header line. a header line starts with word "time", ends with word "bytes_out"
    var lenOflastHeaderLine = 0
    
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
            if #available(OSX 10.15, *) {
                do {
                    try pipe.fileHandleForReading.close()
                } catch { }
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
        
        inCompleteLastLineOfLastOutput = ""
        lenOflastHeaderLine = 0
        
        pidsOfLastOutput.removeAll()
        pidsOfCurOutput.removeAll()
        
        pbArray.removeAll()
        
        self.statusBarView.updateData(up: StatusBarView.INITIAL_RATE_TEXT, down: StatusBarView.INITIAL_RATE_TEXT)
    }
    
    // this methods contains logic to consider unexpected output of nettop with "-l 0" argument,
    // see comment of inCompleteLastLineOfLastOutput.
    // many code are unnecessary for nettop with "-l 1" argument, i.e. current situation.
    func handleOutput(fetchedData: String) {
        
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
                        // unexpected output
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
                        // unexpected output
                    }
                }
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
        if (statusBarView.isMenuShown()) {
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
    
    // get an array of SpeedInfo objects which represent apps with top net speed
    func getTopSpeedInfo() -> Array<SpeedInfo>? {
        if (pbArray.count < 5) {
            return nil
        }
        // use ps command to get all process path of the top 5 processes.
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
        for i in 0...(min(NetSpeedMonitor.TOP_ITEM_COUNT, pbArray.count)  - 1) {
            // find the line which contains pid of pbArray[i].
            var line: String? = nil
            for ln in lines {
                if ln.trimmingCharacters(in: .whitespacesAndNewlines).starts(with: pbArray[i].pid) {
                    line = String(ln)
                    break
                }
            }
            if line != nil {
                // for XXX.app case, only take XXX.app as path.
                let idx = line!.range(of: ".app/Contents/")?.lowerBound
                var path: String
                if idx == nil {
                    let wholeCmd = line!.substring(fromIndex: pathStartIdx)
                    // only take characters before the first space, because characters after
                    // the space might be arguments of the process.
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
            }
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
    // app name or command path.
    var path: String
    // upload speed string
    var upSpeed: String
    var downSpeed: String
}

// string utils.
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
