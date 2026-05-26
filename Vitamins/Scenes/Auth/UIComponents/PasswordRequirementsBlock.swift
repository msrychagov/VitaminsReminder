//
//  PasswordRequirementsBlock.swift
//  Vitamins
//

import SwiftUI

struct PasswordRequirementsBlock: View {
    private let items: [String] = [
        "Минимум 8 символов",
        "Минимум 1 буква",
        "Минимум 1 цифра"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 12))
                Text("Требования к паролю:")
                    .font(.custom("Commissioner-Regular", size: 11).italic())
                    .foregroundColor(.red)
            }

            ForEach(items, id: \.self) { item in
                Text("•  \(item)")
                    .font(.custom("Commissioner-Regular", size: 11).italic())
                    .foregroundColor(.red)
                    .padding(.leading, 18)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
