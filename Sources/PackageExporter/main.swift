//
//  main.swift
//  swift-package-crawler
//
//  Created by Honza Dvorsky on 5/9/16.
//
//

import Utils

do {
    try exportAllPackages()
} catch {
    print(error)
}
