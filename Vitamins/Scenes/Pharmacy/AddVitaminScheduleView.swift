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

    @State private var entries: [IntakeEntry] = [IntakeEntry(order: 1, time: AddVitaminScheduleView.currentTimeString())]
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date().addingTimeInterval(24*60*60*14)
    @State private var activeCourseDateField: CourseDateField?
    @State private var courseRowFrames: [CourseDateField: CGRect] = [:]
    @State private var selectedWeekdays: Set<Weekday> = Set(Weekday.allCases)
    @State private var daysIntakeMode: DaysIntakeMode = .everyDay
    @State private var activeTimeEntryID: UUID?
    @State private var activePickerTime: Date = Date()

    private let blue = Color(hex: "0E75F2")

    private static func currentTimeString() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date())
    }

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
                    StepProgressView(filledSegments: 2)
                        .padding(.top, 18)
                        .padding(.horizontal, 30)

                    titleField
                        .padding(.horizontal, 30)
                        .padding(.bottom, 9)

                    intakeCards
                        .padding(.horizontal, 30)

                    addButton
                        .padding(.top, 20)

                    daysSection
                        .padding(.top, 24)
                        .padding(.horizontal, 30)

                    courseDurationBlock
                        .padding(.top, 18)
                        .padding(.horizontal, 30)
                }
                .padding(.bottom, 150)
            }
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
        }
        .overlay(alignment: .bottom) {
            bottomControls
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
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .contentShape(Rectangle())
        .onTapGesture {
            UIApplication.shared.endEditing()
            if activeCourseDateField != nil {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                    activeCourseDateField = nil
                }
            }
            if activeTimeEntryID != nil {
                withAnimation(.easeInOut(duration: 0.2)) {
                    activeTimeEntryID = nil
                }
            }
        }
    }

    // MARK: - UI
    private var titleField: some View {
        HStack(spacing: 12) {
            Image("pen")
                .resizable()
                .renderingMode(.original)
                .frame(width: 24, height: 24)

            TextField("", text: .constant(draft.name), prompt: Text("Название").foregroundColor(.black))
                .font(.custom("Commissioner-Bold", size: 32))
                .foregroundColor(Color(hex: "3B3B3B"))
                .disabled(true)
        }
    }

    private var intakeCards: some View {
        VStack(spacing: 16) {
            ForEach(entries.indices, id: \.self) { index in
                VStack(alignment: .leading, spacing: 16) {
                    Text("Прием \(entries[index].order)")
                        .font(.custom("Commissioner-SemiBold", size: 18))
                        .foregroundColor(.white)
                        .padding(.top, 16)
                        .padding(.leading, 16)

                    Button {
                        presentTimePicker(for: entries[index])
                    } label: {
                        HStack {
                            Text(entries[index].time.isEmpty ? AddVitaminScheduleView.currentTimeString() : entries[index].time)
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
                .background(
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
                .cornerRadius(26)
                .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
            }
        }
    }

    private var addButton: some View {
        Button {
            let next = (entries.last?.order ?? 0) + 1
            entries.append(IntakeEntry(order: next, time: AddVitaminScheduleView.currentTimeString()))
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
                    daysIntakeMode = .custom
                }
            } label: {
                HStack {
                    Text("Дни приема")
                        .font(.custom("Commissioner-SemiBold", size: 18))
                        .foregroundColor(.black)

                    Spacer()

                    HStack(spacing: 10) {
                        Text(formattedWeekdays)
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

    private var formattedWeekdays: String {
        if selectedWeekdays.isEmpty {
            return "выберите дни"
        }
        if selectedWeekdays.count == Weekday.allCases.count {
            return "каждый день"
        }
        let sorted = Weekday.allCases.filter { selectedWeekdays.contains($0) }
        return sorted.map { $0.rawValue.lowercased() }.joined(separator: ", ")
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
        daysIntakeMode = mode

        switch mode {
        case .today:
            selectedWeekdays = [currentWeekday()]
        case .everyDay:
            selectedWeekdays = Set(Weekday.allCases)
        case .everyOtherDay:
            selectedWeekdays = everyOtherDaySet(startingFrom: currentWeekday())
        case .weekly:
            selectedWeekdays = [currentWeekday()]
        case .custom:
            break
        }
    }

    private func currentWeekday() -> Weekday {
        let weekdayNumber = Calendar.current.component(.weekday, from: Date())
        switch weekdayNumber {
        case 1: return .sun
        case 2: return .mon
        case 3: return .tue
        case 4: return .wed
        case 5: return .thu
        case 6: return .fri
        default: return .sat
        }
    }

    private func everyOtherDaySet(startingFrom weekday: Weekday) -> Set<Weekday> {
        guard let startIndex = Weekday.allCases.firstIndex(of: weekday) else {
            return Set(Weekday.allCases)
        }

        let count = Weekday.allCases.count
        var result = Set<Weekday>()

        for offset in stride(from: 0, to: count, by: 2) {
            let index = (startIndex + offset) % count
            result.insert(Weekday.allCases[index])
        }

        return result
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
                case .end:
                    endDate = clamped
                    if endDate < startDate {
                        startDate = endDate
                    }
                }
            }
        )
    }

    private func floatingDatePicker(for field: CourseDateField, rowFrame: CGRect) -> some View {
        let horizontalInset: CGFloat = 8
        let panelWidth = max(280, rowFrame.width - horizontalInset * 2)
        let panelHeight: CGFloat = 332
        let topInset: CGFloat = 8
        let y = max(topInset, rowFrame.minY - panelHeight - 6)

        return DatePicker(
            "",
            selection: dateBinding(for: field),
            in: Date().startOfDayUniversal...Date.distantFuture,
            displayedComponents: .date
        )
        .datePickerStyle(.graphical)
        .labelsHidden()
        .padding(10)
        .frame(width: panelWidth)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 4)
        )
        .offset(x: rowFrame.minX + horizontalInset, y: y)
        .transition(.asymmetric(
            insertion: .scale(scale: 0.96, anchor: .bottom).combined(with: .opacity),
            removal: .opacity
        ))
        .zIndex(10)
    }

    private var bottomControls: some View {
        VStack(spacing: 48) {
            buttonsRow
                .padding(.horizontal, 30)
            tabBarOverlay
        }
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

    private func continueTapped() {
        var updatedDraft = draft
        updatedDraft.intakeTimes = preparedIntakeTimes()
        updatedDraft.weekdays = preparedWeekdays()
        updatedDraft.courseStartDate = startDate.startOfDayUniversal
        updatedDraft.courseEndDate = endDate.startOfDayUniversal
        onNext(updatedDraft)
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
