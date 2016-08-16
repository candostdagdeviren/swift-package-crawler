//
//  Aliases.swift
//  swift-package-crawler
//
//  Created by Honza Dvorsky on 8/16/16.
//
//

private let authorAliases: [String: String] = [
    "qutheory": "vapor"
]

/// Useful for when authors/orgs get renamed, e.g. qutheory -> vapor,
/// so that both vapor and qutheory are aliased as one author for the stats.
func resolveAuthorAlias(_ name: String) -> String {
    guard let resolved = authorAliases[name] else { return name }
    return resolved
}

extension String {
    
    /// For github name strings e.g. "/czechboy0/Jay", we need to run
    /// the author through the alias resolved
    func authorAliasResolved() -> String {
        var comps = self.components(separatedBy: "/")
        precondition(comps.count == 3)
        comps[1] = resolveAuthorAlias(comps[1])
        return comps.joined(separator: "/")
    }
}

