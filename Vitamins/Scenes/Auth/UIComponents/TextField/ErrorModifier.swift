//
//  ErrorModifier.swift
//  Vitamins
//
//  Created by Михаил Рычагов on 30.11.2025.
//

import SwiftUI

struct InputFieldStyle: ViewModifier {
    var isError: Bool
    var errorMessage: String
    
    func body(content: Content) -> some View {
        VStack(alignment: .leading) {
            content
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isError ? Color.red : Color.blue, lineWidth: 1)
                )
            if isError {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.red)
                    
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .italic()
                }
                .font(.system(size: 9))
            }
        }
    }
}

extension View {
    func inputFieldStyle(isError: Bool, errorMessage: String) -> some View {
        self.modifier(InputFieldStyle(isError: isError, errorMessage: errorMessage))
    }
}
