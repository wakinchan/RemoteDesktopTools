#!/usr/bin/env swift

// Ouput .rdp files to ~/rdp directory
// 1. Execute this file.
// 2. Open Microsoft Remote Desktop
// 3. File > Import.. Select all .rdp files in rdp/

// Usage: ./createRemoteDesktops.swift

import Foundation

extension String {
    func appendPath(path: String) -> String {
        let nsString = self as NSString
        return nsString.stringByAppendingPathComponent(path)
    }
}

let fileManager = NSFileManager.defaultManager()
let currentDirectoryPath = fileManager.currentDirectoryPath
let formatPath: String = {
    return currentDirectoryPath.appendPath("format.txt")
}()
let datasourcePath: String = {
    return currentDirectoryPath.appendPath("datasource.csv")
}()
let subDirectory = "rdp"

func createDirectoryIfNeed(directoryPath: String) {
    guard !fileManager.fileExistsAtPath(directoryPath) else {
        return
    }
    try! fileManager.createDirectoryAtPath(directoryPath, withIntermediateDirectories: false, attributes: nil)
}

struct Content {
    var name: String?
    var ipAddress: String?
    var userName: String?
    var password: String?
    var redirectionPath: String?
}

func read(path filePath: String) -> String {
    return try! String(contentsOfFile: filePath, encoding: NSUTF8StringEncoding)
}

func save(fileName: String, data: String) {
    let directoryPath = currentDirectoryPath.appendPath(subDirectory)
    createDirectoryIfNeed(directoryPath)
    let filePath = directoryPath.appendPath(fileName)
    try! data.writeToFile(filePath, atomically: true, encoding: NSUTF8StringEncoding)
}

func createFormat(content: Content) -> String {
    let data = read(path: formatPath)
    var components = [String]()
    data.enumerateLines{ (line, stop) in
        components.append(line)
    }
    return components.joinWithSeparator("\n")
        .stringByReplacingOccurrencesOfString("${IPADDRESS}", withString: content.ipAddress!)
        .stringByReplacingOccurrencesOfString("${USERNAME}", withString: content.userName!)
}

func getContents() -> [Content] {
    let data = read(path: datasourcePath)
    var contents = [Content]()
    var first = false
    data.enumerateLines { (line, stop) -> () in
        guard first else {
            first = true
            return
        }
        let components = line.componentsSeparatedByString(",")
        var content = Content()
        content.name = components[0]
        content.ipAddress = components[1]
        content.userName = components[2]
        content.password = components[3]
        // content.redirectionPath = components[4]
        contents.append(content)
    }
    return contents
}

let contents = getContents()
for content in contents {
    let format = createFormat(content)
    let fileName: String = {
        return content.name! + "-" + content.ipAddress! + ".rdp"
    }()
    save(fileName, data: format)
    print("Saved! \(subDirectory)/\(fileName)")
}
