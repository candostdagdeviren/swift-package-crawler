import PackageDescription

let package = Package(
    name: "swift-package-crawler",
    targets: [
    	Target(name: "Utils"),
        Target(name: "PackageCrawlerLib", dependencies: ["Utils"]),
        Target(name: "PackageCrawler", dependencies: ["PackageCrawlerLib"]),
        Target(name: "PackageSearcherLib", dependencies: ["Utils"]),
        Target(name: "PackageSearcher", dependencies: ["PackageSearcherLib"]),
        Target(name: "PackageExporterLib", dependencies: ["Utils"]),
        Target(name: "PackageExporter", dependencies: ["PackageExporterLib"]),
        Target(name: "AnalyzerLib", dependencies: ["Utils", "PackageSearcherLib"]),
        Target(name: "Analyzer", dependencies: ["AnalyzerLib"]),
        Target(name: "ServerLib", dependencies: ["Utils"]),
        Target(name: "Server", dependencies: ["ServerLib"]),
        Target(name: "DataUpdater", dependencies: ["Utils"]),
        Target(name: "StatisticsUpdater", dependencies: ["Utils"])
    ],
    dependencies: [

        // Parsing HTML responses of GitHub Search
    	.Package(url: "https://github.com/Zewo/XML.git", majorVersion: 0, minor: 10),

        // Connecting to Redis
    	.Package(url: "https://github.com/czechboy0/Redbird.git", majorVersion: 0, minor: 9),

        // JSON handling
        .Package(url: "https://github.com/czechboy0/Jay.git", majorVersion: 0, minor: 16),

        // Easier working with typesafe JSON
        .Package(url: "https://github.com/czechboy0/Jay-Extras.git", majorVersion: 0, minor: 16),

        // Launching SwiftPM on the CLI
        .Package(url: "https://github.com/czechboy0/Tasks.git", majorVersion: 0, minor: 3),

        // Generating markdown statistics report
        .Package(url: "https://github.com/czechboy0/Templater.git", majorVersion: 0, minor: 2),

        // Getting environment variables
        .Package(url: "https://github.com/czechboy0/Environment.git", majorVersion: 0, minor: 5),

        // Server, HTTPS client for crawling GitHub
        .Package(url: "https://github.com/qutheory/vapor.git", majorVersion: 0, minor: 15),

        // TLS for Vapor
        .Package(url: "https://github.com/qutheory/vapor-tls.git", majorVersion: 0, minor: 4),        

        // Gzip middleware
        .Package(url: "https://github.com/Zewo/gzip.git", majorVersion: 0, minor: 5)
    ]
)
