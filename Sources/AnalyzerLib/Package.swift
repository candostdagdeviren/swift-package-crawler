//
//  Package.swift
//  swift-package-crawler
//
//  Created by Honza Dvorsky on 5/9/16.
//
//

import Jay
import Jay_Extras
import Utils
import Redbird
import Foundation

struct Version {
    let lowerBound: String
    let upperBound: String
    
    init(json: [String: JSON]) throws {
        guard
            let lower = json["lowerBound"]?.string,
            let upper = json["upperBound"]?.string
        else { throw GenericError("Invalid version dict") }
        self.lowerBound = lower
        self.upperBound = upper
    }
}

struct Dependency {
    let url: String
    let version: Version
    
    init(json: [String: JSON]) throws {
        guard
            let url = json["url"]?.string,
            let versionDict = json["version"]?.dictionary
            else { throw GenericError("Invalid dependency") }
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
    
    let originalJSON: [String: JSON]
    
    //extras
    let remoteName: String
    var allDependencies: [Dependency] { return dependencies + testDependencies }
    
    init(json: [String: JSON], remoteName: (String, String)) throws {
        self.originalJSON = json
        if let name = json["name"]?.string {
            self.name = name
        } else {
            self.name = remoteName.1
        }
        self.remoteName = "/\(remoteName.0)/\(remoteName.1)"
        guard let dependenciesArray = json["dependencies"]?.array else {
            throw GenericError("Missing dependencies array")
        }
        guard let testDependenciesArray = json["testDependencies"]?.array else {
            throw GenericError("Missing test dependencies array")
        }
        self.dependencies = try dependenciesArray
            .flatMap { $0.dictionary }
            .map { try Dependency(json: $0) }
        self.testDependencies = try testDependenciesArray
            .flatMap { $0.dictionary }
            .map { try Dependency(json: $0) }

        self.pkgConfig = json["pkgConfig"]?.string
        
        if let anyProviders = json["package.providers"]?.array {
            var provs: [[String: String]] = []
            anyProviders.forEach({ (item) in
                if let dict = item.dictionary {
                    var provider: [String: String] = [:]
                    dict.forEach({ (key, value) in
                        if let stringValue = value.string {
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

func parseJSONPackage(path: String) throws -> Package {
    
    let jsonString = try String(contentsOfFile: path)
    let remoteNameHint = remoteNameHintFromPath(path: path)
    let data = jsonString.toBytes()
    guard let json = try Jay().jsonFromData(data).dictionary else {
        throw GenericError("Expected a top-level dictionary")
    }
    let package = try Package(json: json, remoteName: remoteNameHint)
    return package
}

