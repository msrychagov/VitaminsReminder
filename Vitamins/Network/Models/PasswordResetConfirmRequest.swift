//
//  PasswordResetConfirmRequest.swift
//  Vitamins
//
//  Created by Codex on 2026-02-12.
//

import Foundation

struct PasswordResetConfirmRequest: Encodable {
    let password: String
    let passwordConfirm: String
    let resetToken: String
}
