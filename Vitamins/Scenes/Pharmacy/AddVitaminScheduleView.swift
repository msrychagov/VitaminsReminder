import SwiftUI

struct IntakeEntry: Identifiable {
    let id = UUID()
    var order: Int
    var time: String
}

struct AddVitaminScheduleView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedTab: AppTab
    let draft: VitaminDraft
    let onNext: () -> Void

    @State private var entries: [IntakeEntry] = [IntakeEntry(order: 1, time: "23:53")]
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date().addingTimeInterval(24*60*60*14)
    @State private var showStartPicker = false
    @State private var showEndPicker = false
    @State private var showDaysPicker = false
    @State private var selectedWeekdays: Set<Weekday> = Set(Weekday.allCases)
    @FocusState private var timeFieldFocused: Bool

    private let blue = Color(hex: "0E75F2")

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

            .sheet(isPresented: $showStartPicker) {
                datePickerSheet(title: "Начало", date: Binding(
                    get: { startDate },
                    set: { newValue in
                        let today = Date().startOfDayUniversal
                        let clamped = max(newValue.startOfDayUniversal, today)
                        startDate = clamped
                        if startDate > endDate {
                            endDate = startDate
                        }
                    }),
                    onDone: { showStartPicker = false }
                )
            }
            .sheet(isPresented: $showEndPicker) {
                datePickerSheet(title: "Конец", date: Binding(
                    get: { endDate },
                    set: { newValue in
                        let today = Date().startOfDayUniversal
                        let clamped = max(newValue.startOfDayUniversal, today)
                        endDate = clamped
                        if endDate < startDate {
                            startDate = endDate
                        }
                    }),
                    onDone: { showEndPicker = false }
                )
            }
            .sheet(isPresented: $showDaysPicker) {
                daysPickerSheet()
            }
        }
        .overlay(alignment: .bottom) {
            bottomControls
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .contentShape(Rectangle())
        .onTapGesture {
            UIApplication.shared.endEditing()
            timeFieldFocused = false
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
            ForEach($entries) { $entry in
                VStack(alignment: .leading, spacing: 16) {
                    Text("Прием \(entry.order)")
                        .font(.custom("Commissioner-SemiBold", size: 18))
                        .foregroundColor(.white)
                        .padding(.top, 16)
                        .padding(.leading, 16)

            TextField(
                "",
                text: $entry.time.onChange { newValue in
                    let normalized = formattedTimeInput(newValue)
                    if normalized != newValue {
                        entry.time = normalized
                    }
                },
                prompt: Text("23:00").foregroundColor(.black.opacity(0.4))
            )
            .keyboardType(.numberPad)
            .font(.custom("Commissioner-SemiBold", size: 20))
            .foregroundColor(.black)
            .padding(.horizontal, 19)
            .frame(height: 65, alignment: .center)
            .background(Color.white)
            .cornerRadius(16)
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
            entries.append(IntakeEntry(order: next, time: "23:00"))
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
        return VStack(spacing: 0) {
            Button {
                showDaysPicker = true
            } label: {
                HStack {
                    Text("Дни приёма")
                        .font(.custom("Commissioner-SemiBold", size: 18))
                        .foregroundColor(.black)
                        .padding(.leading, 0)
                    Spacer()
                    HStack(spacing: 12) {
                        Text(formattedWeekdays)
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
                .padding(.horizontal, 18)
                .padding(.bottom, 12)
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
                courseRow(title: "Начало", value: formattedDate(startDate)) {
                    showStartPicker = true
                }
                Rectangle()
                    .fill(Color(hex: "E5E5E5"))
                    .frame(height: 1)
                courseRow(title: "Конец", value: formattedDate(endDate), showDivider: false) {
                    showEndPicker = true
                }
            }
        }
    }

    private func courseRow(title: String, value: String, showDivider: Bool = true, action: @escaping () -> Void) -> some View {
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

    private func formattedTimeInput(_ raw: String) -> String {
        // только цифры, до 4 символов, автоматическая вставка двоеточия после двух цифр, без проверки диапазонов
        var digits = raw.filter { $0.isNumber }
        if digits.count > 4 { digits = String(digits.prefix(4)) }

        switch digits.count {
        case 0:
            return ""
        case 1:
            return digits
        case 2:
            return "\(digits):"
        default:
            let hour = String(digits.prefix(2))
            let minute = String(digits.dropFirst(2))
            return "\(hour):\(minute.prefix(2))"
        }
    }

    private var formattedWeekdays: String {
        if selectedWeekdays.count == Weekday.allCases.count {
            return "каждый день"
        }
        let sorted = Weekday.allCases.filter { selectedWeekdays.contains($0) }
        return sorted.map { $0.rawValue }.joined(separator: ", ")
    }

    private func datePickerSheet(title: String, date: Binding<Date>, onDone: @escaping () -> Void) -> some View {
        return NavigationStack {
            VStack {
                DatePicker("", selection: date, in: Date().startOfDayUniversal...Date.distantFuture, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .padding()

                Spacer()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { onDone() }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { onDone() }
                }
            }
        }
    }

    private func daysPickerSheet() -> some View {
        return NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Выберите дни недели")
                    .font(.custom("Commissioner-SemiBold", size: 18))
                    .padding(.horizontal, 16)
                    .padding(.top, 10)

                List {
                    ForEach(Weekday.allCases) { day in
                        MultipleSelectionRow(
                            title: day.rawValue,
                            isSelected: selectedWeekdays.contains(day),
                            action: {
                                if selectedWeekdays.contains(day) {
                                    selectedWeekdays.remove(day)
                                } else {
                                    selectedWeekdays.insert(day)
                                }
                            }
                        )
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Дни приёма")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") {
                        if selectedWeekdays.isEmpty {
                            selectedWeekdays = Set(Weekday.allCases)
                        }
                        showDaysPicker = false
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        showDaysPicker = false
                    }
                }
            }
        }
    }

    private var bottomControls: some View {
        VStack(spacing: 48) {
            buttonsRow
                .padding(.horizontal, 30)

            if !timeFieldFocused {
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

            Button(action: onNext) {
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
}
