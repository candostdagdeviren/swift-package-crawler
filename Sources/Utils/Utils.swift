//
//  Utils.swift
//  swift-package-crawler
//
//  Created by Honza Dvorsky on 5/9/16.
//
//

import Foundation
import Redbird
import gzip
import Jay
import Tasks
import Vapor
import VaporTLS
import HTTP
import C7

#if os(Linux)
public func autoreleasepool(block: @noescape () throws -> ()) rethrows {
    try block()
}
#endif

public typealias TLSClient = HTTP.Client<TLSClientStream>

public enum CrawlError: Error {
    case got404 //that's the end, finish this crawling session
    case got429 //too many requests, back off
    case got503 //service unavailable, retry
}

public struct GenericError: Error {
    let description: String
    public init(_ description: String) {
        self.description = description
    }
}

public func headersWithGzip() -> [HeaderKey: String] {
    return ["Accept-Encoding": "gzip"]
}

public func decodeResponseData(response: Response) throws -> C7.Data {
    guard let bytes = response.body.bytes else { throw GenericError("No response bytes") }
    let data = C7.Data(bytes)
    guard response.headers["Content-Encoding"] == "gzip" || response.headers["Transfer-Encoding"] == "gzip" else {
        return data
    }
    return try data.gzipUncompressed()
}


extension String {
    
    private func fileManager() -> FileManager {
        return FileManager.default
    }
    
    func mkdir() throws {
        try fileManager().createDirectory(atPath: self, withIntermediateDirectories: true, attributes: nil)
    }
    
    public func rm() throws {
        try fileManager().removeItem(atPath: self)
    }
    
    public func ls() throws -> [String] {
        return try fileManager().contentsOfDirectory(atPath: self)
    }
    
    public func isRemoteGitURL() -> Bool {
        return self.hasPrefix("https://") || self.hasPrefix("git@") || self.hasPrefix("ssh://")
    }
}

func fixedName(_ name: String) -> String {
    return name.components(separatedBy: "/").filter { !$0.isEmpty }.joined(separator: "_")
}

public func packageSwiftPath(name: String) throws -> String {
    let name = "\(fixedName(name))-Package.swift"
    let parent = try packagesSwiftPath()
    return parent.addPathComponents(name)
}

public func packageJSONPath(name: String) throws -> String {
    let name = "\(fixedName(name))-Package.json"
    let parent = try packagesJSONPath()
    return parent.addPathComponents(name)
}

public func analysisResultPath(name: String) throws -> String {
    let parent = try resultsPath()
    return parent.addPathComponents(name)
}

public func cacheRootPath() throws -> String {
    let path = (#file.pathComponents().dropLast(3) + ["Cache"]).joined(separator: "/")
    try path.mkdir()
    return path
}

public func packagesSwiftPath() throws -> String {
    let path = try cacheRootPath().addPathComponents("PackageSwiftFiles")
    try path.mkdir()
    return path
}

public func packagesJSONPath() throws -> String {
    let path = try cacheRootPath().addPathComponents("PackageJSONFiles")
    try path.mkdir()
    return path
}

public func resultsPath() throws -> String {
    let path = try cacheRootPath().addPathComponents("Results")
    try path.mkdir()
    return path
}

extension String {
    public func pathComponents() -> [String] {
        return [""] + self.characters.split(separator: "/").map(String.init)
    }
    
    public func parentDirectory() -> String {
        return self.pathComponents().dropLast().joined(separator: "/")
    }
    
    public func addPathComponents(_ comps: String...) -> String {
        return (self.pathComponents() + comps).joined(separator: "/")
    }
    
    public func setPathExtension(extension: String) -> String {
        var comps = self.pathComponents()
        var last = comps.popLast()!
        var chars = last.characters
        let rev = chars.reversed()
        if let idx = rev.index(of: ".") {
            let distance = rev.distance(from: rev.startIndex, to: idx)
            chars = chars.dropLast(distance+1)
        }
        comps.append(String(chars))
        return comps.joined(separator: "/")
    }
    
    public func githubName() -> String {
        let start = self.range(of: "https://github.com")?.upperBound ?? self.startIndex
        let end = self.range(of: ".git")?.lowerBound ?? self.endIndex
        return String(self.characters[start..<end])
    }
    
    public func markdownGithubRepoLink() -> String {
        return "[\(self)](https://github.com\(self))"
    }
    
    public func markdownGithubUserLink() -> String {
        return "[\(self)](https://github.com/\(self))"
    }
    
    public func leftPad(_ padding: Int) -> String {
        let length = self.lengthOfBytes(using: String.Encoding.utf8)
        if length >= padding {
            return self
        } else {
            let pad = Array(repeating: " ", count: padding - length).joined(separator: "")
            return pad + self
        }
    }
}

extension Int {
    public func leftPad(_ padding: Int) -> String {
        return String(self).leftPad(padding)
    }
    
    public func percentOf(_ total: Int) -> Double {
        let pc = Double(self)/Double(total)
        let percent = Double(Int(10000 * pc))/100
        return percent
    }
}

extension Double {
    public func leftPad(_ padding: Int) -> String {
        return String(self).leftPad(padding)
    }
}

public func saveStat(db: Redbird, name: String, value: String) throws {
    try db.command("SET", params: ["stat::\(name)", value])
}

public func readStat(db: Redbird, name: String) throws -> String {
    let resp = try db.command("GET", params: ["stat::\(name)"]).toString()
    return resp
}

public func deletePackage(db: Redbird, name: String) throws {
    try db.command("DEL", params: ["package::\(name)"])
    try db.command("SREM", params: ["github_names", "\(name)"])
}

extension Collection where Iterator.Element == UInt8 {
    
    public func write(to path: String) throws {
        let string = try self.string()
        try string.write(toFile: path, atomically: true, encoding: String.Encoding.utf8)
    }
}

struct TaskError: Error, CustomStringConvertible {
    
    let taskResult: TaskResult
    let comment: String
    init(_ comment: String, _ taskResult: TaskResult) {
        self.taskResult = taskResult
        self.comment = comment
    }
    
    var description: String {
        return "Error: \(comment): \(taskResult)"
    }
}

public func ifChangesCommitAndPush(repoPath: String) throws {
    
    let gitStatus = try Task.run(["git", "status", "--porcelain"], pwd: repoPath)
    guard gitStatus.code == 0 else {
        throw TaskError("Failed to check for changes", gitStatus)
    }
    
    guard !gitStatus.stdout.isEmpty else {
        print("No changes, exiting...")
        return
    }
    
    let addResult = try Task.run(["git", "add", "."], pwd: repoPath)
    guard addResult.code == 0 else {
        throw TaskError("Failed to git add all changes", addResult)
    }
    
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "'on' yyyy-MM-dd 'at' HH:mm"
    let commitMessage = "Updated data \(dateFormatter.string(from: Date()))"
    
    let commitResult = try Task.run(["git", "commit", "-am", "\(commitMessage)"], pwd: repoPath)
    guard commitResult.code == 0 else {
        throw TaskError("Failed to commit changes", commitResult)
    }
    
    let pushResult = try Task.run(["git", "push", "origin", "master"], pwd: repoPath)
    guard pushResult.code == 0 else {
        throw TaskError("Failed to push changes", pushResult)
    }
}
