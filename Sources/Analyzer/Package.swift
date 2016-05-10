//
//  Package.swift
//  swift-package-crawler
//
//  Created by Honza Dvorsky on 5/9/16.
//
//

import Jay
import Utils
import Redbird
import Foundation

struct Version {
    let lowerBound: String
    let upperBound: String
    
    init(json: [String: Any]) throws {
        guard
            let lower = json["lowerBound"] as? String,
            let upper = json["upperBound"] as? String
        else { throw Error("Invalid version dict") }
        self.lowerBound = lower
        self.upperBound = upper
    }
}

struct Dependency {
    let url: String
    let version: Version
    
    init(json: [String: Any]) throws {
        guard
            let url = json["url"] as? String,
            let versionDict = json["version"] as? [String: Any]
            else { throw Error("Invalid dependency") }
        self.url = url
        self.version = try Version(json: versionDict)
    }
}

extension Dependency: Hashable {
    var hashValue: Int { return url.lowercased().hashValue }
}
func ==(lhs: Dependency, rhs: Dependency) -> Bool {
    return lhs.url.lowercased() == rhs.url.lowercased()
}

struct Package {
    let name: String
    let remoteName: String
    let dependencies: [Dependency]
    let testDependencies: [Dependency]
    var allDependencies: [Dependency] { return dependencies + testDependencies }
    
    init(json: [String: Any], remoteName: (String, String)) throws {
        if let name = json["name"] as? String {
            self.name = name
        } else {
            self.name = remoteName.1
        }
        self.remoteName = "/\(remoteName.0)/\(remoteName.1)"
        guard let dependenciesArray = json["dependencies"] as? [Any] else {
            throw Error("Missing dependencies array")
        }
        guard let testDependenciesArray = json["testDependencies"] as? [Any] else {
            throw Error("Missing test dependencies array")
        }
        self.dependencies = try dependenciesArray.flatMap { $0 as? [String: Any] }.map { try Dependency(json: $0) }
        self.testDependencies = try testDependenciesArray.flatMap { $0 as? [String: Any] }.map { try Dependency(json: $0) }
    }
}

func remoteNameHintFromPath(path: String) -> (String, String) {
    let fileName = path
        .components(separatedBy: "/")
        .last!
        .replacingOccurrences(of: "-Package.json", with: "")
    var comps = fileName.components(separatedBy: "_")
    let name = comps.removeFirst()
    let repo = comps.joined(separator: "_")
    guard !name.isEmpty && !repo.isEmpty else { print("!!! Can't hint from \(path)"); return ("","") }
    return (name, repo)
}

func parseJSONPackage(path: String) throws -> Package {
    
    let jsonString = try String(contentsOfFile: path)
    let remoteNameHint = remoteNameHintFromPath(path: path)
    let data = jsonString.toBytes()
    guard let json = try Jay().jsonFromData(data) as? [String: Any] else {
        throw Error("Failed to parse JSON for package \(path)")
    }
    let package = try Package(json: json, remoteName: remoteNameHint)
    return package
}

