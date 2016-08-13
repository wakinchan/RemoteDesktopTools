#!/usr/bin/env swift

// Set human-readable labels, keychains for remote desktop

// Usage: ./setRemoteDesktopsName.swift

// http://apple.stackexchange.com/questions/182209/where-does-microsoft-rdp-8-for-mac-store-its-configuration
// /Users/${USER}/Library/Containers/com.microsoft.rdc.mac/Data/Library/Preferences/com.microsoft.rdc.mac.plist

import Foundation

extension String {
    func appendPath(path: String) -> String {
        let nsString = self as NSString
        return nsString.stringByAppendingPathComponent(path)
    }
}

// execute shell
func shell(cmd: String, args: [String]) -> String {
    let task = NSTask()
    task.launchPath = cmd
    let pipe = NSPipe()
    task.arguments = args
    task.standardOutput = pipe
    task.launch()
    task.waitUntilExit()
    guard task.terminationStatus == 0 else {
        print("ERROR: shell terminationStatus: \(task.terminationStatus)")
        exit(1)
    }
    let output = pipe.fileHandleForReading.readDataToEndOfFile()
    guard let result = String(data: output, encoding: NSUTF8StringEncoding) else {
        print("ERROR: encoding data")
        exit(1)
    }
    return result
}

let fileManager = NSFileManager.defaultManager()
let currentDirectoryPath = fileManager.currentDirectoryPath

let osUserName = NSUserName()
let fileName = "com.microsoft.rdc.mac.plist"
let directoryPath = "/Users/\(osUserName)/Library/Containers/com.microsoft.rdc.mac/Data/Library/Preferences/"
let preferenceFilePath = directoryPath.appendPath(fileName)
let datasourcePath: String = {
    return currentDirectoryPath.appendPath("datasource.csv")
}()

func read(path filePath: String) -> String {
    return try! String(contentsOfFile: filePath, encoding: NSUTF8StringEncoding)
}

guard var preferences = NSMutableDictionary(contentsOfFile: preferenceFilePath) else {
    print("ERROR: not found file")
    exit(1)
}
guard let bookmarkOrderIds = preferences["bookmarkorder.ids"] as? [String] else {
    print("ERROR: downcasting bookmarkorder.ids")
    exit(1)
}

struct Content {
    var name: String?
    var ipAddress: String?
    var userName: String?
    var password: String?
    var redirectionPath: String?
}

func getContents() -> [Content] {
    let data = read(path: datasourcePath)
    var contents = [Content]()
    data.enumerateLines { (line, stop) -> () in
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

// set keychains
let setKeychain = { (bookmarkOrderId: String, content: Content) in
    let prefixId = "bookmarks.bookmark.\(bookmarkOrderId)"
    let label = content.name!
    let userName = content.userName!
    let hostName = content.ipAddress!
    let password = content.password!
    print("Deleting internet keychain. \(bookmarkOrderId)")
    _ = {
        let args = [
            userName,
            bookmarkOrderId
        ]
        let executeFile = "deleteKeychain"
        shell(executeFile, args: args)
    }()
    print("Adding keychain. \(bookmarkOrderId):\(label)")
    _ = {
        let args = [
            userName,
            label,
            hostName,
            bookmarkOrderId,
            password
        ]
        let executeFile = "addKeychain"
        shell(executeFile, args: args)
    }()
}

// set label, password, redirection file path
for bookmarkOrderId in bookmarkOrderIds {
    let prefixId = "bookmarks.bookmark.\(bookmarkOrderId)"
    // get ipAddress
    guard let hostName = preferences["\(prefixId).hostname"] as? String else {
        print("ERROR: failed get hostName")
        continue
    }
    guard let content = contents.filter({$0.ipAddress == hostName}).first else {
        continue
    }
    if hostName == content.ipAddress {
        preferences.setObject(content.name!, forKey: "\(prefixId).label")
        setKeychain(bookmarkOrderId, content)
    } else {
        print("WARNING: invalid same hostName: \(hostName)")
    }
    
    // set redirection file path
    guard let redirectionPath = content.redirectionPath else {
        continue
    }
    let redirectionName = redirectionPath.componentsSeparatedByString("/").last!
    print(redirectionPath)
    print(redirectionName)
    let folderForwards: [String] = [
        "@Variant(\0\0\0\u{7F}\0\0\0\u{0E}FolderForward\0\0\0\0\u{04}\(redirectionName)\0\0\0\0\u{1B}\(redirectionPath)\0\0)"
    ]
    // NOTE: Crash RDP.app If you specify redirection file path.
    // ascii code is changed by the path.
    // How to use? It is necessary to specify the ascii code that matches the path.
    // 
    // key: secureFilePaths.{directory.redirection.file.path}
    // I cann't understand this data format.
    preferences.setObject(folderForwards, forKey: "\(prefixId).folderForwards")
}
print("Set human-readable labels, keychains for password.")

// sort by label
let sortedBookmarkOrderIds = bookmarkOrderIds.sort { (lhs, rhs) in
    let labelClosure = { (id: String) -> String in
        guard let label = preferences["bookmarks.bookmark.\(id).label"] as? String else {
            return ""
        }
        return label
    }
    let lhsLabel = labelClosure(lhs)
    let rhsLabel = labelClosure(rhs)
    return lhsLabel < rhsLabel
}

print("sorted by label.")

preferences.setObject(sortedBookmarkOrderIds, forKey: "bookmarkorder.ids")

// save
preferences.writeToFile(preferenceFilePath, atomically: true)

print("Please restart Mircrosoft Remtoe Desktop.app.")
