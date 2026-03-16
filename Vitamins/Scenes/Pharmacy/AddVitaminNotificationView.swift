import SwiftUI

private struct NotificationOption: Identifiable, Hashable {
    let id: String
    let title: String
    let placeholder: String
}

struct AddVitaminNotificationView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedTab: AppTab
    let draft: VitaminDraft
    let reminderID: Int?
    let onAdded: () -> Void
    let onTabRequested: ((AppTab) -> Void)?
    let isEditing: Bool
    private let repository: ReminderCreationRepository

    @State private var expandedOptionID: String?
    @State private var detailsByOptionID: [String: String]
    @State private var selectedOptionIDs: Set<String>
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @FocusState private var focusedOptionID: String?
    @State private var didSubmitSuccessfully = false

    private let blue = Color(hex: "0E75F2")
    private let options: [NotificationOption] = [
        .init(id: "dose", title: "Доза за прием", placeholder: "Например, 1 таблетка"),
        .init(id: "frequency", title: "Частота", placeholder: "Например, 2 раза в день"),
        .init(id: "note", title: "Примечание", placeholder: "Добавьте примечание"),
        .init(id: "condition", title: "Условие", placeholder: "Например, после еды"),
        .init(id: "interaction", title: "Взаимодействие", placeholder: "Принимайте с..."),
        .init(id: "compatibility", title: "Совместимость", placeholder: "Уточните совместимость"),
        .init(id: "contraindications", title: "Противопоказания", placeholder: "Укажите противопоказания")
    ]

    init(
        selectedTab: Binding<AppTab>,
        draft: VitaminDraft,
        reminderID: Int? = nil,
        onAdded: @escaping () -> Void = {},
        onTabRequested: ((AppTab) -> Void)? = nil,
        isEditing: Bool = false,
        repository: ReminderCreationRepository = ReminderCreationRepository()
    ) {
        _selectedTab = selectedTab
        self.draft = draft
        self.reminderID = reminderID
        self.onAdded = onAdded
        self.onTabRequested = onTabRequested
        self.isEditing = isEditing
        self.repository = repository
        _detailsByOptionID = State(initialValue: Self.prefilledDetails(from: draft))
        _selectedOptionIDs = State(initialValue: Self.prefilledSelectedOptionIDs(from: draft))
    }

    private static func prefilledSelectedOptionIDs(from draft: VitaminDraft) -> Set<String> {
        var ids = Set<String>()
        if draft.includeDose { ids.insert("dose") }
        if draft.includeFrequency { ids.insert("frequency") }
        ids.insert("note")
        if draft.includeInteraction { ids.insert("interaction") }
        if draft.includeCompatibility { ids.insert("compatibility") }
        if draft.includeCondition { ids.insert("condition") }
        if draft.includeContraindications { ids.insert("contraindications") }
        return ids
    }

    private static func prefilledDetails(from draft: VitaminDraft) -> [String: String] {
        var details: [String: String] = [:]

        let dose = trimmed(draft.dose)
        if !dose.isEmpty {
            details["dose"] = dose
        }

        let frequency = frequencyText(from: draft)
        if !frequency.isEmpty {
            details["frequency"] = frequency
        }

        let note = trimmed(draft.notes)
        if !note.isEmpty {
            details["note"] = note
        }

        let interactionOverride = trimmed(draft.interactionTextOverride)
        let interaction = interactionOverride.isEmpty
            ? trimmed(draft.catalogInteractionText)
            : interactionOverride
        if !interaction.isEmpty {
            details["interaction"] = interaction
        }

        let compatibilityOverride = trimmed(draft.compatibilityTextOverride)
        let compatibility = compatibilityOverride.isEmpty
            ? trimmed(draft.catalogCompatibilityText)
            : compatibilityOverride
        if !compatibility.isEmpty {
            details["compatibility"] = compatibility
        }

        let condition = conditionText(from: draft)
        if !condition.isEmpty {
            details["condition"] = condition
        }

        let contraindicationsOverride = trimmed(draft.contraindicationsTextOverride)
        let contraindications = contraindicationsOverride.isEmpty
            ? trimmed(draft.catalogContraindicationsText)
            : contraindicationsOverride
        if !contraindications.isEmpty {
            details["contraindications"] = contraindications
        }

        return details
    }

    private static func frequencyText(from draft: VitaminDraft) -> String {
        let orderedWeekdays = Weekday.allCases.filter { draft.weekdays.contains($0) }
        let daysText: String
        if orderedWeekdays.isEmpty || orderedWeekdays.count == Weekday.allCases.count {
            daysText = "каждый день"
        } else {
            daysText = orderedWeekdays.map { $0.rawValue.lowercased() }.joined(separator: ", ")
        }

        let times = draft.intakeTimes
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !times.isEmpty else { return daysText }
        return "\(daysText), \(times.joined(separator: ", "))"
    }

    private static func conditionText(from draft: VitaminDraft) -> String {
        if let intake = draft.intake {
            return intake.rawValue.replacingOccurrences(of: "\n", with: " ")
        }
        return localizedCondition(from: draft.catalogDefaultCondition)
    }

    private static func localizedCondition(from apiCondition: String?) -> String {
        switch apiCondition?.lowercased() {
        case "before_meal":
            return "До еды"
        case "after_meal":
            return "После еды"
        case "during_meal":
            return "Во время еды"
        case "any":
            return "Неважно"
        default:
            return ""
        }
    }

    private static func trimmed(_ value: String?) -> String {
        value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
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
                    VStack(spacing: 0) {
                        StepProgressView(filledSegments: 3)
                            .padding(.top, 18)
                            .padding(.horizontal, 30)

                        Text("Выберите пункты, которые\nбудут в уведомлении")
                            .font(.custom("Commissioner-Bold", size: 20))
                            .foregroundColor(.black)
                            .multilineTextAlignment(.center)
                            .padding(.top, 44)
                            .padding(.horizontal, 24)

                        VStack(spacing: 16) {
                            ForEach(options) { option in
                                optionCard(for: option)
                                    .frame(maxWidth: 352)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 32)
                        .padding(.horizontal, 20)

                        buttonsRow
                            .padding(.top, 28)
                            .padding(.horizontal, 30)
                            .padding(.bottom, 28)
                    }
                }
                .navigationBarBackButtonHidden(true)
                .toolbar(.hidden, for: .navigationBar)

                if focusedOptionID == nil {
                    tabBarOverlay
                } else {
                    Color.clear
                        .frame(height: 68)
                }
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .contentShape(Rectangle())
        .onTapGesture {
            UIApplication.shared.endEditing()
            focusedOptionID = nil
        }
        .alert("Ошибка", isPresented: errorAlertBinding) {
            Button("Ок", role: .cancel) {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "Не удалось добавить витамин")
        }
        .onDisappear {
            guard !didSubmitSuccessfully else { return }
            AnalyticsService.shared.track(
                AnalyticsEventName.wizardAbandoned,
                properties: [
                    "screen": "wizard_step3",
                    "flow": .string(analyticsFlow),
                    "step": 3,
                    "reason": "dismissed"
                ]
            )
        }
    }

    private func optionCard(for option: NotificationOption) -> some View {
        let isExpanded = expandedOptionID == option.id
        let isSelected = selectedOptionIDs.contains(option.id)
        let isEditable = isOptionEditable(option.id)

        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 14) {
                Button {
                    toggleOptionSelection(option.id)
                } label: {
                    checkmarkCircle(isSelected: isSelected)
                }
                .buttonStyle(.plain)

                HStack(spacing: 12) {
                    Text(option.title)
                        .font(.custom("Commissioner-SemiBold", size: 18))
                        .foregroundColor(Color(hex: "3B3B3B"))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Image("chevronWhite")
                        .resizable()
                        .renderingMode(.template)
                        .foregroundColor(.black)
                        .frame(width: 20, height: 20)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(.easeInOut(duration: 0.2), value: isExpanded)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    toggleOptionExpansion(option.id, isExpanded: isExpanded)
                }
            }
            .padding(.leading, 10)
            .padding(.trailing, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 48)

            if isExpanded {
                if isEditable {
                    TextField(
                        "",
                        text: detailBinding(for: option.id),
                        prompt: Text(option.placeholder).foregroundColor(Color(hex: "A8A8A8")),
                        axis: .vertical
                    )
                    .focused($focusedOptionID, equals: option.id)
                    .font(.custom("Commissioner-SemiBold", size: 18))
                    .foregroundColor(Color(hex: "3B3B3B"))
                    .lineLimit(2...100)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 30)
                    .padding(.top, 22)
                    .padding(.bottom, 22)
                } else {
                    Text(readOnlyOptionValue(for: option))
                        .font(.custom("Commissioner-SemiBold", size: 18))
                        .foregroundColor(Color(hex: "3B3B3B"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 30)
                        .padding(.top, 22)
                        .padding(.bottom, 22)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(minHeight: 48, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .strokeBorder(cardLinearBorder, lineWidth: 1.6)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .strokeBorder(cardRadialBorder, lineWidth: 1.6)
                )
                .shadow(color: Color.black.opacity(0.12), radius: 2.2, x: 0, y: 1)
        )
    }

    private func checkmarkCircle(isSelected: Bool) -> some View {
        ZStack {
            Circle()
                .fill(Color.white)

            if isSelected {
                Image("chatacteristicMark")
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
                    .frame(width: 20, height: 20)
            }
        }
        .frame(width: 33, height: 33)
        .overlay(
            Circle()
                .strokeBorder(checkLinearBorder, lineWidth: 1)
        )
        .overlay(
            Circle()
                .strokeBorder(checkRadialBorder, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.25), radius: 3.3, x: 1, y: 1)
    }

    private var cardLinearBorder: LinearGradient {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: Color(red: 18/255, green: 113/255, blue: 1, opacity: 0.56), location: 0.0),
                .init(color: Color(hex: "88A4FF").opacity(0.82), location: 0.5),
                .init(color: Color(red: 35/255, green: 118/255, blue: 242/255, opacity: 0.46), location: 1.0)
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var cardRadialBorder: RadialGradient {
        RadialGradient(
            gradient: Gradient(colors: [
                Color.white.opacity(0.22),
                Color.white.opacity(0)
            ]),
            center: UnitPoint(x: 0.1494, y: 0.9673),
            startRadius: 0,
            endRadius: 240
        )
    }

    private var checkLinearBorder: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 231/255, green: 240/255, blue: 1, opacity: 0.523483),
                Color(hex: "88A4FF"),
                Color(red: 180/255, green: 210/255, blue: 1, opacity: 0.1)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var checkRadialBorder: RadialGradient {
        RadialGradient(
            gradient: Gradient(colors: [
                Color.white,
                Color.white.opacity(0)
            ]),
            center: UnitPoint(x: 0.1494, y: 0.9673),
            startRadius: 0,
            endRadius: 120
        )
    }

    private func detailBinding(for optionID: String) -> Binding<String> {
        Binding(
            get: { detailsByOptionID[optionID, default: ""] },
            set: { detailsByOptionID[optionID] = $0 }
        )
    }

    private func isOptionEditable(_ optionID: String) -> Bool {
        switch optionID {
        case "dose", "frequency":
            return false
        default:
            return true
        }
    }

    private func readOnlyOptionValue(for option: NotificationOption) -> String {
        let value = detailsByOptionID[option.id, default: ""].trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? option.placeholder : value
    }

    private func toggleOptionExpansion(_ optionID: String, isExpanded: Bool) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if isExpanded {
                expandedOptionID = nil
                focusedOptionID = nil
            } else {
                expandedOptionID = optionID
            }
        }
    }

    private func toggleOptionSelection(_ optionID: String) {
        withAnimation(.easeInOut(duration: 0.15)) {
            if selectedOptionIDs.contains(optionID) {
                selectedOptionIDs.remove(optionID)
            } else {
                selectedOptionIDs.insert(optionID)
            }
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

            Button(action: submitTapped) {
                ZStack {
                    if isSubmitting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(reminderID == nil ? "Добавить" : "Сохранить")
                            .font(.custom("Commissioner-Bold", size: 20))
                            .foregroundColor(.white)
                    }
                }
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
            .buttonStyle(.plain)
            .disabled(isSubmitting)
            .opacity(isSubmitting ? 0.9 : 1)
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

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    errorMessage = nil
                }
            }
        )
    }

    private func submitTapped() {
        guard !isSubmitting else { return }

        UIApplication.shared.endEditing()
        focusedOptionID = nil
        errorMessage = nil
        isSubmitting = true

        let request = makeCreateReminderRequest()

        Task {
            do {
                if let reminderID {
                    try await repository.updateReminder(id: reminderID, request: request)
                } else {
                    try await repository.createReminder(request: request)
                }
                if let reminders = try? await ReminderRepository().fetchReminders() {
                    await ReminderNotificationScheduler.shared.schedule(from: reminders)
                }
                let reminderProperties = analyticsReminderProperties()
                AnalyticsService.shared.track(
                    AnalyticsEventName.wizardStep3Completed,
                    properties: [
                        "screen": "wizard_step3",
                        "flow": .string(analyticsFlow),
                        "step": 3,
                        "times_count": reminderProperties["times_count"] ?? .int(draft.intakeTimes.count),
                        "days_count": reminderProperties["days_count"] ?? .int(draft.weekdays.count),
                        "has_overrides": reminderProperties["has_overrides"] ?? false
                    ]
                )
                AnalyticsService.shared.track(
                    reminderID == nil
                        ? AnalyticsEventName.reminderCreated
                        : AnalyticsEventName.reminderUpdated,
                    properties: reminderProperties
                )
                AnalyticsService.shared.track(
                    AnalyticsEventName.notificationPreferencesChanged,
                    properties: [
                        "screen": "wizard_step3",
                        "flow": .string(analyticsFlow),
                        "has_overrides": .bool(hasOverrides)
                    ]
                )
                if hasOverrides {
                    AnalyticsService.shared.track(
                        AnalyticsEventName.notificationOverrideEdited,
                        properties: [
                            "screen": "wizard_step3",
                            "flow": .string(analyticsFlow),
                            "has_overrides": true
                        ]
                    )
                }
                await MainActor.run {
                    didSubmitSuccessfully = true
                    isSubmitting = false
                    onAdded()
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = userFriendlyErrorMessage(for: error)
                }
            }
        }
    }

    private func makeCreateReminderRequest() -> CreateVitaminReminderRequest {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let dose = draft.dose.trimmingCharacters(in: .whitespacesAndNewlines)
        let note = resolvedNoteForAPI()
        let condition = resolvedConditionForAPI()

        let weekdays = draft.weekdays.isEmpty ? Weekday.allCases : draft.weekdays
        let times = draft.intakeTimes.isEmpty ? [currentTimeString()] : draft.intakeTimes
        let startDate = draft.courseStartDate
        let endDate = draft.courseEndDate
        let timezone = TimeZone.current.identifier

        return CreateVitaminReminderRequest(
            catalogID: draft.catalogID,
            name: name.isEmpty ? nil : name,
            form: resolvedFormForAPI(),
            dose: dose.isEmpty ? "1" : dose,
            condition: condition,
            note: note,
            course: .init(
                startDate: apiDateString(startDate),
                endDate: endDate.map(apiDateString),
                timezone: timezone
            ),
            schedule: .init(
                days: weekdays.map(\.apiCode),
                times: times
            ),
            notificationPreferences: .init(
                includeDose: selectedOptionIDs.contains("dose"),
                includeFrequency: selectedOptionIDs.contains("frequency"),
                includeInteraction: selectedOptionIDs.contains("interaction"),
                includeCompatibility: selectedOptionIDs.contains("compatibility"),
                includeCondition: selectedOptionIDs.contains("condition"),
                includeContraindications: selectedOptionIDs.contains("contraindications")
            ),
            contentOverrides: .init(
                interactionTextOverride: overrideText(for: "interaction"),
                compatibilityTextOverride: overrideText(for: "compatibility"),
                contraindicationsTextOverride: overrideText(for: "contraindications")
            )
        )
    }

    private func apiDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func overrideText(for optionID: String) -> String? {
        guard selectedOptionIDs.contains(optionID) else { return nil }
        let value = detailsByOptionID[optionID]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !value.isEmpty else { return nil }

        let defaultValue = defaultOverrideText(for: optionID)
        if !defaultValue.isEmpty && value == defaultValue {
            return nil
        }
        return value
    }

    private func resolvedConditionForAPI() -> String {
        if let intake = draft.intake {
            return intake.apiCondition
        }

        switch draft.catalogDefaultCondition?.lowercased() {
        case "before_meal":
            return "before_meal"
        case "after_meal":
            return "after_meal"
        case "during_meal":
            return "during_meal"
        default:
            return "any"
        }
    }

    private func resolvedFormForAPI() -> String {
        switch draft.type.lowercased() {
        case "таблетки":
            return "tablet"
        case "капсулы":
            return "capsule"
        case "капли":
            return "drops"
        case "порошок":
            return "powder"
        case "жевательные таблетки":
            return "chewable_tablet"
        case "жидкость":
            return "liquid"
        case "ампулы":
            return "ampoule"
        case "спрей":
            return "spray"
        case "уколы":
            return "injection"
        default:
            return "capsule"
        }
    }

    private func currentTimeString() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date())
    }

    private func defaultOverrideText(for optionID: String) -> String {
        switch optionID {
        case "interaction":
            return draft.catalogInteractionText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        case "compatibility":
            return draft.catalogCompatibilityText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        case "contraindications":
            return draft.catalogContraindicationsText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        default:
            return ""
        }
    }

    private func resolvedNoteForAPI() -> String {
        guard selectedOptionIDs.contains("note") else { return "" }
        return detailsByOptionID["note"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func userFriendlyErrorMessage(for error: Error) -> String {
        if let apiError = error as? APIError {
            switch apiError {
            case .badRequest(let data), .unprocessableEntity(let data):
                return extractBackendErrorMessage(from: data)
                    ?? "Сервер отклонил данные. Проверьте формат полей и попробуйте снова."
            case .unauthorized:
                return "Сессия истекла. Войдите в аккаунт заново."
            case .forbidden:
                return "Недостаточно прав для этого действия."
            case .notFound:
                return "Выбранный витамин не найден в каталоге."
            case .conflict:
                return "Конфликт данных. Обновите экран и попробуйте снова."
            case .serverError:
                return "Ошибка сервера. Попробуйте позже."
            default:
                break
            }
        }
        return "Не удалось добавить витамин. Проверьте подключение и попробуйте снова."
    }

    private var analyticsFlow: String {
        isEditing ? "update_reminder" : "create_reminder"
    }

    private var hasOverrides: Bool {
        overrideText(for: "interaction") != nil
            || overrideText(for: "compatibility") != nil
            || overrideText(for: "contraindications") != nil
    }

    private func analyticsReminderProperties() -> AnalyticsProperties {
        var properties: AnalyticsProperties = [
            "screen": "wizard_step3",
            "flow": .string(analyticsFlow),
            "form": .string(resolvedFormForAPI()),
            "has_note": .bool(!resolvedNoteForAPI().isEmpty),
            "times_count": .int(draft.intakeTimes.count),
            "days_count": .int(draft.weekdays.count),
            "has_overrides": .bool(hasOverrides)
        ]

        if let catalogID = draft.catalogID {
            properties["catalog_id"] = .int(catalogID)
        }

        return properties
    }

    private func extractBackendErrorMessage(from data: Data?) -> String? {
        guard let data, !data.isEmpty else { return nil }
        guard let json = try? JSONSerialization.jsonObject(with: data) else { return nil }

        if let dict = json as? [String: Any] {
            if let message = dict["message"] as? String, !message.isEmpty {
                return message
            }
            if let messages = dict["message"] as? [String], !messages.isEmpty {
                return messages.joined(separator: "\n")
            }
            if let error = dict["error"] as? String, !error.isEmpty {
                return error
            }
        }

        return nil
    }
}
