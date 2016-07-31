//
//  AdhocAnalyses.swift
//  swift-package-crawler
//
//  Created by Honza Dvorsky on 7/13/16.
//
//

import Utils
import Jay
import Foundation

struct NoNamePackagesAnalysis: Analysis {
    
    func analyze(packageIterator: PackageIterator) throws {
        
        var it = packageIterator
        var countWithName = 0
        var namelessPackages: [Package] = []
        while let package = try it.next() {
            if let _ = package.originalJSON["name"] {
                countWithName += 1
            } else {
                namelessPackages.append(package)
            }
        }
        
        let percentage = namelessPackages.count.percentOf(countWithName + namelessPackages.count)
        let list = namelessPackages.map { $0.remoteName }.sorted()
        
        let out: [String: Any] = [
                                     "percentage_of_nameless": percentage,
                                     "count_of_nameless": list.count,
                                     "names_of_nameless": list
                                 ]
        
        let path = try analysisResultPath(name: "NamelessPackages.json")
        let jsonData = try Jay(formatting: .prettified).dataFromJson(anyDictionary: out)
        try jsonData.write(to: path)
        print("Printed results to \(path)")
        print("Nameless count: \(list.count), percentage: \(percentage)%")
    }
}
