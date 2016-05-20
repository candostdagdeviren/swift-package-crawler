//
//  main.swift
//  swift-package-crawler
//
//  Created by Honza Dvorsky on 5/9/16.
//
//

import AnalyzerLib
import Foundation

do {
    try analyzeAllPackages()
} catch {
    print(error)
    exit(1)
}


