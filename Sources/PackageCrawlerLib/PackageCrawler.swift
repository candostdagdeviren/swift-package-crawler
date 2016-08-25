//
//  PackageCrawler.swift
//  swift-package-crawler
//
//  Created by Honza Dvorsky on 5/9/16.
//
//

import HTTPSClient
import Jay
import Redbird
import Utils
import POSIX
import Foundation

//FIXME: store the etags separately from the files, so that we don't
//have to load the huge files from redis just to get the etag

public class PackageCrawler {

    public init() { }

    private var _githubAPIClient: Client?
    private func githubAPIClient() throws -> Client {
        if let cl = _githubAPIClient {
            return cl
        }
        let uri = URI(scheme: "https", host: "api.github.com", port: 443)
        let config = ClientConfiguration(connectionTimeout: 30.seconds, keepAlive: true)
        let client = try Client(uri: uri, configuration: config)
        _githubAPIClient = client
        return client
    }

    private var _packageFileClient: Client?
    private func packageFileClient() throws -> Client {
        if let cl = _packageFileClient {
            return cl
        }
        let uri = URI(scheme: "https", host: "raw.githubusercontent.com", port: 443)
        let config = ClientConfiguration(connectionTimeout: 30.seconds, keepAlive: true)
        let client = try Client(uri: uri, configuration: config)
        _packageFileClient = client
        return client
    }

    private func getDefaultBranch(repoName: String) throws -> String {
        
        let path = "/repos\(repoName)"
        let client = try githubAPIClient()
        let response = try client.get(path, headers: headersWithGzip())
        
        switch response.status.statusCode {
        case 200:
            //parse response
            let bytes = try decodeResponseData(response: response).bytes
            if
                let dict = try Jay().jsonFromData(bytes) as? [String: Any],
                let branch = dict["default_branch"] as? String
            {
                return branch
            }
        case 404:
            throw CrawlError.got404
        default: break
        }
        throw Error(String(response.status))
    }

    private enum FetchFileResult {
        case FileContents(contents: String, etag: String)
        case Unchanched
    }
    
    private func _fetchFile(client: Client, file: String, name: String, etag: String, branch: String) throws -> FetchFileResult {
        
        //https://raw.githubusercontent.com/czechboy0/Jay/master/Package.swift
        //https://raw.githubusercontent.com/czechboy0/Jay/master/.swift-version
        
        let path = "\(name)/\(branch)/\(file)"
        
        //attach etag and handle 304 properly
        var headers: Headers = headersWithGzip()
        headers["If-None-Match"] = etag
        let response = try client.get(path, headers: headers)
        
        switch response.status.statusCode {
        case 304: //not changed
            return .Unchanched
        case 200:
            let contents = String(try decodeResponseData(response: response))
            let etag = response.headers["ETag"] ?? ""
            return FetchFileResult.FileContents(contents: contents, etag: etag)
        case 404:
            throw CrawlError.got404
        case 503:
            throw CrawlError.got503
        default:
            throw Error(String(response.status))
        }
    }

    private func fetchSwiftVersionFile(client: Client, name: String, etag: String) throws -> FetchFileResult {
        
        // do {
        return try _fetchFile(client: client, file: ".swift-version", name: name, etag: etag, branch: "master")
        // } catch CrawlError.got404 {
        //     //maybe default branch has a different name
        //     let defaultBranch = try getDefaultBranch(repoName: name)
        //     return try _fetchPackageFile(client: client, name: name, etag: etag, branch: defaultBranch)
        // }
    }
    
    private func fetchPackageFile(client: Client, name: String, etag: String) throws -> FetchFileResult {
        
        // do {
        return try _fetchFile(client: client, file: "Package.swift", name: name, etag: etag, branch: "master")
        // } catch CrawlError.got404 {
        //     //maybe default branch has a different name
        //     let defaultBranch = try getDefaultBranch(repoName: name)
        //     return try _fetchPackageFile(client: client, name: name, etag: etag, branch: defaultBranch)
        // }
    }

    //pulls repo names from db and fetches the package.swift
    //for each. uses ETags to not re-fetch unchanged files.
    public func crawlRepoPackageFiles(db: Redbird) throws {
        
        let client = try packageFileClient()
                
        try scanNames(db: db) { (names) in
            
            var packageFilesToAdd: [(name: String, etag: String, data: String)] = []
            var swiftVersionFilesToAdd: [(name: String, etag: String, data: String)] = []
            
            try names.forEach({ (name) in
                
                var packageFileETag: String? = nil
                var swiftVersionFileETag: String? = nil

                if let existing = try db.command("GET", params: ["package::\(name)"]).toMaybeString() {
                    let comps = existing.split(byString: "::")
                    if comps.count == 2 {
                        //we already have a cached version, attach the etag
                        packageFileETag = comps[0]
                    }
                }
                
                if let existing = try db.command("GET", params: ["swift-version::\(name)"]).toMaybeString() {
                    let comps = existing.split(byString: "::")
                    if comps.count == 2 {
                        //we already have a cached version, attach the etag
                        swiftVersionFileETag = comps[0]
                    }
                }
                
                func _fetch() throws {
                    
                    //fetch Package.swift
                    let packageFileResult = try self.fetchPackageFile(client: client, name: name, etag: packageFileETag ?? "")
                    switch packageFileResult {
                    case .FileContents(let contents, let etag):
                        packageFilesToAdd.append((name, etag, contents))
                    case .Unchanched: break //nothing to do
                    }
                    
                    //also try .swift-version, if present
                    do {
                        let swiftVersionResult = try self.fetchSwiftVersionFile(client: client, name: name, etag: swiftVersionFileETag ?? "")
                        switch swiftVersionResult {
                        case .FileContents(let contents, let etag):
                            swiftVersionFilesToAdd.append((name, etag, contents))
                        case .Unchanched: break //nothing to do
                        }
                    } catch { }
                }
                
                func _retry(error: String) {
                    print("Connection failed with error \(error), retrying")
                    //is this a TCPSSL bug or what?
                    //TODO: refactor & autoretry once but nicely (hacked below)
                    
                    do {
                        try _fetch()
                    } catch {
                        print("Error when fetching \(name): \(error)")
                    }
                }

                func _sleep(_ time: UInt32) {
                    print("Stopping for \(time) seconds")
                    sleep(time)
                    print("Continuing")
                }
                
                func _delete(error: String) throws {
                    print("Got \(error) for package \(name), removing it from our list")
                    try deletePackage(db: db, name: name)
                }
                
                do {
                    try _fetch()
                } catch CrawlError.got404 {
                    try _delete(error: "404")
                } catch C7.StreamError.closedStream {
                    _sleep(10)
                    _retry(error: "timed out")
                } catch SystemError.operationTimedOut {
                    _retry(error: "timed out")
                } catch CrawlError.got503 {
                    _retry(error: "503")
                } catch HTTPSClient.ClientError.brokenConnection {
                    _retry(error: "brokenConnection")
                } catch {
                    print("\(name) -> \(error)")
                }
            })
            
            print("[\(NSDate())] Verified \(names.count - packageFilesToAdd.count) cached files")

            //add all the new data to db
            if !packageFilesToAdd.isEmpty {
                let p = db.pipeline()
                try packageFilesToAdd.forEach {
                    try p.enqueue("SET", params: ["package::\($0.name)", "\($0.etag)::\($0.data)"])
                }
                try p.execute()
                print("Fetched package files from:")
                packageFilesToAdd.forEach { print(" -> \($0.name)") }
            }
            
            if !swiftVersionFilesToAdd.isEmpty {
                let p = db.pipeline()
                try swiftVersionFilesToAdd.forEach {
                    try p.enqueue("SET", params: ["swift-version::\($0.name)", "\($0.etag)::\($0.data)"])
                }
                try p.execute()
                print("Fetched swift-version files from:")
                swiftVersionFilesToAdd.forEach { print(" -> \($0.name)") }
            }
        }
    }

    //calls block with a small number of names at a time, to not have to
    //load all the names into memory at once
    private func scanNames(db: Redbird, block: (names: [String]) throws -> ()) throws {
        
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
}