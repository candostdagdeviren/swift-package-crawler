# swift-package-crawler
(Experimental) Crawls GitHub for Swift repos with Package.swift files

# Running

- Run SwiftPM's `swift build`
- Start a Redis server with the default config `redis-server` (install with `brew install redis`)
- Start the Crawler to find the packages & pull the Package.swift files (takes a few minutes)
- `.build/debug/Crawler`
- Export the Package.swift files into `./Cache/PackageSwiftFiles` and `./Cache/PackageJSONFiles`
- `.build/debug/PackageExporter`
- Run analysis of results
- `.build/debug/Analysis`

- more to come

:alien: Author
------
Honza Dvorsky - http://honzadvorsky.com, [@czechboy0](http://twitter.com/czechboy0)
