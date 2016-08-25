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
        guard url.starts(with: "https://github.com") else {
            throw Error("Invalid dependency url: \(url)")
        }
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
    
    //base
    let name: String
    let dependencies: [Dependency]
    let testDependencies: [Dependency]
    let pkgConfig: String?
    let providers: [[String: String]]?
    
    let swiftVersion: String?
    
    let originalJSON: [String: Any]
    
    //extras
    let remoteName: String
    var allDependencies: [Dependency] { return dependencies + testDependencies }
    
    init(json: [String: Any], remoteName: (String, String), swiftVersion: String?) throws {
        self.originalJSON = json
        self.swiftVersion = swiftVersion
        
        if let name = json["name"] as? String {
            self.name = name
        } else {
            self.name = remoteName.1
        }
        let author = resolveAuthorAlias(remoteName.0)
        self.remoteName = "/\(author)/\(remoteName.1)"
        guard let dependenciesArray = json["dependencies"] as? [Any] else {
            throw Error("Missing dependencies array")
        }
        guard let testDependenciesArray = json["testDependencies"] as? [Any] else {
            throw Error("Missing test dependencies array")
        }
        self.dependencies = try dependenciesArray.flatMap { $0 as? [String: Any] }.map { try Dependency(json: $0) }
        self.testDependencies = try testDependenciesArray.flatMap { $0 as? [String: Any] }.map { try Dependency(json: $0) }

        self.pkgConfig = json["pkgConfig"] as? String
        
        if let anyProviders = json["package.providers"] as? [Any] {
            var provs: [[String: String]] = []
            anyProviders.forEach({ (item) in
                if let dict = item as? [String: Any] {
                    var provider: [String: String] = [:]
                    dict.forEach({ (key, value) in
                        if let stringValue = value as? String {
                            provider[key] = stringValue
                        }
                    })
                    provs.append(provider)
                }
            })
            self.providers = provs
        } else {
            self.providers = nil
        }
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

func parseSwiftVersion(name: String) throws -> String? {
    let path = try swiftVersionPath(name: name)
    do {
        var contents = try String(contentsOfFile: path).trim()
        
        //replace swift-DEVELOPMENT-SNAPSHOT with just DEVELOPMENT-SNAPSHOT
        if contents.hasPrefix("swift-") {
            contents = contents.substring(from: contents.index(contents.startIndex, offsetBy: 6))
        }
        
        //delete trailing .xctoolchain
        if contents.hasSuffix(".xctoolchain") {
            contents = contents.substring(to: contents.index(contents.endIndex, offsetBy: -12))
        }
        
        //replace prepend "3.0-" before DEVELOPMENT-SNAPSHOT
        if contents.hasPrefix("DEVELOPMENT-SNAPSHOT") {
            contents = "3.0-" + contents
        }
        
        return contents
        
    } catch {
        return nil
    }
}

func parseJSONPackage(path: String) throws -> Package {
    let jsonString = try String(contentsOfFile: path)
    let remoteNameHint = remoteNameHintFromPath(path: path)
    let data = jsonString.toBytes()
    guard let json = try Jay().jsonFromData(data) as? [String: Any] else {
        throw Error("Failed to parse JSON for package \(path)")
    }
    let swiftVersion = try parseSwiftVersion(name: "\(remoteNameHint.0)/\(remoteNameHint.1)")
    let package = try Package(json: json, remoteName: remoteNameHint, swiftVersion: swiftVersion)
    return package
}

