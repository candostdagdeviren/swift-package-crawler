//
//  main.swift
//  swift-package-crawler
//
//  Created by Honza Dvorsky on 5/9/16.
//
//

import Redbird
import Utils

var args = Process.arguments.dropFirst()

enum Flag: String {
    case noSearch = "--no-search"
}

do {
    
    var flag: Flag? = nil
    if let flagString = args.popFirst() {
        if let parsedFlag = Flag(rawValue: flagString) {
            flag = parsedFlag
        } else {
            throw Error("Unrecognized flag '\(flagString)'")
        }
    }
    
    var skipSearch = flag == Flag.noSearch
    var skipFileFetch = false
    
    print("Crawler starting")
    
    //you need to have a redis-server running at 127.0.0.1 port 6379
    let db = try Redbird()
    
    if !skipSearch {
        //fetches repo names
        try SearchResultsFetcher().crawlRepoNames(db: db)
    }
    
    if !skipFileFetch {
        //download Package.swift for each package
        try PackageFileFetcher().crawlRepoPackageFiles(db: db)
    }
    
    print("Crawler finished")
    
} catch {
    print(error)
}


