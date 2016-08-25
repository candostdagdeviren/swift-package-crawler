//
//  SwiftVersions.swift
//  swift-package-crawler
//
//  Created by Honza Dvorsky on 8/25/16.
//
//

import Redbird
import Utils

struct SwiftVersions: Analysis {
    
    let db: Redbird
    
    func analyze(packageIterator: PackageIterator) throws {
        print("Starting SwiftVersions analyzer...")
        
        var versions: [String: Int] = [:]
        var it = packageIterator.makeNew()
        while let package = try it.next() {
            let version = package.swiftVersion ?? "unknown"
            versions[version] = (versions[version] ?? 0) + 1
        }
        
        //sort keys by swift versions chronologically
        let sortedVersions = versions
            .keys.sorted(isOrderedBefore: { (a, b) -> Bool in a.lowercased() < b.lowercased() })
            .map { return ($0, versions[$0]!) }
        
        //render as markdown
        let table = makeMarkdownTable(title: "Swift versions", headers: ["Version", "# Packages"], rowCount: sortedVersions.count) { (i) -> [String] in
            let info = sortedVersions[i]
            return [info.0, String(info.1)]
        }
        try saveStat(db: db, name: "swift_versions_stat", value: table)
        
        print("Finished SwiftVersions analyzer...")
    }
}
