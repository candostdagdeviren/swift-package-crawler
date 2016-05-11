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
        
        //find most popular direct dependencies
        directDependenciesTopChart(directDeps)
        
        //find most popular indirect/transitive dependencies (reach)
        transitiveDependenciesTopChart(directDeps)
        
        print("Analyzed \(directDeps.count) packages")
    }
    
    private func transitiveDependenciesTopChart(_ directDeps: [String: [String]]) {
        
        var transitiveDependees: [String: Set<String>] = [:]
        let directDependees = _dependees(directDependencies: directDeps)
        var stack: Set<String> = [] //for cycle detection
        
        func _calculateTransitiveDependees(name: String) -> Set<String> {
            //check the cache first
            if let deps = transitiveDependees[name] {
                return deps
            }
            
//            print("+ \(name)?")
            if stack.contains(name) {
                //cycle detected
                print("Cycle detected when re-adding \(name). Cycle between \(stack)")
                return []
            }
            stack.insert(name)
            
            //by definition, transitive dependees are
            //all direct dependees + their transitive dependees
            let direct = directDependees[name] ?? []
            let transDepsOfDeps = direct
                .map { _calculateTransitiveDependees(name: $0) }
                .reduce(Set<String>(), combine: { $0.union($1) })
            let allDependees = direct.union(transDepsOfDeps)
            transitiveDependees[name] = allDependees
            
            stack.remove(name)
//            print("- \(name) -> \(allDependees.count)")
            
            return allDependees
        }
        
        //run
        directDependees.keys.forEach { _calculateTransitiveDependees(name: $0) }
        
        let topCharts = transitiveDependees
            .map { (key, value) -> (String, Int) in
                return (key, value.count)
            }.sorted(isOrderedBefore: { $0.0.1 > $0.1.1 })
        
        let count = 10
        print("Top \(count) most popular transitive dependencies")
        
        print("| Rank | # Dependees | Name |")
        print("| --- | --- | --- |")
        for i in 0...count-1 {
            let item = topCharts[i]
            print("| \((i+1).leftPad(3)). | \(item.1.leftPad(3)) | \(item.0.markdownGithubLink()) |")
        }
    }
    
    private func dependencyCountHistogram(_ directDeps: [String: [String]]) {
        
        let counts = directDeps.map { $0.value.count }
        var histogram: [Int: Int] = [:]
        counts.forEach { (depCount) in
            histogram[depCount] = (histogram[depCount] ?? 0) + 1
        }
        
        let total = histogram.values.reduce(0, combine: +)
        
        print("Dependency histogram:")
        print("| # Dependencies | # Packages | % of Total |")
        print("| --- | --- | --- |")
        histogram.keys.sorted().forEach { (key) in
            let count = histogram[key]!
            let percent = count.percentOf(total)
            print("| \(key.leftPad(3)) | \(count.leftPad(3)) | \(percent.leftPad(5))% |")
        }
    }
    
    private func _dependees(directDependencies: [String: [String]]) -> [String: Set<String>] {
        var dependees: [String: Set<String>] = [:]
        directDependencies.forEach { (name: String, dependencies: [String]) in
            dependencies.forEach({ (dependency) in
                var d = dependees[dependency.lowercased()] ?? []
                d.insert(name.lowercased())
                dependees[dependency.lowercased()] = d
            })
        }
        return dependees
    }
    
    private func directDependenciesTopChart(_ directDeps: [String: [String]]) {
        
        let dependees = _dependees(directDependencies: directDeps)
        let topCharts = dependees
            .map { (key, value) -> (String, Int) in
                return (key, value.count)
            }.sorted(isOrderedBefore: { $0.0.1 > $0.1.1 })
        
        let count = 10
        print("Top \(count) most popular direct dependencies")
        print("| Rank | # Dependees | Name |")
        print("| --- | --- | --- |")
        for i in 0...count-1 {
            let item = topCharts[i]
            print("| \((i+1).leftPad(3)). | \(item.1.leftPad(3)) | \(item.0.markdownGithubLink()) |")
        }
    }
}

