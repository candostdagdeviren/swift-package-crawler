//
//  Analysis.swift
//  swift-package-crawler
//
//  Created by Honza Dvorsky on 5/10/16.
//
//

import Utils
import Redbird

protocol Analysis {
    func analyze(nextPackage: () throws -> Package?) throws
}

func analyzeAllPackages() throws {
    let root = try packagesJSONPath()
    let files = try root
        .ls()
        .filter { $0.hasSuffix("-Package.json") }
        .map { root.addPathComponents($0) }
    let db = try Redbird()
    
    let analyses: [Analysis] =
        [
            AllUniqueDependencies(db: db)
            ]
    
    try analyses.forEach { (analysis) in
        var iterator = files.makeIterator()
        try analysis.analyze(nextPackage: { () throws -> Package? in
            guard let fileName = iterator.next() else { return nil }
            let package = try parseJSONPackage(path: fileName)
            return package
        })
    }
    
}
