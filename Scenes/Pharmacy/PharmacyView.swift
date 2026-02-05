import SwiftUI

struct PharmacyView: View {
    @StateObject private var viewModel: PharmacyViewModel
    let onAdd: () -> Void

    init(
        viewModel: PharmacyViewModel = PharmacyViewModel(),
        onAdd: @escaping () -> Void
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onAdd = onAdd
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    Text("Аптечка")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(Color(hex: "3B3B3B"))
                        .padding(.top, 12)

                    content(width: proxy.size.width)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.bottom, 160) // keep content above tab bar and floating button
            }
            .task {
                await viewModel.load()
            }
            .overlay(alignment: .bottomTrailing) {
                FloatingPlusButton(action: onAdd)
                    .padding(.trailing, 24)
                    .padding(.bottom, 110)
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
                    availableWidth: width
                )
            }
        }
    }
}

private struct EmptyPharmacyView: View {
    let onAdd: () -> Void

    private let buttonGradient = LinearGradient(
        colors: [
            Color(red: 214/255, green: 254/255, blue: 194/255),
            Color(red: 111/255, green: 149/255, blue: 252/255),
            Color(red: 7/255, green: 115/255, blue: 241/255)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        VStack(spacing: 20) {
            Image("aptechka")
                .resizable()
                .scaledToFit()
                .frame(height: 220)
                .padding(.top, 6)

            Button(action: onAdd) {
                Text("Добавить витамин")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 188, height: 58)
                    .background(
                        buttonGradient
                            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(Color.white.opacity(0.8), lineWidth: 1.66)
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
    let vitamins: [Vitamin]
    let availableWidth: CGFloat
    private let itemSize: CGFloat = 120

    var body: some View {
        let spacing = max(0, (availableWidth - itemSize * 2) / 3)
        let columns = [
            GridItem(.fixed(itemSize), spacing: spacing),
            GridItem(.fixed(itemSize), spacing: spacing)
        ]

        LazyVGrid(columns: columns, alignment: .center, spacing: spacing) {
            ForEach(vitamins) { vitamin in
                VitaminCardView(title: vitamin.name)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct VitaminCardView: View {
    let title: String

    private let strokeGradient = LinearGradient(
        colors: [
            Color(red: 235/255, green: 243/255, blue: 255/255),
            Color(red: 128/255, green: 168/255, blue: 255/255)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        Text(title)
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(Color(hex: "555555"))
            .frame(width: 120, height: 120)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(strokeGradient, lineWidth: 1.5)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
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
