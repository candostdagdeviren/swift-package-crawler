//
//  Utils.swift
//  swift-package-crawler
//
//  Created by Honza Dvorsky on 5/9/16.
//
//

import Foundation
import Redbird

public struct Error: ErrorProtocol {
    let description: String
    public init(_ description: String) {
        self.description = description
    }
}

extension String {
    func mkdir() throws {
        try NSFileManager().createDirectory(atPath: self, withIntermediateDirectories: true, attributes: nil)
    }
    
    public func rm() throws {
        try NSFileManager().removeItem(atPath: self)
    }
    
    public func ls() throws -> [String] {
        return try NSFileManager().contentsOfDirectory(atPath: self)
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
}

public func deletePackage(db: Redbird, name: String) throws {
    try db.command("DEL", params: ["package::\(name)"])
    try db.command("SREM", params: ["github_names", "\(name)"])
}
