import SwiftUI

// MARK: - Shared Tab Bar
enum AppTab: CaseIterable, Hashable {
    case schedule, pharmacy, stats

    var title: String {
        switch self {
        case .schedule: return "Расписание"
        case .pharmacy: return "Аптечка"
        case .stats: return "Статистика"
        }
    }

    var imageName: String {
        switch self {
        case .schedule: return "calendarTab"
        case .pharmacy: return "aptechkaTab"
        case .stats: return "statisticsTab"
        }
    }
}

enum TabBarConstants {
    static let deviceWidth: CGFloat = 402
    static let containerWidth: CGFloat = 363
    static let containerHeight: CGFloat = 56
    static let containerLeft: CGFloat = 22
    static let containerRadius: CGFloat = 100
    static let containerFill: Color = .white
    static let containerBorder: Color = Color(hex: "D9D9D9")
    static let containerShadowOpacity: Double = 0.25
    static let containerShadowRadius: CGFloat = 2
    static let containerShadowX: CGFloat = 0
    static let containerShadowY: CGFloat = 4

    static let highlightWidth: CGFloat = 118
    static let highlightHeight: CGFloat = 55
    static let highlightRadius: CGFloat = 80
    static let highlightShadowOpacity: Double = 0.25
    static let highlightShadowRadius: CGFloat = 2
    static let highlightShadowX: CGFloat = 0
    static let highlightShadowY: CGFloat = 4
    static let highlightOpacity: Double = 0.6
    static let highlightTopColor: Color = Color(red: 7/255, green: 115/255, blue: 241/255).opacity(0.33)
    static let highlightBottomColor: Color = Color(red: 31/255, green: 182/255, blue: 237/255).opacity(0.1386)

    static let bottomGap: CGFloat = 31
    static let containerRightInset: CGFloat = max(0, deviceWidth - containerLeft - containerWidth)

    static let selectedColor: Color = Color(hex: "0773F1")
    static let unselectedOpacity: Double = 0.65
    static let iconSize: CGFloat = 32
    static let centerIconSize: CGFloat = 32
    static let centerOffsetY: CGFloat = 3
}

struct AppTabBar: View {
    @Binding var selectedTab: AppTab
    var onSelect: ((AppTab) -> Void)?

    @Namespace private var highlightNamespace

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: TabBarConstants.containerRadius, style: .continuous)
                .fill(TabBarConstants.containerFill)
                .overlay(
                    RoundedRectangle(cornerRadius: TabBarConstants.containerRadius, style: .continuous)
                        .stroke(TabBarConstants.containerBorder, lineWidth: 1 / UIScreen.main.scale)
                )
                .shadow(color: .black.opacity(TabBarConstants.containerShadowOpacity),
                        radius: TabBarConstants.containerShadowRadius,
                        x: TabBarConstants.containerShadowX,
                        y: TabBarConstants.containerShadowY)

            GeometryReader { geo in
                let tabWidth = geo.size.width / CGFloat(AppTab.allCases.count)

                ZStack {
                    RoundedRectangle(cornerRadius: TabBarConstants.highlightRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    TabBarConstants.highlightTopColor,
                                    TabBarConstants.highlightBottomColor
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .opacity(TabBarConstants.highlightOpacity)
                        .matchedGeometryEffect(id: "highlight", in: highlightNamespace)
                        .frame(width: TabBarConstants.highlightWidth, height: TabBarConstants.highlightHeight)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: highlightAlignment(for: selectedTab))
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: selectedTab)

                HStack(spacing: 0) {
                    ForEach(Array(AppTab.allCases), id: \.self) { tab in
                        TabItemView(
                            tab: tab,
                            isSelected: tab == selectedTab,
                            isCenter: tab == .pharmacy,
                            action: { select(tab) }
                        )
                        .frame(width: tabWidth, height: geo.size.height)
                    }
                }
            }
        }
        .frame(width: TabBarConstants.containerWidth, height: TabBarConstants.containerHeight)
    }

    private func select(_ tab: AppTab) {
        onSelect?(tab)
        guard tab != selectedTab else { return }
        selectedTab = tab
    }

    private func highlightAlignment(for tab: AppTab) -> Alignment {
        switch tab {
        case .schedule: return .leading
        case .pharmacy: return .center
        case .stats: return .trailing
        }
    }
}

private struct TabItemView: View {
    let tab: AppTab
    let isSelected: Bool
    let isCenter: Bool
    let action: () -> Void

    var body: some View {
        VStack(spacing: 2) {
            Image(tab.imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: isCenter ? TabBarConstants.centerIconSize : TabBarConstants.iconSize)
                .padding(.top, isCenter ? -TabBarConstants.centerOffsetY : 0)
                .foregroundColor(TabBarConstants.selectedColor.opacity(isSelected ? 1.0 : TabBarConstants.unselectedOpacity))

            Text(tab.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(TabBarConstants.selectedColor.opacity(isSelected ? 1.0 : TabBarConstants.unselectedOpacity))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { action() }
    }
}
