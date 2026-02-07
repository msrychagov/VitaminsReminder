//
//  UpdateProfileRequest.swift
//  Vitamins
//
//  Created by Codex on 07.02.2026.
//

import Foundation

struct UpdateProfileRequest: Encodable {
    let email: String
    let firstName: String
    let lastName: String
}

