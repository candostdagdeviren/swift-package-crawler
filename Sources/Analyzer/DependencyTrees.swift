//
//  DependencyTrees.swift
//  swift-package-crawler
//
//  Created by Honza Dvorsky on 5/10/16.
//
//

struct DependencyTrees: Analysis {
        
    func analyze(nextPackage: () throws -> Package?) throws {
        
        print("Starting DependencyTrees analyzer...")
        
        var directDeps: [String: [String]] = [:]
        while let package = try nextPackage() {
            let deps = package
                .allDependencies
                .filter { $0.url.lowercased().isRemoteGitURL() }
            
            let names = deps.map { $0.url.githubName() }
            directDeps[package.remoteName] = names
        }
        
        //look at the histogram of dependencies
        dependencyCountHistogram(directDeps)
        
        print("Analyzed \(directDeps.count) packages")
    }
    
    private func dependencyCountHistogram(_ directDeps: [String: [String]]) {
        
        let counts = directDeps.map { $0.value.count }
        var histogram: [Int: Int] = [:]
        counts.forEach { (depCount) in
            histogram[depCount] = (histogram[depCount] ?? 0) + 1
        }
        
        let total = histogram.values.reduce(0, combine: +)
        
        print("Dependency histogram:")
        histogram.keys.sorted().forEach { (key) in
            let count = histogram[key]!
            let percent = Double(Int(10000 * Double(count)/Double(total)))/100
            print(" \(key) \t-> \t\(count) \t[\(percent)%]")
        }
    }
}

