
import Foundation

public struct Error: ErrorProtocol {
    let description: String
    public init(_ description: String) {
        self.description = description
    }
}

public func filePath(name: String) -> String {
    let fixedName = name.components(separatedBy: "/").filter { !$0.isEmpty }.joined(separator: "_")
    let comps = #file.components(separatedBy: "/").dropLast(3) + ["Cache", "PackageFiles", "\(fixedName)-Package.swift"]
    let path = comps.joined(separator: "/")
    return path
}

public func packagesRootPath() -> String {
    let comps = #file.components(separatedBy: "/").dropLast(3) + ["Cache", "PackageFiles"]
    return comps.joined(separator: "/")
}

