//
//  AuthEndpoints.swift
//  Vitamins
//
//  Created by Михаил Рычагов on 26.01.2026.
//

import Foundation

enum AuthEndpoint {
    case login
    case register
}

extension AuthEndpoint: Endpoint {
    var method: EndpointType {
        .post
    }
    
    var authorized: Bool {
        false
    }
    
    var queryItems: [URLQueryItem]? {
        nil
    }
    
    var baseURL: URL {
        URL(string: "\(NetworkClient.Constants.baseURL)/auth")!
    }
    
    var url: URL {
        switch self {
        case .login: baseURL.appendingPathComponent("login")
        case .register: baseURL.appendingPathComponent("register")
        }
    }
    
    
}
