//
//  PasswordResetVerifyRequest.swift
//  Vitamins
//
//  Created by Codex on 03.02.2026.
//

import Foundation

struct PasswordResetVerifyRequest: Encodable {
    let email: String
    let code: String
}
