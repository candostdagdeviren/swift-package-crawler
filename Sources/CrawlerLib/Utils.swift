//
//  Utils.swift
//  swift-package-crawler
//
//  Created by Honza Dvorsky on 5/9/16.
//
//

enum CrawlError: ErrorProtocol {
    case got404 //that's the end, finish this crawling session
    case got429 //too many requests, back off
}

