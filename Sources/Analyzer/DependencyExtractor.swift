//
//  DependencyExtractor.swift
//  swift-package-crawler
//
//  Created by Honza Dvorsky on 5/10/16.
//
//

//extracts all dependencies from all packages
//and takes all the github ones and adds them to the list
//of known packages. grow the web naturally.

struct AllUniqueDependencies: Analysis {
    
    func analyze(nextPackage: () throws -> Package?) throws {
        
        var allDependencies: Set<Dependency> = []
        while let package = try nextPackage() {
            let deps = package
                .allDependencies
                //filter out local deps
                .filter { $0.url.lowercased().isRemoteGitURL() }
            
            allDependencies.formUnion(deps)
            print("\(package.remoteName) has \(deps.count) dependencies")
        }
        
        //TODO: add the github ones to redis!
        
        print("Overall found \(allDependencies.count) dependencies:")
        Array(allDependencies)
            .sorted(isOrderedBefore: { $0.url < $1.url })
            .forEach {
            print(" -> \($0.url)")
        }
    }
}


