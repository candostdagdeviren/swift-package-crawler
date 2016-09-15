//
//  AllUniqueDependencies.swift
//  swift-package-crawler
//
//  Created by Honza Dvorsky on 5/10/16.
//
//

//extracts all dependencies from all packages
//and takes all the github ones and adds them to the list
//of known packages. grow the web naturally.

import PackageSearcherLib
import Redbird

struct AllUniqueDependencies: Analysis {
    
    let db: Redbird

    func analyze(packageIterator: PackageIterator) throws {
        
        print("Starting AllUniqueDependencies analyzer...")
        
        var allDependencies: Set<Dependency> = []
        var it = packageIterator
        while let package = try it.next() {
            let deps = package
                .allDependencies
                //filter out local deps
                .filter { $0.url.lowercased().isRemoteGitURL() }
            
            allDependencies.formUnion(deps)
        }
        
        //add the github ones to redis!
        //TODO: handle case insensitivity
        let dependencyGitHubUrls = allDependencies
            .map { $0.url }
            .filter { $0.hasPrefix("https://github.com/") }
            .flatMap { $0.githubName() }
        let counts = try GoogleSearcher().insertIntoDb(db: db, newlyFetched: Array(dependencyGitHubUrls))
        print("Added \(counts.added) new dependencies to our list")
        print("Overall found \(allDependencies.count) dependencies:")
    }
}


