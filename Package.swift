import PackageDescription

let package = Package(
    name: "swift-package-crawler",
    targets: [
    	Target(name: "Utils"),
    	Target(name: "CrawlerLib", dependencies: [.Target(name: "Utils")]),
        Target(name: "Crawler", dependencies: [.Target(name: "CrawlerLib"), .Target(name: "Utils")]),
        Target(name: "PackageExporter", dependencies: [.Target(name: "Utils")]),
        Target(name: "Analyzer", dependencies: [.Target(name: "Utils"), .Target(name: "CrawlerLib")])
    ],
    dependencies: [
    	.Package(url: "https://github.com/VeniceX/HTTPSClient.git", majorVersion: 0, minor: 7),
    	.Package(url: "https://github.com/Zewo/XML.git", majorVersion: 0, minor: 7),
    	.Package(url: "https://github.com/czechboy0/Redbird.git", majorVersion: 0, minor: 7),
        .Package(url: "https://github.com/czechboy0/Jay.git", majorVersion: 0, minor: 8),
        .Package(url: "https://github.com/czechboy0/Tasks.git", majorVersion: 0, minor: 1)
    ]
)
