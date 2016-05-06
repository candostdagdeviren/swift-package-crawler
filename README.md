# swift-package-crawler
(Experimental) Crawls GitHub for Swift repos with Package.swift files

# Running

- Run SwiftPM's `swift build`
- Start a Redis server with the default config `redis-server` (install with `brew install redis`)
- Start the Crawler to find the packages & pull the Package.swift files (takes a few minutes)
- `.build/debug/Crawler`
- Export the Package.swift files into `./Cache/PackageFiles`, first run `mkdir Cache; cd Cache; mkdir PackageFiles; cd ..`
- `.build/debug/PackageExporter`
- Look into the `./Cache/PackageFiles` folder, should contain all the Package.swift files

- more to come

:alien: Author
------
Honza Dvorsky - http://honzadvorsky.com, [@czechboy0](http://twitter.com/czechboy0)
