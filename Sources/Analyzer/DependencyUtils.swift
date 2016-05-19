//
//  DependencyUtils.swift
//  swift-package-crawler
//
//  Created by Honza Dvorsky on 5/19/16.
//
//

private func _prettyDependencyNames(package: Package) -> [String] {
    let deps = package
        .allDependencies
        .filter { $0.url.lowercased().isRemoteGitURL() }
        .map { $0.url.githubName() }
    return deps
}

func _directDependencies(packageIterator: PackageIterator) throws -> [String: [String]] {
    var directDeps: [String: [String]] = [:]
    var it = packageIterator
    while let package = try it.next() {
        directDeps[package.remoteName] = _prettyDependencyNames(package: package)
    }
    return directDeps
}

func _transitiveDependees(_ directDeps: [String: [String]]) -> [String: Set<String>] {
    var transitiveDependees: [String: Set<String>] = [:]
    let directDependees = _directDependees(directDependencies: directDeps)
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

func _directDependees(directDependencies: [String: [String]]) -> [String: Set<String>] {
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
