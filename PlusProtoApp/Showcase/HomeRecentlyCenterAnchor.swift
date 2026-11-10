import Foundation

/// Переносит точку внутри карточки (или gap) между двумя размерами ленты.
/// Поля и gap постоянны.
enum HomeRecentlyCenterAnchor {
    static func width(_ widths: [CGFloat], scale: CGFloat, gap: CGFloat, leading: CGFloat, trailing: CGFloat) -> CGFloat {
        leading + widths.reduce(0, +) * scale + CGFloat(max(0, widths.count - 1)) * gap + trailing
    }

    /// UIScrollView сообщает промежуточную ширину во время доводки размера.
    /// Фиксированные gap и поля вычитаются до восстановления масштаба медиа.
    static func renderedScale(contentWidth: CGFloat, widths: [CGFloat], gap: CGFloat,
                              leading: CGFloat, trailing: CGFloat) -> CGFloat? {
        let mediaWidth = widths.reduce(0, +)
        guard mediaWidth > 0 else { return nil }
        let fixedWidth = leading + trailing + CGFloat(max(0, widths.count - 1)) * gap
        let scale = (contentWidth - fixedWidth) / mediaWidth
        return scale.isFinite && scale > 0 ? scale : nil
    }

    static func offset(_ offset: CGFloat, viewport: CGFloat, widths: [CGFloat],
                       from oldScale: CGFloat, to newScale: CGFloat,
                       gap: CGFloat, leading: CGFloat, trailing: CGFloat) -> CGFloat {
        guard oldScale > 0, newScale > 0, !widths.isEmpty else { return offset }
        // В начале ряда удерживаем левый край; любой реальный сдвиг выбирает центр.
        if offset <= 0.01 { return 0 }
        let oldGap = gap
        let newGap = gap
        let point = offset + viewport / 2
        var oldX = leading
        var newX = leading
        var mapped = point
        for (index, width) in widths.enumerated() {
            let oldEnd = oldX + width * oldScale
            let newEnd = newX + width * newScale
            if point <= oldEnd {
                mapped = newX + (point - oldX) * newScale / oldScale
                break
            }
            if index < widths.count - 1, point <= oldEnd + oldGap {
                mapped = newEnd + (point - oldEnd) * newGap / oldGap
                break
            }
            oldX = oldEnd + oldGap
            newX = newEnd + newGap
            mapped = point + newX - oldX
        }
        let total = width(widths, scale: newScale, gap: newGap, leading: leading, trailing: trailing)
        return min(max(0, mapped - viewport / 2), max(0, total - viewport))
    }
}
