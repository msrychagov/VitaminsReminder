import SwiftUI

struct WelcomeView: View {
    var onContinue: () -> Void
    
    private let highlightColor = Color(hex: "D6FEC2")
    
    var body: some View {
        ZStack {
            background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerGraphic
                    .padding(.top, 28)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                
                contentText
                    .padding(.horizontal, 28)
                    .padding(.bottom, 20)
                
                primaryButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, 60)
            }
        }
    }
    
    private var background: some View {
        LinearGradient(
            stops: [
                .init(color: Color(hex: "D6FEC2"), location: 0.0739),
                .init(color: Color(hex: "6C94FC"), location: 0.3153),
                .init(color: Color(hex: "0E75F2"), location: 0.8206),
                .init(color: Color(hex: "D6FEC2"), location: 0.9768)
            ],
            startPoint: UnitPoint(x: 1.05, y: 0.1),
            endPoint: UnitPoint(x: -0.05, y: 1.1)
        )
    }
    
    private var headerGraphic: some View {
        Image("Kodee")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 520, height: 520)
            .offset(x: -50, y: -18)
            .opacity(0.92)
    }
    
    private var contentText: some View {
        VStack(spacing: 12) {
            VStack(spacing: 4) {
                titleText
                    .multilineTextAlignment(.center)
                
                subtitleText
                    .multilineTextAlignment(.center)
            }
        }
        .offset(y: -20)
    }
    
    private var titleText: some View {
        (
            Text("Добро пожаловать\nв ваш персональный\n")
            + Text("трекер").foregroundColor(highlightColor)
            + Text("\u{00A0}витаминов") // неразрывный пробел, чтобы не стало 4 строк
        )
        .font(.custom("Commissioner-ExtraBold", size: 28))
        .foregroundColor(.white)
        .lineSpacing(4)
        .multilineTextAlignment(.center)
        .lineLimit(3)
        .minimumScaleFactor(0.85)
        .allowsTightening(true)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 41)
    }
    
    
    private var subtitleText: some View {
        Text("Отслеживайте приём и сохраняйте\nбаланс каждый день.")
            .font(.custom("Commissioner-Regular", size: 16))
            .foregroundColor(Color.white.opacity(0.9))
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.9)
            .allowsTightening(true)
            .fixedSize(horizontal: false, vertical: true)
    }

    
    private var primaryButton: some View {
        Button(action: onContinue) {
            Text("Далее")
                .font(.custom("Commissioner-SemiBold", size: 16))
                .foregroundColor(.black)
                .frame(maxWidth: 260)
                .padding(.vertical, 16)
                .background(Color.white)
                .clipShape(Capsule())
                .shadow(color: Color.black.opacity(0.18), radius: 10, y: 6)
        }
    }
}
