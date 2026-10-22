import SwiftUI

/// Прогресс под вертикальной карточкой фильма и книги — `timeline` `2932:36252`: полоса
/// 40 × 3 по центру под обложкой, зазор 4; подложка Fill/Eight, заливка — акцент Плюса,
/// капсулы. Один компонент на постеры и книги (правка пользователя 2026-10-22: вместо
/// бейджа с процентами на обложке книги).
struct CardProgressBar: View {
    let progress: Double

    static let width: CGFloat = 40
    static let height: CGFloat = 3
    static let gap: CGFloat = 4
    /// Сколько полоса добавляет к высоте карточки
    static var footprint: CGFloat { gap + height }

    var body: some View {
        Capsule()
            .fill(Color.fillEight)
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(Color.plusSolidOne)
                    .frame(width: Self.width * min(max(progress, 0), 1))
            }
            .frame(width: Self.width, height: Self.height)
            .accessibilityLabel("Прогресс \(Int((min(max(progress, 0), 1) * 100).rounded()))%")
    }
}
