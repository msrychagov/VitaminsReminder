import SwiftUI

struct AddVitaminPlaceholderView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(Color(hex: "0773F1"))

            Text("Экран добавления витамина")
                .font(.title2.weight(.bold))

            Text("Здесь будет логика создания витамина. Пока это заглушка.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.ignoresSafeArea())
        .navigationTitle("Добавить")
        .navigationBarTitleDisplayMode(.inline)
    }
}
