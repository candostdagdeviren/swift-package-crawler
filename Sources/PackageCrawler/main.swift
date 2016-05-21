//
//  main.swift
//  swift-package-crawler
//
//  Created by Honza Dvorsky on 5/9/16.
//
//

import Redbird
import PackageCrawlerLib
import Foundation

do {
    print("PackageCrawler starting")
    
    //you need to have a redis-server running at 127.0.0.1 port 6379
    let db = try Redbird()
    
    //download Package.swift for each package
    try PackageCrawler().crawlRepoPackageFiles(db: db)
    
    print("PackageCrawler finished")
} catch {
    print(error)
    exit(1)
}


