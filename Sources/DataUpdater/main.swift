
import Utils
import Foundation
import Tasks


//in Cache folder, git add everything, commit with the timestamp, push to remote

do {
    print("DataUpdater starting")
    defer { print("DataUpdater finished") }
    
    let cacheRoot = try cacheRootPath()
    try ifChangesCommitAndPush(repoPath: try cacheRootPath())

} catch {
    print(error)
    exit(1)
}
