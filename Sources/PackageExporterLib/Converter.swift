//
//  Converter.swift
//  swift-package-crawler
//
//  Created by Honza Dvorsky on 5/9/16.
//
//

import Tasks
import Jay
import Utils
import Foundation
import Redbird

enum ExportError: ErrorProtocol {
    case PackageSwiftFailedToParse(packagePath: String, stderr: String)
}

func convertPackageToJSON(name: String) throws {
    
    let packagePath = try packageSwiftPath(name: name)
    let jsonPath = try packageJSONPath(name: name)
    let swiftPath = "/Library/Developer/Toolchains/swift-DEVELOPMENT-SNAPSHOT-2016-06-06-a.xctoolchain/usr/bin/swift"
    let args: [String] = [
                             swiftPath,
                             "package",
                             "dump-package",
                             "--output", //TODO: change to --input once my PR gets merged
                             packagePath
    ]
    let result = try Task.run(args)
    guard result.code == 0 else {
        throw ExportError.PackageSwiftFailedToParse(packagePath: packagePath, stderr: result.stderr)
    }
    let jsonString = result.stdout
    let data = jsonString.toBytes()
    guard let _ = try Jay().jsonFromData(data) as? [String: Any] else {
        throw Error("Failed to parse JSON for package \(packagePath)")
    }
    try jsonString.write(toFile: jsonPath, atomically: true, encoding: NSUTF8StringEncoding)
}

func exportPackage(db: Redbird, name: String) throws {
    
    //fetch contents from redis
    let packageName = "package::\(name)"
    guard let str = try db.command("GET", params: [packageName]).toMaybeString() else {
        throw Error("No Package.swift found for \(name)")
    }
    guard let package = str.components(separatedBy: "::").last else {
        throw Error("Unable to parse package contents for \(name)")
    }
    
    //also try to fetch swift-version from redis
    let swiftVersionName = "swift-version::\(name)"
    if let str = try db.command("GET", params: [swiftVersionName]).toMaybeString() {
        guard let swiftVersion = str.components(separatedBy: "::").last else {
            throw Error("Unable to parse swift-version contents for \(name)")
        }
        
        //write back to file
        let path = try swiftVersionPath(name: name)
        try swiftVersion.write(toFile: path, atomically: true, encoding: NSUTF8StringEncoding)
    }

    //create path
    let packagePath = try packageSwiftPath(name: name)
    
    //save to path
    try package.write(toFile: packagePath, atomically: true, encoding: NSUTF8StringEncoding)
    print("Saved \(name)")
}

func scanPackages(db: Redbird, block: (keys: [String]) throws -> ()) throws {
    
    var cursor = 0
    let maxScans = Int.max
    var scanCount = 0
    while scanCount <= maxScans {
        try autoreleasepool { _ in
            
            let arr = try db.command("SCAN", params: ["\(cursor)"]).toArray()
            guard arr.count == 2 else { throw Error("Invalid Redis response \(arr)") }
            guard
                let newCursorString = try arr[0].toMaybeString(),
                let newCursor = Int(newCursorString),
                let keysObjs = try arr[1].toMaybeArray()
                else { throw Error("Invalid Redis response \(arr)") }
            let keys = keysObjs.flatMap { try? $0.toString() }.filter { $0.hasPrefix("package::") }
            let names = keys.flatMap { $0.components(separatedBy: "::").last }
            
            //call block with keys
            try block(keys: names)
            scanCount += 1
            cursor = newCursor
        }
        if cursor == 0 {
            break
        }
    }
}

public func exportAllPackages() throws {
    
    //delete folders first
    //TODO: only re-export files if they're not already there in the right
    //revision, will probably require keeping around - in Redis - 
    //a lastModified or something received from a stat call on the file)
    try packagesSwiftPath().rm()
    try packagesJSONPath().rm()
    try swiftVersionPath().rm()
    
    let db = try Redbird()

    var processedNames: Set<String> = []
    try scanPackages(db: db, block: { (keys) in
        
        try keys.forEach {
            do {
                try exportPackage(db: db, name: $0)
                try convertPackageToJSON(name: $0)
            } catch ExportError.PackageSwiftFailedToParse(let path, let err) {
                print("Failed to parse \(path), error \(err)")
                
                //delete file
                try path.rm()
                
                //delete from redis
                try deletePackage(db: db, name: $0)
            }
        }
        print("Exported \(keys.count) packages")
        processedNames.formUnion(keys)
    })
    
    print("Finished exporting \(processedNames.count) packages")
}
