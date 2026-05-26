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
    @State private var showDeleteAccountDialog = false
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
            VStack(spacing: 18) {
                avatarSection
                    .padding(.top, 8)

                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    changePhotoButton
                }

                nameAndEmailCard

                doneButton

                menuList
                    .padding(.top, 12)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 24)
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
            Color.black
                .opacity(showLogoutDialog ? 0.25 : 0)
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
        .overlay {
            Color.black
                .opacity(showDeleteAccountDialog ? 0.25 : 0)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.25), value: showDeleteAccountDialog)
        }
        .overlay {
            if showDeleteAccountDialog {
                deleteAccountConfirmOverlay
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showDeleteAccountDialog)
    }

    // MARK: - Avatar
    private var avatarSection: some View {
        ZStack {
            avatarImage
                .frame(width: 156, height: 156)
                .clipShape(Circle())

            Circle()
                .stroke(avatarStroke, lineWidth: 3)
                .frame(width: 156, height: 156)
        }
        .frame(maxWidth: .infinity)
    }

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

    private var avatarStroke: LinearGradient {
        LinearGradient(
            colors: [
                Color(hex: "DCE7FF"),
                Color(hex: "88A4FF"),
                Color(hex: "B4D2FF")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Change photo button
    private var changePhotoButton: some View {
        HStack(spacing: 10) {
            Image(systemName: "camera")
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(Color.profileAccent)
            Text("Изменить фотографию")
                .font(.custom("Commissioner-SemiBold", size: 16))
                .foregroundColor(Color.profileAccent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.profileAccent.opacity(0.45), lineWidth: 1.5)
        )
        .shadow(color: Color.profileAccent.opacity(0.08), radius: 6, x: 0, y: 2)
    }

    // MARK: - Name + Email card
    private var nameAndEmailCard: some View {
        VStack(spacing: 0) {
            TextField("Имя", text: $viewModel.firstName)
                .font(.custom(viewModel.firstName.isEmpty ? "Commissioner-Regular" : "Commissioner-Bold", size: 18))
                .foregroundColor(.black)
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)
                .padding(.horizontal, 22)
                .frame(height: 56)

            Rectangle()
                .fill(Color(hex: "DCE7FF"))
                .frame(height: 1)
                .padding(.horizontal, 18)

            TextField("E-mail", text: $viewModel.email)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .font(.custom("Commissioner-Regular", size: 16))
                .foregroundColor(.black.opacity(0.6))
                .padding(.horizontal, 22)
                .frame(height: 56)
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.profileAccent.opacity(0.35), lineWidth: 1.5)
        )
        .shadow(color: Color.profileAccent.opacity(0.08), radius: 8, x: 0, y: 3)
    }

    // MARK: - Done
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
                .frame(width: 130, height: 40)
                .background(doneBackground)
                .clipShape(Capsule(style: .continuous))
                .shadow(
                    color: viewModel.hasChanges ? Color.profileAccent.opacity(0.3) : .clear,
                    radius: 8,
                    y: 3
                )
        }
        .disabled(!viewModel.hasChanges)
    }

    private var doneBackground: Color {
        viewModel.hasChanges
            ? Color.profileAccent
            : Color(red: 158/255, green: 162/255, blue: 170/255)
    }

    // MARK: - Menu
    private var menuList: some View {
        VStack(spacing: 0) {
            menuRow(
                iconName: "lock",
                title: "Изменить пароль",
                color: Color.profileAccent
            ) {
                passwordResetStore = makePasswordResetStore()
                showPasswordReset = true
            }
            menuDivider

            menuRow(
                iconName: "rectangle.portrait.and.arrow.right",
                title: "Выйти из аккаунта",
                color: Color.profileAccent
            ) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showLogoutDialog = true
                }
            }
            menuDivider

            menuRow(
                iconName: "trash",
                title: "Удалить аккаунт",
                color: Color.red
            ) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showDeleteAccountDialog = true
                }
            }
        }
    }

    private func menuRow(
        iconName: String,
        title: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: iconName)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(color)
                    .frame(width: 24, height: 24)

                Text(title)
                    .font(.custom("Commissioner-SemiBold", size: 16))
                    .foregroundColor(color)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var menuDivider: some View {
        Rectangle()
            .fill(Color(hex: "E5E8EE"))
            .frame(height: 1)
    }

    // MARK: - Background
    private var background: some View {
        LinearGradient(
            colors: [Color(hex: "F8FBFF"), Color.white],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Profile loading
    private func makePasswordResetStore() -> StoreOf<AuthFeature> {
        var state = AuthFeature.State(mode: .passwordResetRequest)
        state.forms[.passwordResetRequest]?.email = viewModel.email.trimmingCharacters(in: .whitespacesAndNewlines)
        return Store(initialState: state) {
            AuthFeature()
        }
    }

    private func loadProfile() async {
        AnalyticsService.shared.track(
            AnalyticsEventName.profileViewed,
            properties: [
                "screen": "profile"
            ]
        )
        do {
            try await viewModel.fetchRemoteProfile()
        } catch {
            alertTitle = "Не удалось загрузить профиль"
            alertMessage = "Показаны сохраненные данные.\n\(error.localizedDescription)"
            showAlert = true
        }
    }

    // MARK: - Logout confirm overlay
    private var logoutConfirmOverlay: some View {
        confirmDialog(
            title: "Выйти?",
            titleColor: Color.profileAccent,
            messageBuilder: {
                let prefix = Text("При выходе из аккаунта ваши настройки и добавленные витамины ")
                let bold = Text("не").font(.custom("Commissioner-Bold", size: 15))
                let suffix = Text(" будут удалены, так что вы сможете вернуться")
                return prefix + bold + suffix
            },
            primaryTitle: "Выйти",
            primaryColor: Color.profileAccent,
            primaryBold: true,
            onCancel: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showLogoutDialog = false
                }
            },
            onPrimary: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showLogoutDialog = false
                }
                if let onLogout {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        onLogout()
                    }
                } else {
                    viewModel.clear()
                    TokenStorage.clear()
                    dismiss()
                }
            }
        )
    }

    // MARK: - Delete confirm overlay
    private var deleteAccountConfirmOverlay: some View {
        confirmDialog(
            title: "Удалить аккаунт?",
            titleColor: Color.profileAccent,
            messageBuilder: {
                Text("Если вы удалите аккаунт, то все витамины из вашей аптечки пропадут, а также вы потеряете статистику")
            },
            primaryTitle: "Удалить",
            primaryColor: Color.red,
            primaryBold: true,
            onCancel: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showDeleteAccountDialog = false
                }
            },
            onPrimary: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showDeleteAccountDialog = false
                }
                Task {
                    do {
                        try await viewModel.deleteAccount()
                    } catch {
                        alertTitle = "Не удалось удалить аккаунт"
                        alertMessage = error.localizedDescription
                        showAlert = true
                        return
                    }
                    viewModel.clear()
                    TokenStorage.clear()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        if let onLogout {
                            onLogout()
                        } else {
                            dismiss()
                        }
                    }
                }
            }
        )
    }

    // MARK: - Reusable confirm dialog
    private func confirmDialog(
        title: String,
        titleColor: Color,
        @ViewBuilder messageBuilder: () -> Text,
        primaryTitle: String,
        primaryColor: Color,
        primaryBold: Bool,
        onCancel: @escaping () -> Void,
        onPrimary: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.custom("Commissioner-Bold", size: 22))
                .foregroundColor(titleColor)
                .padding(.top, 20)
                .padding(.bottom, 12)
                .multilineTextAlignment(.center)

            messageBuilder()
                .font(.custom("Commissioner-Regular", size: 15))
                .foregroundColor(Color(hex: "7A7A7A"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.bottom, 18)

            Rectangle()
                .fill(alertGradient(horizontal: true))
                .frame(height: 1.5)

            HStack(spacing: 0) {
                Button(action: onCancel) {
                    Text("Отмена")
                        .font(.custom("Commissioner-SemiBold", size: 17))
                        .foregroundColor(Color.profileAccent)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                Rectangle()
                    .fill(alertGradient(horizontal: false))
                    .frame(width: 1.5)

                Button(action: onPrimary) {
                    Text(primaryTitle)
                        .font(.custom(primaryBold ? "Commissioner-Bold" : "Commissioner-SemiBold", size: 17))
                        .foregroundColor(primaryColor)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(height: 50)
        }
        .frame(width: 300)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(alertStrokeGradient, lineWidth: 2)
        )
        .shadow(color: Color.black.opacity(0.18), radius: 18, x: 0, y: 8)
    }

    private var alertStrokeGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(hex: "E1ECFF"),
                Color(hex: "C8D9FF"),
                Color(hex: "A8C2FF"),
                Color(hex: "C8D9FF")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func alertGradient(horizontal: Bool) -> LinearGradient {
        LinearGradient(
            colors: [
                Color(hex: "E1ECFF"),
                Color(hex: "A8C2FF"),
                Color(hex: "E1ECFF")
            ],
            startPoint: horizontal ? .leading : .top,
            endPoint: horizontal ? .trailing : .bottom
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
        let normalizedData: Data?
        if let data, let image = UIImage(data: data) {
            normalizedData = image.jpegData(compressionQuality: 0.85) ?? data
        } else {
            normalizedData = data
        }

        imageData = normalizedData
        storage.updateImageData(normalizedData)
    }

    func saveChanges() {
        let profile = currentProfile
        storage.save(profile)
        original = profile
    }

    func submitChanges() async throws {
        let profile = currentProfile
        let previousProfile = original
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

        AnalyticsService.shared.track(
            AnalyticsEventName.profileUpdated,
            properties: [
                "screen": "profile",
                "has_avatar": .bool(profile.imageData != nil)
            ]
        )

        if previousProfile.email != profile.email {
            AnalyticsService.shared.track(
                AnalyticsEventName.profileEmailChanged,
                properties: [
                    "screen": "profile"
                ]
            )
        }

        if previousProfile.firstName != profile.firstName || previousProfile.lastName != profile.lastName {
            AnalyticsService.shared.track(
                AnalyticsEventName.profileNameChanged,
                properties: [
                    "screen": "profile"
                ]
            )
        }
    }

    func deleteAccount() async throws {
        _ = try await networkClient.request(
            endpoint: UserEndpoint.deleteMe
        ) as EmptyResponse?
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

// MARK: - Colors
private extension Color {
    static let profileAccent = Color(hex: "0773F1")
}
