//
//  PackageCrawler.swift
//  swift-package-crawler
//
//  Created by Honza Dvorsky on 5/9/16.
//
//

import Vapor
import VaporTLS
import Jay
import Jay_Extras
import Redbird
import Utils
import POSIX
import Foundation
import String

//FIXME: store the etags separately from the files, so that we don't
//have to load the huge files from redis just to get the etag

public class PackageCrawler {

    public init() { }

    private var _githubAPIClient: TLSClient?
    private func githubAPIClient() throws -> TLSClient {
        if let cl = _githubAPIClient {
            return cl
        }
//        let uri = URI(scheme: "https", host: "api.github.com", port: 443)
//        let config = ClientConfiguration(connectionTimeout: 30.seconds, keepAlive: true)
//        let client = try Client(uri: uri, configuration: config)
        let client = try TLSClient(scheme: "https", host: "api.github.com", port: 443, securityLayer: .tls)
        _githubAPIClient = client
        return client
    }

    private var _packageFileClient: TLSClient?
    private func packageFileClient() throws -> TLSClient {
        if let cl = _packageFileClient {
            return cl
        }
//        let uri = URI(scheme: "https", host: "raw.githubusercontent.com", port: 443)
//        let config = ClientConfiguration(connectionTimeout: 30.seconds, keepAlive: true)
//        let client = try Client(uri: uri, configuration: config)
        let client = try TLSClient(scheme: "https", host: "raw.githubusercontent.com", port: 443, securityLayer: .tls)
        _packageFileClient = client
        return client
    }

    private func getDefaultBranch(repoName: String) throws -> String {
        
        let path = "/repos\(repoName)"
        let client = try githubAPIClient()
        let response = try client.get(path: path, headers: headersWithGzip())
        
        switch response.status.statusCode {
        case 200:
            //parse response
            let bytes = try decodeResponseData(response: response).bytes
            let dict = try Jay().jsonFromData(bytes)
            if let branch = dict.dictionary?["default_branch"]?.string {
                return branch
            }
        case 404:
            throw CrawlError.got404
        default: break
        }
        throw GenericError(String(response.status))
    }

    private enum FetchPackageResult {
        case FileContents(contents: String, etag: String)
        case Unchanched
    }

    private func _fetchPackageFile(client: TLSClient, name: String, etag: String, branch: String) throws -> FetchPackageResult {
        
        //https://raw.githubusercontent.com/czechboy0/Jay/master/Package.swift
        let path = "\(name)/\(branch)/Package.swift"
        
        //attach etag and handle 304 properly
        var headers = headersWithGzip()
        headers["If-None-Match"] = etag
        let response = try client.get(path: path, headers: headers)
        
        switch response.status.statusCode {
        case 304: //not changed
            return .Unchanched
        case 200:
            let contents = String(try decodeResponseData(response: response))
            let etag = response.headers["ETag"] ?? ""
            return FetchPackageResult.FileContents(contents: contents, etag: etag)
        case 404:
            throw CrawlError.got404
        case 503:
            throw CrawlError.got503
        default:
            throw GenericError(String(response.status))
        }
    }

    private func fetchPackageFile(client: TLSClient, name: String, etag: String) throws -> FetchPackageResult {
        
        // do {
            return try _fetchPackageFile(client: client, name: name, etag: etag, branch: "master")
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
                
                func _fetch() throws {
                    let result = try self.fetchPackageFile(client: client, name: name, etag: etag ?? "")
                    switch result {
                    case .FileContents(let contents, let etag):
                        toAdd.append((name, etag, contents))
                    case .Unchanched: break //nothing to do
                    }
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
//                } catch C7.StreamError.closedStream {
//                    _sleep(10)
//                    _retry(error: "timed out")
                } catch SystemError.operationTimedOut {
                    _retry(error: "timed out")
                } catch CrawlError.got503 {
                    _retry(error: "503")
//                } catch HTTPSClient.ClientError.brokenConnection {
//                    _retry(error: "brokenConnection")
                } catch {
                    print("\(name) -> \(error)")
                }
            })
            
            print("[] Verified \(names.count - toAdd.count) cached files")

            //add all the new data to db
            if !toAdd.isEmpty {
                let p = db.pipeline()
                try toAdd.forEach {
                    _ = try p.enqueue("SET", params: ["package::\($0.name)", "\($0.etag)::\($0.data)"])
                }
                try p.execute()
                print("Fetched package files from:")
                toAdd.forEach { print(" -> \($0.name)") }
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
