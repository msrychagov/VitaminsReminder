//
//  PasswordResetVerifyResponse.swift
//  Vitamins
//
//  Created by Codex on 2026-02-12.
//

import Foundation

struct PasswordResetVerifyResponse: Decodable, Equatable {
    let resetToken: String
}
