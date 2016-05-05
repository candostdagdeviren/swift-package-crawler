
import HTTPSClient
import XML
import Redbird
import Jay

struct Error: ErrorProtocol {
    let description: String
    init(_ description: String) {
        self.description = description
    }
}

enum CrawlError: ErrorProtocol {
    case got404 //that's the end, finish this crawling session
    case got429 //too many requests, back off
}

func makePath(query: String, page: Int) -> String {
    let path = "/search?l=swift&o=desc&p=\(page)&q=\(query)&ref=searchresults&s=indexed&type=Code&utf8=true"
    return path
}

func fetchPage(client: Client, query: String, page: Int) throws -> [String] {
    
    let path = makePath(query: query, page: page)
    print("Fetching page \(page)", terminator: " ... ")
    let headers: Headers = [
          "User-Agent":"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_11_5) AppleWebKit/602.1.29 (KHTML, like Gecko) Version/9.1.1 Safari/601.6.17",
          "Referer":"https://github.com/search?l=swift&q=Package.swift+language%3ASwift+in%3Apath+path%3A%2F&ref=searchresults&type=Code&utf8=%E2%9C%93",
          "Accept":"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
    ]
    
    var response = try client.get(path, headers: headers)
    let status = response.status.statusCode
    print(status)
    switch status {
    case 200: break
    case 429: throw CrawlError.got429
    case 404: throw CrawlError.got404
    default: throw Error("\(response.status)")
    }
    
    let data = try response.body.becomeBuffer()
    guard let doc = XMLDocument(htmlData: data) else { throw Error("Incorrect") }
    
    func classSelector(_ className: String) -> String {
        return "//*[contains(concat(' ', @class, ' '), ' \(className) ')]"
    }
    
    guard let list = doc.xPath(classSelector("code-list-item")) else { throw Error("Incorrect") }
    let repos = list.flatMap { (el: XMLNode) -> String? in
        guard let titleDiv = el.xPath("./*[contains(concat(' ', @class, ' '), ' title ')]").first else { return nil }
        guard let name = titleDiv.xPath("a").first?.attributes["href"] else { return nil }
        return name
    }
    return repos
}


var _githubAPIClient: Client?
func githubAPIClient() throws -> Client {
    if let cl = _githubAPIClient {
        return cl
    }
    let uri = URI(scheme: "https", host: "api.github.com", port: 443)
    let client = try Client(uri: uri)
    _githubAPIClient = client
    return client
}

func getDefaultBranch(repoName: String) throws -> String {
    
    let path = "/repos\(repoName)"
    let client = try githubAPIClient()
    var response = try client.get(path)
    
    switch response.status.statusCode {
    case 200:
        //parse response
        let bytes = try response.body.becomeBuffer().bytes
        if
            let dict = try Jay().jsonFromData(bytes) as? [String: Any],
            let branch = dict["default_branch"] as? String
        {
            return branch
        }
    default: break
    }
    throw Error(String(response.status))
}

enum FetchPackageResult {
    case FileContents(contents: String, etag: String)
    case Unchanched
}

func _fetchPackageFile(client: Client, name: String, etag: String, branch: String) throws -> FetchPackageResult {
    
    //https://raw.githubusercontent.com/czechboy0/Jay/master/Package.swift
    let path = "\(name)/\(branch)/Package.swift"
    
    //attach etag and handle 304 properly
    let headers: Headers = ["If-None-Match": Header(etag)]
    var response = try client.get(path, headers: headers)
    
    switch response.status.statusCode {
    case 304: //not changed
        return .Unchanched
    case 200:
        let contents = String(try response.body.becomeBuffer())
        let etag = response.headers["ETag"].values.first ?? ""
        return FetchPackageResult.FileContents(contents: contents, etag: etag)
    case 404:
        throw CrawlError.got404
    default:
        throw Error(String(response.status))
    }
}

func fetchPackageFile(client: Client, name: String, etag: String) throws -> FetchPackageResult {
    
    do {
        return try _fetchPackageFile(client: client, name: name, etag: etag, branch: "master")
    } catch CrawlError.got404 {
        //maybe default branch has a different name
        let defaultBranch = try getDefaultBranch(repoName: name)
        return try _fetchPackageFile(client: client, name: name, etag: etag, branch: defaultBranch)
    }
}

func insertIntoDb(db: Redbird, newlyFetched: [String]) throws -> (added: Int, total: Int) {
    
    let setName = "github_names"
    let params = [setName] + newlyFetched
    let resp = try db
        .pipeline()
        .enqueue("SADD", params: params)
        .enqueue("SCARD", params: [setName])
        .execute()
    let added = try resp[0].toInt()
    let total = try resp[1].toInt()
    return (added, total)
}

//crawl github for repositories which have a Package.swift at their root
//and are written in swift
func crawlRepoNames(db: Redbird) throws {
    
    let uri = URI(scheme: "https", host: "github.com", port: 443)
    let client = try Client(uri: uri)
    let query = "Package.swift+language%3ASwift+in%3Apath+path%3A%2F"
    
    var page = 1
    let max = Int.max
    var repos: Set<String> = []
    while page <= max {
        
        do {
            let fetched = try fetchPage(client: client, query: query, page: page)
            let counts = try insertIntoDb(db: db, newlyFetched: fetched)
            print("New added: \(counts.added), Total Count: \(counts.total)")
            repos.unionInPlace(fetched)
            page += 1
            sleep(1)
        } catch CrawlError.got429 {
            let sleepDuration: UInt32 = 20
            print("Stopping for \(sleepDuration) seconds")
            sleep(sleepDuration)
            print("Continuing")
            continue
        } catch CrawlError.got404 {
            print("Finished")
            break
        }
    }
    
    let sorted = Array(repos).sorted()
    print("Fetched \(sorted.count) repos")
//    sorted.forEach { print(" -> " + $0) }
}

//pulls repo names from db and fetches the package.swift
//for each. uses ETags to not re-fetch unchanged files.
func crawlRepoPackageFiles(db: Redbird) throws {
    
    let uri = URI(scheme: "https", host: "raw.githubusercontent.com", port: 443)
    let client = try Client(uri: uri)
    
    try scanNames(db: db) { (names) in
        
        var toAdd: [(name: String, etag: String, data: String)] = []
        try names.forEach({ (name) in
            
            var etag: String? = nil
            if let existing = try db.command("GET", params: ["package::\(name)"]).toMaybeString() {
                let comps = existing.split(byString: "::")
                if comps.count == 2 {
                    //we already have a cached version, attach the etag
                    etag = comps[0]
                }
            }
            
            do {
                let result = try fetchPackageFile(client: client, name: name, etag: etag ?? "")
                switch result {
                case .FileContents(let contents, let etag):
                    toAdd.append((name, etag, contents))
                case .Unchanched: break //nothing to do
                }
            } catch {
                print("\(name) -> \(error)")
            }
        })
        
        print("Verified \(names.count - toAdd.count) cached files")

        //add all the new data to db
        if !toAdd.isEmpty {
            let p = db.pipeline()
            try toAdd.forEach {
                try p.enqueue("SET", params: ["package::\($0.name)", "\($0.etag)::\($0.data)"])
            }
            try p.execute()
            print("Fetched package files from:")
            toAdd.forEach { print(" -> \($0.name)") }
        }
    }
}

//calls block with a small number of names at a time, to not have to
//load all the names into memory at once
func scanNames(db: Redbird, block: (names: [String]) throws -> ()) throws {
    
    func pull(it: Int) throws -> (Int, [String]?) {
        let resp = try db.command("SSCAN", params: ["github_names", String(it)]).toArray()
        let nextCursor = Int(try resp[0].toString()) ?? 0
        let arr = try resp[1].toArray().map { try $0.toString() }
        return (nextCursor, arr)
    }
    
    var cursor = 0
    repeat {
        
        let (c, arr) = try pull(it: cursor)
        cursor = c
        if let arr = arr {
            try block(names: arr)
        }
    } while cursor > 0
}

do {
    
    //you need to have a redis-server running at 127.0.0.1 port 6379
    let db = try Redbird()
    
    //fetches repo names
    try crawlRepoNames(db: db)
    
    //download Package.swift for each package
    try crawlRepoPackageFiles(db: db)
    
    //TODO: analyze?
    
} catch {
    print(error)
}


