import SwiftUI

struct StepProgressView: View {
    let filledSegments: Int
    private let segmentWidth: CGFloat = 109
    private let spacing: CGFloat = 12

    var body: some View {
        let totalWidth = segmentWidth * 3 + spacing * 2

        return ZStack(alignment: .leading) {
            HStack(spacing: spacing) {
                ForEach(0..<3) { _ in
                    RoundedRectangle(cornerRadius: 50)
                        .fill(Color(hex: "D6D6D6"))
                        .frame(width: segmentWidth, height: 5)
                }
            }

            if filledSegments > 0 {
                let filledCount = min(max(filledSegments, 0), 3)
                let filledWidth = segmentWidth * CGFloat(filledCount) + spacing * CGFloat(max(filledCount - 1, 0))

                LinearGradient(
                    colors: [
                        Color(hex: "0773F1"),
                        Color(hex: "38A9FF"),
                        Color(hex: "6CDCC0"),
                        Color(hex: "A2EBAE")
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: filledWidth, height: 5)
                .mask(
                    HStack(spacing: spacing) {
                        ForEach(0..<filledCount) { _ in
                            RoundedRectangle(cornerRadius: 50)
                                .frame(width: segmentWidth, height: 5)
                        }
                    }
                )
            }
        }
        .frame(width: totalWidth)
    }
}
