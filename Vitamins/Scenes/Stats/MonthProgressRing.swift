import SwiftUI

struct MonthProgressRing: View {
    let takenDays: Int
    let missedDays: Int
    let remainingDays: Int
    let completionPercent: Double
    let status: String

    private let ringWidth: CGFloat = 22
    private let percentColor = Color(hex: "0773F1")

    var body: some View {
        ZStack {
            ringContent
                .rotationEffect(.degrees(-90))

            VStack(spacing: 2) {
                Text("\(Int(completionPercent.rounded()))%")
                    .font(.custom("Commissioner-Bold", size: 44))
                    .foregroundColor(percentColor.opacity(isFaded ? 0.45 : 1))
                Text("выполнено")
                    .font(.custom("Commissioner-Regular", size: 13))
                    .foregroundColor(Color(hex: "8C8C8C"))
            }
        }
        .frame(width: 200, height: 200)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var ringContent: some View {
        switch theme {
        case .notStarted:
            Circle()
                .stroke(Color(hex: "ECEEF3"),
                        style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))

        case .completed:
            Circle()
                .stroke(blueGradient,
                        style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))

        case .allMissed:
            Circle()
                .stroke(redGradient,
                        style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))

        case .inProgress:
            inProgressSegments
        }
    }

    private var inProgressSegments: some View {
        let total = max(takenDays + missedDays + remainingDays, 0)
        let takenFraction = total == 0 ? 0 : Double(takenDays) / Double(total)
        let missedFraction = total == 0 ? 0 : Double(missedDays) / Double(total)
        let overlap = 0.012

        return ZStack {
            // 1. База — полный голубой круг (remaining). Видимая часть голубого — от taken+missed до 1.
            Circle()
                .stroke(lightBlueGradient,
                        style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))

            // 2. Красный сегмент. Сдвиг через rotation так, чтобы overlap заходил поверх правого конца синего.
            if missedFraction > 0 {
                Circle()
                    .trim(from: 0, to: missedFraction + overlap)
                    .stroke(redGradient,
                            style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))
                    .rotationEffect(.degrees(360 * max(0, takenFraction - overlap)))
            }

            // 3. Синий поверх красного. Закрывает правый конец красного (закрытый конец красного).
            if takenFraction > 0 {
                Circle()
                    .trim(from: 0, to: takenFraction)
                    .stroke(blueGradient,
                            style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))
            }

            // 4. Маленький голубой cap поверх верхнего конца синего — закрывает синий со стороны 12 часов.
            if takenFraction > 0 {
                Circle()
                    .trim(from: 0, to: overlap)
                    .stroke(lightBlueGradient,
                            style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))
            }
        }
    }

    private var blueGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "5BA0FF"), Color(hex: "0F6FE5")],
            startPoint: .top,
            endPoint: .bottomLeading
        )
    }

    private var redGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "FFB1B1"), Color(hex: "F04A4A")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var lightBlueGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "D9E6FF"), Color(hex: "C2D7FF")],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var theme: RingTheme {
        switch status {
        case "not_started":
            return .notStarted
        case "completed":
            return .completed
        case "all_missed":
            return .allMissed
        default:
            return .inProgress
        }
    }

    private var isFaded: Bool {
        theme == .notStarted
    }

    private enum RingTheme {
        case notStarted, completed, allMissed, inProgress
    }
}
