//
//  HomeView.swift
//  Vitamins
//
//  Created by Михаил Рычагов on 26.01.2026.
//

import SwiftUI
import Combine

private enum HomeRoute: Hashable {
    case addVitamin
    case addVitaminSchedule(VitaminDraft)
    case addVitaminNotification(VitaminDraft)
}

// MARK: - Home View with Custom Tab Bar
struct HomeView: View {
    var onLogout: (() -> Void)?
    @State private var selectedTab: AppTab = .pharmacy
    @State private var navigationPath: [HomeRoute] = []
    
    init(onLogout: (() -> Void)? = nil) {
        self.onLogout = onLogout
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            GeometryReader { proxy in
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
                        onPlus: { navigationPath.append(.addVitamin) },
                        onLogout: onLogout
                    )
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    HStack(spacing: 0) {
                        Spacer(minLength: 0)
                        AppTabBar(selectedTab: $selectedTab) { tab in
                            guard tab != selectedTab else { return }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                selectedTab = tab
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 0)
                    .padding(.bottom, 12)
                }
            }
            .background(Color.white.opacity(0.8).ignoresSafeArea())
            .navigationDestination(for: HomeRoute.self) { route in
                switch route {
                case .addVitamin:
                    AddVitaminView(
                        selectedTab: $selectedTab,
                        onNext: { draft in
                            navigationPath.append(.addVitaminSchedule(draft))
                        }
                    )
                case .addVitaminSchedule(let draft):
                    AddVitaminScheduleView(
                        selectedTab: $selectedTab,
                        draft: draft,
                        onNext: { updatedDraft in
                            navigationPath.append(.addVitaminNotification(updatedDraft))
                        }
                    )
                case .addVitaminNotification(let draft):
                    AddVitaminNotificationView(
                        selectedTab: $selectedTab,
                        draft: draft,
                        onAdded: {
                            selectedTab = .pharmacy
                            navigationPath.removeAll()
                        }
                    )
                }
            }
        }
    }
    
    @ViewBuilder
    private func content(for tab: AppTab) -> some View {
        switch tab {
        case .schedule:
            ScheduleView {
                navigationPath.append(.addVitamin)
            }
        case .pharmacy:
            PharmacyView {
                navigationPath.append(.addVitamin)
            }
        case .stats:
            StatsView()
        }
    }
}

// MARK: - Schedule
private struct ScheduleView: View {
    @StateObject private var viewModel = ScheduleViewModel()
    let onAdd: () -> Void
    private let sectionSpacing: CGFloat = 8

    var body: some View {
        ScrollViewReader { reader in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: sectionSpacing) {
                    Text("Расписание")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(Color(hex: "3B3B3B"))
                        .padding(.top, 8)

                    calendarStrip(reader: reader)
                        .padding(.horizontal, -24)

                    if viewModel.groupedReminders.isEmpty {
                        ScheduleEmptyState()
                    } else {
                        ForEach(viewModel.groupedReminders, id: \.part) { group in
                            DayPartSection(
                                part: group.part,
                                reminders: group.reminders
                            ) { reminder in
                                ReminderCard(
                                    reminder: reminder,
                                    onToggle: { viewModel.toggle(reminder) }
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 140) // keep above tab bar
            }
            .background(Color.white)
            .onAppear {
                viewModel.scrollProxy = reader
                viewModel.centerTodayWithoutAnimation()
            }
            .task {
                await viewModel.load()
            }
            .overlay(alignment: .bottomTrailing) {
                if viewModel.hasLoaded && !viewModel.hasAnyReminders {
                    FloatingPlusButton(action: onAdd)
                        .padding(.trailing, 30)
                        .padding(.bottom, 30)
                }
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
    @Published private(set) var hasLoaded = false
    @Published private(set) var hasAnyReminders = false
    var scrollProxy: ScrollViewProxy?

    private let repository: ReminderRepository
    private let calendar = Calendar.current
    private var remoteReminders: [ReminderRemote] = []
    private var takenReminderIDs: Set<String> = []
    private let serverDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    init(repository: ReminderRepository = ReminderRepository()) {
        self.repository = repository
    }

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

    struct DayPartGroup: Identifiable {
        let part: DayPart
        let reminders: [Reminder]
        var id: DayPart { part }
    }

    var groupedReminders: [DayPartGroup] {
        DayPart.allCases.compactMap { part in
            let items = remindersForSelectedDate.filter { dayPart(for: $0) == part }
            return items.isEmpty ? nil : DayPartGroup(part: part, reminders: items)
        }
    }

    @MainActor
    func load() async {
        hasLoaded = false
        do {
            remoteReminders = try await repository.fetchReminders()
            hasAnyReminders = remoteReminders.contains {
                $0.isActive && !($0.schedule?.times?.isEmpty ?? true)
            }
            rebuildReminders(for: selectedDate)
        } catch {
            remoteReminders = []
            reminders = []
            hasAnyReminders = false
        }
        hasLoaded = true
    }

    func select(_ date: Date) {
        selectedDate = date.startOfDay
        rebuildReminders(for: selectedDate)
        scrollTo(date)
    }

    func toggle(_ reminder: Reminder) {
        guard let index = reminders.firstIndex(where: { $0.id == reminder.id }) else { return }
        reminders[index].isTaken.toggle()

        if reminders[index].isTaken {
            takenReminderIDs.insert(reminder.id)
        } else {
            takenReminderIDs.remove(reminder.id)
        }
    }

    private func scrollToToday() {
        scrollTo(Date(), animated: false)
    }

    func centerTodayWithoutAnimation() {
        scrollToToday()
    }

    private func scrollTo(_ date: Date, animated: Bool = true) {
        if animated {
            scrollProxy?.scrollTo(date.startOfDay, anchor: .center)
            return
        }

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            scrollProxy?.scrollTo(date.startOfDay, anchor: .center)
        }
    }

    private func rebuildReminders(for day: Date) {
        let scheduleDay = day.startOfDay
        let scheduleDayID = isoDateString(for: scheduleDay)

        let mapped = remoteReminders
            .filter { $0.isActive }
            .filter { applies($0, to: scheduleDay) }
            .flatMap { remote -> [Reminder] in
                let intake = IntakeType(apiCondition: remote.condition)
                let validTimes = remote.schedule?.times?.filter { $0.minutesFromMidnight != nil } ?? []

                return validTimes.enumerated().map { index, time in
                    let id = "\(remote.id)-\(scheduleDayID)-\(time)-\(index)"
                    return Reminder(
                        id: id,
                        date: scheduleDay,
                        vitaminName: remote.name,
                        intakeType: intake,
                        time: time,
                        count: 1,
                        isTaken: takenReminderIDs.contains(id)
                    )
                }
            }
            .sorted { ($0.time.minutesFromMidnight ?? 0) < ($1.time.minutesFromMidnight ?? 0) }

        reminders = mapped
    }

    private func applies(_ remote: ReminderRemote, to day: Date) -> Bool {
        if let startDateString = remote.course?.startDate,
           let startDate = serverDateFormatter.date(from: startDateString),
           day < startDate.startOfDay {
            return false
        }

        let days = remote.schedule?.days?.map { $0.lowercased() } ?? []
        guard !days.isEmpty else { return true }
        guard let weekdayCode = WeekdayCode(date: day, calendar: calendar)?.rawValue else { return false }
        return days.contains(weekdayCode)
    }

    private func isoDateString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func dayPart(for reminder: Reminder) -> DayPart {
        guard let minutes = reminder.time.minutesFromMidnight else { return .morning }

        switch minutes {
        case 0...240: return .night          // 00:00 - 04:00
        case 241...720: return .morning      // 04:01 - 12:00
        case 721...960: return .day          // 12:01 - 16:00
        case 961...1439: return .evening     // 16:01 - 23:59
        default: return .morning
        }
    }
}

private enum DayPart: CaseIterable {
    case morning, day, evening, night

    var title: String {
        switch self {
        case .morning: return "Утро"
        case .day: return "День"
        case .evening: return "Вечер"
        case .night: return "Ночь"
        }
    }

    var icon: Image {
        switch self {
        case .morning: return Image("risingSun")
        case .day: return Image(systemName: "sun.max.fill")       // placeholder
        case .evening: return Image("moon")
        case .night: return Image(systemName: "moon.stars.fill")  // placeholder
        }
    }
}

private struct DayPartSection<Content: View>: View {
    let part: DayPart
    let reminders: [Reminder]
    let content: (Reminder) -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                part.icon
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                Text(part.title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color(hex: "3B3B3B"))
            }

            VStack(spacing: 8) {
                ForEach(reminders) { reminder in
                    content(reminder)
                }
            }
        }
    }
}

private struct ScheduleEmptyState: View {
    var body: some View {
        VStack(spacing: 24) {
            Image("calendar")
                .resizable()
                .scaledToFit()
                .frame(width: 142, height: 168.6234130859375)

            VStack(spacing: 20) {
                Text("В расписании пока ничего нет...")
                    .font(.custom("Commissioner-Regular", size: 15))
                    .foregroundColor(Color(hex: "3B3B3B").opacity(0.8))
                Text("Добавьте витамины в аптечку\nи отслеживайте каждый прием")
                    .multilineTextAlignment(.center)
                    .font(.custom("Commissioner-Regular", size: 15))
                    .foregroundColor(Color(hex: "3B3B3B").opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 48)
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

    private let linearBackground = LinearGradient(
        gradient: Gradient(stops: [
            .init(color: Color(hex: "2C86FF"), location: 0.0),
            .init(color: Color(hex: "4D92FF"), location: 0.45),
            .init(color: Color(hex: "8EC3DD"), location: 1.0)
        ]),
        startPoint: .leading,
        endPoint: .trailing
    )

    private let cardRadius: CGFloat = 18

    var body: some View {
        HStack(spacing: 14) {
            ToggleCircle(isOn: reminder.isTaken, action: onToggle)

            VStack(alignment: .leading, spacing: 6) {
                Text(reminder.vitaminName)
                    .font(.custom("Commissioner-Bold", size: 25))
                    .foregroundColor(.white)

                Text("\(reminder.intakeType.description) — \(reminder.time)")
                    .font(.custom("Commissioner-Medium", size: 18))
                    .foregroundColor(.black)
            }

            Spacer()

            VStack(spacing: 0) {
                Text("\(reminder.count)")
                    .font(.custom("Commissioner-Bold", size: 47.23))
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
            RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                .fill(linearBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                        .fill(Color.black.opacity(reminder.isTaken ? 0.28 : 0))
                )
                .shadow(color: Color.black.opacity(0.25), radius: 4, x: 0, y: 4)
        )
        .opacity(reminder.isTaken ? 0.68 : 1)
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

// MARK: - Models
private struct Reminder: Identifiable, Equatable {
    let id: String
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

private extension IntakeType {
    init(apiCondition: String?) {
        switch apiCondition?.lowercased() {
        case "before_meal":
            self = .beforeMeal
        case "during_meal":
            self = .duringMeal
        default:
            self = .afterMeal
        }
    }
}

private enum WeekdayCode: String {
    case mon
    case tue
    case wed
    case thu
    case fri
    case sat
    case sun

    init?(date: Date, calendar: Calendar) {
        switch calendar.component(.weekday, from: date) {
        case 1: self = .sun
        case 2: self = .mon
        case 3: self = .tue
        case 4: self = .wed
        case 5: self = .thu
        case 6: self = .fri
        case 7: self = .sat
        default: return nil
        }
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

private extension String {
    var minutesFromMidnight: Int? {
        let components = split(separator: ":")
        guard components.count == 2,
              let hours = Int(components[0]),
              let minutes = Int(components[1]) else { return nil }
        return hours * 60 + minutes
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
