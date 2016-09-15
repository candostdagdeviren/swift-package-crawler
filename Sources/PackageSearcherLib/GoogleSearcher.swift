import Tasks
import Jay
import Redbird

public struct GoogleSearcher: Searcher {
    
    public enum Error: ErrorProtocol {
        case googlerError
        case incorrectJSON(String)
    }
    
    public init() { }
    
    func ensureInstalled() {
        guard try! Task.run("googler", "--help").code == 0 else {
            fatalError("Error: Googler not detected, please install with `brew install googler`")
        }
    }
    
    public func run(db: Redbird) throws {
        ensureInstalled()
        print("Started GoogleSearcher...")
        var index = 1
        let perPage = 100
        while true {
            do {
                let names = try searchPage(startIndex: index, perPage: perPage)
                guard !names.isEmpty else { print("No more results"); break }
                let (added, total) = try insertIntoDb(db: db, newlyFetched: names)
                print("Added \(added) new ones, total \(total) names")
            } catch {
                print(error)
                break
            }
            
            index += perPage
        }
        print("Finished GoogleSearcher...")
    }
    
    func searchPage(startIndex: Int, perPage: Int) throws -> [String] {
        //./googler -n 100 -s 300 --json --site github.com Package.swift
        let start = String(startIndex)
        let count = String(perPage)
        let args: [String] = [
                                 "googler",
                                 "-n", count,
                                 "-s", start,
                                 "-t", "d5", //indexed in the last five days
                                 "--json",
                                 "--site", "github.com",
                                 "Package.swift"
        ]
        let res = try Task.run(args)
        guard res.code == 0 else {
            throw Error.googlerError
        }
        let jsonString = res.stdout
        guard let json = try Jay().typesafeJsonFromData(jsonString.toBytes()).array else {
            throw Error.incorrectJSON(jsonString)
        }
        func parseGitHubUrl(url: String) -> String? {
            guard url.hasPrefix("https://github.com/") else { return nil }
            let comps = Array(url.components(separatedBy: "/").dropFirst(3))
            guard comps.count >= 2 else { return nil }
            return "/\(comps[0])/\(comps[1])"
        }
        let githubNames = json
            .flatMap { $0.dictionary?["url"]?.string }
            .flatMap { parseGitHubUrl(url: $0) }
        return githubNames
    }
}
