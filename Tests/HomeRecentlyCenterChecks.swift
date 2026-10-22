import Foundation

@main enum HomeRecentlyCenterChecks {
    static let widths: [CGFloat] = [70, 138, 78, 54, 80, 78, 80, 54, 80, 138, 78, 80]
    static func offset(_ x: CGFloat, _ old: CGFloat, _ new: CGFloat, viewport: CGFloat = 402) -> CGFloat {
        HomeRecentlyCenterAnchor.offset(x, viewport: viewport, widths: widths, from: old, to: new,
                                       gap: 8, leading: 8, trailing: 16)
    }
    static func expect(_ a: CGFloat, _ b: CGFloat) { precondition(abs(a - b) < 0.00001, "\(a) != \(b)") }

    static func main() {
        for viewport: CGFloat in [375, 402, 440] {
            // Точка внутри каждого типа карточки и внутри фиксированного gap.
            for index in 3..<8 {
                let preceding = widths.prefix(index).reduce(0, +)
                for fraction: CGFloat in [0, 0.23, 0.5, 1] {
                    let oldPoint = 8 + preceding * 0.8 + CGFloat(index) * 8 + widths[index] * 0.8 * fraction
                    let newPoint = 8 + preceding * 1.2 + CGFloat(index) * 8 + widths[index] * 1.2 * fraction
                    expect(offset(oldPoint - viewport / 2, 0.8, 1.2, viewport: viewport), newPoint - viewport / 2)
                }
                let oldGap = 8 + (preceding + widths[index]) * 0.8 + CGFloat(index) * 8 + 4
                let newGap = 8 + (preceding + widths[index]) * 1.2 + CGFloat(index) * 8 + 4
                expect(offset(oldGap - viewport / 2, 0.8, 1.2, viewport: viewport), newGap - viewport / 2)
            }
        }
        // Нет накопления дрейфа при сотне покадровых раскрытий/сворачиваний.
        var x: CGFloat = 430
        for _ in 0..<100 {
            for step in 1...64 { x = offset(x, 0.8 + CGFloat(step - 1) / 160, 0.8 + CGFloat(step) / 160) }
            for step in (1...64).reversed() { x = offset(x, 0.8 + CGFloat(step) / 160, 0.8 + CGFloat(step - 1) / 160) }
        }
        expect(x, 430)
        expect(offset(0, 1.2, 0.8), 0) // У границы не появляется пустое поле.
        let total = HomeRecentlyCenterAnchor.width(widths, scale: 0.8, gap: 8, leading: 8, trailing: 16)
        expect(offset(10000, 1.2, 0.8), total - 402)
        print("PASS: visible center, mixed widths, fixed gaps, viewport sizes, no cumulative drift, edge clamping")
    }
}
