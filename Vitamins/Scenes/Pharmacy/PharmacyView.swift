import SwiftUI

struct PharmacyView: View {
    @StateObject private var viewModel: PharmacyViewModel
    let onAdd: () -> Void
    let onOpenReminder: (Int) -> Void

    init(
        viewModel: PharmacyViewModel = PharmacyViewModel(),
        onAdd: @escaping () -> Void,
        onOpenReminder: @escaping (Int) -> Void
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onAdd = onAdd
        self.onOpenReminder = onOpenReminder
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    Text("Аптечка")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(Color(hex: "3B3B3B"))
                        .padding(.top, 32)

                    content(width: proxy.size.width - 48) // minus horizontal padding
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.bottom, 180) // keep content above tab bar and floating button
            }
            .task {
                await viewModel.load()
            }
            .overlay(alignment: .bottomTrailing) {
                FloatingPlusButton(action: onAdd)
                    .padding(.trailing, 30)
                    .padding(.bottom, 30) // tab bar now via safeAreaInset
            }
        }
        .background(Color.white)
    }

    @ViewBuilder
    private func content(width: CGFloat) -> some View {
        switch viewModel.state {
        case .loading:
            ProgressView()
                .progressViewStyle(.circular)
                .tint(Color(hex: "0773F1"))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

        case .failed(let message):
            VStack(spacing: 12) {
                Text(message)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.secondary)

                Button(action: { Task { await viewModel.load() } }) {
                    Text("Повторить")
                        .font(.system(size: 16, weight: .semibold))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Color(hex: "0773F1").opacity(0.12))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, alignment: .center)

        case .loaded(let vitamins):
            if vitamins.isEmpty {
                EmptyPharmacyView(onAdd: onAdd)
            } else {
                VitaminsGridView(
                    vitamins: vitamins,
                    availableWidth: width,
                    onSelect: onOpenReminder
                )
            }
        }
    }
}

private struct EmptyPharmacyView: View {
    let onAdd: () -> Void

    private let buttonCornerRadius: CGFloat = 26
    private let buttonBorderWidth: CGFloat = 2

    private var buttonGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: Color(hex: "D6FEC2"), location: -0.2223),
                .init(color: Color(hex: "6F95FC"), location: 0.4319),
                .init(color: Color(hex: "0773F1"), location: 1.4378)
            ]),
            startPoint: UnitPoint(x: 0.7403, y: 0.9385),
            endPoint: UnitPoint(x: 0.2597, y: 0.0615)
        )
    }

    private var buttonLinearBorder: LinearGradient {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(
                    color: Color(
                        red: 231/255,
                        green: 240/255,
                        blue: 255/255,
                        opacity: 0.523483
                    ),
                    location: 0.2276
                ),
                .init(color: Color(hex: "88A4FF"), location: 0.4951),
                .init(
                    color: Color(
                        red: 180/255,
                        green: 210/255,
                        blue: 255/255,
                        opacity: 0.1
                    ),
                    location: 0.8712
                )
            ]),
            startPoint: UnitPoint(x: 0.0684, y: 0.2483),
            endPoint: UnitPoint(x: 0.9316, y: 0.7517)
        )
    }

    private var buttonRadialBorder: RadialGradient {
        RadialGradient(
            gradient: Gradient(colors: [
                .white,
                .white.opacity(0)
            ]),
            center: UnitPoint(x: 0.1494, y: 0.9673),
            startRadius: 0,
            endRadius: 116
        )
    }

    var body: some View {
        VStack(spacing: 20) {
            Image("aptechka")
                .resizable()
                .scaledToFit()
                .frame(height: 220)
                .padding(.top, 6)

            Button(action: onAdd) {
                Text("Добавить витамин")
                    .font(.custom("Commissioner-Bold", size: 16))
                    .foregroundColor(.white)
                    .frame(width: 188, height: 58)
                    .background(
                        buttonGradient
                            .clipShape(
                                RoundedRectangle(
                                    cornerRadius: buttonCornerRadius,
                                    style: .continuous
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: buttonCornerRadius, style: .continuous)
                            .strokeBorder(buttonLinearBorder, lineWidth: buttonBorderWidth)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: buttonCornerRadius, style: .continuous)
                            .strokeBorder(buttonRadialBorder, lineWidth: buttonBorderWidth)
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)

            Text("Добавьте свои витамины, чтобы  получать напоминания, отслеживать запасы, просматривать свой прогресс и многое другое")
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "656565"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

private struct VitaminsGridView: View {
    let vitamins: [PharmacyReminderItem]
    let availableWidth: CGFloat
    let onSelect: (Int) -> Void
    private let itemSize: CGFloat = 137

    var body: some View {
        let spacing = max(0, (availableWidth - itemSize * 2) / 3)
        let columns = [
            GridItem(.fixed(itemSize), spacing: spacing),
            GridItem(.fixed(itemSize), spacing: spacing)
        ]

        LazyVGrid(columns: columns, alignment: .center, spacing: spacing) {
            ForEach(vitamins) { vitamin in
                Button {
                    onSelect(vitamin.id)
                } label: {
                    VitaminCardView(title: vitamin.title)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct VitaminCardView: View {
    let title: String

    private let size: CGFloat = 137
    private let cornerRadius: CGFloat = 15
    private let borderWidth: CGFloat = 4

    private var linearBorder: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 231/255, green: 240/255, blue: 255/255, opacity: 0.523483),
                Color(hex: "88A4FF"),
                Color(red: 180/255, green: 210/255, blue: 255/255, opacity: 0.1)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var radialBorder: RadialGradient {
        RadialGradient(
            gradient: Gradient(colors: [
                .white,
                .white.opacity(0)
            ]),
            center: UnitPoint(x: 0.1494, y: 0.9673),
            startRadius: 0,
            endRadius: 180
        )
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(linearBorder, lineWidth: borderWidth)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(radialBorder, lineWidth: borderWidth)
                )
                .shadow(color: Color.black.opacity(0.25), radius: 4, x: 0, y: 4)

            Text(title)
                .font(.custom("Commissioner-Bold", size: 18.69))
                .foregroundColor(Color(hex: "737373"))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 10)
        }
        .frame(width: size, height: size)
    }
}

private struct FloatingPlusButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Color.white)
                .frame(width: 62, height: 62)
                .shadow(color: .black.opacity(0.16), radius: 10, x: 0, y: 6)
                .overlay(
                    Image("plus")
                        .resizable()
                        .renderingMode(.original)
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                )
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
    }
}
