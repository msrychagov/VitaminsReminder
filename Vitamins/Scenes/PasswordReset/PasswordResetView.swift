import SwiftUI

struct PasswordResetView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email: String
    @State private var showAlert = false
    @State private var alertMessage = ""

    init(email: String = "") {
        _email = State(initialValue: email)
    }

    var body: some View {
        VStack(spacing: 18) {
            Text("Сброс пароля")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(Color(hex: "0773F1"))
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Укажите почту, и мы отправим письмо с инструкцией для сброса пароля.")
                .font(.system(size: 15))
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .leading)

            TextField("E-mail", text: $email)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .textInputAutocapitalization(.never)
                .padding(.horizontal, 16)
                .frame(height: 54)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color(hex: "D9E4FF"), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)

            Button {
                if email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    alertMessage = "Введите e-mail, чтобы продолжить."
                } else {
                    alertMessage = "Если такой адрес зарегистрирован, письмо со ссылкой уже отправлено."
                }
                showAlert = true
            } label: {
                Text("Отправить")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "0773F1"), Color(hex: "1BB4ED")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: Color.blue.opacity(0.25), radius: 12, y: 4)
            }

            Button("Отменить") {
                dismiss()
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.gray)
            .padding(.top, 4)

            Spacer()
        }
        .padding(22)
        .background(
            LinearGradient(
                colors: [Color(hex: "F8FBFF"), Color.white],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .navigationBarTitleDisplayMode(.inline)
        .alert("Почти готово", isPresented: $showAlert) {
            Button("Ок", role: .cancel) {
                if !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    dismiss()
                }
            }
        } message: {
            Text(alertMessage)
        }
    }
}
