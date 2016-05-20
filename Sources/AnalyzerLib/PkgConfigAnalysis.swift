//
//  PkgConfigAnalysis.swift
//  swift-package-crawler
//
//  Created by Honza Dvorsky on 5/11/16.
//
//

struct PkgConfigAnalysis: Analysis {
    
    func analyze(packageIterator: PackageIterator) throws {
        
        print("Starting PkgConfigAnalysis analyzer...")
        
        try basicCountAnalysis(packageIterator: packageIterator)
    }
    
    func basicCountAnalysis(packageIterator: PackageIterator) throws {
        
        var total = 0
        var withPkgConfig: [Package] = []
        var withProviders: [Package] = []
        
        var it = packageIterator
        while let package = try it.next() {
            if let _ = package.pkgConfig {
                withPkgConfig.append(package)
            }
            if let _ = package.providers {
                withProviders.append(package)
            }
            total += 1
        }
        
        let pkgConfigCount = withPkgConfig.count
        let providersCount = withProviders.count
        let pkgConfigPercent = pkgConfigCount.percentOf(total)
        let providersPercent = providersCount.percentOf(total)
        
        print("Pkg-config: out of \(total) packages, \(pkgConfigCount) (\(pkgConfigPercent)%) have 'pkgConfig' and \(providersCount) (\(providersPercent)%) have 'providers' specified.")
    }
}

