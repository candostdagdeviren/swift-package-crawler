
import HTTPSClient
import XML
import Redbird
import Jay

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


