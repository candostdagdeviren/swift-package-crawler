//
//  DependencyTrees.swift
//  swift-package-crawler
//
//  Created by Honza Dvorsky on 5/10/16.
//
//

import Redbird
import Utils
import String

struct DependencyTrees: Analysis {
    
    let db: Redbird
    
    func analyze(packageIterator: PackageIterator) throws {
        
        print("Starting DependencyTrees analyzer...")
        
        let directDeps = try _directDependencies(packageIterator: packageIterator)
        
        //look at the histogram of dependencies
        let number_of_dependencies_histogram_stat = dependencyCountHistogram(directDeps)
        try saveStat(db: db, name: "number_of_dependencies_histogram_stat", value: number_of_dependencies_histogram_stat)
        
        //find most popular direct dependencies
        let most_popular_direct_dependencies_stat = directDependenciesTopChart(directDeps)
        try saveStat(db: db, name: "most_popular_direct_dependencies_stat", value: most_popular_direct_dependencies_stat)

        //find most popular indirect/transitive dependencies (reach)
        let most_popular_transitive_dependencies_stat = transitiveDependenciesTopChart(directDeps)
        try saveStat(db: db, name: "most_popular_transitive_dependencies_stat", value: most_popular_transitive_dependencies_stat)

        //find most popular author's of direct dependencies
        let most_popular_authors_direct_dependencies_stat = directDependencyAuthorTopChart(directDeps)
        try saveStat(db: db, name: "most_popular_authors_direct_dependencies_stat", value: most_popular_authors_direct_dependencies_stat)

        //find most popular author's of transitive dependencies
        let most_popular_authors_transitive_dependencies_stat = transitiveDependencyAuthorTopChart(directDeps)
        try saveStat(db: db, name: "most_popular_authors_transitive_dependencies_stat", value: most_popular_authors_transitive_dependencies_stat)

        try saveStat(db: db, name: "package_count", value: String(directDeps.count))
        
        print("Analyzed \(directDeps.count) packages")
    }
    
    private func dependencyCountHistogram(_ directDeps: [String: [String]]) -> String {
        
        let counts = directDeps.map { $0.value.count }
        var histogram: [Int: Int] = [:]
        counts.forEach { (depCount) in
            histogram[depCount] = (histogram[depCount] ?? 0) + 1
        }
        
        let total = histogram.values.reduce(0, +)
        let keys = histogram.keys.sorted()
        return makeMarkdownTable(title: "Dependency histogram", headers: ["# Dependencies", "# Packages", "% of Total"], rowCount: histogram.count) {
            let key = keys[$0]
            let count = histogram[key]!
            let percent = count.percentOf(total)
            return [key.leftPad(3), count.leftPad(3), "\(percent.leftPad(5))%"]
        }
    }
    
    private func transitiveDependenciesTopChart(_ directDeps: [String: [String]]) -> String {
        
        let transitiveDependees = _transitiveDependees(directDeps)
        let topCharts = transitiveDependees
            .map { (key, value) -> (String, Int) in
                return (key, value.count)
            }.sorted(by: { $0.0.1 > $0.1.1 })
        
        let count = 10
        return makeMarkdownTable(title: "Top \(count) most popular transitive dependencies", headers: ["Rank", "# Dependees", "Name"], rowCount: count) {
            let item = topCharts[$0]
            return [($0+1).leftPad(3)+".", item.1.leftPad(3), item.0.markdownGithubRepoLink()]
        }
    }
    
    private func directDependencyAuthorTopChart(_ directDeps: [String: [String]]) -> String {
        let directDependees = _directDependees(directDependencies: directDeps)
        let topCharts = getAuthorTopChartFromDependees(directDependees)
        let count = 10
        return makeMarkdownTable(title: "Top \(count) most popular authors of direct dependencies", headers: ["Rank", "# Dependees", "Author"], rowCount: count) {
            let item = topCharts[$0]
            return [($0+1).leftPad(3)+".", item.1.leftPad(3), item.0.markdownGithubUserLink()]
        }
    }
    
    private func transitiveDependencyAuthorTopChart(_ directDeps: [String: [String]]) -> String {
        let transitiveDependees = _transitiveDependees(directDeps)
        let topCharts = getAuthorTopChartFromDependees(transitiveDependees)
        let count = 10
        return makeMarkdownTable(title: "Top \(count) most popular authors of transitive dependencies", headers: ["Rank", "# Dependees", "Author"], rowCount: count) {
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
            }.sorted(by: { $0.0.1 > $0.1.1 })
        return topCharts
    }
    
    private func directDependenciesTopChart(_ directDeps: [String: [String]]) -> String {
        
        let dependees = _directDependees(directDependencies: directDeps)
        let topCharts = dependees
            .map { (key, value) -> (String, Int) in
                return (key, value.count)
            }.sorted(by: { $0.0.1 > $0.1.1 })
        
        let count = 10
        return makeMarkdownTable(title: "Top \(count) most popular direct dependencies", headers: ["Rank", "# Dependees", "Name"], rowCount: count) {
            let item = topCharts[$0]
            return [($0+1).leftPad(3)+".", item.1.leftPad(3), item.0.markdownGithubRepoLink()]
        }
    }
    
    //MARK: Utils
        
    private func makeMarkdownTable(title: String, headers: [String], rowCount: Int, row: (i: Int) -> [String]) -> String {
        
        var output: String = ""
        
        let columnCount = headers.count
        let head = ([""] + headers.map { " \($0) " } + [""]).joined(separator: "|")
        output.appendLine(head)
        let headLine = ([""] + headers.map { _ in " --- " } + [""]).joined(separator: "|")
        output.appendLine(headLine)
        for i in 0...rowCount-1 {
            let rowData = row(i: i)
            assert(columnCount == rowData.count, "Number of headers and row columns must match")
            let line = ([""] + rowData.map { " \($0) " } + [""]).joined(separator: "|")
            output.appendLine(line)
        }
        
        return output
    }
    
}

extension String {
    mutating func appendLine(_ line: String) {
        let ln = line.appending("\n")
        self = appending(ln)
    }
}

