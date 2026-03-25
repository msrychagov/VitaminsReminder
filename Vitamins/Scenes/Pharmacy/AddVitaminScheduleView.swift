import SwiftUI

struct IntakeEntry: Identifiable {
    let id = UUID()
    var order: Int
    var time: String
}

struct AddVitaminScheduleView: View {
    private enum CourseDateField {
        case start
        case end
    }

    private enum DaysIntakeMode {
        case today
        case everyDay
        case everyOtherDay
        case weekly
        case custom
    }

    private struct CourseRowFramePreferenceKey: PreferenceKey {
        static var defaultValue: [CourseDateField: CGRect] = [:]

        static func reduce(value: inout [CourseDateField: CGRect], nextValue: () -> [CourseDateField: CGRect]) {
            value.merge(nextValue(), uniquingKeysWith: { _, new in new })
        }
    }

    @Environment(\.dismiss) private var dismiss
    @Binding var selectedTab: AppTab
    let draft: VitaminDraft
    let onNext: (VitaminDraft) -> Void
    let onTabRequested: ((AppTab) -> Void)?
    let isEditing: Bool

    @State private var entries: [IntakeEntry]
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var activeCourseDateField: CourseDateField?
    @State private var courseRowFrames: [CourseDateField: CGRect] = [:]
    @State private var selectedWeekdays: Set<Weekday>
    @State private var daysIntakeMode: DaysIntakeMode
    @State private var activeTimeEntryID: UUID?
    @State private var activePickerTime: Date = Date()
    @State private var swipeOffsets: [UUID: CGFloat] = [:]
    @State private var openedSwipeEntryID: UUID?
    @State private var suppressedTimePickerEntryID: UUID?
    @State private var didCompleteStep = false

    private let blue = Color(hex: "0E75F2")
    private let intakeCardCornerRadius: CGFloat = 26
    private let intakeCardShadowInsetHorizontal: CGFloat = 4
    private let intakeCardShadowInsetVertical: CGFloat = 6
    private let swipeActionWidth: CGFloat = 86
    private let swipeOpenThreshold: CGFloat = 42
    private let timePickerTapSuppressionDuration: TimeInterval = 0.2

    private var isInputOverlayPresented: Bool {
        activeTimeEntryID != nil || activeCourseDateField != nil
    }

    private static func currentTimeString() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date())
    }

    init(
        selectedTab: Binding<AppTab>,
        draft: VitaminDraft,
        onNext: @escaping (VitaminDraft) -> Void,
        onTabRequested: ((AppTab) -> Void)? = nil,
        isEditing: Bool = false
    ) {
        let weekdays = Set(draft.weekdays.isEmpty ? Weekday.allCases : draft.weekdays)
        let start = draft.courseStartDate
        let end = draft.courseEndDate ?? start.addingTimeInterval(24 * 60 * 60 * 14)
        let scheduleMode = draft.scheduleMode == .everyDay && weekdays.count != Weekday.allCases.count
            ? VitaminScheduleMode.resolved(weekdays: Array(weekdays), courseStartDate: start)
            : draft.scheduleMode

        _selectedTab = selectedTab
        self.draft = draft
        self.onNext = onNext
        self.onTabRequested = onTabRequested
        self.isEditing = isEditing
        _entries = State(initialValue: Self.initialEntries(from: draft.intakeTimes))
        _startDate = State(initialValue: start)
        _endDate = State(initialValue: max(end, start))
        _selectedWeekdays = State(initialValue: weekdays)
        _daysIntakeMode = State(initialValue: Self.daysMode(for: scheduleMode))
    }

    private static func initialEntries(from times: [String]) -> [IntakeEntry] {
        let normalized = times
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if normalized.isEmpty {
            return [IntakeEntry(order: 1, time: currentTimeString())]
        }

        return normalized.enumerated().map { index, time in
            IntakeEntry(order: index + 1, time: time)
        }
    }

    private static func daysMode(for scheduleMode: VitaminScheduleMode) -> DaysIntakeMode {
        switch scheduleMode {
        case .today:
            return .today
        case .everyDay:
            return .everyDay
        case .everyOtherDay:
            return .everyOtherDay
        case .weekly:
            return .weekly
        case .custom:
            return .custom
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "EFF6FF"), .white],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        StepProgressView(filledSegments: 2)
                            .padding(.top, 18)
                            .padding(.horizontal, 30)

                        titleField
                            .padding(.horizontal, 30)
                            .padding(.bottom, 9)

                        intakeCards
                            .padding(.horizontal, 30 - intakeCardShadowInsetHorizontal)

                        addButton
                            .padding(.top, 20)

                        daysSection
                            .padding(.top, 24)
                            .padding(.horizontal, 30)

                        courseDurationBlock
                            .padding(.top, 18)
                            .padding(.horizontal, 30)

                        buttonsRow
                            .padding(.top, 28)
                            .padding(.horizontal, 30)
                            .padding(.bottom, 28)
                    }
                }
                .navigationBarBackButtonHidden(true)
                .toolbar(.hidden, for: .navigationBar)

                tabBarOverlay
            }
            .contentShape(Rectangle())
            .simultaneousGesture(
                TapGesture().onEnded {
                    UIApplication.shared.endEditing()
                    closeAllSwipeRows()
                }
            )
            .allowsHitTesting(!isInputOverlayPresented)
        }
        .overlay {
            if activeTimeEntryID != nil {
                floatingTimePickerOverlay
            }
        }
        .overlay(alignment: .topLeading) {
            if let field = activeCourseDateField, let frame = courseRowFrames[field] {
                floatingDatePicker(for: field, rowFrame: frame)
            }
        }
        .coordinateSpace(name: "AddVitaminScheduleSpace")
        .onPreferenceChange(CourseRowFramePreferenceKey.self) { value in
            courseRowFrames = value
        }
        .onDisappear {
            guard !didCompleteStep else { return }
            AnalyticsService.shared.track(
                AnalyticsEventName.wizardAbandoned,
                properties: [
                    "screen": "wizard_step2",
                    "flow": .string(analyticsFlow),
                    "step": 2,
                    "reason": "dismissed"
                ]
            )
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    // MARK: - UI
    private var titleField: some View {
        TextField("", text: .constant(draft.name), prompt: Text("Название").foregroundColor(.black))
            .font(.custom("Commissioner-Bold", size: 32))
            .foregroundColor(Color(hex: "3B3B3B"))
            .disabled(true)
    }

    private var intakeCards: some View {
        VStack(spacing: 4) {
            ForEach(entries) { entry in
                intakeCard(entry)
                    .padding(.horizontal, intakeCardShadowInsetHorizontal)
                    .padding(.vertical, intakeCardShadowInsetVertical)
            }
        }
    }

    @ViewBuilder
    private func intakeCard(_ entry: IntakeEntry) -> some View {
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            let offset = swipeOffsets[entry.id] ?? 0
            let canDelete = entries.count > 1
            let isDeleteVisible = offset < 0

            ZStack(alignment: .trailing) {
                if isDeleteVisible, canDelete {
                    Button(role: .destructive) {
                        deleteEntry(id: entry.id)
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "trash")
                                .font(.system(size: 18, weight: .semibold))
                            Text("Удалить")
                                .font(.custom("Commissioner-SemiBold", size: 14))
                        }
                        .foregroundColor(.white)
                        .frame(width: swipeActionWidth, height: 146)
                        .background(Color.red)
                        .cornerRadius(intakeCardCornerRadius)
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                }

                intakeCardContent(entry: entry, index: index)
                    .offset(x: offset)
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 10)
                            .onChanged { value in
                                handleSwipeChanged(for: entry.id, value: value, canDelete: canDelete)
                            }
                            .onEnded { value in
                                handleSwipeEnded(for: entry.id, value: value, canDelete: canDelete)
                            }
                    )
            }
            .frame(height: 146)
            .clipped()
        }
    }

    private func intakeCardContent(entry: IntakeEntry, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Прием \(entries[index].order)")
                .font(.custom("Commissioner-SemiBold", size: 18))
                .foregroundColor(.white)
                .padding(.top, 16)
                .padding(.leading, 16)

            Button {
                guard !consumeSuppressedTimePickerTap(for: entry.id) else { return }
                closeAllSwipeRows()
                presentTimePicker(for: entry)
            } label: {
                HStack {
                    Text(entry.time.isEmpty ? AddVitaminScheduleView.currentTimeString() : entry.time)
                        .font(.custom("Commissioner-SemiBold", size: 20))
                        .foregroundColor(.black)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 19)
                .frame(height: 65, alignment: .leading)
                .background(Color.white)
                .cornerRadius(16)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 19)
            .padding(.bottom, 16)
        }
        .frame(height: 146, alignment: .topLeading)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: intakeCardCornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "6F95FC"),
                            Color(hex: "0773F1"),
                            Color(hex: "D6FEC2")
                        ],
                        startPoint: UnitPoint(x: 0.0, y: 0.0),
                        endPoint: UnitPoint(x: 1.0, y: 1.2)
                    )
                )
                .shadow(color: Color.black.opacity(0.08), radius: 16, x: 0, y: 8)
                .shadow(color: Color.black.opacity(0.04), radius: 5, x: 0, y: 2)
        }
        .clipShape(
            RoundedRectangle(cornerRadius: intakeCardCornerRadius, style: .continuous)
        )
    }

    private func handleSwipeChanged(for id: UUID, value: DragGesture.Value, canDelete: Bool) {
        guard canDelete else {
            swipeOffsets[id] = 0
            if openedSwipeEntryID == id {
                openedSwipeEntryID = nil
            }
            return
        }
        guard abs(value.translation.width) > abs(value.translation.height) else { return }
        suppressedTimePickerEntryID = id

        if value.translation.width < 0 {
            if openedSwipeEntryID != id {
                closeAllSwipeRows(except: id, animated: false)
                openedSwipeEntryID = id
            }
            swipeOffsets[id] = max(-swipeActionWidth, value.translation.width)
        } else {
            let base = openedSwipeEntryID == id ? -swipeActionWidth : 0
            swipeOffsets[id] = min(0, base + value.translation.width)
        }
    }

    private func handleSwipeEnded(for id: UUID, value: DragGesture.Value, canDelete: Bool) {
        defer { scheduleTimePickerTapSuppressionClear(for: id) }

        guard canDelete else {
            withAnimation(.easeInOut(duration: 0.18)) {
                swipeOffsets[id] = 0
                if openedSwipeEntryID == id {
                    openedSwipeEntryID = nil
                }
            }
            return
        }

        guard abs(value.translation.width) > abs(value.translation.height) else {
            if openedSwipeEntryID == id {
                swipeOffsets[id] = -swipeActionWidth
            }
            return
        }

        let currentOffset = swipeOffsets[id] ?? 0
        let shouldOpen = currentOffset <= -swipeOpenThreshold

        if shouldOpen {
            withAnimation(.easeInOut(duration: 0.18)) {
                openedSwipeEntryID = id
                swipeOffsets[id] = -swipeActionWidth
            }
        } else {
            withAnimation(.easeInOut(duration: 0.18)) {
                swipeOffsets[id] = 0
                if openedSwipeEntryID == id {
                    openedSwipeEntryID = nil
                }
            }
        }
    }

    private func consumeSuppressedTimePickerTap(for id: UUID) -> Bool {
        guard suppressedTimePickerEntryID == id else { return false }
        suppressedTimePickerEntryID = nil
        return true
    }

    private func scheduleTimePickerTapSuppressionClear(for id: UUID) {
        DispatchQueue.main.asyncAfter(deadline: .now() + timePickerTapSuppressionDuration) {
            guard suppressedTimePickerEntryID == id else { return }
            suppressedTimePickerEntryID = nil
        }
    }

    private func closeAllSwipeRows(except keptID: UUID? = nil, animated: Bool = true) {
        let updates = {
            for key in swipeOffsets.keys where key != keptID {
                swipeOffsets[key] = 0
            }
            if openedSwipeEntryID != keptID {
                openedSwipeEntryID = nil
            }
        }

        if animated {
            withAnimation(.easeInOut(duration: 0.18), updates)
        } else {
            updates()
        }
    }

    private func deleteEntry(id: UUID) {
        guard entries.count > 1 else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            entries.removeAll { $0.id == id }
            for index in entries.indices {
                entries[index].order = index + 1
            }

            swipeOffsets[id] = nil
            if openedSwipeEntryID == id {
                openedSwipeEntryID = nil
            }
            if activeTimeEntryID == id {
                activeTimeEntryID = nil
            }

            if entries.count <= 1 {
                swipeOffsets.removeAll()
                openedSwipeEntryID = nil
            }
        }

        AnalyticsService.shared.track(
            AnalyticsEventName.scheduleTimeRemoved,
            properties: [
                "screen": "wizard_step2",
                "flow": .string(analyticsFlow),
                "times_count": .int(entries.count)
            ]
        )
    }

    private var addButton: some View {
        Button {
            closeAllSwipeRows()
            let next = (entries.last?.order ?? 0) + 1
            entries.append(IntakeEntry(order: next, time: AddVitaminScheduleView.currentTimeString()))
            AnalyticsService.shared.track(
                AnalyticsEventName.scheduleTimeAdded,
                properties: [
                    "screen": "wizard_step2",
                    "flow": .string(analyticsFlow),
                    "times_count": .int(entries.count)
                ]
            )
        } label: {
            Circle()
                .fill(blue)
                .frame(width: 50, height: 50)
                .shadow(color: Color.black.opacity(0.25), radius: 3.3, x: 1, y: 1)
                .overlay(
                    Image("plus")
                        .resizable()
                        .renderingMode(.template)
                        .foregroundColor(.white)
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var daysSection: some View {
        VStack(spacing: 0) {
            Menu {
                Button("Только сегодня") {
                    applyDaysMode(.today)
                }
                Button("Каждый день") {
                    applyDaysMode(.everyDay)
                }
                Button("Через день") {
                    applyDaysMode(.everyOtherDay)
                }
                Button("Еженедельно") {
                    applyDaysMode(.weekly)
                }
                Divider()
                Button("Выбрать дни...") {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                        daysIntakeMode = .custom
                    }
                }
            } label: {
                HStack {
                    Text("Дни приема")
                        .font(.custom("Commissioner-SemiBold", size: 18))
                        .foregroundColor(.black)

                    Spacer()

                    HStack(spacing: 10) {
                        Text(daysSummaryText)
                            .font(.custom("Commissioner-SemiBold", size: 18))
                            .foregroundColor(Color(hex: "C3C3C3"))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)

                        Image("chevronWhite")
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(.black)
                            .frame(width: 20, height: 20)
                            .rotationEffect(.degrees(90))
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, daysIntakeMode == .custom ? 0 : 12)
            }
            .buttonStyle(.plain)

            if daysIntakeMode == .custom {
                HStack(spacing: 8) {
                    ForEach(Weekday.allCases) { day in
                        weekdayCell(for: day)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
                .padding(.top, 12)
                .padding(.bottom, 14)
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .opacity
                    )
                )
            }

            Rectangle()
                .fill(Color(hex: "E5E5E5"))
                .frame(height: 1)
        }
    }

    private var courseDurationBlock: some View {
        VStack(spacing: 0) {
            Text("Продолжительность курса")
                .font(.custom("Commissioner-Medium", size: 12))
                .foregroundColor(blue)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 18)
                .padding(.bottom, 12)

            VStack(spacing: 0) {
                courseRow(
                    field: .start,
                    title: "Начало",
                    value: formattedDate(startDate)
                ) {
                    toggleCourseDateField(.start)
                }

                Rectangle()
                    .fill(Color(hex: "E5E5E5"))
                    .frame(height: 1)

                courseRow(
                    field: .end,
                    title: "Конец",
                    value: formattedDate(endDate)
                ) {
                    toggleCourseDateField(.end)
                }
            }
        }
    }

    private func toggleCourseDateField(_ field: CourseDateField) {
        UIApplication.shared.endEditing()
        activeTimeEntryID = nil

        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            if activeCourseDateField == field {
                activeCourseDateField = nil
            } else {
                activeCourseDateField = field
            }
        }
    }

    private func courseRow(field: CourseDateField, title: String, value: String, action: @escaping () -> Void) -> some View {
        return Button(action: action) {
            HStack {
                Text(title)
                    .font(.custom("Commissioner-SemiBold", size: 18))
                    .foregroundColor(.black)
                    .padding(.leading, 0)
                Spacer()
                HStack(spacing: 12) {
                    Text(value)
                        .font(.custom("Commissioner-SemiBold", size: 18))
                        .foregroundColor(Color(hex: "C3C3C3"))
                    Image("chevronWhite")
                        .resizable()
                        .renderingMode(.template)
                        .foregroundColor(.black)
                        .frame(width: 20, height: 20)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 18)
        }
        .background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: CourseRowFramePreferenceKey.self,
                    value: [field: proxy.frame(in: .named("AddVitaminScheduleSpace"))]
                )
            }
        )
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "dd.MM.yy"
        return formatter.string(from: date)
    }

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "HH:mm"
        return formatter
    }

    private var scheduleMode: VitaminScheduleMode {
        switch daysIntakeMode {
        case .today:
            return .today
        case .everyDay:
            return .everyDay
        case .everyOtherDay:
            return .everyOtherDay
        case .weekly:
            return .weekly
        case .custom:
            return .custom
        }
    }

    private var daysSummaryText: String {
        let weekdays = preparedWeekdays()
        return scheduleMode.summaryText(weekdays: weekdays, courseStartDate: startDate)
    }

    private func weekdayCell(for day: Weekday) -> some View {
        let isSelected = selectedWeekdays.contains(day)

        return Button {
            if isSelected {
                selectedWeekdays.remove(day)
            } else {
                selectedWeekdays.insert(day)
            }
            daysIntakeMode = .custom
            trackDaysChanged()
        } label: {
            Text(day.rawValue.lowercased())
                .font(.custom("Commissioner-Bold", size: 34 / 2))
                .foregroundColor(isSelected ? .white : Color(hex: "0773F1"))
                .frame(width: 42, height: 39)
                .background(
                    Capsule(style: .continuous)
                        .fill(isSelected ? Color(hex: "0773F1") : .white)
                        .shadow(color: Color.black.opacity(0.25), radius: 3.3, x: 1, y: 1)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.black.opacity(isSelected ? 0 : 0.08), lineWidth: 0.7)
                )
        }
        .buttonStyle(.plain)
    }

    private func applyDaysMode(_ mode: DaysIntakeMode) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            daysIntakeMode = mode

            switch mode {
            case .today:
                selectedWeekdays = [Weekday.from(date: Date())]
            case .everyDay:
                selectedWeekdays = Set(Weekday.allCases)
            case .everyOtherDay:
                selectedWeekdays = Weekday.everyOtherDaySet(startingFrom: Weekday.from(date: startDate))
            case .weekly:
                selectedWeekdays = [Weekday.from(date: startDate)]
            case .custom:
                break
            }
        }

        if mode == .everyDay {
            AnalyticsService.shared.track(
                AnalyticsEventName.scheduleEverydaySelected,
                properties: [
                    "screen": "wizard_step2",
                    "flow": .string(analyticsFlow),
                    "days_count": .int(Weekday.allCases.count)
                ]
            )
        }

        trackDaysChanged()
    }

    private func syncSelectedWeekdaysWithStartDateIfNeeded() {
        switch daysIntakeMode {
        case .everyOtherDay:
            selectedWeekdays = Weekday.everyOtherDaySet(startingFrom: Weekday.from(date: startDate))
        case .weekly:
            selectedWeekdays = [Weekday.from(date: startDate)]
        case .today, .everyDay, .custom:
            break
        }
    }

    private var floatingTimePickerOverlay: some View {
        ZStack {
            Color.black.opacity(0.25)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissTimePicker()
                }

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button("Готово") {
                        dismissTimePicker()
                    }
                    .buttonStyle(.plain)
                    .font(.custom("Commissioner-SemiBold", size: 18))
                    .foregroundColor(Color(hex: "0773F1"))
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 4)

                DatePicker(
                    "",
                    selection: activeTimeBinding,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(height: 210)
                .clipped()
            }
            .frame(width: 320)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 6)
            )
            .padding(.horizontal, 24)
        }
        .transition(.opacity)
        .zIndex(20)
    }

    private var activeTimeBinding: Binding<Date> {
        Binding(
            get: { activePickerTime },
            set: { newValue in
                activePickerTime = newValue
                applyPickerTimeToActiveEntry(newValue)
            }
        )
    }

    private func presentTimePicker(for entry: IntakeEntry) {
        UIApplication.shared.endEditing()
        activeCourseDateField = nil

        activePickerTime = dateFromTimeString(entry.time)
        withAnimation(.easeInOut(duration: 0.2)) {
            activeTimeEntryID = entry.id
        }
    }

    private func dismissTimePicker() {
        withAnimation(.easeInOut(duration: 0.2)) {
            activeTimeEntryID = nil
        }
    }

    private func applyPickerTimeToActiveEntry(_ date: Date) {
        guard let activeTimeEntryID else { return }
        guard let index = entries.firstIndex(where: { $0.id == activeTimeEntryID }) else { return }
        entries[index].time = timeFormatter.string(from: date)
    }

    private func dateFromTimeString(_ raw: String) -> Date {
        let normalized = normalizedTimeForAPI(raw) ?? AddVitaminScheduleView.currentTimeString()
        let parts = normalized.split(separator: ":")
        guard parts.count == 2,
              let hours = Int(parts[0]),
              let minutes = Int(parts[1]) else {
            return Date()
        }

        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = hours
        components.minute = minutes
        components.second = 0
        return Calendar.current.date(from: components) ?? Date()
    }

    private func dateBinding(for field: CourseDateField) -> Binding<Date> {
        Binding(
            get: {
                switch field {
                case .start: return startDate
                case .end: return endDate
                }
            },
            set: { newValue in
                let today = Date().startOfDayUniversal
                let clamped = max(newValue.startOfDayUniversal, today)

                switch field {
                case .start:
                    startDate = clamped
                    if startDate > endDate {
                        endDate = startDate
                    }
                    syncSelectedWeekdaysWithStartDateIfNeeded()
                case .end:
                    endDate = clamped
                    if endDate < startDate {
                        startDate = endDate
                    }
                }

                DispatchQueue.main.async {
                    guard activeCourseDateField == field else { return }
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        activeCourseDateField = nil
                    }
                }
            }
        )
    }

    private func floatingDatePicker(for field: CourseDateField, rowFrame: CGRect) -> some View {
        let horizontalInset: CGFloat = 8
        let panelWidth = max(280, rowFrame.width - horizontalInset * 2)
        let panelHeight: CGFloat = 388
        let calendarPadding: CGFloat = 10
        let topInset: CGFloat = 8
        let y = max(topInset, rowFrame.minY - panelHeight - 6)

        return ZStack(alignment: .topLeading) {
            Color.black.opacity(0.001)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        activeCourseDateField = nil
                    }
                }

            DatePicker(
                "",
                selection: dateBinding(for: field),
                in: Date().startOfDayUniversal...Date.distantFuture,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(calendarPadding)
            .frame(width: panelWidth, height: panelHeight, alignment: .topLeading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 4)
            .padding(.leading, rowFrame.minX + horizontalInset)
            .padding(.top, y)
            .transition(.asymmetric(
                insertion: .scale(scale: 0.96, anchor: .bottom).combined(with: .opacity),
                removal: .opacity
            ))
        }
        .zIndex(10)
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

            Button(action: continueTapped) {
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
                        UIApplication.shared.endEditing()
                        if onTabRequested == nil {
                            selectedTab = tab
                            dismiss()
                        }
                    }
                ),
                onSelect: { tab in
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    guard let onTabRequested else { return }
                    UIApplication.shared.endEditing()
                    onTabRequested(tab)
                }
            )
            Spacer(minLength: 0)
        }
        .padding(.bottom, 12)
        .padding(.horizontal, 0)
        .background(Color.clear.ignoresSafeArea(edges: .bottom))
    }

    private func continueTapped() {
        var updatedDraft = draft
        let intakeTimes = preparedIntakeTimes()
        let weekdays = preparedWeekdays()
        updatedDraft.intakeTimes = intakeTimes
        updatedDraft.scheduleMode = scheduleMode
        updatedDraft.weekdays = weekdays
        updatedDraft.courseStartDate = startDate.startOfDayUniversal
        updatedDraft.courseEndDate = endDate.startOfDayUniversal
        didCompleteStep = true
        AnalyticsService.shared.track(
            AnalyticsEventName.wizardStep2Completed,
            properties: [
                "screen": "wizard_step2",
                "flow": .string(analyticsFlow),
                "step": 2,
                "times_count": .int(intakeTimes.count),
                "days_count": .int(weekdays.count)
            ]
        )
        onNext(updatedDraft)
    }

    private var analyticsFlow: String {
        isEditing ? "update_reminder" : "create_reminder"
    }

    private func trackDaysChanged() {
        AnalyticsService.shared.track(
            AnalyticsEventName.scheduleDaysChanged,
            properties: [
                "screen": "wizard_step2",
                "flow": .string(analyticsFlow),
                "days_count": .int(selectedWeekdays.count)
            ]
        )
    }

    private func preparedWeekdays() -> [Weekday] {
        let ordered = Weekday.allCases.filter { selectedWeekdays.contains($0) }
        return ordered.isEmpty ? Weekday.allCases : ordered
    }

    private func preparedIntakeTimes() -> [String] {
        var seen = Set<String>()
        var times: [String] = []

        for entry in entries.sorted(by: { $0.order < $1.order }) {
            guard let normalized = normalizedTimeForAPI(entry.time) else { continue }
            if seen.insert(normalized).inserted {
                times.append(normalized)
            }
        }

        return times.isEmpty ? [AddVitaminScheduleView.currentTimeString()] : times
    }

    private func normalizedTimeForAPI(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: ":", omittingEmptySubsequences: false)

        if parts.count == 2,
           let hours = Int(parts[0]),
           let minutes = Int(parts[1]),
           (0...23).contains(hours),
           (0...59).contains(minutes) {
            return String(format: "%02d:%02d", hours, minutes)
        }

        let digits = trimmed.filter(\.isNumber)
        guard !digits.isEmpty, digits.count <= 4 else { return nil }

        let hours: Int
        let minutes: Int

        switch digits.count {
        case 1:
            hours = Int(digits) ?? -1
            minutes = 0
        case 2:
            hours = Int(digits) ?? -1
            minutes = 0
        case 3:
            hours = Int(String(digits.prefix(1))) ?? -1
            minutes = Int(String(digits.suffix(2))) ?? -1
        default:
            hours = Int(String(digits.prefix(2))) ?? -1
            minutes = Int(String(digits.suffix(2))) ?? -1
        }

        guard (0...23).contains(hours), (0...59).contains(minutes) else { return nil }
        return String(format: "%02d:%02d", hours, minutes)
    }
}
