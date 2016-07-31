
import Utils
import Redbird
import Foundation
import Templater

func updateStats(db: Redbird) throws {
    
    let templatePath = #file.parentDirectory().addPathComponents("StatTemplate.md")
    let template = try String(contentsOfFile: templatePath)
    
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    let date = dateFormatter.string(from: Date())
    
    let monthFormatter = DateFormatter()
    monthFormatter.dateFormat = "MMMM yyyy"
    let growthMonth = monthFormatter.string(from: Date())
    
    let number_of_dependencies_histogram_stat = try readStat(db: db, name: "number_of_dependencies_histogram_stat")
    let most_popular_direct_dependencies_stat = try readStat(db: db, name: "most_popular_direct_dependencies_stat")
    let most_popular_transitive_dependencies_stat = try readStat(db: db, name: "most_popular_transitive_dependencies_stat")
    let most_popular_authors_direct_dependencies_stat = try readStat(db: db, name: "most_popular_authors_direct_dependencies_stat")
    let most_popular_authors_transitive_dependencies_stat = try readStat(db: db, name: "most_popular_authors_transitive_dependencies_stat")
    
    let packageCount = try readStat(db: db, name: "package_count")

    let context = [
                      "last_updated_date": date,
                      "analyzed_package_count": packageCount,
                      "growth_rate": "30",
                      "growth_month" : growthMonth,
                      "number_of_dependencies_histogram_stat": number_of_dependencies_histogram_stat,
                      "most_popular_direct_dependencies_stat": most_popular_direct_dependencies_stat,
                      "most_popular_transitive_dependencies_stat": most_popular_transitive_dependencies_stat,
                      "most_popular_authors_direct_dependencies_stat": most_popular_authors_direct_dependencies_stat,
                      "most_popular_authors_transitive_dependencies_stat": most_popular_authors_transitive_dependencies_stat
                  ]
    let report = try Template(template).fill(with: context)
    print("Generated markdown report")
    
    let statsRoot = try cacheRootPath()
        .parentDirectory()
        .addPathComponents("swiftpm-packages-statistics")
    let reportPath = statsRoot
        .addPathComponents("README.md")
    try report.write(toFile: reportPath, atomically: true, encoding: String.Encoding.utf8)
    
    try ifChangesCommitAndPush(repoPath: statsRoot)
}

do {
    print("StatisticsUpdater starting")
    
    //you need to have a redis-server running at 127.0.0.1 port 6379
    let db = try Redbird()
    
    try updateStats(db: db)
    
    print("StatisticsUpdater finished")
} catch {
    print(error)
    exit(1)
}

