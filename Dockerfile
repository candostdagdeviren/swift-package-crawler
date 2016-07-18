
FROM kylef/swiftenv
RUN swiftenv install DEVELOPMENT-SNAPSHOT-2016-05-09-a

WORKDIR /package
VOLUME /package
EXPOSE 8080

# mount in local sources via:  -v $(PWD):/package

CMD swift build && .build/debug/PackageSearcher && .build/debug/PackageCrawler && .build/debug/PackageExporter && .build/debug/Analyzer && .build/debug/DataUpdater && .build/debug/StatisticsUpdater
