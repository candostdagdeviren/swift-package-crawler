
import Tasks
import Jay
import Utils
import Redbird

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

struct Package {
    let name: String
    let dependencies: [Dependency]
    let testDependencies: [Dependency]
    var allDependencies: [Dependency] { return dependencies + testDependencies }
    
    init(json: [String: Any], nameHint: String) throws {
        if let name = json["name"] as? String {
            self.name = name
        } else {
            self.name = nameHint
        }
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

func nameHintFromPath(path: String) -> String {
    let fileName = path
        .components(separatedBy: "/")
        .last!
        .replacingOccurrences(of: "-Package.swift", with: "")
    var comps = fileName.components(separatedBy: "_")
    comps.removeFirst()
    let nameHint = comps.joined(separator: "_")
    return nameHint
}

func parsePackage(path: String) throws -> Package {

    //Soon in SwiftPM: https://github.com/apple/swift-package-manager/pull/333
    let args: [String] = [
                             "/Users/honzadvorsky/Documents/swift-repos/swiftpm/.build/debug/swift-build",
                             "--dump-package",
                             path
                         ]
    let result = try Task.run(args)
    guard result.code == 0 else { throw Error("Failed to parse package \(path), error \(result.stderr)") }
    let data = result.stdout.toBytes()
    guard let json = try Jay().jsonFromData(data) as? [String: Any] else {
        throw Error("Failed to parse JSON for package \(path)")
    }
    let nameHint = nameHintFromPath(path: path)
    let package = try Package(json: json, nameHint: nameHint)
    return package
}

