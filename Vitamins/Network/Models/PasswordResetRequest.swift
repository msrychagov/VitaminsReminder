//
//  PasswordResetRequest.swift
//  Vitamins
//
//  Created by Михаил Рычагов on 26.01.2026.
//

import Foundation

struct PasswordResetRequest: Encodable {
    let password: String
    let repeatPassword: String
}





