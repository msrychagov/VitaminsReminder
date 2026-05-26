//
//  PasswordField.swift
//  Vitamins
//

import SwiftUI

struct PasswordField: View {
    let placeholder: String
    @Binding var text: String
    let isError: Bool
    let errorMessage: String

    @State private var isRevealed = false

    var body: some View {
        ZStack(alignment: .trailing) {
            Group {
                if isRevealed {
                    TextField(placeholder, text: $text)
                        .textContentType(.password)
                        .autocapitalization(.none)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                } else {
                    SecureField(placeholder, text: $text)
                        .textContentType(.password)
                }
            }
            .padding(.trailing, 36)
            .animation(nil, value: isRevealed)

            Button {
                var tx = Transaction()
                tx.disablesAnimations = true
                withTransaction(tx) {
                    isRevealed.toggle()
                }
            } label: {
                Image(systemName: isRevealed ? "eye" : "eye.slash")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isRevealed ? "Скрыть пароль" : "Показать пароль")
        }
        .inputFieldStyle(isError: isError, errorMessage: errorMessage)
    }
}
