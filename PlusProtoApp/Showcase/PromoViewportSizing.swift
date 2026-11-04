import Foundation

/// База402pt сохраняет телефонный макет. Ограничение защищает широкое окно iPad
/// от увеличения карточки до размеров экрана; дальние соседи скрываются независимо от ширины окна.
enum PromoViewportSizing {
    static let maximumMediaViewportWidth: CGFloat = 528
    static let maximumPosterWidth: CGFloat = 288
    static let maximumOtherWidth: CGFloat = 326
    static let referenceWidth: CGFloat = 402
    static let growthSpan: CGFloat = 200
    static let scaleRange: ClosedRange<CGFloat> = 0.6...1.2

    /// Открытый диапазон из трёх слотов: одновременно ненулевую opacity
    /// имеют максимум три карточки. Уход гаснет во второй половине пути 1…1.5.
    static func visibility(at position: CGFloat, count: Int = 3) -> Double {
        let fadeStart = CGFloat(count / 2) + 0.25
        let t = min(max((abs(position) - fadeStart) / 0.25, 0), 1)
        return Double(1 - t * t * (3 - 2 * t))
    }

    static func scale(viewportWidth: CGFloat) -> CGFloat {
        min(max(1 + (viewportWidth - referenceWidth) / growthSpan,
                scaleRange.lowerBound), scaleRange.upperBound)
    }
}
