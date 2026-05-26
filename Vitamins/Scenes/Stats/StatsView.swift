import SwiftUI

struct StatsView: View {
    @StateObject private var viewModel = StatsViewModel()
    @State private var isMonthPickerPresented = false

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "LLLL yyyy"
        return f
    }()

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Статистика")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(Color(hex: "3B3B3B"))
                    .padding(.top, 8)

                monthPill

                content
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 140)
        }
        .background(Color.white)
        .onAppear {
            Task { await viewModel.load() }
        }
        .sheet(isPresented: $isMonthPickerPresented) {
            MonthPickerSheet(
                selection: Binding(
                    get: { viewModel.selectedMonth },
                    set: { newValue in
                        viewModel.selectedMonth = newValue
                        Task { await viewModel.load() }
                    }
                )
            )
            .presentationDetents([.height(360)])
        }
    }

    private var monthPill: some View {
        Button {
            isMonthPickerPresented = true
        } label: {
            HStack(spacing: 8) {
                calendarIcon

                Text(Self.monthFormatter.string(from: viewModel.selectedMonth).capitalized)
                    .font(.custom("Commissioner-SemiBold", size: 15))
                    .foregroundColor(.black)

                Image("chevron")
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(Color(hex: "0773F1"))
                    .scaledToFit()
                    .frame(width: 12, height: 12)
                    .rotationEffect(.degrees(90))
                    .padding(.leading, 2)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white)
                    .shadow(color: Color(hex: "0773F1").opacity(0.18), radius: 10, x: 0, y: 4)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var calendarIcon: some View {
        if let uiImage = UIImage(named: "statsCalendar") {
            Image(uiImage: uiImage)
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(width: 22, height: 22)
        } else {
            Image(systemName: "calendar")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color(hex: "0773F1"))
                .frame(width: 22, height: 22)
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.stats == nil {
            ProgressView()
                .progressViewStyle(.circular)
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
        } else if let stats = viewModel.stats {
            statsBody(for: stats)
        } else if let message = viewModel.errorMessage {
            Text(message)
                .font(.custom("Commissioner-Regular", size: 16))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
        }
    }

    private func statsBody(for stats: MonthStatsResponse) -> some View {
        VStack(spacing: 16) {
            ringCard(for: stats)
            summaryCard(for: stats)

            if !viewModel.items.isEmpty {
                vitaminBreakdown
            }
        }
    }

    private var vitaminBreakdown: some View {
        VStack(spacing: 12) {
            ForEach(viewModel.items) { item in
                reminderItemCard(item)
            }
        }
    }

    private func reminderItemCard(_ item: ReminderStatsItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(item.name)
                .font(.custom("Commissioner-Bold", size: 15))
                .foregroundColor(.black)
                .lineLimit(1)

            HStack(spacing: 10) {
                progressBar(percent: item.completionPercent)
                    .frame(height: 8)

                Text("\(Int(item.completionPercent.rounded()))%")
                    .font(.custom("Commissioner-Bold", size: 16))
                    .foregroundColor(Color(hex: "0773F1"))
            }

            HStack(spacing: 14) {
                statLine(title: "Принято:", value: item.takenCount, valueColor: Color(hex: "0773F1"))
                statLine(title: "Пропущено:", value: item.missedCount, valueColor: Color(hex: "F04A4A"))
                statLine(title: "Осталось:", value: item.remainingCount, valueColor: Color(hex: "8AB4FF"))
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color(hex: "0773F1").opacity(0.10), radius: 10, x: 0, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    LinearGradient(
                        stops: [
                            .init(color: Color(hex: "F1F5FF"), location: 0.0),
                            .init(color: Color(hex: "E5ECFF"), location: 0.6),
                            .init(color: Color(hex: "B4D2FF"), location: 0.9),
                            .init(color: Color(hex: "7FB1FF"), location: 1.0)
                        ],
                        startPoint: .bottomLeading,
                        endPoint: .topTrailing
                    ),
                    lineWidth: 1.5
                )
        )
    }

    private func progressBar(percent: Double) -> some View {
        let clamped = min(max(percent / 100.0, 0), 1)
        return GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(hex: "D9E6FF"))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "5BA0FF"), Color(hex: "0773F1")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(8, proxy.size.width * clamped))
            }
        }
    }

    private func statLine(title: String, value: Int, valueColor: Color) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.custom("Commissioner-Regular", size: 12))
                .foregroundColor(.black)
            Text("\(value)")
                .font(.custom("Commissioner-Bold", size: 12))
                .foregroundColor(valueColor)
        }
    }

    private func ringCard(for stats: MonthStatsResponse) -> some View {
        MonthProgressRing(
            takenDays: stats.takenDays,
            missedDays: stats.missedDays,
            remainingDays: stats.remainingDays,
            completionPercent: stats.completionPercent,
            status: stats.status
        )
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color(hex: "0773F1").opacity(0.10), radius: 12, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    LinearGradient(
                        stops: [
                            .init(color: Color(hex: "F1F5FF"), location: 0.0),
                            .init(color: Color(hex: "E5ECFF"), location: 0.6),
                            .init(color: Color(hex: "B4D2FF"), location: 0.9),
                            .init(color: Color(hex: "7FB1FF"), location: 1.0)
                        ],
                        startPoint: .bottomLeading,
                        endPoint: .topTrailing
                    ),
                    lineWidth: 1.5
                )
        )
    }

    private func summaryCard(for stats: MonthStatsResponse) -> some View {
        VStack(spacing: 14) {
            Text("За этот месяц:")
                .font(.custom("Commissioner-Bold", size: 16))
                .foregroundColor(.black)

            HStack(alignment: .top, spacing: 0) {
                summaryColumn(
                    value: stats.takenDays,
                    valueColor: Color(hex: "0773F1"),
                    title: "дней\nприема",
                    iconName: "checkmark",
                    iconColor: Color(hex: "0773F1")
                )
                summaryDivider
                summaryColumn(
                    value: stats.missedDays,
                    valueColor: Color(hex: "F04A4A"),
                    title: "дней\nпропущено",
                    iconName: "exclamationmark",
                    iconColor: Color(hex: "F04A4A")
                )
                summaryDivider
                summaryColumn(
                    value: stats.remainingDays,
                    valueColor: Color(hex: "0773F1"),
                    title: "дней\nосталось",
                    iconName: nil,
                    iconColor: Color(hex: "0773F1")
                )
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color(hex: "0773F1").opacity(0.10), radius: 12, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    LinearGradient(
                        stops: [
                            .init(color: Color(hex: "F1F5FF"), location: 0.0),
                            .init(color: Color(hex: "E5ECFF"), location: 0.6),
                            .init(color: Color(hex: "B4D2FF"), location: 0.9),
                            .init(color: Color(hex: "7FB1FF"), location: 1.0)
                        ],
                        startPoint: .bottomLeading,
                        endPoint: .topTrailing
                    ),
                    lineWidth: 1.5
                )
        )
    }

    private var summaryDivider: some View {
        Rectangle()
            .fill(Color(hex: "E5E8EE"))
            .frame(width: 1, height: 88)
    }

    private func summaryColumn(
        value: Int,
        valueColor: Color,
        title: String,
        iconName: String?,
        iconColor: Color
    ) -> some View {
        VStack(spacing: 6) {
            Text("\(value)")
                .font(.custom("Commissioner-Bold", size: 28))
                .foregroundColor(valueColor)

            Text(title)
                .font(.custom("Commissioner-Regular", size: 13))
                .foregroundColor(.black)
                .multilineTextAlignment(.center)

            ZStack {
                Circle()
                    .stroke(iconColor.opacity(0.5), lineWidth: 1.5)
                    .frame(width: 26, height: 26)
                if let iconName {
                    Image(systemName: iconName)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(iconColor)
                }
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct MonthPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: Date

    @State private var monthIndex: Int
    @State private var yearIndex: Int

    private let months: [String]
    private let years: [Int]

    init(selection: Binding<Date>) {
        self._selection = selection
        let calendar = Calendar(identifier: .gregorian)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        self.months = formatter.standaloneMonthSymbols.map { $0.capitalized }

        let currentYear = calendar.component(.year, from: Date())
        let yearList = Array((currentYear - 5)...(currentYear + 10))
        self.years = yearList

        let components = calendar.dateComponents([.month, .year], from: selection.wrappedValue)
        self._monthIndex = State(initialValue: (components.month ?? 1) - 1)
        self._yearIndex = State(initialValue: yearList.firstIndex(of: components.year ?? currentYear) ?? 0)
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Выберите месяц")
                .font(.custom("Commissioner-SemiBold", size: 18))
                .foregroundColor(Color(hex: "3B3B3B"))
                .padding(.top, 12)

            HStack(spacing: 0) {
                Picker("", selection: $monthIndex) {
                    ForEach(0..<months.count, id: \.self) { idx in
                        Text(months[idx]).tag(idx)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)

                Picker("", selection: $yearIndex) {
                    ForEach(0..<years.count, id: \.self) { idx in
                        Text("\(String(years[idx]))").tag(idx)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 16)

            Button {
                applySelection()
                dismiss()
            } label: {
                Text("Готово")
                    .font(.custom("Commissioner-SemiBold", size: 16))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(hex: "0773F1"))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
    }

    private func applySelection() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ru_RU")
        var components = DateComponents()
        components.year = years[yearIndex]
        components.month = monthIndex + 1
        components.day = 1
        if let date = calendar.date(from: components) {
            selection = date
        }
    }
}
