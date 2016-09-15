# swift-package-crawler
(Experimental) Crawls GitHub for Swift repos with Package.swift files

Generates [swiftpm-packages-statistics](https://github.com/czechboy0/swiftpm-packages-statistics) and [swift-package-crawler-data](https://github.com/czechboy0/swift-package-crawler-data).

# Running

- clone this repo with `git clone URL --recursive`, to ensure submodules are properly checked out as well
- install Googler (CLI tool to search Google) with `brew install googler`
- Run SwiftPM's `swift build`
- Start a Redis server with the default config `redis-server` (install with `brew install redis`)
- Start the Crawler to find the packages & pull the Package.swift files (takes a few minutes)
- `.build/debug/PackageSearcher && .build/debug/PackageCrawler`
- Export the Package.swift files into `./Cache/PackageSwiftFiles` and `./Cache/PackageJSONFiles`
- `.build/debug/PackageExporter`
- Run analysis of results with `.build/debug/Analyzer`

To run the whole pipeline, run `.build/debug/PackageSearcher && .build/debug/PackageCrawler && .build/debug/PackageExporter && .build/debug/Analyzer`, or also `make full`, which also updates the statistics etc.

:alien: Author
------
Honza Dvorsky - http://honzadvorsky.com, [@czechboy0](http://twitter.com/czechboy0)
