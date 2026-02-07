//
//  HomeView.swift
//  Vitamins
//
//  Created by Михаил Рычагов on 26.01.2026.
//

import SwiftUI
import Combine

// MARK: - Constants (Figma values, no scaling)
private struct TabBarConstants {
    // Device/frame
    static let deviceWidth: CGFloat = 402
    
    // Tab bar container (Rectangle 1888)
    static let containerWidth: CGFloat = 363
    static let containerHeight: CGFloat = 56
    static let containerLeft: CGFloat = 22
    static let containerRadius: CGFloat = 100
    static let containerFill: Color = .white
    static let containerBorder: Color = Color(hex: "D9D9D9")
    static let containerShadowOpacity: Double = 0.25
    static let containerShadowRadius: CGFloat = 2 // blur 4 ≈ radius 2
    static let containerShadowX: CGFloat = 0
    static let containerShadowY: CGFloat = 4
    
    // Highlight (Rectangle 1892)
    static let highlightWidth: CGFloat = 118
    static let highlightHeight: CGFloat = 55
    static let highlightRadius: CGFloat = 80
    static let highlightShadowOpacity: Double = 0.25
    static let highlightShadowRadius: CGFloat = 2 // blur 4
    static let highlightShadowX: CGFloat = 0
    static let highlightShadowY: CGFloat = 4
    static let highlightOpacity: Double = 0.6
    static let highlightTopColor: Color = Color(red: 7/255, green: 115/255, blue: 241/255).opacity(0.33)
    static let highlightBottomColor: Color = Color(red: 31/255, green: 182/255, blue: 237/255).opacity(0.1386)
    
    // Layout gaps
    static let bottomGap: CGFloat = 31 // distance from container bottom to device bottom (without safe area)
    static let containerRightInset: CGFloat = max(0, deviceWidth - containerLeft - containerWidth) // 17
    
    // Icons/text
    static let selectedColor: Color = Color(hex: "0773F1")
    static let unselectedOpacity: Double = 0.65
    static let iconSize: CGFloat = 32
    static let centerIconSize: CGFloat = 32
    static let centerOffsetY: CGFloat = 3
}

// MARK: - Tab Enum
private enum Tab: CaseIterable, Hashable {
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

// MARK: - Home View with Custom Tab Bar
struct HomeView: View {
    var onLogout: (() -> Void)?
    @State private var selectedTab: Tab = .pharmacy
    @Namespace private var highlightNamespace
    @State private var showAddVitamin = false
    
    init(onLogout: (() -> Void)? = nil) {
        self.onLogout = onLogout
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let safeBottom = proxy.safeAreaInsets.bottom
                let adjustedBottom = max(0, TabBarConstants.bottomGap - max(0, safeBottom))
                
                ZStack {
                    Color.white
                        .ignoresSafeArea()
                    
                    content(for: selectedTab)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .toolbar(.hidden, for: .navigationBar)
                .safeAreaInset(edge: .top, spacing: 0) {
                    MedicineKitTopHeader(
                        safeTop: proxy.safeAreaInsets.top,
                        onPlus: { showAddVitamin = true },
                        onLogout: onLogout
                    )
                }
                .safeAreaInset(edge: .bottom) {
                    HStack(spacing: 0) {
                        Spacer(minLength: 0)
                        CustomTabBar(
                            selectedTab: $selectedTab,
                            namespace: highlightNamespace
                        )
                        .frame(width: TabBarConstants.containerWidth, height: TabBarConstants.containerHeight)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 0)
                    .padding(.bottom, 30)
                    .zIndex(1)
                }
            }
            .ignoresSafeArea(edges: .bottom)
            .background(Color.white.opacity(0.8).ignoresSafeArea())
            .background(
                NavigationLink(
                    destination: AddVitaminPlaceholderView(),
                    isActive: $showAddVitamin,
                    label: { EmptyView() }
                )
            )
        }
    }
    
    @ViewBuilder
    private func content(for tab: Tab) -> some View {
        switch tab {
        case .schedule:
            ScheduleView()
        case .pharmacy:
            PharmacyView {
                showAddVitamin = true
            }
        case .stats:
            StatsView()
        }
    }
}

// MARK: - Custom Tab Bar
private struct CustomTabBar: View {
    @Binding var selectedTab: Tab
    var namespace: Namespace.ID
    
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
                let tabWidth = geo.size.width / CGFloat(Tab.allCases.count)
                
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
                        .matchedGeometryEffect(id: "highlight", in: namespace)
                        .frame(width: TabBarConstants.highlightWidth, height: TabBarConstants.highlightHeight)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: highlightAlignment(for: selectedTab))
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: selectedTab)
                
                HStack {
                    ForEach(Array(Tab.allCases), id: \.self) { tab in
                        TabItemView(
                            tab: tab,
                            isSelected: tab == selectedTab,
                            isCenter: tab == .pharmacy
                        ) {
                            guard tab != selectedTab else { return }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                selectedTab = tab
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
    }
    
    private func highlightAlignment(for tab: Tab) -> Alignment {
        switch tab {
        case .schedule: return .leading
        case .pharmacy: return .center
        case .stats: return .trailing
        }
    }
}

// MARK: - Tab Item
private struct TabItemView: View {
    let tab: Tab
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
                .padding(.top, 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { action() }
    }
}

// MARK: - Schedule
private struct ScheduleView: View {
    @StateObject private var viewModel = ScheduleViewModel()

    var body: some View {
        ScrollViewReader { reader in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Расписание")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(Color(hex: "3B3B3B"))
                        .padding(.top, 8)

                    calendarStrip(reader: reader)

                    Text("Принять сегодня")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Color(hex: "3B3B3B"))

                    VStack(spacing: 14) {
                        ForEach(viewModel.remindersForSelectedDate) { reminder in
                            ReminderCard(
                                reminder: reminder,
                                onToggle: { viewModel.toggle(reminder) }
                            )
                        }
                    }
                    .padding(.bottom, 140) // keep above tab bar
                }
                .padding(.horizontal, 24)
            }
            .background(Color.white)
            .onAppear {
                viewModel.scrollProxy = reader
                viewModel.load()
            }
        }
    }

    private func calendarStrip(reader: ScrollViewProxy) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(viewModel.monthDays, id: \.self) { day in
                    DateCell(
                        date: day,
                        isSelected: Calendar.current.isDate(day, inSameDayAs: viewModel.selectedDate),
                        onTap: {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                                viewModel.select(day)
                            }
                        }
                    )
                    .id(day)
                }
            }
            .padding(.vertical, 6)
        }
    }
}

private final class ScheduleViewModel: ObservableObject {
    @Published var selectedDate: Date = Date().startOfDay
    @Published var reminders: [Reminder] = []
    var scrollProxy: ScrollViewProxy?

    private let storage = ReminderStorage()
    private let calendar = Calendar.current

    var monthDays: [Date] {
        guard
            let monthRange = calendar.range(of: .day, in: .month, for: selectedDate),
            let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedDate))
        else { return [] }

        return monthRange.compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day - 1, to: monthStart)
        }
    }

    var remindersForSelectedDate: [Reminder] {
        reminders.filter { calendar.isDate($0.date, inSameDayAs: selectedDate) }
    }

    func load() {
        reminders = storage.load()

        if reminders.isEmpty {
            seedSamples()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.scrollToToday()
        }
    }

    func select(_ date: Date) {
        selectedDate = date.startOfDay
        scrollTo(date)
    }

    func toggle(_ reminder: Reminder) {
        guard let index = reminders.firstIndex(of: reminder) else { return }
        reminders[index].isTaken.toggle()
        storage.save(reminders)
        objectWillChange.send()
    }

    private func scrollToToday() {
        scrollTo(Date())
    }

    private func scrollTo(_ date: Date) {
        scrollProxy?.scrollTo(date.startOfDay, anchor: .center)
    }

    private func seedSamples() {
        let today = Date().startOfDay
        reminders = [
            Reminder(
                id: UUID(),
                date: today,
                vitaminName: "Витамин B",
                intakeType: .beforeMeal,
                time: "9:00",
                count: 2,
                isTaken: true
            ),
            Reminder(
                id: UUID(),
                date: today,
                vitaminName: "Витамин D",
                intakeType: .afterMeal,
                time: "20:00",
                count: 1,
                isTaken: false
            ),
            Reminder(
                id: UUID(),
                date: today,
                vitaminName: "Витамин A",
                intakeType: .duringMeal,
                time: "22:00",
                count: 1,
                isTaken: false
            )
        ]
        storage.save(reminders)
    }
}

private struct DateCell: View {
    let date: Date
    let isSelected: Bool
    let onTap: () -> Void

    private let size = CGSize(width: 69, height: 101)

    var body: some View {
        let weekday = date.shortWeekday
        let day = date.dayString

        let background: AnyShapeStyle = isSelected
        ? AnyShapeStyle(
            LinearGradient(
                colors: [
                    Color.white,
                    Color(hex: "4E73FB"),
                    Color(hex: "0773F1")
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        : AnyShapeStyle(Color.white)

        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(background)
                .frame(width: size.width, height: size.height)
                .shadow(color: Color.black.opacity(0.18), radius: 3, x: -1, y: 3)

            VStack(alignment: .leading, spacing: 0) {
                Text(weekday)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black)
                    .padding(.top, 8)
                    .padding(.leading, 8)

                Spacer()

                Text(day)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(isSelected ? .white : .black)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 20)
            }
            .frame(width: size.width, height: size.height)
        }
        .onTapGesture { onTap() }
    }
}

private struct ReminderCard: View {
    let reminder: Reminder
    let onToggle: () -> Void

    private let gradient = LinearGradient(
        colors: [
            Color(red: 214/255, green: 254/255, blue: 194/255),
            Color(red: 111/255, green: 149/255, blue: 252/255),
            Color(red: 7/255, green: 115/255, blue: 241/255)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        HStack(spacing: 14) {
            ToggleCircle(isOn: reminder.isTaken, action: onToggle)

            VStack(alignment: .leading, spacing: 6) {
                Text(reminder.vitaminName)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                Text("\(reminder.intakeType.description) — \(reminder.time)")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.black)
            }

            Spacer()

            VStack(spacing: 0) {
                Text("\(reminder.count)")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                Text("шт")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(gradient)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(Color.white.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 4)
    }
}

private struct ToggleCircle: View {
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: 26, height: 26)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 1.2)
                    )

                if isOn {
                    Image("mark")
                        .resizable()
                        .renderingMode(.original)
                        .scaledToFit()
                        .frame(width: 14, height: 14)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Models & Storage
private struct Reminder: Identifiable, Codable, Equatable {
    let id: UUID
    let date: Date
    let vitaminName: String
    let intakeType: IntakeType
    let time: String
    let count: Int
    var isTaken: Bool
}

private enum IntakeType: String, Codable {
    case beforeMeal
    case afterMeal
    case duringMeal

    var description: String {
        switch self {
        case .beforeMeal: return "До еды"
        case .afterMeal: return "После еды"
        case .duringMeal: return "Во время еды"
        }
    }
}

private final class ReminderStorage {
    private let defaults: UserDefaults
    private let cacheKey = "cached_reminders_v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func save(_ reminders: [Reminder]) {
        guard let data = try? JSONEncoder().encode(reminders) else { return }
        defaults.set(data, forKey: cacheKey)
    }

    func load() -> [Reminder] {
        guard
            let data = defaults.data(forKey: cacheKey),
            let reminders = try? JSONDecoder().decode([Reminder].self, from: data)
        else {
            return []
        }
        return reminders
    }
}

// MARK: - Helpers
private extension Date {
    var startOfDay: Date { Calendar.current.startOfDay(for: self) }

    var shortWeekday: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "EE"
        return formatter.string(from: self)
            .replacingOccurrences(of: ".", with: "")
            .capitalized
    }

    var dayString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d"
        return formatter.string(from: self)
    }
}

private struct StatsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar")
                .font(.system(size: 72))
                .foregroundStyle(.blue)
            
            Text("Статистика")
                .font(.system(size: 28, weight: .bold))
            
            Text("Скоро здесь появится статистика приёма лекарств.")
                .font(.system(size: 16))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
    }
}

// MARK: - Helpers
private extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        _ = scanner.scanString("#")
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        HomeView()
    }
}

