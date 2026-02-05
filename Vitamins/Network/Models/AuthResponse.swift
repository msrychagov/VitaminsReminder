//
//  AuthResponse.swift
//  Vitamins
//
//  Created by Михаил Рычагов on 26.01.2026.
//

import Foundation

struct AuthResponse: Decodable, Equatable {
    let accessToken: String
    let refreshToken: String
    let user: User?
    
    // Для обратной совместимости, если нужно
    var token: String? {
        accessToken
    }
}

struct User: Decodable, Equatable {
    let id: String
    let email: String
}

