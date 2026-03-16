import SwiftUI

private struct VitaminInfoOption: Identifiable {
    let id: String
    let title: String
    let text: String
}

struct PharmacyVitaminDetailsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedTab: AppTab
    let reminderID: Int
    let onConfigure: (VitaminDraft, Int) -> Void
    let onTabRequested: ((AppTab) -> Void)?
    private let repository: ReminderRepository

    @State private var reminder: ReminderRemote?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var expandedOptionIDs: Set<String> = []
    @State private var selectedOptionIDs: Set<String> = []
    @State private var isDeleting = false
    @State private var showDeleteConfirmDialog = false
    @State private var actionErrorMessage: String?

    private let blue = Color(hex: "0E75F2")

    init(
        selectedTab: Binding<AppTab>,
        reminderID: Int,
        onConfigure: @escaping (VitaminDraft, Int) -> Void,
        onTabRequested: ((AppTab) -> Void)? = nil,
        repository: ReminderRepository = ReminderRepository()
    ) {
        _selectedTab = selectedTab
        self.reminderID = reminderID
        self.onConfigure = onConfigure
        self.onTabRequested = onTabRequested
        self.repository = repository
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [Color(hex: "EFF6FF"), .white],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            content
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await loadReminder()
        }
        .alert("Ошибка", isPresented: actionErrorBinding) {
            Button("Ок", role: .cancel) {
                actionErrorMessage = nil
            }
        } message: {
            Text(actionErrorMessage ?? "Не удалось удалить витамин")
        }
        .overlay {
            Color.white
                .opacity(showDeleteConfirmDialog ? 0.75 : 0)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.25), value: showDeleteConfirmDialog)
        }
        .overlay {
            if showDeleteConfirmDialog {
                deleteConfirmOverlay
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showDeleteConfirmDialog)
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(blue)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let reminder {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    header(title: resolvedVitaminName(for: reminder))
                        .padding(.top, 12)
                        .padding(.horizontal, 24)

                    Image("capsule2d")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 160, height: 73.51)
                        .padding(.top, 34)

                    topStatsRow(for: reminder)
                        .padding(.top, 36)
                        .padding(.horizontal, 28)

                    VStack(spacing: 18) {
                        ForEach(infoOptions(for: reminder)) { option in
                            infoCard(option: option)
                        }
                    }
                    .padding(.top, 20)
                    .padding(.horizontal, 24)

                    Button {
                        onConfigure(makeDraft(from: reminder, selectedOptionIDs: selectedOptionIDs), reminder.id)
                    } label: {
                        Text("Настроить")
                            .font(.custom("Commissioner-SemiBold", size: 16))
                            .foregroundColor(.black)
                            .frame(width: 174, height: 40)
                            .background(Color.white)
                            .overlay(configureBorder)
                            .clipShape(RoundedRectangle(cornerRadius: 100, style: .continuous))
                            .shadow(color: Color.black.opacity(0.25), radius: 3.3, x: 1, y: 1)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 28)

                    Button {
                        guard !isDeleting else { return }
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showDeleteConfirmDialog = true
                        }
                    } label: {
                        ZStack {
                            if isDeleting {
                                ProgressView()
                                    .tint(Color(hex: "EA3E3E"))
                            } else {
                                Text("Удалить")
                                    .font(.custom("Commissioner-SemiBold", size: 16))
                                    .foregroundColor(Color(hex: "EA3E3E"))
                            }
                        }
                        .frame(width: 174, height: 40)
                        .background(Color.white)
                        .overlay(configureBorder)
                        .clipShape(RoundedRectangle(cornerRadius: 100, style: .continuous))
                        .shadow(color: Color.black.opacity(0.25), radius: 3.3, x: 1, y: 1)
                    }
                    .buttonStyle(.plain)
                    .disabled(isDeleting)
                    .opacity(isDeleting ? 0.85 : 1)
                    .padding(.top, 12)

                    Color.clear
                        .frame(height: 160)
                }
                .frame(maxWidth: .infinity)
            }
            .overlay(alignment: .bottom) {
                tabBarOverlay
            }
        } else {
            VStack(spacing: 12) {
                Text(errorMessage ?? "Не удалось загрузить данные витамина")
                    .font(.custom("Commissioner-SemiBold", size: 16))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.gray)

                Button("Повторить") {
                    Task { await loadReminder() }
                }
                .font(.custom("Commissioner-SemiBold", size: 16))
                .foregroundColor(blue)
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func header(title: String) -> some View {
        HStack {
            CustomBackButton {
                dismiss()
            }

            Spacer(minLength: 16)

            Text(title)
                .font(.custom("Commissioner-Bold", size: 32.5))
                .foregroundColor(Color(hex: "3B3B3B"))
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Spacer(minLength: 16)

            Color.clear
                .frame(width: 44, height: 44)
        }
    }

    private func topStatsRow(for reminder: ReminderRemote) -> some View {
        HStack(alignment: .top, spacing: 24) {
            statCell(
                content: .text(doseAmount(from: reminder.dose)),
                subtitle: localizedFormLabel(from: reminder.form)
            )

            statCell(
                content: .calendar,
                subtitle: frequencyLabel(from: reminder)
            )

            statCell(
                content: .condition(icon: conditionIconName(from: reminder.condition), size: conditionIconSize(from: reminder.condition)),
                subtitle: conditionLabel(from: reminder.condition)
            )
        }
        .frame(maxWidth: .infinity)
    }

    private func statCell(content: StatContent, subtitle: String) -> some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.black.opacity(0.2), lineWidth: 0.6)
                    )
                    .shadow(color: Color.black.opacity(0.25), radius: 4, x: 0, y: 1)

                switch content {
                case .text(let value):
                    Text(value)
                        .font(.custom("Commissioner-Bold", size: 43))
                        .foregroundStyle(doseValueGradient)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                case .calendar:
                    Image("calendar")
                        .resizable()
                        .renderingMode(.original)
                        .frame(width: 32, height: 35)
                case .condition(let iconName, let size):
                    Image(iconName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: size.width, height: size.height)
                }
            }
            .frame(width: 74.7, height: 69)

            Text(subtitle)
                .font(.custom("Commissioner-Medium", size: 12))
                .foregroundColor(Color(hex: "3B3B3B"))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(width: 90)
        }
    }

    private func infoCard(option: VitaminInfoOption) -> some View {
        let isExpanded = expandedOptionIDs.contains(option.id)
        let isSelected = selectedOptionIDs.contains(option.id)

        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 14) {
                checkmarkCircle(isSelected: isSelected)

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
                Text(option.text)
                    .font(.custom("Commissioner-Medium", size: 16))
                    .foregroundColor(Color(hex: "3B3B3B"))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 30)
                    .padding(.top, 14)
                    .padding(.bottom, 20)
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
                .shadow(color: Color.black.opacity(0.14), radius: 2.4, x: 1, y: 1)
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
            gradient: Gradient(colors: [.white.opacity(0.22), .white.opacity(0)]),
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
            gradient: Gradient(colors: [.white, .white.opacity(0)]),
            center: UnitPoint(x: 0.1494, y: 0.9673),
            startRadius: 0,
            endRadius: 120
        )
    }

    private var configureBorder: some View {
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
            .overlay(
                RoundedRectangle(cornerRadius: 100)
                    .strokeBorder(
                        RadialGradient(
                            gradient: Gradient(colors: [.white, .white.opacity(0)]),
                            center: UnitPoint(x: 0.1494, y: 0.9673),
                            startRadius: 0,
                            endRadius: 120
                        ),
                        lineWidth: 2
                    )
            )
    }

    private var doseValueGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: Color(hex: "7FB2FF"), location: 0.0),
                .init(color: Color(hex: "3B8CF4"), location: 0.48),
                .init(color: Color(hex: "0E75F2"), location: 1.0)
            ]),
            startPoint: UnitPoint(x: 0.46, y: 0.0),
            endPoint: UnitPoint(x: 0.54, y: 1.0)
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
                        if onTabRequested == nil {
                            selectedTab = tab
                            dismiss()
                        }
                    }
                ),
                onSelect: { tab in
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    guard let onTabRequested else { return }
                    onTabRequested(tab)
                }
            )
            Spacer(minLength: 0)
        }
        .padding(.bottom, 12)
        .padding(.horizontal, 0)
        .background(Color.clear.ignoresSafeArea(edges: .bottom))
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

    private var deleteConfirmOverlay: some View {
        ZStack {
            VStack(spacing: 0) {
                Text("Удалить?")
                    .font(.custom("Commissioner-Bold", size: 28.8))
                    .foregroundColor(blue)
                    .padding(.top, 8)

                VStack {
                    Spacer(minLength: 0)

                    Text("Вы точно хотите удалить\nнапоминание о приеме витамина?")
                        .font(.custom("Commissioner-Bold", size: 16))
                        .foregroundColor(Color(hex: "7A7A7A"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 18)

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(dialogDividerGradient)
                    .frame(height: 2)

                HStack(spacing: 0) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showDeleteConfirmDialog = false
                        }
                    } label: {
                        Text("Отмена")
                            .font(.custom("Commissioner-SemiBold", size: 21.75))
                            .foregroundColor(blue)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }

                    Rectangle()
                        .fill(dialogDividerGradient)
                        .frame(width: 2)

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showDeleteConfirmDialog = false
                        }
                        guard let reminder else { return }
                        deleteTapped(reminderID: reminder.id)
                    } label: {
                        Text("Да")
                            .font(.custom("Commissioner-Bold", size: 21.75))
                            .foregroundColor(blue)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(height: 48)
            }
            .frame(width: 318, height: 229, alignment: .top)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(dialogBorderLinearGradient, lineWidth: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(dialogBorderRadialGradient, lineWidth: 2)
            )
            .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 3)
        }
    }

    private var dialogBorderLinearGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 231/255, green: 240/255, blue: 255/255, opacity: 0.523),
                Color(red: 180/255, green: 210/255, blue: 255/255, opacity: 0.1),
                Color(red: 136/255, green: 164/255, blue: 255/255, opacity: 1)
            ],
            startPoint: UnitPoint(x: 0.0, y: 0.0),
            endPoint: UnitPoint(x: 1.0, y: 1.0)
        )
    }

    private var dialogBorderRadialGradient: RadialGradient {
        RadialGradient(
            gradient: Gradient(colors: [Color.white, Color.white.opacity(0)]),
            center: UnitPoint(x: 0.15, y: 0.95),
            startRadius: 0,
            endRadius: 260
        )
    }

    private var dialogDividerGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 90/255, green: 129/255, blue: 255/255, opacity: 0.495),
                Color(red: 86/255, green: 125/255, blue: 255/255, opacity: 0.525413),
                Color(red: 78/255, green: 120/255, blue: 255/255, opacity: 0.495)
            ],
            startPoint: UnitPoint(x: 0.0, y: 0.2),
            endPoint: UnitPoint(x: 1.0, y: 0.9)
        )
    }

    private func loadReminder() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        do {
            let reminders = try await repository.fetchReminders()
            guard let target = reminders.first(where: { $0.id == reminderID }) else {
                await MainActor.run {
                    reminder = nil
                    isLoading = false
                    errorMessage = "Витамин не найден"
                    selectedOptionIDs = []
                }
                return
            }

            await MainActor.run {
                reminder = target
                isLoading = false
                selectedOptionIDs = infoOptionIDs(from: target)
            }
        } catch {
            await MainActor.run {
                reminder = nil
                isLoading = false
                errorMessage = "Не удалось загрузить данные витамина"
                selectedOptionIDs = []
            }
        }
    }

    private func deleteTapped(reminderID: Int) {
        guard !isDeleting else { return }
        isDeleting = true
        actionErrorMessage = nil

        Task {
            do {
                try await repository.deleteReminder(id: reminderID)
                if let reminders = try? await repository.fetchReminders() {
                    await ReminderNotificationScheduler.shared.schedule(from: reminders)
                }
                AnalyticsService.shared.track(
                    AnalyticsEventName.reminderDeleted,
                    properties: [
                        "screen": "reminder_details",
                        "flow": "delete_reminder",
                        "catalog_id": reminder?.catalogID.map(AnalyticsValue.int) ?? .null
                    ]
                )
                await MainActor.run {
                    isDeleting = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isDeleting = false
                    actionErrorMessage = userFriendlyErrorMessage(for: error)
                }
            }
        }
    }

    private func userFriendlyErrorMessage(for error: Error) -> String {
        if let apiError = error as? APIError {
            switch apiError {
            case .unauthorized:
                return "Сессия истекла. Войдите в аккаунт заново."
            case .forbidden:
                return "Недостаточно прав для удаления."
            case .notFound:
                return "Витамин уже удален или не найден."
            case .serverError:
                return "Ошибка сервера. Попробуйте позже."
            default:
                break
            }
        }
        return "Не удалось удалить витамин. Попробуйте снова."
    }

    private func infoOptions(for reminder: ReminderRemote) -> [VitaminInfoOption] {
        [
            .init(id: "interaction", title: "Взаимодействие", text: resolvedInteractionText(for: reminder)),
            .init(id: "compatibility", title: "Совместимость", text: resolvedCompatibilityText(for: reminder)),
            .init(id: "condition", title: "Условие", text: resolvedConditionText(for: reminder)),
            .init(id: "contraindications", title: "Противопоказания", text: resolvedContraindicationsText(for: reminder))
        ]
    }

    private func resolvedVitaminName(for reminder: ReminderRemote) -> String {
        let catalogTitle = reminder.catalog?.displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !catalogTitle.isEmpty {
            return catalogTitle
        }
        let name = reminder.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Витамин" : name
    }

    private func resolvedInteractionText(for reminder: ReminderRemote) -> String {
        let override = reminder.contentOverrides?.interactionTextOverride?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !override.isEmpty { return override }
        let value = reminder.catalog?.interactionText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? "Нет данных" : value
    }

    private func resolvedCompatibilityText(for reminder: ReminderRemote) -> String {
        let override = reminder.contentOverrides?.compatibilityTextOverride?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !override.isEmpty { return override }
        let value = reminder.catalog?.compatibilityText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? "Нет данных" : value
    }

    private func resolvedContraindicationsText(for reminder: ReminderRemote) -> String {
        let override = reminder.contentOverrides?.contraindicationsTextOverride?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !override.isEmpty { return override }
        let value = reminder.catalog?.contraindicationsText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? "Нет данных" : value
    }

    private func resolvedConditionText(for reminder: ReminderRemote) -> String {
        let prefix = conditionLabel(from: reminder.condition).replacingOccurrences(of: "\n", with: " ")
        let note = reminder.note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let merged = [prefix, note].filter { !$0.isEmpty }.joined(separator: ". ")
        return merged.isEmpty ? "Нет данных" : merged
    }

    private func doseAmount(from dose: String?) -> String {
        let source = dose?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let digits = source.filter(\.isNumber)
        return digits.isEmpty ? "1" : digits
    }

    private func localizedFormLabel(from form: String?) -> String {
        switch form?.lowercased() {
        case "tablet": return "Таблетка"
        case "capsule": return "Капсула"
        case "drops": return "Капли"
        case "powder": return "Порошок"
        case "chewable_tablet": return "Жевательная\nтаблетка"
        case "liquid": return "Жидкость"
        case "ampoule": return "Ампула"
        case "spray": return "Спрей"
        case "injection": return "Укол"
        default: return "Вид"
        }
    }

    private func frequencyLabel(from reminder: ReminderRemote) -> String {
        let days = (reminder.schedule?.days ?? []).map { $0.lowercased() }
        if days.isEmpty || Set(days).count >= 7 {
            return "Каждый\nдень"
        }
        let mapped = days.compactMap { dayCodeToLabel($0) }
        if mapped.isEmpty { return "По дням" }
        return mapped.joined(separator: ", ")
    }

    private func dayCodeToLabel(_ code: String) -> String? {
        switch code {
        case "mon": return "Пн"
        case "tue": return "Вт"
        case "wed": return "Ср"
        case "thu": return "Чт"
        case "fri": return "Пт"
        case "sat": return "Сб"
        case "sun": return "Вс"
        default: return nil
        }
    }

    private func conditionLabel(from apiCondition: String?) -> String {
        switch apiCondition?.lowercased() {
        case "before_meal": return "До еды"
        case "after_meal": return "После еды"
        case "during_meal": return "Во время\nеды"
        default: return "Неважно"
        }
    }

    private func conditionIconName(from apiCondition: String?) -> String {
        switch apiCondition?.lowercased() {
        case "before_meal": return "plateUnselected"
        case "after_meal": return "forkUnselected"
        case "during_meal": return "kneeUnselected"
        default: return "markMagnifierUnselected"
        }
    }

    private func conditionIconSize(from apiCondition: String?) -> CGSize {
        switch apiCondition?.lowercased() {
        case "before_meal": return CGSize(width: 32, height: 32)
        case "after_meal": return CGSize(width: 16, height: 39)
        case "during_meal": return CGSize(width: 26, height: 26)
        default: return CGSize(width: 30, height: 30)
        }
    }

    private func makeDraft(from reminder: ReminderRemote, selectedOptionIDs: Set<String>) -> VitaminDraft {
        var draft = VitaminDraft()
        draft.name = resolvedVitaminName(for: reminder)
        draft.type = localizedDraftType(from: reminder.form)
        draft.dose = reminder.dose?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        draft.intake = intakeMoment(from: reminder.condition)
        draft.notes = reminder.note ?? ""
        draft.catalogID = reminder.catalogID
        draft.catalogDefaultUnit = reminder.catalog?.defaultUnit
        draft.catalogInteractionText = reminder.catalog?.interactionText
        draft.catalogCompatibilityText = reminder.catalog?.compatibilityText
        draft.catalogContraindicationsText = reminder.catalog?.contraindicationsText
        draft.catalogDefaultCondition = reminder.catalog?.defaultCondition
        draft.interactionTextOverride = reminder.contentOverrides?.interactionTextOverride
        draft.compatibilityTextOverride = reminder.contentOverrides?.compatibilityTextOverride
        draft.contraindicationsTextOverride = reminder.contentOverrides?.contraindicationsTextOverride
        draft.includeDose = reminder.notificationPreferences?.includeDose ?? true
        draft.includeFrequency = reminder.notificationPreferences?.includeFrequency ?? true
        draft.includeInteraction = selectedOptionIDs.contains("interaction")
        draft.includeCompatibility = selectedOptionIDs.contains("compatibility")
        draft.includeCondition = selectedOptionIDs.contains("condition")
        draft.includeContraindications = selectedOptionIDs.contains("contraindications")

        let times = (reminder.schedule?.times ?? [])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        draft.intakeTimes = times.isEmpty ? [currentTimeString()] : times

        let weekdays = (reminder.schedule?.days ?? []).compactMap(weekday(from:))
        draft.weekdays = weekdays.isEmpty ? Weekday.allCases : weekdays

        draft.courseStartDate = dateFromAPI(reminder.course?.startDate) ?? Date().startOfDayUniversal
        draft.courseEndDate = dateFromAPI(reminder.course?.endDate)
        return draft
    }

    private func infoOptionIDs(from reminder: ReminderRemote) -> Set<String> {
        var ids = Set<String>()
        if reminder.notificationPreferences?.includeInteraction ?? true {
            ids.insert("interaction")
        }
        if reminder.notificationPreferences?.includeCompatibility ?? true {
            ids.insert("compatibility")
        }
        if reminder.notificationPreferences?.includeCondition ?? true {
            ids.insert("condition")
        }
        if reminder.notificationPreferences?.includeContraindications ?? true {
            ids.insert("contraindications")
        }
        return ids
    }

    private func toggleOptionExpansion(_ optionID: String, isExpanded: Bool) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if isExpanded {
                expandedOptionIDs.remove(optionID)
            } else {
                expandedOptionIDs.insert(optionID)
            }
        }
    }

    private func localizedDraftType(from form: String?) -> String {
        switch form?.lowercased() {
        case "tablet": return "Таблетки"
        case "capsule": return "Капсулы"
        case "drops": return "Капли"
        case "powder": return "Порошок"
        case "chewable_tablet": return "Жевательные таблетки"
        case "liquid": return "Жидкость"
        case "ampoule": return "Ампулы"
        case "spray": return "Спрей"
        case "injection": return "Уколы"
        default: return "Капсулы"
        }
    }

    private func intakeMoment(from apiCondition: String?) -> IntakeMoment? {
        switch apiCondition?.lowercased() {
        case "before_meal": return .before
        case "after_meal": return .after
        case "during_meal": return .during
        case "any": return .any
        default: return nil
        }
    }

    private func weekday(from code: String) -> Weekday? {
        switch code.lowercased() {
        case "mon": return .mon
        case "tue": return .tue
        case "wed": return .wed
        case "thu": return .thu
        case "fri": return .fri
        case "sat": return .sat
        case "sun": return .sun
        default: return nil
        }
    }

    private func dateFromAPI(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: raw)?.startOfDayUniversal
    }

    private func currentTimeString() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date())
    }
}

private enum StatContent {
    case text(String)
    case calendar
    case condition(icon: String, size: CGSize)
}
