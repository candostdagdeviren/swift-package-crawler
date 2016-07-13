//
//  PkgConfigDependeesAnalysis.swift
//  swift-package-crawler
//
//  Created by Honza Dvorsky on 5/19/16.
//
//

import Jay
import Foundation
import Utils

struct PkgConfigDependeesAnalysis: Analysis {
    
    func analyze(packageIterator: PackageIterator) throws {
        
        print("Starting PkgConfigDependeesAnalysis analyzer...")
        
        try pkgConfigDependencyAnalysis(packageIterator: packageIterator)
    }
    
    private func getWithPkgConfig(packageIterator: PackageIterator) throws -> [Package] {
        var withPkgConfig: [Package] = []
        var it = packageIterator
        while let package = try it.next() {
            if let _ = package.pkgConfig {
                withPkgConfig.append(package)
            }
        }
        return withPkgConfig
    }
    
    func pkgConfigDependencyAnalysis(packageIterator: PackageIterator) throws {
        
        let withPkgConfig = try getWithPkgConfig(packageIterator: packageIterator)
        
        //first just print names of the packages that have a pkgConfig key
        let sortedNames = withPkgConfig.map { $0.remoteName.lowercased() }.sorted()
        
        //get direct and transitive dependees
        let directDependencies = try _directDependencies(packageIterator: packageIterator)
        let directDependees = _directDependees(directDependencies: directDependencies)
        let transitiveDependees = _transitiveDependees(directDependencies)
        
        let results = sortedNames.map { (name: String) -> [String: Any] in
            let dirDeps = Array(directDependees[name] ?? [])
            let tranDeps = Array(transitiveDependees[name] ?? [])
            return [
                       "name": name,
                       "direct_dependees": dirDeps,
                       "transitive_dependees": tranDeps
            ]
        }
        
        let path = try analysisResultPath(name: "PkgConfigDependees.json")
        let jsonData = try Jay(formatting: .prettified).dataFromJson(results)
        let jsonString = try jsonData.string()
        try jsonString.write(toFile: path, atomically: true, encoding: NSUTF8StringEncoding)
        print("Printed results to \(path)")
    }
}


