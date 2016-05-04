import PackageDescription

let package = Package(
    name: "swift-package-crawler",
    dependencies: [
    	.Package(url: "https://github.com/VeniceX/HTTPSClient.git", majorVersion: 0, minor: 6)
    ]
)
