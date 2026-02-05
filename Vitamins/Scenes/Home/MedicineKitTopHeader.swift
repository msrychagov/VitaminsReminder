import SwiftUI

struct MedicineKitTopHeader: View {
    let safeTop: CGFloat
    let onPlus: () -> Void
    let onLogout: (() -> Void)?

    private let headerHeight: CGFloat = 141
    private let topPadding: CGFloat = -24
    private let trailingPadding: CGFloat = 20
    private let buttonSpacing: CGFloat = 12

    var body: some View {
        ZStack(alignment: .top) {
            TopHeaderGlowView()

            HStack(spacing: buttonSpacing) {
                NavigationLink {
                    EditProfileView(onLogout: onLogout)
                } label: {
                    ProfileCircleButton()
                }
                .buttonStyle(.plain)

                PlusCircleButton(action: onPlus)
            }
            .padding(.trailing, trailingPadding)
            .padding(.top, 10)
            .frame(maxWidth: .infinity, alignment: .topTrailing)
        }
        .frame(height: 72)
        .shadow(color: Color.headerShadow.opacity(0.2), radius: 18, x: 0, y: 3)
    }
}

struct TopHeaderGlowView: View {
    var body: some View {
        Color.white
            .background(.ultraThinMaterial)
            .ignoresSafeArea(edges: .top)
    }
}

private extension Color {
    static let headerShadow   = Color(red: 112/255, green: 135/255, blue: 255/255, opacity: 1)
}
