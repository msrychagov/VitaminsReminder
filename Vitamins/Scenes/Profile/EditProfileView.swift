import SwiftUI
import PhotosUI
import UIKit
import Combine
import ComposableArchitecture
import Foundation

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ProfileViewModel
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showPasswordReset = false
    @State private var passwordResetStore: StoreOf<AuthFeature>?
    @State private var showLogoutDialog = false
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    let onLogout: (() -> Void)?

    init(onLogout: (() -> Void)? = nil, fallbackEmail: String? = nil) {
        _viewModel = StateObject(wrappedValue: ProfileViewModel(fallbackEmail: fallbackEmail))
        self.onLogout = onLogout
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
                avatarSection

                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    changePhotoButton
                }

                nameFields

                emailField

                changePasswordButton

                doneButton

                logoutButton
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 30)
        }
        .background(background)
        .task {
            await loadProfile()
        }
        .onChange(of: selectedPhotoItem) { newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        viewModel.setImageData(data)
                    }
                }
            }
        }
        .sheet(isPresented: $showPasswordReset, onDismiss: { passwordResetStore = nil }) {
            PasswordResetFlowView(
                store: passwordResetStore ?? makePasswordResetStore(),
                onFinished: {
                    showPasswordReset = false
                    passwordResetStore = nil
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .customBackButton(
            show: true,
            action: { dismiss() }
        )
        .alert(alertTitle, isPresented: $showAlert) {
            Button("Ок", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .overlay {
            Color.white
                .opacity(showLogoutDialog ? 0.75 : 0)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.25), value: showLogoutDialog)
        }
        .overlay {
            if showLogoutDialog {
                logoutConfirmOverlay
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showLogoutDialog)
    }

    // MARK: - UI Sections
    private var avatarSection: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 184, height: 184)
                .shadow(color: Color.black.opacity(0.08), radius: 16, x: 0, y: 8)

            avatarImage
                .frame(width: 170, height: 170)
                .clipShape(Circle())

            Circle()
                .stroke(avatarGradient, lineWidth: 4)
                .frame(width: 184, height: 184)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
    }

    private var changePhotoButton: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(photoBorderLinearGradient, lineWidth: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(photoBorderRadialGradient, lineWidth: 2)
                )
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
                .frame(width: 318, height: 44)

            HStack(spacing: 12) {
                Image("camera")
                    .renderingMode(.template)
                    .foregroundColor(Color.profileAccent)
                    .frame(width: 24, height: 20)

                Text("Изменить фотографию")
                    .font(.custom("Commissioner-Bold", size: 16))
                    .foregroundColor(Color.profileAccent)

                Spacer()
            }
            .padding(.horizontal, 20)
            .frame(width: 318, height: 44, alignment: .leading)
        }
    }

    private var nameFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Имя", text: $viewModel.firstName)
                .font(.custom("Commissioner-Bold", size: 22))
                .foregroundColor(Color(hex: "5F5F5F"))
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)

            Rectangle()
                .fill(nameDividerGradient)
                .frame(height: 2)

            TextField("Фамилия", text: $viewModel.lastName)
                .font(.custom("Commissioner-Bold", size: 22))
                .foregroundColor(Color(hex: "5F5F5F"))
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 6)
        .frame(width: 318, height: 120, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(photoBorderLinearGradient, lineWidth: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(photoBorderRadialGradient, lineWidth: 2)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 5)
    }

    private var emailField: some View {
        TextField("E-mail", text: $viewModel.email)
            .keyboardType(.emailAddress)
            .autocapitalization(.none)
            .textInputAutocapitalization(.never)
            .font(.custom("Commissioner-Bold", size: 22))
            .foregroundColor(Color(hex: "5F5F5F"))
            .padding(.horizontal, 18)
            .frame(width: 318, height: 63, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(photoBorderLinearGradient, lineWidth: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(photoBorderRadialGradient, lineWidth: 2)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
    }

    private var changePasswordButton: some View {
        Button {
            passwordResetStore = makePasswordResetStore()
            showPasswordReset = true
        } label: {
            ZStack {
                HStack(spacing: 12) {
                    Image("lockVitamins")
                        .renderingMode(.original)
                        .frame(width: 22, height: 22)

                    Spacer()

                    Image("chevron")
                        .renderingMode(.template)
                        .foregroundColor(Color.profileAccent)
                        .frame(width: 12, height: 18)
                }
                .padding(.horizontal, 18)

                Text("Сменить пароль")
                    .font(.custom("Commissioner-Bold", size: 16))
                    .foregroundColor(Color.profileAccent)
            }
            .frame(width: 318, height: 44)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(photoBorderLinearGradient, lineWidth: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(photoBorderRadialGradient, lineWidth: 2)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
        }
    }

    private var doneButton: some View {
        Button {
            Task {
                do {
                    try await viewModel.submitChanges()
                    await MainActor.run { dismiss() }
                } catch {
                    alertTitle = "Не удалось сохранить"
                    alertMessage = error.localizedDescription
                    showAlert = true
                }
            }
        } label: {
            Text("Готово")
                .font(.custom("Commissioner-SemiBold", size: 16))
                .foregroundColor(.white)
                .frame(width: 134, height: 42)
                .background(doneBackground)
                .clipShape(RoundedRectangle(cornerRadius: 80.67, style: .continuous))
                .shadow(
                    color: viewModel.hasChanges ? Color.authPrimaryButton.opacity(0.3) : .clear,
                    radius: 10,
                    y: 4
                )
        }
        .disabled(!viewModel.hasChanges)
    }

    private var doneBackground: Color {
        if viewModel.hasChanges {
            return Color.authPrimaryButton
        } else {
            return Color(red: 105/255, green: 105/255, blue: 105/255, opacity: 0.5)
        }
    }

    private var logoutButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                showLogoutDialog = true
            }
        } label: {
            Text("Выйти из аккаунта")
                .font(.custom("Commissioner-Bold", size: 16))
                .foregroundColor(Color.red)
                .frame(width: 318, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(photoBorderLinearGradient, lineWidth: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(photoBorderRadialGradient, lineWidth: 2)
                )
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
        }
        .padding(.top, 6)
    }

    // MARK: - Helpers
    private var avatarImage: some View {
        Group {
            if let uiImage = viewModel.avatarUIImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else if let placeholder = UIImage(named: "profile") {
                Image(uiImage: placeholder)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Color.profileAccent)
            }
        }
    }

    private var avatarGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 231/255, green: 240/255, blue: 255/255, opacity: 0.82),
                Color(red: 136/255, green: 164/255, blue: 255/255, opacity: 1),
                Color(red: 180/255, green: 210/255, blue: 255/255, opacity: 0.55)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var photoBorderLinearGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 231/255, green: 240/255, blue: 255/255, opacity: 0.52),
                Color(red: 136/255, green: 164/255, blue: 255/255, opacity: 1),
                Color(red: 180/255, green: 210/255, blue: 255/255, opacity: 0.1)
            ],
            startPoint: UnitPoint(x: 0.0, y: 0.1),
            endPoint: UnitPoint(x: 1.0, y: 1.0)
        )
    }

    private var photoBorderRadialGradient: RadialGradient {
        RadialGradient(
            gradient: Gradient(colors: [Color.white, Color.white.opacity(0)]),
            center: UnitPoint(x: 0.15, y: 0.95),
            startRadius: 0,
            endRadius: 260
        )
    }

    private var nameDividerGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 90/255, green: 129/255, blue: 255/255, opacity: 0.495),
                Color(red: 86/255, green: 125/255, blue: 255/255, opacity: 0.525413),
                Color(red: 78/255, green: 120/255, blue: 255/255, opacity: 0.495)
            ],
            startPoint: UnitPoint(x: 0.0, y: 0.2),
            endPoint: UnitPoint(x: 1.0, y: 0.9)
        )
    }

    private var background: some View {
        LinearGradient(
            colors: [
                Color(hex: "F8FBFF"),
                Color.white
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private func makePasswordResetStore() -> StoreOf<AuthFeature> {
        var state = AuthFeature.State(mode: .passwordResetRequest)
        state.forms[.passwordResetRequest]?.email = viewModel.email.trimmingCharacters(in: .whitespacesAndNewlines)
        return Store(initialState: state) {
            AuthFeature()
        }
    }

    private func loadProfile() async {
        do {
            try await viewModel.fetchRemoteProfile()
        } catch {
            alertTitle = "Не удалось загрузить профиль"
            alertMessage = "Показаны сохраненные данные.\n\(error.localizedDescription)"
            showAlert = true
        }
    }

    // MARK: - Logout Confirmation Overlay
    private var logoutConfirmOverlay: some View {
        ZStack {
            VStack(spacing: 0) {
                Text("Выйти?")
                    .font(.custom("Commissioner-Bold", size: 28.8))
                    .foregroundColor(Color.profileAccent)
                    .padding(.top, 8)

                Text("При выходе из аккаунта ваши\nнастройки и добавленные\nвитамины не будут удалены,\nтак что вы сможете вернуться")
                    .font(.custom("Commissioner-Bold", size: 16))
                    .foregroundColor(Color(hex: "7A7A7A"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)
                    .padding(.top, 2)

                Spacer(minLength: 6)

                Rectangle()
                    .fill(dividerGradient)
                    .frame(height: 2)

                HStack(spacing: 0) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showLogoutDialog = false
                        }
                    } label: {
                        Text("Отмена")
                            .font(.custom("Commissioner-SemiBold", size: 21.75))
                            .foregroundColor(Color.profileAccent)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }

                    Rectangle()
                        .fill(dividerGradient)
                        .frame(width: 2)

                    Button {
                        viewModel.clear()
                        TokenStorage.clear()
                        onLogout?()
                        dismiss()
                        showLogoutDialog = false
                    } label: {
                        Text("Выйти")
                            .font(.custom("Commissioner-Bold", size: 21.75))
                            .foregroundColor(Color.profileAccent)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(height: 48)
            }
            .frame(width: 318, height: 229, alignment: .top)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(backBorderLinearGradient, lineWidth: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(photoBorderRadialGradient, lineWidth: 2)
            )
            .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 3)
        }
    }

    private var backBorderLinearGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 231/255, green: 240/255, blue: 255/255, opacity: 0.523),
                Color(red: 180/255, green: 210/255, blue: 255/255, opacity: 0.1),
                Color(red: 136/255, green: 164/255, blue: 255/255, opacity: 1)
            ],
            startPoint: UnitPoint(x: 0.0, y: 0.0),
            endPoint: UnitPoint(x: 1.0, y: 1.0)
        )
    }

    private var dividerGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 90/255, green: 129/255, blue: 255/255, opacity: 0.495),
                Color(red: 86/255, green: 125/255, blue: 255/255, opacity: 0.525413),
                Color(red: 78/255, green: 120/255, blue: 255/255, opacity: 0.495)
            ],
            startPoint: UnitPoint(x: 0.0, y: 0.2),
            endPoint: UnitPoint(x: 1.0, y: 0.9)
        )
    }
}

// MARK: - Password Reset Flow via existing AuthFeature
fileprivate struct PasswordResetFlowView: View {
    @Environment(\.dismiss) private var dismiss
    let store: StoreOf<AuthFeature>
    private let onFinished: () -> Void

    init(store: StoreOf<AuthFeature>, onFinished: @escaping () -> Void) {
        self.store = store
        self.onFinished = onFinished
    }

    var body: some View {
        WithViewStore(self.store, observe: { $0 }) { viewStore in
            AuthView(viewStore: store)
                .onChange(of: viewStore.rootMode) { _ in
                    handleIfCompleted(viewStore: viewStore)
                }
                .onChange(of: viewStore.navigationPath) { _ in
                    handleIfCompleted(viewStore: viewStore)
                }
        }
    }

    private func handleIfCompleted(viewStore: ViewStoreOf<AuthFeature>) {
        // В AuthFeature успешный сброс пароля приводит к rootMode = .signIn и пустому navigationPath.
        if viewStore.rootMode == .signIn,
           viewStore.navigationPath.isEmpty {
            onFinished()
            dismiss()
        }
    }
}

// MARK: - View Model
final class ProfileViewModel: ObservableObject {
    @Published var firstName: String
    @Published var lastName: String
    @Published var email: String
    @Published private(set) var imageData: Data?

    private let storage: UserProfileStorage
    private var original: UserProfile
    private let networkClient: NetworkClient

    init(
        storage: UserProfileStorage = .init(),
        networkClient: NetworkClient = .init(),
        fallbackEmail: String? = nil
    ) {
        self.storage = storage
        self.networkClient = networkClient
        let stored = storage.load()
        let initialEmail = stored.email.isEmpty ? (fallbackEmail ?? "") : stored.email
        let cleanedFirstName = stored.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedLastName = stored.lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedEmail = initialEmail.trimmingCharacters(in: .whitespacesAndNewlines)

        self.firstName = cleanedFirstName
        self.lastName = cleanedLastName
        self.email = cleanedEmail
        self.imageData = stored.imageData
        self.original = UserProfile(
            firstName: cleanedFirstName,
            lastName: cleanedLastName,
            email: cleanedEmail,
            imageData: stored.imageData
        )
    }

    var avatarUIImage: UIImage? {
        guard let imageData else { return nil }
        return UIImage(data: imageData)
    }

    var hasChanges: Bool {
        currentProfile != original
    }

    func setImageData(_ data: Data?) {
        imageData = data
    }

    func saveChanges() {
        let profile = currentProfile
        storage.save(profile)
        original = profile
    }

    func submitChanges() async throws {
        let profile = currentProfile
        let request = UpdateProfileRequest(
            email: profile.email,
            firstName: profile.firstName,
            lastName: profile.lastName
        )
        _ = try await networkClient.request(
            body: request,
            endpoint: UserEndpoint.updateMe
        ) as EmptyResponse?

        await MainActor.run {
            storage.save(profile)
            original = profile
        }
    }

    func fetchRemoteProfile() async throws {
        let response = try await networkClient.request(
            endpoint: UserEndpoint.fetchMe
        ) as UserProfileResponse?

        guard let user = response else { return }

        await MainActor.run {
            firstName = user.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
            lastName = user.lastName.trimmingCharacters(in: .whitespacesAndNewlines)
            email = user.email.trimmingCharacters(in: .whitespacesAndNewlines)
            let updated = currentProfile
            storage.save(updated)
            original = updated
        }
    }

    func clear() {
        storage.clear()
        firstName = ""
        lastName = ""
        email = ""
        imageData = nil
        original = .empty
    }

    private var currentProfile: UserProfile {
        get {
            let trimmedFirst = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedLast = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
            return UserProfile(
                firstName: trimmedFirst,
                lastName: trimmedLast,
                email: trimmedEmail,
                imageData: imageData
            )
        }
    }
}

// MARK: - Colors
private extension Color {
    static let profileAccent = Color(hex: "0773F1")
    static let profileBorder = Color(hex: "D9E4FF")
    static let profileSeparator = Color(hex: "E7E8EA")
}
