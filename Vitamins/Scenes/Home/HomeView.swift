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
    case pharmacyDetails(Int)
    case editVitamin(reminderID: Int, draft: VitaminDraft)
    case editVitaminSchedule(reminderID: Int, draft: VitaminDraft)
    case editVitaminNotification(reminderID: Int, draft: VitaminDraft)
}

// MARK: - Home View with Custom Tab Bar
struct HomeView: View {
    var onLogout: (() -> Void)?
    @State private var selectedTab: AppTab = .pharmacy
    @State private var navigationPath: [HomeRoute] = []
    @StateObject private var scheduleViewModel = ScheduleViewModel()
    @StateObject private var notificationRouter = ReminderNotificationRouter.shared
    @State private var activeReminder: Reminder?
    @State private var actionInProgress = false
    @State private var actionErrorMessage: String?
    @State private var onboardingStep: HomeOnboardingStep?
    private let onboardingStorage = PostRegistrationOnboardingStorage()
    
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
                        onLogout: onLogout
                    )
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    HStack(spacing: 0) {
                        Spacer(minLength: 0)
                        AppTabBar(selectedTab: $selectedTab) { tab in
                            guard onboardingStep == nil else {
                                if selectedTab != .pharmacy {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                        selectedTab = .pharmacy
                                        activeReminder = nil
                                    }
                                }
                                return
                            }
                            guard tab != selectedTab else { return }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                if tab != .schedule {
                                    activeReminder = nil
                                }
                                selectedTab = tab
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 0)
                    .padding(.bottom, 12)
                }
                .overlay {
                    if selectedTab == .schedule, let reminder = activeReminder {
                        ReminderActionOverlay(
                            reminder: reminder,
                            isSubmitting: actionInProgress,
                            primaryButtonTitle: reminder.isTaken ? "Снять прием" : "Отметить прием",
                            showsSnoozeButtons: !reminder.isTaken,
                            onDismiss: {
                                guard !actionInProgress else { return }
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    activeReminder = nil
                                }
                            },
                            onPrimaryAction: {
                                handlePopupAction(reminder.isTaken ? .unmarkTaken : .markTaken, for: reminder)
                            },
                            onSnooze15: {
                                handlePopupAction(.snooze(minutes: 15), for: reminder)
                            },
                            onSnooze60: {
                                handlePopupAction(.snooze(minutes: 60), for: reminder)
                            }
                        )
                        .transition(.opacity)
                    }
                }
                .overlay {
                    if let onboardingStep {
                        HomeOnboardingOverlay(
                            step: onboardingStep,
                            onClose: dismissOnboarding,
                            onNext: goToNextOnboardingStep,
                            onPrevious: goToPreviousOnboardingStep
                        )
                        .transition(.opacity)
                    }
                }
                .alert("Ошибка", isPresented: actionErrorBinding) {
                    Button("Ок", role: .cancel) {
                        actionErrorMessage = nil
                    }
                } message: {
                    Text(actionErrorMessage ?? "Не удалось обновить напоминание")
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
                        },
                        onTabRequested: { tab in
                            handleTabSelectionFromFlow(tab)
                        },
                        isEditing: false
                    )
                case .addVitaminSchedule(let draft):
                    AddVitaminScheduleView(
                        selectedTab: $selectedTab,
                        draft: draft,
                        onNext: { updatedDraft in
                            navigationPath.append(.addVitaminNotification(updatedDraft))
                        },
                        onTabRequested: { tab in
                            handleTabSelectionFromFlow(tab)
                        },
                        isEditing: false
                    )
                case .addVitaminNotification(let draft):
                    AddVitaminNotificationView(
                        selectedTab: $selectedTab,
                        draft: draft,
                        onAdded: {
                            selectedTab = .pharmacy
                            navigationPath.removeAll()
                        },
                        onTabRequested: { tab in
                            handleTabSelectionFromFlow(tab)
                        },
                        isEditing: false
                    )
                case .pharmacyDetails(let reminderID):
                    PharmacyVitaminDetailsView(
                        selectedTab: $selectedTab,
                        reminderID: reminderID,
                        onConfigure: { draft, id in
                            navigationPath.append(.editVitamin(reminderID: id, draft: draft))
                        },
                        onTabRequested: { tab in
                            handleTabSelectionFromFlow(tab)
                        }
                    )
                case .editVitamin(let reminderID, let draft):
                    AddVitaminView(
                        selectedTab: $selectedTab,
                        onNext: { updatedDraft in
                            navigationPath.append(.editVitaminSchedule(reminderID: reminderID, draft: updatedDraft))
                        },
                        onTabRequested: { tab in
                            handleTabSelectionFromFlow(tab)
                        },
                        initialDraft: draft,
                        isEditing: true
                    )
                case .editVitaminSchedule(let reminderID, let draft):
                    AddVitaminScheduleView(
                        selectedTab: $selectedTab,
                        draft: draft,
                        onNext: { updatedDraft in
                            navigationPath.append(.editVitaminNotification(reminderID: reminderID, draft: updatedDraft))
                        },
                        onTabRequested: { tab in
                            handleTabSelectionFromFlow(tab)
                        },
                        isEditing: true
                    )
                case .editVitaminNotification(let reminderID, let draft):
                    AddVitaminNotificationView(
                        selectedTab: $selectedTab,
                        draft: draft,
                        reminderID: reminderID,
                        onAdded: {
                            selectedTab = .pharmacy
                            navigationPath.removeAll()
                        },
                        onTabRequested: { tab in
                            handleTabSelectionFromFlow(tab)
                        },
                        isEditing: true
                    )
                }
            }
            .task {
                await ReminderNotificationScheduler.shared.requestAuthorizationIfNeeded()
                await syncLocalNotifications()
                if let context = notificationRouter.pendingContext {
                    handleOpenReminderFromNotification(context)
                }
                await MainActor.run {
                    showOnboardingIfNeeded()
                }
            }
            .onReceive(notificationRouter.$pendingContext.compactMap { $0 }) { context in
                handleOpenReminderFromNotification(context)
            }
        }
    }
    
    @ViewBuilder
    private func content(for tab: AppTab) -> some View {
        switch tab {
        case .schedule:
            ScheduleView(
                viewModel: scheduleViewModel,
                onAdd: {
                    navigationPath.append(.addVitamin)
                },
                onReminderLongPress: { reminder in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                        activeReminder = reminder
                    }
                }
            )
        case .pharmacy:
            PharmacyView(
                onAdd: {
                    navigationPath.append(.addVitamin)
                },
                onOpenReminder: { reminderID in
                    navigationPath.append(.pharmacyDetails(reminderID))
                }
            )
        case .stats:
            StatsView()
        }
    }

    private var actionErrorBinding: Binding<Bool> {
        Binding(
            get: { actionErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    actionErrorMessage = nil
                }
            }
        )
    }

    private func handlePopupAction(_ action: ReminderAction, for reminder: Reminder) {
        guard !actionInProgress else { return }
        actionInProgress = true
        actionErrorMessage = nil

        Task {
            do {
                try await scheduleViewModel.apply(action: action, to: reminder)
                await MainActor.run {
                    actionInProgress = false
                    withAnimation(.easeInOut(duration: 0.2)) {
                        activeReminder = nil
                    }
                }
            } catch {
                await MainActor.run {
                    actionInProgress = false
                    actionErrorMessage = "Не удалось обновить напоминание. Попробуйте снова."
                }
            }
        }
    }

    private func syncLocalNotifications() async {
        guard let reminders = try? await ReminderRepository().fetchReminders() else { return }
        await ReminderNotificationScheduler.shared.schedule(from: reminders)
    }

    private func handleTabSelectionFromFlow(_ tab: AppTab) {
        UIApplication.shared.endEditing()
        activeReminder = nil
        actionInProgress = false
        actionErrorMessage = nil
        navigationPath.removeAll()

        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            selectedTab = tab
        }
    }

    private func handleOpenReminderFromNotification(_ context: ReminderOpenContext) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            selectedTab = .schedule
        }

        Task {
            let reminder = await scheduleViewModel.revealReminderFromNotification(
                reminderID: context.reminderID,
                preferredTime: context.preferredTime
            )

            await MainActor.run {
                if let reminder {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        activeReminder = reminder
                    }
                }
                notificationRouter.consume()
            }
        }
    }

    private func showOnboardingIfNeeded() {
        guard onboardingStep == nil, onboardingStorage.shouldPresentOnboarding else { return }
        setOnboardingStep(.schedule)
    }

    private func dismissOnboarding() {
        onboardingStorage.markCompleted()
        withAnimation(.easeInOut(duration: 0.2)) {
            onboardingStep = nil
        }
    }

    private func goToNextOnboardingStep() {
        guard let current = onboardingStep else { return }
        guard let next = current.next else {
            dismissOnboarding()
            return
        }
        setOnboardingStep(next)
    }

    private func goToPreviousOnboardingStep() {
        guard let current = onboardingStep, let previous = current.previous else { return }
        setOnboardingStep(previous)
    }

    private func setOnboardingStep(_ step: HomeOnboardingStep) {
        withAnimation(.easeInOut(duration: 0.2)) {
            onboardingStep = step
            selectedTab = .pharmacy
            activeReminder = nil
        }
    }
}

private enum HomeOnboardingStep: Int, CaseIterable {
    case schedule
    case pharmacy
    case stats
    case profile

    var title: String {
        switch self {
        case .schedule: return "Расписание:"
        case .pharmacy: return "Аптечка:"
        case .stats: return "Статистика:"
        case .profile: return "Профиль:"
        }
    }

    var message: String {
        switch self {
        case .schedule:
            return "Здесь можно посмотреть и отредактировать расписание приема витаминов"
        case .pharmacy:
            return "Здесь будут все ваши витамины и информация о них, которую вы можете редактировать"
        case .stats:
            return "Здесь можно посмотреть на статистику приема витаминов за определенный период"
        case .profile:
            return "Здесь можно настроить вид приложения, напоминания и управлять аккаунтом"
        }
    }

    var imageName: String {
        switch self {
        case .schedule: return "onBoarding1"
        case .pharmacy: return "onBoarding2"
        case .stats: return "onBoarding3"
        case .profile: return "onBoarding4"
        }
    }

    var highlightedTab: AppTab? {
        .pharmacy
    }

    var progressText: String {
        "\(rawValue + 1)/\(Self.allCases.count)"
    }

    var next: HomeOnboardingStep? {
        HomeOnboardingStep(rawValue: rawValue + 1)
    }

    var previous: HomeOnboardingStep? {
        HomeOnboardingStep(rawValue: rawValue - 1)
    }
}

private struct HomeOnboardingOverlay: View {
    let step: HomeOnboardingStep
    let onClose: () -> Void
    let onNext: () -> Void
    let onPrevious: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: proxy.safeAreaInsets.top + 72)

                    Color(
                        red: 251.0 / 255.0,
                        green: 251.0 / 255.0,
                        blue: 251.0 / 255.0
                    )
                    .opacity(0.9)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    Color.clear
                        .frame(height: proxy.safeAreaInsets.bottom + 68)
                }
                .ignoresSafeArea()

                switch step {
                case .schedule:
                    VStack {
                        Spacer()
                        HStack(spacing: 16) {
                            HomeOnboardingBubble(step: step)
                            OnboardingCircleButton(
                                imageName: "backButton",
                                rotation: .degrees(180),
                                action: onNext
                            )
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 100)
                    }
                case .pharmacy:
                    VStack {
                        Spacer()
                        HStack(spacing: 14) {
                            OnboardingCircleButton(imageName: "backButton", action: onPrevious)
                            HomeOnboardingBubble(step: step)
                            OnboardingCircleButton(
                                imageName: "backButton",
                                rotation: .degrees(180),
                                action: onNext
                            )
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 100)
                    }
                case .stats:
                    VStack {
                        Spacer()
                        HStack(spacing: 14) {
                            OnboardingCircleButton(imageName: "backButton", action: onPrevious)
                            HomeOnboardingBubble(step: step)
                            OnboardingCircleButton(
                                imageName: "backButton",
                                rotation: .degrees(180),
                                action: onNext
                            )
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 100)
                    }
                case .profile:
                    VStack {
                        Color.clear
                            .frame(height: max(proxy.safeAreaInsets.top + 28, 74))
                        HStack(spacing: 14) {
                            OnboardingCircleButton(imageName: "backButton", action: onPrevious)
                            HomeOnboardingBubble(step: step)
                            OnboardingCircleButton(
                                imageName: "markOnboarding",
                                iconSize: 26,
                                tint: .black,
                                action: onClose
                            )
                        }
                        .padding(.horizontal, 8)
                        .offset(x: -4)
                        Spacer()
                    }
                }

                if step != .profile {
                    VStack {
                        HStack {
                            Button(action: onClose) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(.black)
                                    .frame(width: 36, height: 36)
                                    .background(Circle().fill(Color.white))
                                    .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 2)
                            }
                            .buttonStyle(.plain)
                            .padding(.leading, 16)
                            .padding(.top, proxy.safeAreaInsets.top + 8)
                            Spacer()
                        }
                        Spacer()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {}
        }
    }
}

private struct HomeOnboardingBubble: View {
    let step: HomeOnboardingStep

    var body: some View {
        ZStack(alignment: .topLeading) {
            Image(step.imageName)
                .resizable()
                .renderingMode(.original)
                .scaledToFit()

            VStack(alignment: .leading, spacing: 11) {
                Text(step.title)
                    .font(.custom("Commissioner-SemiBold", size: 16))
                    .foregroundStyle(.black)
                    .lineLimit(1)

                Text(step.message)
                    .font(.custom("Commissioner-Regular", size: 13.54))
                    .foregroundStyle(.black)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack {
                    Spacer()
                    Text(step.progressText)
                        .font(.custom("Commissioner-Regular", size: 16.38))
                        .foregroundStyle(.black)
                        .offset(y: (step == .schedule || step == .profile) ? -6 : 0)
                }
            }
            .padding(.horizontal, 15)
            .padding(.top, step == .profile ? 36 : 17)
            .padding(.bottom, 12)
            .padding(.leading, step == .schedule ? 8 : (step == .profile ? 2 : 0))
            .padding(.trailing, step == .profile ? 6 : 0)
        }
        .frame(width: step == .profile ? 248 : 246)
    }
}

private struct OnboardingCircleButton: View {
    let imageName: String
    var rotation: Angle = .zero
    var iconSize: CGFloat = 22
    var tint: Color? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 46, height: 46)
                    .shadow(color: .black.opacity(0.16), radius: 8, x: 0, y: 4)

                Group {
                    if let tint {
                        Image(imageName)
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                            .frame(width: iconSize, height: iconSize)
                            .foregroundStyle(tint)
                    } else {
                        Image(imageName)
                            .resizable()
                            .renderingMode(.original)
                            .scaledToFit()
                            .frame(width: iconSize, height: iconSize)
                    }
                }
                .rotationEffect(rotation)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Schedule
enum TodayDirection {
    case left, right
}

private struct VisibleDayPreferenceKey: PreferenceKey {
    static var defaultValue: [VisibleDayInfo] = []
    static func reduce(value: inout [VisibleDayInfo], nextValue: () -> [VisibleDayInfo]) {
        value.append(contentsOf: nextValue())
    }
}

private struct VisibleDayInfo: Equatable {
    let date: Date
    let minX: CGFloat
    let maxX: CGFloat
}

private struct MonthCalendarHeader: View {
    let month: Date

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "LLLL yyyy"
        return f
    }()

    var body: some View {
        Text(Self.formatter.string(from: month).capitalized)
            .font(.custom("Commissioner-Regular", size: 14))
            .foregroundColor(Color(hex: "8C8C8C"))
            .animation(.easeInOut(duration: 0.2), value: month)
    }
}

private struct TodayJumpButton: View {
    enum Direction { case left, right }
    let direction: Direction
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text("Сегодня")
                    .font(.custom("Commissioner-SemiBold", size: 14))
                Image(systemName: direction == .right ? "arrow.right" : "arrow.left")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(hex: "0773F1"))
            .clipShape(Capsule())
            .shadow(color: Color(hex: "0773F1").opacity(0.3), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
    }
}

private struct ScheduleView: View {
    @ObservedObject var viewModel: ScheduleViewModel
    let onAdd: () -> Void
    let onReminderLongPress: (Reminder) -> Void
    private let sectionSpacing: CGFloat = 8
    private let calendarSpaceName = "calendarStrip"

    var body: some View {
        ScrollViewReader { reader in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: sectionSpacing) {
                    Text("Расписание")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(Color(hex: "3B3B3B"))
                        .padding(.top, 8)

                    HStack(alignment: .center, spacing: 8) {
                        MonthCalendarHeader(month: viewModel.visibleMonth)
                        Spacer(minLength: 8)
                        if !viewModel.isTodayVisible {
                            TodayJumpButton(direction: viewModel.todayDirection == .right ? .right : .left) {
                                withAnimation(.easeInOut(duration: 0.4)) {
                                    viewModel.select(Date().startOfDay)
                                }
                            }
                            .transition(.opacity)
                        }
                    }
                    .frame(height: 34)
                    .animation(.easeInOut(duration: 0.2), value: viewModel.isTodayVisible)

                    calendarStrip(reader: reader)
                        .padding(.horizontal, -24)

                    if !viewModel.hasLoaded {
                        ScheduleLoadingState()
                    } else if viewModel.groupedReminders.isEmpty {
                        ScheduleEmptyState()
                    } else {
                        ForEach(viewModel.groupedReminders, id: \.part) { group in
                            DayPartSection(
                                part: group.part,
                                reminders: group.reminders
                            ) { reminder in
                                ReminderCard(
                                    reminder: reminder,
                                    onToggle: { viewModel.toggle(reminder) },
                                    onLongPress: { onReminderLongPress(reminder) }
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
                            viewModel.select(day)
                        }
                    )
                    .id(day)
                    .background(
                        GeometryReader { proxy in
                            let frame = proxy.frame(in: .named(calendarSpaceName))
                            Color.clear
                                .preference(
                                    key: VisibleDayPreferenceKey.self,
                                    value: [VisibleDayInfo(date: day, minX: frame.minX, maxX: frame.maxX)]
                                )
                        }
                    )
                }
            }
            .padding(.vertical, 6)
        }
        .coordinateSpace(name: calendarSpaceName)
        .onPreferenceChange(VisibleDayPreferenceKey.self) { entries in
            updateVisibility(from: entries)
        }
    }

    private func updateVisibility(from entries: [VisibleDayInfo]) {
        guard !entries.isEmpty else { return }
        let screenWidth = UIScreen.main.bounds.width
        let visible = entries
            .filter { $0.maxX > 0 && $0.minX < screenWidth }
            .sorted { $0.minX < $1.minX }
        guard let first = visible.first else { return }
        viewModel.updateVisibleDay(first.date)

        let today = Date().startOfDay
        let todayInfo = entries.first { Calendar.current.isDate($0.date, inSameDayAs: today) }
        let todayVisible = todayInfo.map { $0.maxX > 0 && $0.minX < screenWidth } ?? false
        viewModel.setTodayVisibility(todayVisible)

        if !todayVisible, let todayInfo {
            viewModel.updateTodayDirection(todayInfo.minX >= screenWidth ? .right : .left)
        }
    }
}

private enum ReminderAction {
    case markTaken
    case unmarkTaken
    case snooze(minutes: Int)
}

private final class ScheduleViewModel: ObservableObject {
    @Published var selectedDate: Date = Date().startOfDay
    @Published var reminders: [Reminder] = []
    @Published private(set) var hasLoaded = false
    @Published private(set) var hasAnyReminders = false
    @Published var visibleMonth: Date = Date().startOfDay
    @Published var isTodayVisible: Bool = true
    @Published var todayDirection: TodayDirection = .right
    var scrollProxy: ScrollViewProxy?

    private let repository: ReminderRepository
    private let completionStorage: ReminderCompletionStorage
    private let notificationScheduler: ReminderNotificationScheduler
    private let snoozeStorage: ReminderSnoozeStorage
    private let calendar = Calendar.current
    private var remoteReminders: [ReminderRemote] = []
    private var takenReminderIDs: Set<String> = []
    private var suppressionToken: Int = 0
    private var isSuppressingVisibility: Bool = false
    private let serverDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    init(
        repository: ReminderRepository = ReminderRepository(),
        completionStorage: ReminderCompletionStorage = ReminderCompletionStorage(),
        notificationScheduler: ReminderNotificationScheduler = .shared,
        snoozeStorage: ReminderSnoozeStorage = ReminderSnoozeStorage()
    ) {
        self.repository = repository
        self.completionStorage = completionStorage
        self.notificationScheduler = notificationScheduler
        self.snoozeStorage = snoozeStorage
        self.takenReminderIDs = completionStorage.load()
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
        takenReminderIDs = completionStorage.load()
        do {
            remoteReminders = try await repository.fetchReminders()
            hasAnyReminders = remoteReminders.contains {
                $0.isActive && !($0.schedule?.times?.isEmpty ?? true)
            }
            await notificationScheduler.schedule(from: remoteReminders, overrides: snoozeStorage.load())
            rebuildReminders(for: selectedDate)
        } catch {
            remoteReminders = []
            reminders = []
            hasAnyReminders = false
        }
        hasLoaded = true
    }

    @MainActor
    func revealReminderFromNotification(reminderID: Int, preferredTime: String?) async -> Reminder? {
        if remoteReminders.isEmpty {
            do {
                remoteReminders = try await repository.fetchReminders()
                hasAnyReminders = remoteReminders.contains {
                    $0.isActive && !($0.schedule?.times?.isEmpty ?? true)
                }
            } catch {
                return nil
            }
        }

        let today = Date().startOfDay
        selectedDate = today
        rebuildReminders(for: today)

        if let preferredTime, let normalized = canonicalTime(preferredTime) {
            if let exact = reminders.first(where: { $0.remoteID == reminderID && canonicalTime($0.time) == normalized }) {
                return exact
            }
        }

        return reminders.first(where: { $0.remoteID == reminderID })
    }

    func select(_ date: Date) {
        let day = date.startOfDay

        // Данные/выделение — без анимации, чтобы пилюли и карточки не делали crossfade.
        var noAnim = Transaction()
        noAnim.disablesAnimations = true
        withTransaction(noAnim) {
            selectedDate = day
            rebuildReminders(for: selectedDate)

            let today = Date().startOfDay
            let selectedIsToday = calendar.isDate(day, inSameDayAs: today)
            if isTodayVisible != selectedIsToday {
                isTodayVisible = selectedIsToday
            }
            if !selectedIsToday {
                todayDirection = day > today ? .left : .right
            }
        }

        // Скролл ленты — анимированно.
        withAnimation(.easeInOut(duration: 0.3)) {
            scrollProxy?.scrollTo(day, anchor: .center)
        }

        suppressionToken += 1
        let token = suppressionToken
        isSuppressingVisibility = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { [weak self] in
            guard let self else { return }
            if self.suppressionToken == token {
                self.isSuppressingVisibility = false
            }
        }
    }

    func updateVisibleDay(_ date: Date) {
        let day = date.startOfDay
        if !calendar.isDate(day, equalTo: visibleMonth, toGranularity: .month) {
            visibleMonth = day
        }
    }

    func setTodayVisibility(_ visible: Bool) {
        guard !isSuppressingVisibility else { return }
        guard isTodayVisible != visible else { return }
        isTodayVisible = visible
    }

    func updateTodayDirection(_ direction: TodayDirection) {
        guard !isSuppressingVisibility else { return }
        todayDirection = direction
    }

    func toggle(_ reminder: Reminder) {
        guard let index = reminders.firstIndex(where: { $0.id == reminder.id }) else { return }
        let wasTaken = reminders[index].isTaken
        let willBeTaken = !wasTaken

        reminders[index].isTaken = willBeTaken
        if willBeTaken {
            takenReminderIDs.insert(reminder.id)
        } else {
            takenReminderIDs.remove(reminder.id)
        }
        persistTakenReminderIDs()

        Task { [weak self] in
            await self?.syncIntake(for: reminder, markTaken: willBeTaken)
        }
    }

    @MainActor
    private func syncIntake(for reminder: Reminder, markTaken: Bool) async {
        guard let remote = remoteReminders.first(where: { $0.id == reminder.remoteID }) else { return }
        let scheduledFor = ReminderTimeFormatters.makeRFC3339(
            date: reminder.date,
            time: reminder.time,
            timezoneID: remote.course?.timezone
        )

        do {
            if markTaken {
                _ = try await repository.markIntake(reminderID: remote.id, scheduledFor: scheduledFor)
            } else {
                try await repository.unmarkIntake(reminderID: remote.id, scheduledFor: scheduledFor)
            }
        } catch {
            // Локальный флаг оставляем — оптимистично.
        }
    }

    @MainActor
    func apply(action: ReminderAction, to reminder: Reminder) async throws {
        guard let remoteIndex = remoteReminders.firstIndex(where: { $0.id == reminder.remoteID }) else {
            return
        }
        let remote = remoteReminders[remoteIndex]

        switch action {
        case .markTaken:
            takenReminderIDs.insert(reminder.id)
            persistTakenReminderIDs()
            await syncIntake(for: reminder, markTaken: true)
        case .unmarkTaken:
            takenReminderIDs.remove(reminder.id)
            persistTakenReminderIDs()
            await syncIntake(for: reminder, markTaken: false)
        case .snooze(let minutes):
            try await applySnooze(minutes: minutes, reminder: reminder, remote: remote)
        }

        rebuildReminders(for: selectedDate)
    }

    @MainActor
    private func applySnooze(minutes: Int, reminder: Reminder, remote: ReminderRemote) async throws {
        let timezoneID = remote.course?.timezone
        let originalSlotDate = canonicalSourceDate(for: reminder, timezoneID: timezoneID)
        let originalSlotTime = canonicalSourceTime(for: reminder)
        let scheduledFor = ReminderTimeFormatters.makeRFC3339(
            date: originalSlotDate,
            time: originalSlotTime,
            timezoneID: timezoneID
        )

        let response = try await repository.snoozeOccurrence(
            id: remote.id,
            scheduledFor: scheduledFor,
            minutes: minutes
        )

        guard let snoozedUntilDate = ReminderTimeFormatters.parseRFC3339(response.snoozedUntil) else { return }

        let scheduledDateString = ReminderTimeFormatters.slotDateString(snoozedUntilDate, timezoneID: timezoneID)
        let scheduledTimeString = ReminderTimeFormatters.slotTimeString(snoozedUntilDate, timezoneID: timezoneID)
        let sourceDateString = ReminderTimeFormatters.slotDateString(originalSlotDate, timezoneID: timezoneID)

        var overrides = snoozeStorage.load()
        let entry = ReminderSnoozeEntry(
            reminderID: remote.id,
            sourceDate: sourceDateString,
            sourceTime: originalSlotTime,
            sourceIndex: max(reminder.scheduleTimeIndex, 0),
            scheduledDate: scheduledDateString,
            scheduledTime: scheduledTimeString
        )
        overrides[entry.occurrenceID] = entry
        snoozeStorage.save(overrides)

        await notificationScheduler.schedule(from: remoteReminders, overrides: overrides)
    }

    private func canonicalSourceDate(for reminder: Reminder, timezoneID: String?) -> Date {
        let overrides = snoozeStorage.load()
        let candidate = ReminderSnoozeEntry.makeOccurrenceID(
            reminderID: reminder.remoteID,
            sourceDate: ReminderTimeFormatters.slotDateString(reminder.date, timezoneID: timezoneID),
            sourceTime: canonicalSourceTime(for: reminder),
            sourceIndex: max(reminder.scheduleTimeIndex, 0)
        )
        if overrides[candidate] != nil {
            return reminder.date
        }
        return reminder.date
    }

    private func canonicalSourceTime(for reminder: Reminder) -> String {
        canonicalTime(reminder.time) ?? reminder.time
    }

    func centerTodayWithoutAnimation() {
        let today = Date().startOfDay
        selectedDate = today
        rebuildReminders(for: today)
        scrollTo(today, animated: false)
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

        let overrides = pruneExpiredOverrides(snoozeStorage.load())
        let overridesByOccurrence = overrides
        let movedInToday: [String: ReminderSnoozeEntry] = Dictionary(
            uniqueKeysWithValues: overrides.values
                .filter { $0.scheduledDate == scheduleDayID && $0.sourceDate != scheduleDayID }
                .map { ($0.occurrenceID, $0) }
        )

        var mapped = remoteReminders
            .filter { $0.isActive }
            .filter { applies($0, to: scheduleDay) }
            .flatMap { remote -> [Reminder] in
                let intake = IntakeType(apiCondition: remote.condition)
                let validTimes = normalizedTimes(remote.schedule?.times, fallback: nil)
                let displayName = resolvedVitaminName(for: remote)
                let doseCount = resolvedDoseCount(for: remote)
                let timesCount = max(1, validTimes.count)
                let infoItems = reminderInfoItems(for: remote, timesCount: timesCount)

                return validTimes.enumerated().compactMap { index, time in
                    let canonicalSourceTime = canonicalTime(time) ?? time
                    let canonicalID = "\(remote.id)-\(scheduleDayID)-\(canonicalSourceTime)-\(index)"
                    let occurrenceID = ReminderSnoozeEntry.makeOccurrenceID(
                        reminderID: remote.id,
                        sourceDate: scheduleDayID,
                        sourceTime: canonicalSourceTime,
                        sourceIndex: index
                    )

                    if let override = overridesByOccurrence[occurrenceID] {
                        if override.scheduledDate != scheduleDayID {
                            return nil
                        }
                        return Reminder(
                            id: canonicalID,
                            remoteID: remote.id,
                            scheduleTimeIndex: index,
                            date: scheduleDay,
                            vitaminName: displayName,
                            intakeType: intake,
                            time: override.scheduledTime,
                            count: doseCount,
                            infoItems: infoItems,
                            isTaken: takenReminderIDs.contains(canonicalID)
                        )
                    }

                    return Reminder(
                        id: canonicalID,
                        remoteID: remote.id,
                        scheduleTimeIndex: index,
                        date: scheduleDay,
                        vitaminName: displayName,
                        intakeType: intake,
                        time: time,
                        count: doseCount,
                        infoItems: infoItems,
                        isTaken: takenReminderIDs.contains(canonicalID)
                    )
                }
            }

        for entry in movedInToday.values {
            guard let remote = remoteReminders.first(where: { $0.id == entry.reminderID }) else { continue }
            let intake = IntakeType(apiCondition: remote.condition)
            let displayName = resolvedVitaminName(for: remote)
            let doseCount = resolvedDoseCount(for: remote)
            let timesCount = max(1, normalizedTimes(remote.schedule?.times, fallback: nil).count)
            let infoItems = reminderInfoItems(for: remote, timesCount: timesCount)
            let canonicalID = "\(remote.id)-\(entry.sourceDate)-\(entry.sourceTime)-\(entry.sourceIndex)"
            mapped.append(
                Reminder(
                    id: canonicalID,
                    remoteID: remote.id,
                    scheduleTimeIndex: entry.sourceIndex,
                    date: scheduleDay,
                    vitaminName: displayName,
                    intakeType: intake,
                    time: entry.scheduledTime,
                    count: doseCount,
                    infoItems: infoItems,
                    isTaken: takenReminderIDs.contains(canonicalID)
                )
            )
        }

        mapped.sort { ($0.time.minutesFromMidnight ?? 0) < ($1.time.minutesFromMidnight ?? 0) }
        reminders = mapped
    }

    private func pruneExpiredOverrides(_ overrides: [String: ReminderSnoozeEntry]) -> [String: ReminderSnoozeEntry] {
        let todayString = isoDateString(for: Date().startOfDay)
        let live = overrides.filter { $0.value.scheduledDate >= todayString }
        if live.count != overrides.count {
            snoozeStorage.save(live)
        }
        return live
    }

    private func makeUpdateRequest(from remote: ReminderRemote, fallbackTime: String) -> CreateVitaminReminderRequest {
        let scheduleTimes = normalizedTimes(remote.schedule?.times, fallback: fallbackTime)
        let scheduleDays = (remote.schedule?.days?.map { $0.lowercased() }).flatMap { $0.isEmpty ? nil : $0 }
            ?? WeekdayCode.allCases.map(\.rawValue)

        return CreateVitaminReminderRequest(
            catalogID: remote.catalogID,
            name: remote.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : remote.name,
            form: remote.form?.nonEmpty ?? "capsule",
            dose: remote.dose?.nonEmpty ?? "1",
            condition: remote.condition?.nonEmpty ?? "any",
            note: remote.note ?? "",
            course: .init(
                startDate: remote.course?.startDate ?? isoDateString(for: selectedDate),
                endDate: remote.course?.endDate,
                timezone: remote.course?.timezone ?? TimeZone.current.identifier
            ),
            schedule: .init(
                days: scheduleDays,
                times: scheduleTimes
            ),
            notificationPreferences: .init(
                includeDose: remote.notificationPreferences?.includeDose ?? true,
                includeFrequency: remote.notificationPreferences?.includeFrequency ?? true,
                includeInteraction: remote.notificationPreferences?.includeInteraction ?? true,
                includeCompatibility: remote.notificationPreferences?.includeCompatibility ?? true,
                includeCondition: remote.notificationPreferences?.includeCondition ?? true,
                includeContraindications: remote.notificationPreferences?.includeContraindications ?? true
            ),
            contentOverrides: .init(
                interactionTextOverride: remote.contentOverrides?.interactionTextOverride,
                compatibilityTextOverride: remote.contentOverrides?.compatibilityTextOverride,
                contraindicationsTextOverride: remote.contentOverrides?.contraindicationsTextOverride
            )
        )
    }

    private func resolvedVitaminName(for remote: ReminderRemote) -> String {
        if let title = remote.catalog?.displayName?.nonEmpty {
            return title
        }
        if let name = remote.name.nonEmpty {
            return name
        }
        return "Витамин"
    }

    private func reminderInfoItems(for remote: ReminderRemote, timesCount: Int) -> [ReminderInfoItem] {
        let preferences = remote.notificationPreferences
        var items: [ReminderInfoItem] = []

        if preferences?.includeDose ?? true {
            items.append(.init(id: "dose", title: "Доза за прием", text: resolvedDosePerIntakeText(for: remote)))
        }

        if preferences?.includeFrequency ?? true {
            items.append(.init(id: "frequency", title: "Частота", text: resolvedFrequencyText(timesCount: timesCount)))
        }

        if let note = resolvedNoteText(for: remote) {
            items.append(.init(id: "note", title: "Примечание", text: note))
        }

        if preferences?.includeCondition ?? true {
            items.append(.init(id: "condition", title: "Условие", text: resolvedConditionText(for: remote)))
        }

        if preferences?.includeInteraction ?? true {
            items.append(.init(id: "interaction", title: "Взаимодействие", text: resolvedInteractionText(for: remote)))
        }

        if preferences?.includeCompatibility ?? true {
            items.append(.init(id: "compatibility", title: "Совместимость", text: resolvedCompatibilityText(for: remote)))
        }

        if preferences?.includeContraindications ?? true {
            items.append(.init(id: "contraindications", title: "Противопоказания", text: resolvedContraindicationsText(for: remote)))
        }

        return items
    }

    private func resolvedDosePerIntakeText(for remote: ReminderRemote) -> String {
        remote.dose?.nonEmpty ?? "1 капсула"
    }

    private func resolvedFrequencyText(timesCount: Int) -> String {
        frequencyDescription(for: timesCount)
    }

    private func resolvedDoseCount(for remote: ReminderRemote) -> Int {
        let source = remote.dose?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let digits = source.filter(\.isNumber)
        return Int(digits) ?? 1
    }

    private func resolvedConditionText(for remote: ReminderRemote) -> String {
        humanConditionDescription(remote.condition) ?? "Следуйте рекомендациям по приему."
    }

    private func resolvedNoteText(for remote: ReminderRemote) -> String? {
        remote.note?.nonEmpty
    }

    private func resolvedInteractionText(for remote: ReminderRemote) -> String {
        remote.contentOverrides?.interactionTextOverride?.nonEmpty
            ?? remote.catalog?.interactionText?.nonEmpty
            ?? "Нет данных о взаимодействии."
    }

    private func resolvedCompatibilityText(for remote: ReminderRemote) -> String {
        remote.contentOverrides?.compatibilityTextOverride?.nonEmpty
            ?? remote.catalog?.compatibilityText?.nonEmpty
            ?? "Нет данных о совместимости."
    }

    private func resolvedContraindicationsText(for remote: ReminderRemote) -> String {
        remote.contentOverrides?.contraindicationsTextOverride?.nonEmpty
            ?? remote.catalog?.contraindicationsText?.nonEmpty
            ?? "Нет данных о противопоказаниях."
    }

    private func humanConditionDescription(_ condition: String?) -> String? {
        switch condition?.lowercased() {
        case "before_meal":
            return "Принимать до еды."
        case "after_meal":
            return "Принимать после еды."
        case "during_meal":
            return "Принимать во время еды."
        case "any":
            return "Время приема неважно."
        default:
            return nil
        }
    }

    private func frequencyDescription(for count: Int) -> String {
        switch count {
        case 1:
            return "1 раз в день"
        case 2, 3, 4:
            return "\(count) раза в день"
        default:
            return "\(count) раз в день"
        }
    }

    private func canonicalTime(_ raw: String) -> String? {
        guard let totalMinutes = raw.minutesFromMidnight else { return nil }
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return String(format: "%02d:%02d", hours, minutes)
    }

    private func normalizedTimes(_ rawTimes: [String]?, fallback: String?) -> [String] {
        let source = (rawTimes ?? []).compactMap(canonicalTime)
        var unique: [String] = []
        var seen = Set<String>()

        for time in source where seen.insert(time).inserted {
            unique.append(time)
        }

        if unique.isEmpty, let fallback, let normalized = canonicalTime(fallback) {
            unique = [normalized]
        }

        return unique
    }

    private func shiftedTime(_ time: String, by minutes: Int) -> String {
        guard let base = time.minutesFromMidnight else { return time }
        let total = (base + minutes + 1440) % 1440
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    private func persistTakenReminderIDs() {
        completionStorage.save(takenReminderIDs)
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

private struct ScheduleLoadingState: View {
    var body: some View {
        VStack(spacing: 14) {
            ProgressView()
                .scaleEffect(1.1)
                .tint(Color(hex: "0773F1"))

            Text("Загружаем расписание...")
                .font(.custom("Commissioner-Medium", size: 16))
                .foregroundColor(Color(hex: "3B3B3B").opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 72)
    }
}

private struct DateCell: View {
    let date: Date
    let isSelected: Bool
    let onTap: () -> Void

    private let size = CGSize(width: 60, height: 84)

    var body: some View {
        let weekday = date.shortWeekday
        let day = date.dayString

        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    isSelected
                    ? AnyShapeStyle(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white, location: 0.0),
                                .init(color: Color(hex: "B4D2FF"), location: 0.35),
                                .init(color: Color(hex: "6F95FC"), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    : AnyShapeStyle(Color.white)
                )
                .animation(nil, value: isSelected)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color(hex: "E5E8EE"), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 2)

            VStack(spacing: 6) {
                Text(weekday)
                    .font(.custom("Commissioner-Regular", size: 13))
                    .foregroundColor(Color(hex: "8C8C8C"))
                    .padding(.top, 10)

                Text(day)
                    .font(.custom("Commissioner-Bold", size: 22))
                    .foregroundColor(isSelected ? .white : .black)

                if isSelected {
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 18, height: 2)
                        .padding(.top, -2)
                }
                Spacer(minLength: 0)
            }
        }
        .frame(width: size.width, height: size.height)
        .onTapGesture { onTap() }
    }
}

private struct ReminderCard: View {
    let reminder: Reminder
    let onToggle: () -> Void
    let onLongPress: () -> Void

    private let cardRadius: CGFloat = 16
    private let blue = Color(hex: "0773F1")

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            ToggleCircle(isOn: reminder.isTaken, action: onToggle)

            VStack(alignment: .leading, spacing: 6) {
                Text(reminder.vitaminName)
                    .font(.custom("Commissioner-Bold", size: 18))
                    .foregroundColor(.black)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(blue)
                    Text("\(reminder.intakeType.description) — \(reminder.time)")
                        .font(.custom("Commissioner-Regular", size: 13))
                        .foregroundColor(Color(hex: "6E7480"))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text("\(reminder.count)")
                    .font(.custom("Commissioner-Bold", size: 28))
                    .foregroundColor(blue)
                Text("шт")
                    .font(.custom("Commissioner-Regular", size: 12))
                    .foregroundColor(Color(hex: "8C8C8C"))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                    .fill(Color(hex: "88A4FF").opacity(0.85))
                    .offset(x: -5, y: 0)

                RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                    .fill(Color.white)
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                .stroke(blue, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 1)
        .padding(.leading, 5)
        .contentShape(RoundedRectangle(cornerRadius: cardRadius, style: .continuous))
        .onLongPressGesture(minimumDuration: 0.35, perform: onLongPress)
    }
}

private struct ReminderActionOverlay: View {
    let reminder: Reminder
    let isSubmitting: Bool
    let primaryButtonTitle: String
    let showsSnoozeButtons: Bool
    let onDismiss: () -> Void
    let onPrimaryAction: () -> Void
    let onSnooze15: () -> Void
    let onSnooze60: () -> Void
    @State private var infoContentHeight: CGFloat = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            VStack(spacing: 16) {
                actionCard

                if showsSnoozeButtons {
                    VStack(spacing: 10) {
                        secondaryButton("Отложить на 15 мин", action: onSnooze15)
                        secondaryButton("Отложить на 1 ч", action: onSnooze60)
                    }
                }
            }
            .padding(.horizontal, 24)
        }
    }

    private var actionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Image("capsule")
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
                    .frame(width: 36, height: 40)

                Text(reminder.vitaminName)
                    .font(.custom("Commissioner-Bold", size: 32))
                    .foregroundColor(.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            if !reminder.infoItems.isEmpty {
                Group {
                    if infoContentHeight > maxInfoContentHeight {
                        ScrollView(showsIndicators: false) {
                            infoItemsContent
                        }
                        .frame(height: maxInfoContentHeight, alignment: .top)
                    } else {
                        infoItemsContent
                    }
                }
            }

            Button(action: onPrimaryAction) {
                ZStack {
                    if isSubmitting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(primaryButtonTitle)
                            .font(.custom("Commissioner-Bold", size: 20))
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 193, height: 52)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "A6C4DD"), Color(hex: "1F7CF4")],
                        startPoint: .trailing,
                        endPoint: .leading
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 100, style: .continuous))
            }
            .padding(.top, 4)
            .buttonStyle(.plain)
            .disabled(isSubmitting)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(width: 340, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.25), radius: 10, x: 0, y: 4)
        )
    }

    private var infoItemsContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(reminder.infoItems) { item in
                infoBlock(title: item.title, text: item.text)
            }
        }
        .background(
            GeometryReader { proxy in
                Color.clear
                    .preference(key: ReminderInfoContentHeightPreferenceKey.self, value: proxy.size.height)
            }
        )
        .onPreferenceChange(ReminderInfoContentHeightPreferenceKey.self) { height in
            infoContentHeight = height
        }
    }

    private var maxInfoContentHeight: CGFloat {
        UIScreen.main.bounds.height * 0.34
    }

    private func infoBlock(title: String, text: String) -> some View {
        (
            Text("\(title): ")
                .font(.custom("Commissioner-Medium", size: 14))
            +
            Text(text)
                .font(.custom("Commissioner-Regular", size: 14))
        )
        .foregroundColor(.black)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.custom("Commissioner-Medium", size: 16))
                .foregroundColor(Color(hex: "0773F1"))
                .frame(width: 174, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 100, style: .continuous)
                        .fill(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 100, style: .continuous)
                                .strokeBorder(secondaryLinearBorder, lineWidth: 2)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 100, style: .continuous)
                                .strokeBorder(secondaryRadialBorder, lineWidth: 2)
                        )
                        .shadow(color: Color.black.opacity(0.25), radius: 4, x: 0, y: 4)
                )
        }
        .buttonStyle(.plain)
        .disabled(isSubmitting)
        .opacity(isSubmitting ? 0.7 : 1)
    }

    private var secondaryLinearBorder: LinearGradient {
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

    private var secondaryRadialBorder: RadialGradient {
        RadialGradient(
            gradient: Gradient(colors: [
                .white,
                .white.opacity(0)
            ]),
            center: UnitPoint(x: 0.1494, y: 0.9673),
            startRadius: 0,
            endRadius: 120
        )
    }
}

private struct ToggleCircle: View {
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isOn {
                    Circle()
                        .fill(Color(hex: "0773F1"))
                        .frame(width: 38, height: 38)

                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 38, height: 38)
                    Circle()
                        .stroke(Color(hex: "0773F1"), lineWidth: 2)
                        .frame(width: 38, height: 38)
                }
            }
            .contentShape(Circle())
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
private struct ReminderInfoItem: Identifiable, Equatable {
    let id: String
    let title: String
    let text: String
}

private struct ReminderInfoContentHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct Reminder: Identifiable, Equatable {
    let id: String
    let remoteID: Int
    let scheduleTimeIndex: Int
    let date: Date
    let vitaminName: String
    let intakeType: IntakeType
    let time: String
    let count: Int
    let infoItems: [ReminderInfoItem]
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

private enum WeekdayCode: String, CaseIterable {
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
        guard components.count >= 2,
              let hours = Int(components[0]),
              let minutes = Int(components[1]),
              (0...23).contains(hours),
              (0...59).contains(minutes)
        else { return nil }
        return hours * 60 + minutes
    }

    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
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
