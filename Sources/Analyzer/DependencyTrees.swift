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
        
        //find most popular author's of direct dependencies
        directDependencyAuthorTopChart(directDeps)

        //find most popular author's of transitive dependencies
        transitiveDependencyAuthorTopChart(directDeps)
        
        print("Analyzed \(directDeps.count) packages")
    }
    
    private func _transitiveDependees(_ directDeps: [String: [String]]) -> [String: Set<String>] {
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
        return transitiveDependees
    }
    
    private func dependencyCountHistogram(_ directDeps: [String: [String]]) {
        
        let counts = directDeps.map { $0.value.count }
        var histogram: [Int: Int] = [:]
        counts.forEach { (depCount) in
            histogram[depCount] = (histogram[depCount] ?? 0) + 1
        }
        
        let total = histogram.values.reduce(0, combine: +)
        let keys = histogram.keys.sorted()
        printMarkdownTable(title: "Dependency histogram", headers: ["# Dependencies", "# Packages", "% of Total"], rowCount: histogram.count) {
            let key = keys[$0]
            let count = histogram[key]!
            let percent = count.percentOf(total)
            return [key.leftPad(3), count.leftPad(3), "\(percent.leftPad(5))%"]
        }
    }
    
    private func transitiveDependenciesTopChart(_ directDeps: [String: [String]]) {
        
        let transitiveDependees = _transitiveDependees(directDeps)
        let topCharts = transitiveDependees
            .map { (key, value) -> (String, Int) in
                return (key, value.count)
            }.sorted(isOrderedBefore: { $0.0.1 > $0.1.1 })
        
        let count = 10
        printMarkdownTable(title: "Top \(count) most popular transitive dependencies", headers: ["Rank", "# Dependees", "Name"], rowCount: count) {
            let item = topCharts[$0]
            return [($0+1).leftPad(3)+".", item.1.leftPad(3), item.0.markdownGithubRepoLink()]
        }
    }
    
    private func directDependencyAuthorTopChart(_ directDeps: [String: [String]]) {
        let directDependees = _dependees(directDependencies: directDeps)
        let topCharts = getAuthorTopChartFromDependees(directDependees)
        let count = 10
        printMarkdownTable(title: "Top \(count) most popular authors of direct dependencies", headers: ["Rank", "# Dependees", "Author"], rowCount: count) {
            let item = topCharts[$0]
            return [($0+1).leftPad(3)+".", item.1.leftPad(3), item.0.markdownGithubUserLink()]
        }
    }
    
    private func transitiveDependencyAuthorTopChart(_ directDeps: [String: [String]]) {
        let transitiveDependees = _transitiveDependees(directDeps)
        let topCharts = getAuthorTopChartFromDependees(transitiveDependees)
        let count = 10
        printMarkdownTable(title: "Top \(count) most popular authors of transitive dependencies", headers: ["Rank", "# Dependees", "Author"], rowCount: count) {
            let item = topCharts[$0]
            return [($0+1).leftPad(3)+".", item.1.leftPad(3), item.0.markdownGithubUserLink()]
        }
    }
    
    private func getAuthorTopChartFromDependees(_ dependees: [String: Set<String>]) -> [(String, Int)] {
        var allAuthorDependees: [String: Set<String>] = [:]

        //get a mapping from an author to all their dependees
        dependees.forEach { (repo, dependees) in
            let author = repo.split(byString: "/").filter { !$0.isEmpty }.first!
            let authorDependees = allAuthorDependees[author] ?? []
            allAuthorDependees[author] = authorDependees.union(dependees)
        }
        
        //count them and sort them into a chart
        let topCharts = allAuthorDependees
            .map { (key, value) -> (String, Int) in
                return (key, value.count)
            }.sorted(isOrderedBefore: { $0.0.1 > $0.1.1 })
        return topCharts
    }
    
    private func directDependenciesTopChart(_ directDeps: [String: [String]]) {
        
        let dependees = _dependees(directDependencies: directDeps)
        let topCharts = dependees
            .map { (key, value) -> (String, Int) in
                return (key, value.count)
            }.sorted(isOrderedBefore: { $0.0.1 > $0.1.1 })
        
        let count = 10
        printMarkdownTable(title: "Top \(count) most popular direct dependencies", headers: ["Rank", "# Dependees", "Name"], rowCount: count) {
            let item = topCharts[$0]
            return [($0+1).leftPad(3)+".", item.1.leftPad(3), item.0.markdownGithubRepoLink()]
        }
    }
    
    //MARK: Utils
    
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
    
    private func printMarkdownTable(title: String, headers: [String], rowCount: Int, row: (i: Int) -> [String]) {
        print("---------------------------------")
        print("")
        print(title)
        let columnCount = headers.count
        let head = ([""] + headers.map { " \($0) " } + [""]).joined(separator: "|")
        print(head)
        let headLine = ([""] + headers.map { _ in " --- " } + [""]).joined(separator: "|")
        print(headLine)
        for i in 0...rowCount-1 {
            let rowData = row(i: i)
            assert(columnCount == rowData.count, "Number of headers and row columns must match")
            let line = ([""] + rowData.map { " \($0) " } + [""]).joined(separator: "|")
            print(line)
        }
        print("")
        print("---------------------------------")
    }
}

