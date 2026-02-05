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
        let hasError = isError && !errorMessage.isEmpty
        VStack(alignment: .leading, spacing: 4) {
            content
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(height: 56)
                .background(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isError ? Color.red : Color.authInputBorder, lineWidth: 2)
                )
                .cornerRadius(12)
                .font(.custom("Commissioner-Regular", size: 16))
            
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 12))
                    .opacity(hasError ? 1 : 0)
                
                Text(hasError ? errorMessage : " ")
                    .foregroundColor(.red)
                    .font(.custom("Commissioner-Regular", size: 9))
                    .italic()
                    
            }
            .opacity(hasError ? 1 : 0)
            .accessibilityHidden(!hasError)
        }
    }
}

extension View {
    func inputFieldStyle(isError: Bool, errorMessage: String) -> some View {
        self.modifier(InputFieldStyle(isError: isError, errorMessage: errorMessage))
    }
}
