import PackageDescription

let package = Package(
    name: "swift-package-crawler",
    dependencies: [
    	.Package(url: "https://github.com/VeniceX/HTTPSClient.git", majorVersion: 0, minor: 6),
    	.Package(url: "https://github.com/Zewo/XML.git", majorVersion: 0, minor: 6),
    	.Package(url: "https://github.com/czechboy0/Redbird.git", majorVersion: 0, minor: 7),
        .Package(url: "https://github.com/czechboy0/Jay.git", majorVersion: 0, minor: 5)
    ]
)
