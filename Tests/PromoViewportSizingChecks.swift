import Foundation

@main
enum PromoViewportSizingChecks {
    static func main() {
        precondition(PromoViewportSizing.scale(viewportWidth: 402) == 1)
        for width: CGFloat in stride(from: 375, through: 440, by: 1) {
            let oldScale = (width / 2 - 101.8) / 99.2
            let newScale = PromoViewportSizing.scale(viewportWidth: width)
            for base: CGFloat in [220, 248, 256] {
                precondition(abs(base * (newScale - oldScale)) < 0.5,
                             "Phone card changed by more than half a point")
            }
            precondition(abs(180 * (newScale - oldScale)) < 0.5)
        }
        for width: CGFloat in [320, 375, 402, 440, 768, 834, 1024, 1366] {
            let scale = PromoViewportSizing.scale(viewportWidth: width)
            precondition((0.6...1.2).contains(scale))
            precondition(256 * scale <= 307.2 + 0.001)
        }
        precondition(PromoViewportSizing.scale(viewportWidth: 768) == 1.2)
        precondition(PromoViewportSizing.scale(viewportWidth: 1366) == 1.2)
        print("PASS: phone dimensions within0.5pt; scale60…120%; tablet media capped307.2pt")
    }
}
