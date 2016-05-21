//
//  Server.swift
//  swift-package-crawler
//
//  Created by Honza Dvorsky on 5/20/16.
//
//

import Vapor

public func setupRoutes(app: Application) {
    
    ManifestController().setupRoutes(app: app)
    
}
