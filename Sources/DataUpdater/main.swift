
import Utils
import Foundation
import Tasks

struct Error: ErrorProtocol, CustomStringConvertible {
    
    let taskResult: TaskResult
    let comment: String
    init(_ comment: String, _ taskResult: TaskResult) {
        self.taskResult = taskResult
        self.comment = comment
    }
    
    var description: String {
        return "Error: \(comment): \(taskResult)"
    }
}

//in Cache folder, git add everything, commit with the timestamp, push to remote

do {
    print("DataUpdater starting")
    defer { print("DataUpdater finished") }
    
    let cacheRoot = try cacheRootPath()
    let gitStatus = try Task.run(["git", "status", "--porcelain"], pwd: cacheRoot)
    guard gitStatus.code == 0 else {
        throw Error("Failed to check for changes in the Cache folder", gitStatus)
    }
    
    guard !gitStatus.stdout.isEmpty else {
        print("No changes in Cache folder, exiting...")
        exit(0)
    }
    
    let addResult = try Task.run(["git", "add", "."], pwd: cacheRoot)
    guard addResult.code == 0 else {
        throw Error("Failed to git add all changes", addResult)
    }
    
    let dateFormatter = NSDateFormatter()
    dateFormatter.dateFormat = "'on' yyyy-MM-dd 'at' HH:mm"
    let commitMessage = "Updated data \(dateFormatter.string(from: NSDate()))"
    
    let commitResult = try Task.run(["git", "commit", "-am", "\(commitMessage)"], pwd: cacheRoot)
    guard commitResult.code == 0 else {
        throw Error("Failed to commit changes", commitResult)
    }

    let pushResult = try Task.run(["git", "push", "origin", "master"], pwd: cacheRoot)
    guard pushResult.code == 0 else {
        throw Error("Failed to push changes", pushResult)
    }

} catch {
    print(error)
    exit(1)
}
