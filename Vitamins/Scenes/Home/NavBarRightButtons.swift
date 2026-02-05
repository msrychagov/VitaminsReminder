import SwiftUI

// MARK: - Buttons
struct PlusCircleButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Color.white)
                .overlay(
                    Circle()
                        .stroke(Color.plusStroke, lineWidth: 1)
                )
                .overlay(
                    Image("plus")
                        .resizable()
                        .renderingMode(.original)
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                )
                .frame(width: 46, height: 46)
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
    }
}

struct ProfileCircleButton: View {
    var body: some View {
        ZStack {
            Image("profile")
                .resizable()
                .scaledToFill()
                .frame(width: 46, height: 46)
                .clipShape(Circle())

            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.profileStroke1,
                            Color.profileStroke2,
                            Color.profileStroke3
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
                .frame(width: 46, height: 46)
                .shadow(color: Color.navShadow, radius: 30.1, x: 0, y: -14)
        }
        .frame(width: 46, height: 46)
        .contentShape(Circle())
    }
}

// MARK: - Colors
private extension Color {
    static let navShadow = Color(red: 112/255, green: 135/255, blue: 255/255, opacity: 1)
    static let plusStroke = Color.black.opacity(0.08)
    static let profileStroke1 = Color(red: 231/255, green: 240/255, blue: 255/255, opacity: 0.52)
    static let profileStroke2 = Color(red: 136/255, green: 164/255, blue: 255/255, opacity: 1)
    static let profileStroke3 = Color(red: 180/255, green: 210/255, blue: 255/255, opacity: 0.1)
}
