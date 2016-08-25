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
    func analyze(packageIterator: PackageIterator) throws
}

struct PackageIterator {
    
    private let files: [String]
    private var iterator: IndexingIterator<[String]>
    
    init(files: [String]) {
        self.files = files
        self.iterator = self.files.makeIterator()
    }

    typealias Element = Package
    
    mutating func next() throws -> Package? {
        guard let fileName = iterator.next() else { return nil }
        do {
            let package = try parseJSONPackage(path: fileName)
            return package
        } catch {
//            print(error)
            return try next()
        }
    }
    
    func makeNew() -> PackageIterator {
        return PackageIterator(files: files)
    }
}

public func analyzeAllPackages() throws {
    let root = try packagesJSONPath()
    let files = try root
        .ls()
        .filter { $0.hasSuffix("-Package.json") }
        .map { root.addPathComponents($0) }
    let db = try Redbird()
    
    let analyses: [Analysis] =
        [
            SwiftVersions(db: db),
            NoNamePackagesAnalysis(),
            AllUniqueDependencies(db: db),
            DependencyTrees(db: db),
            PkgConfigAnalysis(),
            PkgConfigDependeesAnalysis()
        ]
    
    let iterator = PackageIterator(files: files)
    try analyses.forEach { (analysis) in
        try analysis.analyze(packageIterator: iterator)
    }
}
