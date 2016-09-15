//
//  main.swift
//  swift-package-crawler
//
//  Created by Honza Dvorsky on 5/9/16.
//
//

import Redbird
import PackageSearcherLib
import Foundation
import Utils
import Jay

do {
    print("PackageSearcher starting")
    
    //you need to have a redis-server running at 127.0.0.1 port 6379
    let db = try Redbird()
    
    //fetch from google
    let googleSearcher = GoogleSearcher()
    try googleSearcher.run(db: db)
    
    //fetches repo names
//    let searcher = GitHubHTMLPackageSearcher()
//    try searcher.crawlRepoNames(db: db)
    
   // let jsonPath = try cacheRootPath().addPathComponents("librariesio-swift-repos.json")
   // let jsonString = try NSString(contentsOfFile: jsonPath, encoding: NSUTF8StringEncoding) as String
   // let data = jsonString.toBytes()
   // guard let jsonList = try Jay().typesafeJsonFromData(data).array else {
   //     throw Error("Failed to parse JSON for file \(jsonPath)")
   // }
   // let jsonStringList = jsonList.map { $0.string! }
   // try searcher.oneTimeInjectListOfNames(db: db, names: jsonStringList)
    
    print("PackageSearcher finished")
} catch {
    print(error)
    exit(1)
}


