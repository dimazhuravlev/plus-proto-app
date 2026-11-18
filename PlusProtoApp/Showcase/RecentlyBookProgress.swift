import SwiftUI

/// Figma 655:45519: процент чтения, 18 pt, поля 4, скругление 6.
struct RecentlyBookProgress: View {
    let progress: Double
    var body: some View {
        Text("\(Int((min(1, max(0, progress)) * 100).rounded()))%")
            .plusText(.textXS, .semibold)
            .foregroundStyle(Color.fillInverted)
            .padding(.horizontal, 4)
            .frame(height: 18)
            .background(Color.fillOne, in: RoundedRectangle(cornerRadius: 6))
            .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
            .opacity(HomeQuickAccessLayout.labelProgress)
            .accessibilityHidden(HomeQuickAccessLayout.labelProgress == 0)
            .accessibilityLabel("Прочитано \(Int((min(1, max(0, progress)) * 100).rounded())) процентов")
    }
}
