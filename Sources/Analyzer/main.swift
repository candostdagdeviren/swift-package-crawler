
import Utils
import Foundation

func getUniqueDependencies(root: String, fileNames: [String]) throws {
    
    fileNames.forEach {
        let fileName = [root, $0].joined(separator: "/")
        do {
            let package = try parsePackage(path: fileName)
            print(package.name)
        } catch {
            print("Failed to parse \($0), error \(error)")
        }
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


