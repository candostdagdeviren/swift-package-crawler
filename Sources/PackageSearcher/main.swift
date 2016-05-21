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

do {
    print("PackageSearcher starting")
    
    //you need to have a redis-server running at 127.0.0.1 port 6379
    let db = try Redbird()
    
    //fetches repo names
    try PackageSearcher().crawlRepoNames(db: db)
    
    print("PackageSearcher finished")
} catch {
    print(error)
    exit(1)
}


