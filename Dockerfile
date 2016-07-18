
FROM kylef/swiftenv
RUN swiftenv install DEVELOPMENT-SNAPSHOT-2016-05-09-a

# install redis
RUN         cd /tmp && curl -O http://download.redis.io/redis-stable.tar.gz && tar xzvf redis-stable.tar.gz && cd redis-stable && make && make install

# install openssl and libxml2
RUN apt-get install -y libssl-dev
RUN apt-get install -y libxml2-dev

WORKDIR /package
VOLUME /package
EXPOSE 8080

# mount in local sources via:  -v $(PWD):/package

CMD redis-server ./Redis/redis.conf && swift build && .build/debug/PackageSearcher && .build/debug/PackageCrawler && .build/debug/PackageExporter && .build/debug/Analyzer && .build/debug/DataUpdater && .build/debug/StatisticsUpdater
