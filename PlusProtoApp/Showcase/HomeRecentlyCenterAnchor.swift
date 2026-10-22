import Foundation

/// Переносит точку внутри карточки (или gap) между двумя размерами ленты.
/// Gap и внешние поля не масштабируются вместе с изображениями.
enum HomeRecentlyCenterAnchor {
    static func width(_ widths: [CGFloat], scale: CGFloat, gap: CGFloat, leading: CGFloat, trailing: CGFloat) -> CGFloat {
        leading + widths.reduce(0, +) * scale + CGFloat(max(0, widths.count - 1)) * gap + trailing
    }

    static func offset(_ offset: CGFloat, viewport: CGFloat, widths: [CGFloat],
                       from oldScale: CGFloat, to newScale: CGFloat,
                       gap: CGFloat, leading: CGFloat, trailing: CGFloat) -> CGFloat {
        guard oldScale > 0, newScale > 0, !widths.isEmpty else { return offset }
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
            if index < widths.count - 1, point <= oldEnd + gap {
                mapped = newEnd + (point - oldEnd)
                break
            }
            oldX = oldEnd + gap
            newX = newEnd + gap
            mapped = point + newX - oldX
        }
        let total = width(widths, scale: newScale, gap: gap, leading: leading, trailing: trailing)
        return min(max(0, mapped - viewport / 2), max(0, total - viewport))
    }
}
