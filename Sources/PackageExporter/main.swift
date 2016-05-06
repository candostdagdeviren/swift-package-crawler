
import Redbird
import Foundation
import Utils

func filePath(name: String) -> String {
    let fixedName = name.components(separatedBy: "/").filter { !$0.isEmpty }.joined(separator: "_")
    let comps = #file.components(separatedBy: "/").dropLast(3) + ["Cache", "PackageFiles", "\(fixedName)-Package.swift"]
    let path = comps.joined(separator: "/")
    return path
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
    
    //create path
    let path = filePath(name: name)
    
    //save to path
    try package.write(toFile: path, atomically: true, encoding: NSUTF8StringEncoding)
    print("Saved \(name)")
}

func scanPackages(db: Redbird, block: (keys: [String]) throws -> ()) throws {
    
    var cursor = 0
    let maxScans = Int.max
    var scanCount = 0
    while scanCount <= maxScans {
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
        if cursor == 0 {
            break
        }
    }
}

do {
    
    let db = try Redbird()
    var total = 0
    try scanPackages(db: db, block: { (keys) in
        
        try keys.forEach {
            try exportPackage(db: db, name: $0)
        }
        print("Exported \(keys.count) packages")
        total += keys.count
    })

    print("Finished exporting \(total) packages")
    
} catch {
    print(error)
}


