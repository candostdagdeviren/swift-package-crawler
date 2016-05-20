//
//  main.swift
//  swift-package-crawler
//
//  Created by Honza Dvorsky on 5/9/16.
//
//

import PackageExporterLib
import Foundation

do {
    try exportAllPackages()
} catch {
    print(error)
    exit(1)
}
