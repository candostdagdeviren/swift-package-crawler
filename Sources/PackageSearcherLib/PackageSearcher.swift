//
//  PackageSearcher.swift
//  swift-package-crawler
//
//  Created by Honza Dvorsky on 5/9/16.
//
//

import XML
import HTTPSClient
import Redbird
import Utils
import Foundation

public struct PackageSearcher {
    
    public init() { }
    
    private func makePath(query: String, page: Int) -> String {
        let path = "/search?l=swift&o=desc&p=\(page)&q=\(query)&ref=searchresults&s=indexed&type=Code&utf8=true"
        return path
    }

    private func fetchPage(client: Client, query: String, page: Int) throws -> [String] {
        
        let path = makePath(query: query, page: page)
        print("[\(NSDate())] Fetching page \(page)", terminator: " ... ")
        var headers: Headers = headersWithGzip()
        headers["User-Agent"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_11_5) AppleWebKit/602.1.29 (KHTML, like Gecko) Version/9.1.1 Safari/601.6.17"
        headers["Referer"] = "https://github.com/search?l=swift&q=Package.swift+language%3ASwift+in%3Apath+path%3A%2F&ref=searchresults&type=Code&utf8=%E2%9C%93"
        headers["Accept"] = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
        
        func _fetch() throws -> Response {
            do {
                let response = try client.get(path, headers: headers)
                return response
            } catch {
                //one retry
                let response = try client.get(path, headers: headers)
                return response
            }
        }
        
        var response = try _fetch()
        let status = response.status.statusCode
        print(status, terminator: " -> ")
        switch status {
        case 200: break
        case 429: throw CrawlError.got429
        case 404: throw CrawlError.got404
        default: throw Error("\(response.status)")
        }
        
        let data = try decodeResponseData(response: response)
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

    public func insertIntoDb(db: Redbird, newlyFetched: [String]) throws -> (added: Int, total: Int) {
        
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
    public func crawlRepoNames(db: Redbird) throws {
        
        let uri = URI(scheme: "https", host: "github.com", port: 443)
        let config = ClientConfiguration(connectionTimeout: 30.seconds, keepAlive: true)
        let client = try Client(uri: uri, configuration: config)
        let query = "Package.swift+language%3ASwift+in%3Apath+path%3A%2F"
        
        var page = 1
        let max = Int.max
        var repos: Set<String> = []
        var noNewResultsPages = 0
        let noNewResultThreshold = 200
        while page <= max {
            
            if noNewResultsPages >= noNewResultThreshold {
                //stop searching, we're probably up to date
                print("Stopping, no new results in the last \(noNewResultThreshold) pages")
                break
            }
            
            do {
                func _fetch() throws {
                    let fetched = try fetchPage(client: client, query: query, page: page)
                    if !fetched.isEmpty {
                        let counts = try insertIntoDb(db: db, newlyFetched: fetched)
                        print("New added: \(counts.added), Total Count: \(counts.total)")
                        repos = repos.union(fetched)
                        if counts.added > 0 {
                            noNewResultsPages = 0
                        } else {
                            noNewResultsPages += 1
                        }
                    }
                    page += 1
                    // sleep(1)
                }
                do {
                    try _fetch()
                } catch SystemError.operationTimedOut {
                    print("Timed out, retrying")
                    try _fetch()
                }
            } catch CrawlError.got429 {
                let sleepDuration: UInt32 = 10
                print("Stopping for \(sleepDuration) seconds")
                sleep(sleepDuration)
                print("Continuing")
                continue
            } catch CrawlError.got404 {
                print("End of search results, finishing")
                break
            }
        }
        
        let sorted = Array(repos).sorted()
        print("Fetched \(sorted.count) repos")
    }
}


