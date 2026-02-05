//
//  Colors.swift
//  Vitamins
//
//  Created by Codex on 28.01.2026.
//

import SwiftUI

extension Color {
    static let authTitle = Color(hex: "6C94FC")
    static let authPrimaryButton = Color(hex: "0E75F2")
    static let authSubtitle = Color(hex: "757575")
    static let authInfo = Color(hex: "CCCCCC")
    static let authInputBorder = Color(hex: "7298FA", alpha: 0.57)
    static let authSecondaryButton = Color(hex: "097AFF")
    static let authCodeBackground = Color(hex: "BAB8B8")
    static let authCodeBorderFocus = Color(hex: "0773F1")
    static let authCodeBorderSuccess = Color(hex: "83CCB4")

    init(hex: String, alpha: Double = 1.0) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        let int = UInt64(hex, radix: 16) ?? 0
        let r, g, b: UInt64
        switch hex.count {
        case 6:
            r = (int >> 16) & 0xFF
            g = (int >> 8) & 0xFF
            b = int & 0xFF
        case 3:
            r = ((int >> 8) & 0xF) * 17
            g = ((int >> 4) & 0xF) * 17
            b = (int & 0xF) * 17
        default:
            r = 0
            g = 0
            b = 0
        }
        self.init(.sRGB,
                  red: Double(r) / 255.0,
                  green: Double(g) / 255.0,
                  blue: Double(b) / 255.0,
                  opacity: alpha)
    }
}
