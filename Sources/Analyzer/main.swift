
import Utils
import Foundation

func getUniqueDependencies(root: String, fileNames: [String]) throws {
    
    var deps: Set<String> = []
    fileNames.forEach {
        let fileName = [root, $0].joined(separator: "/")
        let githubName = $0.replacingOccurrences(of: "-Package.swift", with: "")
        do {
            let package = try parsePackage(path: fileName)
            let d = package.allDependencies.map { $0.url }
            deps.formUnion(d)
            print("\(githubName) (\(package.name)) has \(d.count) dependencies")
        } catch {
            print("Failed to parse \($0), error \(error)")
        }
    }
    
    print("Overall found \(deps.count) dependencies:")
    Array(deps).sorted().forEach {
        print(" -> \($0)")
    }
}

do {

    let root = packagesRootPath()
    let fm = NSFileManager()
    let files = try fm.contentsOfDirectory(atPath: root)
        .filter { $0.hasSuffix("-Package.swift") }
    
    //start analyzing
    try getUniqueDependencies(root: root, fileNames: files)
    
    print("")

} catch {
    print(error)
}


