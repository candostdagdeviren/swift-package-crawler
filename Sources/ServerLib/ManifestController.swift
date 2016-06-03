//
//  ManifestController.swift
//  swift-package-crawler
//
//  Created by Honza Dvorsky on 5/20/16.
//
//

// import Vapor
// import Foundation
// import Utils

// public struct ManifestController {
    
//     public func setupRoutes(app: Application) {
        
//         app.get("/v1/packages/github/:user/:repo/manifest/json") { request in
            
//             let params = request.parameters
//             guard let user = params["user"]?.lowercased(), let repo = params["repo"]?.lowercased() else {
//                 throw Abort.badRequest
//             }
            
//             //try to load the JSON manifest, if present
//             let jsonPath = try packageJSONPath(name: "/\(user)/\(repo)")
//             do {
//                 let jsonString = try String(contentsOfFile: jsonPath)
//                 let json = try Json.deserialize(jsonString)
//                 return Response(status: .ok, json: json)
//             } catch {
//                 throw Abort.notFound
//             }
//         }
        
//         app.get("/v1/packages/github/:user/:repo/manifest") { request in
            
//             let params = request.parameters
//             guard let user = params["user"]?.lowercased(), let repo = params["repo"]?.lowercased() else {
//                 throw Abort.badRequest
//             }
            
//             //try to load the Swift manifest, if present
//             let jsonPath = try packageSwiftPath(name: "/\(user)/\(repo)")
//             do {
//                 let packageString = try String(contentsOfFile: jsonPath)
//                 return Response(status: .ok, text: packageString)
//             } catch {
//                 throw Abort.notFound
//             }
//         }
//     }
// }
