import SwiftUI
import PhotosUI
import UIKit
import Combine

struct EditProfileView: View {
    @StateObject private var viewModel: ProfileViewModel
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showPasswordReset = false
    @State private var showLogoutDialog = false
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
        .navigationTitle("Профиль")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .navigationBarBackButtonHidden(false)
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
        .overlay(
            NavigationLink(
                destination: PasswordResetView(email: viewModel.email),
                isActive: $showPasswordReset,
                label: { EmptyView() }
            )
            .hidden()
        )
        .confirmationDialog(
            "Выйти из аккаунта?",
            isPresented: $showLogoutDialog,
            titleVisibility: .visible
        ) {
            Button("Выйти", role: .destructive) {
                viewModel.clear()
                TokenStorage.clear()
                onLogout?()
            }
            Button("Отмена", role: .cancel) { }
        } message: {
            Text("Вы сможете войти снова, используя свои данные.")
        }
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
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 6)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.profileAccent, lineWidth: 1.2)
                )
                .frame(height: 54)

            HStack {
                cameraImage
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(Color.profileAccent)
                    .frame(width: 22, height: 18)
                    .padding(.leading, 18)

                Spacer()

                Text("Изменить фотографию")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.profileAccent)

                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var nameFields: some View {
        VStack(spacing: 0) {
            TextField("Имя", text: $viewModel.firstName)
                .padding(.horizontal, 16)
                .frame(height: 54)
                .background(Color.white)

            Divider()
                .frame(height: 1)
                .background(Color.profileSeparator)

            TextField("Фамилия", text: $viewModel.lastName)
                .padding(.horizontal, 16)
                .frame(height: 54)
                .background(Color.white)
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.profileBorder, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 6)
    }

    private var emailField: some View {
        TextField("E-mail", text: $viewModel.email)
            .keyboardType(.emailAddress)
            .autocapitalization(.none)
            .textInputAutocapitalization(.never)
            .padding(.horizontal, 16)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.profileBorder, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 6)
    }

    private var changePasswordButton: some View {
        Button {
            showPasswordReset = true
        } label: {
            HStack {
                Image(systemName: "lock.fill")
                    .foregroundColor(Color.profileAccent)
                    .frame(width: 24, height: 24)

                Text("Сменить пароль")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.profileAccent)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color.profileAccent)
            }
            .padding(.horizontal, 16)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.profileBorder, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
        }
    }

    private var doneButton: some View {
        Button {
            viewModel.saveChanges()
        } label: {
            Text("Готово")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(doneBackground)
                .clipShape(Capsule())
                .shadow(
                    color: viewModel.hasChanges ? Color.blue.opacity(0.25) : .clear,
                    radius: 12,
                    y: 4
                )
        }
        .disabled(!viewModel.hasChanges)
    }

    private var doneBackground: LinearGradient {
        if viewModel.hasChanges {
            return LinearGradient(
                colors: [Color(hex: "0773F1"), Color(hex: "1BB4ED")],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else {
            let gray = Color.gray.opacity(0.55)
            return LinearGradient(
                colors: [gray, gray],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }

    private var logoutButton: some View {
        Button {
            showLogoutDialog = true
        } label: {
            Text("Выйти из аккаунта")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.red)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.red.opacity(0.25), lineWidth: 1.1)
                )
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

    private var cameraImage: Image {
        if let image = UIImage(named: "camera") {
            return Image(uiImage: image)
        }
        return Image(systemName: "camera.fill")
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
}

// MARK: - View Model
final class ProfileViewModel: ObservableObject {
    @Published var firstName: String
    @Published var lastName: String
    @Published var email: String
    @Published private(set) var imageData: Data?

    private let storage: UserProfileStorage
    private var original: UserProfile

    init(storage: UserProfileStorage = .init(), fallbackEmail: String? = nil) {
        self.storage = storage
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
