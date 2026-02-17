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
    let onAdded: () -> Void
    private let repository: ReminderCreationRepository

    @State private var expandedOptionID: String?
    @State private var detailsByOptionID: [String: String] = [:]
    @State private var selectedOptionIDs: Set<String> = [
        "dose",
        "frequency",
        "interaction",
        "compatibility",
        "condition",
        "contraindications"
    ]
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @FocusState private var focusedOptionID: String?

    private let blue = Color(hex: "0E75F2")
    private let options: [NotificationOption] = [
        .init(id: "dose", title: "Доза за прием", placeholder: "Например, 1 таблетка"),
        .init(id: "frequency", title: "Частота", placeholder: "Например, 2 раза в день"),
        .init(id: "interaction", title: "Взаимодействие", placeholder: "Принимайте с..."),
        .init(id: "compatibility", title: "Совместимость", placeholder: "Уточните совместимость"),
        .init(id: "condition", title: "Условие", placeholder: "Например, после еды"),
        .init(id: "contraindications", title: "Противопоказания", placeholder: "Укажите противопоказания")
    ]

    init(
        selectedTab: Binding<AppTab>,
        draft: VitaminDraft,
        onAdded: @escaping () -> Void = {},
        repository: ReminderCreationRepository = ReminderCreationRepository()
    ) {
        _selectedTab = selectedTab
        self.draft = draft
        self.onAdded = onAdded
        self.repository = repository
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "EFF6FF"), .white],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

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

                    VStack(spacing: 24) {
                        ForEach(options) { option in
                            optionCard(for: option)
                                .frame(maxWidth: 352)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 32)
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 160)
            }
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
        }
        .overlay(alignment: .bottom) {
            bottomControls
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
    }

    private func optionCard(for option: NotificationOption) -> some View {
        let isExpanded = expandedOptionID == option.id
        let isSelected = selectedOptionIDs.contains(option.id)

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
                TextField(
                    "",
                    text: detailBinding(for: option.id),
                    prompt: Text(option.placeholder).foregroundColor(Color(hex: "A8A8A8"))
                )
                .focused($focusedOptionID, equals: option.id)
                .font(.custom("Commissioner-SemiBold", size: 18))
                .foregroundColor(Color(hex: "3B3B3B"))
                .padding(.horizontal, 30)
                .padding(.top, 22)

                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: isExpanded ? 185 : 48, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .strokeBorder(cardLinearBorder, lineWidth: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .strokeBorder(cardRadialBorder, lineWidth: 2)
                )
                .shadow(color: Color.black.opacity(0.2), radius: 3.3, x: 1, y: 1)
        )
    }

    private func checkmarkCircle(isSelected: Bool) -> some View {
        ZStack {
            Circle()
                .fill(Color.white)

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Color(hex: "1871FF"))
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
            colors: [
                Color(red: 18/255, green: 113/255, blue: 1, opacity: 0.523483),
                Color(hex: "88A4FF"),
                Color(red: 35/255, green: 118/255, blue: 242/255, opacity: 0.1)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var cardRadialBorder: RadialGradient {
        RadialGradient(
            gradient: Gradient(colors: [
                Color.white,
                Color.white.opacity(0)
            ]),
            center: UnitPoint(x: 0.1494, y: 0.9673),
            startRadius: 0,
            endRadius: 220
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

    private var bottomControls: some View {
        VStack(spacing: 48) {
            buttonsRow
                .padding(.horizontal, 30)

            if focusedOptionID == nil {
                tabBarOverlay
            } else {
                Color.clear
                    .frame(height: 68)
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

            Button(action: addTapped) {
                ZStack {
                    if isSubmitting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Добавить")
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

    private func addTapped() {
        guard !isSubmitting else { return }

        UIApplication.shared.endEditing()
        focusedOptionID = nil
        errorMessage = nil
        isSubmitting = true

        let request = makeCreateReminderRequest()

        Task {
            do {
                try await repository.createReminder(request: request)
                await MainActor.run {
                    isSubmitting = false
                    onAdded()
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = "Не удалось добавить витамин. Проверьте подключение и попробуйте снова."
                }
            }
        }
    }

    private func makeCreateReminderRequest() -> CreateVitaminReminderRequest {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let dose = draft.dose.trimmingCharacters(in: .whitespacesAndNewlines)
        let note = draft.notes.trimmingCharacters(in: .whitespacesAndNewlines)

        let weekdays = draft.weekdays.isEmpty ? Weekday.allCases : draft.weekdays
        let times = draft.intakeTimes.isEmpty ? ["09:00"] : draft.intakeTimes
        let startDate = draft.courseStartDate
        let endDate = draft.courseEndDate
        let timezone = TimeZone.current.identifier

        return CreateVitaminReminderRequest(
            catalogID: 1,
            name: name.isEmpty ? nil : name,
            form: "capsule",
            dose: dose.isEmpty ? "1" : dose,
            condition: draft.intake?.apiCondition ?? "any",
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
        let trimmed = detailsByOptionID[optionID]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}
