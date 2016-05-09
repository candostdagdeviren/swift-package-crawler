//
//  main.swift
//  swift-package-crawler
//
//  Created by Honza Dvorsky on 5/9/16.
//
//

import Redbird

do {
    
    print("Crawler starting")
    
    //you need to have a redis-server running at 127.0.0.1 port 6379
    let db = try Redbird()
    
    //fetches repo names
    try SearchResultsFetcher().crawlRepoNames(db: db)
    
    //download Package.swift for each package
    try PackageFileFetcher().crawlRepoPackageFiles(db: db)
    
    print("Crawler finished")
    
} catch {
    print(error)
}


