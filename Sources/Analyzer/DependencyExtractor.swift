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

import CrawlerLib
import Redbird

struct AllUniqueDependencies: Analysis {
    
    let db: Redbird
    
    func analyze(nextPackage: () throws -> Package?) throws {
        
        print("Starting AllUniqueDependencies analyzer...")
        
        var allDependencies: Set<Dependency> = []
        while let package = try nextPackage() {
            let deps = package
                .allDependencies
                //filter out local deps
                .filter { $0.url.lowercased().isRemoteGitURL() }
            
            allDependencies.formUnion(deps)
//            print("\(package.remoteName) has \(deps.count) dependencies")
        }
        
        //add the github ones to redis!
        //TODO: handle case insensitivity
        let dependencyGitHubUrls = allDependencies
            .map { $0.url }
            .filter { $0.hasPrefix("https://github.com/") }
            .map { (url) -> String in
                let start = url.range(of: "https://github.com")?.upperBound ?? url.startIndex
                let end = url.range(of: ".git")?.lowerBound ?? url.endIndex
                return String(url.characters[start..<end])
        }
        let counts = try SearchResultsFetcher().insertIntoDb(db: db, newlyFetched: Array(dependencyGitHubUrls))
        print("Added \(counts.added) new dependencies to our list")
        
        print("Overall found \(allDependencies.count) dependencies:")
//        Array(allDependencies)
//            .sorted(isOrderedBefore: { $0.url < $1.url })
//            .forEach {
//            print(" -> \($0.url)")
//        }
    }
}


