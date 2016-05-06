
enum CrawlError: ErrorProtocol {
    case got404 //that's the end, finish this crawling session
    case got429 //too many requests, back off
}

