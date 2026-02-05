import SwiftUI

struct CustomBackButton: View {
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image("backButton")
                .renderingMode(.original)
                .frame(width: 44, height: 44)
                .background(Color.white)
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
        }
    }
}

private struct CustomBackButtonModifier: ViewModifier {
    let show: Bool
    let action: () -> Void
    
    func body(content: Content) -> some View {
        content
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
            .overlay(alignment: .topLeading) {
                if show {
                    CustomBackButton(action: action)
                        .padding(.leading, 20)
                        .padding(.top, 20)
                }
            }
    }
}

extension View {
    func customBackButton(show: Bool, action: @escaping () -> Void) -> some View {
        modifier(CustomBackButtonModifier(show: show, action: action))
    }
}
