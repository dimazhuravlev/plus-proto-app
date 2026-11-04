import Foundation

@main enum PromoCarouselSpacingChecks {
    static func main() {
        let base: [PromoCarouselSpacing.Card] = (0..<45).map { (index: Int) in
            let main: CGFloat = 219 + CGFloat(index % 5) * 8
            let side: CGFloat = 176 + CGFloat(index % 3) * 4
            return PromoCarouselSpacing.Card(mainWidth: main, sideWidth: side)
        }
        let cards = base.map { PromoCarouselSpacing.Card(mainWidth: $0.mainWidth * 1.2, sideWidth: $0.sideWidth * 1.2) }
        // Независимый эталон: исходная сумма рёбер. Проверяет оба направления,
        // неодинаковые ширины и все положения в длинной ленте.
        func originalCenter(_ item: Int, anchor: Int, width: CGFloat) -> CGFloat {
            guard item != anchor else { return width / 2 }
            let direction = item > anchor ? 1 : -1
            var distance: CGFloat = 0
            var previous = anchor
            for next in stride(from: anchor + direction, through: item, by: direction) {
                let a = previous == anchor ? cards[previous].mainWidth : cards[previous].sideWidth
                let baseA = previous == anchor ? base[previous].mainWidth : base[previous].sideWidth
                let baseGap: CGFloat = (180 - (baseA + base[next].sideWidth) / 2).rounded()
                let growth: CGFloat = max(0, (width - 402) / 2).rounded()
                let gap: CGFloat = min(-16, baseGap + growth)
                distance += (a + cards[next].sideWidth) / 2 + gap
                previous = next
            }
            return width / 2 + CGFloat(direction) * distance
        }
        for width: CGFloat in [403, 414, 440, 600, 834, 1024, 1366] {
            let g = PromoCarouselSpacing(cards: cards, viewportWidth: width, baselineCards: base)
            for anchor in cards.indices {
                for item in cards.indices {
                    precondition(abs(g.center(of: CGFloat(item), scrollPosition: CGFloat(anchor))
                                     - originalCenter(item, anchor: anchor, width: width)) < 0.00001)
                }
            }
            for anchor in 1..<(cards.count - 1) {
                let before = g.center(of: 22.4, scrollPosition: CGFloat(anchor) - 0.00001)
                let after = g.center(of: 22.4, scrollPosition: CGFloat(anchor) + 0.00001)
                precondition(abs(before - after) < 0.001, "Discontinuous swipe")
            }
        }
        var previousGap: CGFloat = -.infinity
        for width: CGFloat in stride(from: 403, through: 1000, by: 1) {
            let g = PromoCarouselSpacing(cards: cards, viewportWidth: width, baselineCards: base)
            let gap = g.center(of: 1, scrollPosition: 0) - width / 2 - (cards[0].mainWidth + cards[1].sideWidth) / 2
            precondition(gap >= previousGap - 0.00001 && gap <= -16 + 0.00001)
            if width >= 600 { precondition(abs(gap + 16) < 0.00001) }
            previousGap = gap
        }
        let mixed = PromoCarouselSpacing(cards: cards, viewportWidth: 834, baselineCards: base)
        for removed in 1..<(cards.count - 1) {
            let compacted = mixed.removing(at: removed)
            // Next card becomes the exact center; its own main width controls both gaps.
            precondition(compacted.center(of: CGFloat(removed), scrollPosition: CGFloat(removed)) == 417)
            let left = compacted.center(of: CGFloat(removed - 1), scrollPosition: CGFloat(removed))
            let expectedDistance = (cards[removed + 1].mainWidth + cards[removed - 1].sideWidth) / 2 - 16
            precondition(abs(417 - left - expectedDistance) < 0.00001)
        }
        let uniform = Array(repeating: PromoCarouselSpacing.Card(mainWidth: 280, sideWidth: 180), count: 9)
        let g = PromoCarouselSpacing(cards: uniform, viewportWidth: 920, baselineCards: uniform)
        let third = g.center(of: 7, scrollPosition: 4)
        precondition(third - 90 < 920 && third + 90 > 920, "Third neighbour should be partially visible")
        precondition(g.sevenCardMinimumWidth < 920, "Seven slots must be enabled before full cards fit")
        let empty = PromoCarouselSpacing(cards: [], viewportWidth: 402, baselineCards: [])
        precondition(empty.center(of: 0, scrollPosition: 0) == 201)
        precondition(empty.sevenCardMinimumWidth.isInfinite)
        precondition(PromoCarouselSpacing.projectedWidth(width: 200, height: 300, degrees: 9) > 200)
        print("PASS: prefix spacing matches original formula; continuous swipes; overlap stops at −16; seven slots start at partial visibility")
    }
}
