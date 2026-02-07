//
//  UserProfileResponse.swift
//  Vitamins
//
//  Created by Codex on 07.02.2026.
//

import Foundation

struct UserProfileResponse: Decodable {
    let firstName: String
    let lastName: String
    let email: String
}

