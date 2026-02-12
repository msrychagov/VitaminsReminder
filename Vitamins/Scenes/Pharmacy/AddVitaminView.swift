import SwiftUI

struct VitaminDraft {
    var name: String = ""
    var type: String = ""
    var dose: String = ""
    var intake: IntakeMoment? = nil
    var notes: String = ""
}

enum IntakeMoment: String, CaseIterable, Identifiable {
    case before = "До еды"
    case after = "После еды"
    case during = "Во время\nеды"
    case any = "Неважно"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .before: return "plateUnselected"
        case .after: return "forkUnselected"
        case .during: return "kneeUnselected"
        case .any: return "markMagnifierUnselected"
        }
    }

    var selectedIconName: String {
        switch self {
        case .before: return "plateSelected"
        case .after: return "forkSelected"
        case .during: return "kneeSelected"
        case .any: return "markMahnifierSelected"
        }
    }
}

struct AddVitaminView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedTab: AppTab

    @State private var draft = VitaminDraft()
    @State private var navigateToNotifications = false

    private let blue = Color(hex: "0E75F2")
    private let lightField = Color(red: 248/255, green: 250/255, blue: 251/255)

    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [Color(hex: "EFF6FF"), .white],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    progressIndicators
                        .padding(.top, 18)
                        .padding(.horizontal, 30)

                    titleField
                        .padding(.bottom, 9) // 1.5x spacing to next element

                    vitaminTypeButton
                        .padding(.horizontal, 30)

                    doseBlock
                        .padding(.horizontal, 30)

                    intakeGrid
                        .padding(.top, 36) // reduced spacing to dose block
                        .padding(.horizontal, 30)

                    notesField
                        .padding(.top, 18) // double gap from cells
                        .padding(.horizontal, 30)

                    buttonsRow
                        .padding(.top, 4)
                        .padding(.horizontal, 30)
                }
                .padding(.bottom, 150) // give more space below buttons toward tab bar
            }
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
            .background(
                NavigationLink(
                    destination: NotificationSetupPlaceholderView(draft: draft),
                    isActive: $navigateToNotifications
                ) { EmptyView() }
            )

            tabBarOverlay
        }
    }

    // MARK: - Sections
    private var progressIndicators: some View {
        let segmentWidth: CGFloat = 109
        let spacing: CGFloat = 12
        let totalWidth = segmentWidth * 3 + spacing * 2

        return ZStack {
            // Unfilled background for all steps
            HStack(spacing: spacing) {
                RoundedRectangle(cornerRadius: 50)
                    .fill(Color(hex: "D6D6D6"))
                    .frame(width: segmentWidth, height: 5)
                RoundedRectangle(cornerRadius: 50)
                    .fill(Color(hex: "D6D6D6"))
                    .frame(width: segmentWidth, height: 5)
                RoundedRectangle(cornerRadius: 50)
                    .fill(Color(hex: "D6D6D6"))
                    .frame(width: segmentWidth, height: 5)
            }

            // Filled gradient only for first segment
            LinearGradient(
                colors: [
                    Color(hex: "0773F1"),
                    Color(hex: "38A9FF")
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: segmentWidth, height: 5)
            .mask(
                RoundedRectangle(cornerRadius: 50)
                    .frame(width: segmentWidth, height: 5)
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: totalWidth)
        .frame(maxWidth: .infinity)
    }

    private var conicGradient: AngularGradient {
        AngularGradient(
            gradient: Gradient(stops: [
                .init(color: Color(hex: "0773F1"), location: 0.0),
                .init(color: .white, location: 0.55),
                .init(color: Color(hex: "D1FFBA"), location: 0.72),
                .init(color: Color(hex: "0773F1"), location: 0.96),
                .init(color: .white, location: 1.0)
            ]),
            center: .init(x: 0.9037, y: -1.4375),
            angle: .degrees(205)
        )
    }

    private var titleField: some View {
        HStack(spacing: 12) {
            Image("pen")
                .resizable()
                .renderingMode(.original)
                .frame(width: 24, height: 24)

            TextField("", text: $draft.name, prompt: Text("Название").foregroundColor(.black))
                .font(.custom("Commissioner-Bold", size: 32))
                .foregroundColor(Color(hex: "3B3B3B"))
        }
        .padding(.horizontal, 30)
    }

    private var vitaminTypeButton: some View {
        Button {
            // Placeholder: could open picker later
        } label: {
            HStack {
                Text(draft.type.isEmpty ? "Вид витамина" : draft.type)
                    .font(.custom("Commissioner-SemiBold", size: 18))
                    .foregroundColor(.white)
                Spacer()
                Image("chevronWhite")
                    .resizable()
                    .frame(width: 22, height: 22)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .frame(height: 49)
            .background(blue)
            .cornerRadius(14)
        }
        .frame(maxWidth: 343)
    }

    private var doseBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Разовая доза")
                .font(.custom("Commissioner-Medium", size: 12))
                .foregroundColor(Color(hex: "4A4A4A"))
                .padding(.leading, 24)

            TextField("", text: $draft.dose, prompt: Text("Введите количество").foregroundColor(.white))
                .keyboardType(.decimalPad)
                .font(.custom("Commissioner-SemiBold", size: 18))
                .foregroundColor(.white)
                .padding(.leading, 24)
                .padding(.trailing, 16)
                .frame(height: 49)
                .frame(maxWidth: .infinity)
                .background(blue)
                .cornerRadius(14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var intakeGrid: some View {
        HStack(alignment: .top, spacing: 16) {
            ForEach(IntakeMoment.allCases) { moment in
                VStack(spacing: 10) {
                    intakeSquare(for: moment)
                    Text(moment.rawValue)
                        .font(.custom("Commissioner-Medium", size: 12))
                        .foregroundColor(Color(hex: "3B3B3B"))
                        .multilineTextAlignment(.center)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func intakeSquare(for moment: IntakeMoment) -> some View {
        let isSelected = draft.intake == moment
        let size: CGSize = {
            switch moment {
            case .before: return CGSize(width: 32, height: 32)
            case .after: return CGSize(width: 16, height: 39)
            case .during: return CGSize(width: 26, height: 26)
            case .any: return CGSize(width: 30, height: 30)
            }
        }()

        let imageName = isSelected ? moment.selectedIconName : moment.iconName

        return Image(imageName)
            .resizable()
            .scaledToFit()
            .frame(width: size.width, height: size.height)
            .shadow(color: .clear, radius: 0)
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .frame(width: 74.7, height: 69)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? blue : Color.white)
                    .shadow(color: Color.black.opacity(0.25), radius: 4, x: 0, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.clear : Color.black.opacity(0.2), lineWidth: 0.6)
            )
            .contentShape(RoundedRectangle(cornerRadius: 14))
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.15)) {
                    draft.intake = moment
                }
            }
    }

    private var notesField: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(lightField)
                .frame(height: 57)
                .shadow(color: Color.black.opacity(0.25), radius: 4, x: 0, y: 1)

            TextField(
                "",
                text: $draft.notes,
                prompt: Text("Примечание").foregroundColor(Color(hex: "8093A6"))
            )
            .font(.custom("Commissioner-Medium", size: 16))
            .foregroundColor(Color(hex: "3B3B3B"))
            .padding(.horizontal, 18)
            .frame(height: 57, alignment: .center)
        }
        .frame(maxWidth: .infinity)
    }

    private var buttonsRow: some View {
        HStack(spacing: 0) {
            Button(action: { dismiss() }) {
                Text("Назад")
                    .font(.custom("Commissioner-Bold", size: 20))
                    .foregroundColor(blue)
                    .frame(width: 155, height: 52)
                    .background(Color.white)
                    .overlay(borderGradientStroke)
                    .clipShape(RoundedRectangle(cornerRadius: 100, style: .continuous))
                    .shadow(color: Color.black.opacity(0.25), radius: 4, x: 0, y: 4)
            }

            Spacer()

            Button(action: { navigateToNotifications = true }) {
                Text("Далее")
                    .font(.custom("Commissioner-Bold", size: 20))
                    .foregroundColor(.white)
                    .frame(width: 155, height: 52)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "1E7BF3"), Color(hex: "A6C4DD")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 100, style: .continuous))
            }
        }
        .padding(.top, 60)
    }

    private var borderGradientStroke: some View {
        RoundedRectangle(cornerRadius: 100)
            .strokeBorder(
                LinearGradient(
                    colors: [
                        Color(red: 231/255, green: 240/255, blue: 255/255, opacity: 0.52),
                        Color(red: 136/255, green: 164/255, blue: 255/255, opacity: 1),
                        Color(red: 180/255, green: 210/255, blue: 255/255, opacity: 0.1)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                lineWidth: 2
            )
    }

    private var tabBarOverlay: some View {
        HStack {
            Spacer(minLength: 0)
            AppTabBar(
                selectedTab: Binding(
                    get: { selectedTab },
                    set: { tab in
                        guard tab != selectedTab else { return }
                        selectedTab = tab
                        dismiss()
                    }
                ),
                onSelect: { _ in
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            )
            Spacer(minLength: 0)
        }
        .padding(.bottom, 12)
        .padding(.horizontal, 0)
        .background(Color.clear.ignoresSafeArea(edges: .bottom))
    }
}

// Placeholder for notification setup
struct NotificationSetupPlaceholderView: View {
    let draft: VitaminDraft

    var body: some View {
        let nameValue = draft.name.isEmpty ? "—" : draft.name
        let typeValue = draft.type.isEmpty ? "—" : draft.type
        let doseValue = draft.dose.isEmpty ? "—" : draft.dose
        let intakeValue = draft.intake?.rawValue ?? "—"
        let notesValue = draft.notes.isEmpty ? "—" : draft.notes

        VStack(spacing: 16) {
            Text("Настройка уведомлений")
                .font(.custom("Commissioner-Bold", size: 24))

            VStack(alignment: .leading, spacing: 8) {
                Text("Название: \(nameValue)")
                Text("Вид: \(typeValue)")
                Text("Доза: \(doseValue)")
                Text("Прием: \(intakeValue)")
                Text("Примечание: \(notesValue)")
            }
            .font(.custom("Commissioner-Medium", size: 16))
            .foregroundColor(Color(hex: "4A4A4A"))

            Text("Здесь будет логика выбора времени напоминаний и отправка запроса на сервер.")
                .font(.custom("Commissioner-Regular", size: 15))
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 24)

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}
