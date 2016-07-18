
redis:
	redis-server ./Redis/redis.conf

build:
	swift build

recrawl: build
	.build/debug/PackageSearcher
	.build/debug/PackageCrawler
	.build/debug/PackageExporter
	.build/debug/Analyzer

update:
	.build/debug/DataUpdater
	.build/debug/StatisticsUpdater

full: build recrawl update
	@echo "Finished"

