import Foundation

/// Расстановка по видимым границам, независимо от технического шага ScrollView.
/// Префиксы расстояний дают O(1) на слот даже на длинной тестовой ленте.
struct PromoCarouselSpacing {
    struct Card {
        let mainWidth: CGFloat
        let sideWidth: CGFloat
    }

    let cards: [Card]
    let viewportWidth: CGFloat
    private let baselineCards: [Card]
    private let sidePrefix: [CGFloat]
    private let leftCorrection: [CGFloat]
    private let rightCorrection: [CGFloat]

    init(cards: [Card], viewportWidth: CGFloat, baselineCards: [Card]) {
        precondition(cards.count == baselineCards.count)
        self.cards = cards
        self.viewportWidth = viewportWidth
        self.baselineCards = baselineCards
        let growth = max(0, (viewportWidth - 402) / 2).rounded()
        func distance(_ a: CGFloat, _ b: CGFloat, _ baseA: CGFloat, _ baseB: CGFloat) -> CGFloat {
            let gap = min(-16, (180 - (baseA + baseB) / 2).rounded() + growth)
            return (a + b) / 2 + gap
        }
        var prefix: [CGFloat] = [0]
        var left = Array(repeating: CGFloat.zero, count: cards.count)
        var right = left
        for index in cards.indices.dropLast() {
            let a = cards[index], b = cards[index + 1]
            let baseA = baselineCards[index], baseB = baselineCards[index + 1]
            let side = distance(a.sideWidth, b.sideWidth, baseA.sideWidth, baseB.sideWidth)
            prefix.append(prefix.last! + side)
            right[index] = distance(a.mainWidth, b.sideWidth, baseA.mainWidth, baseB.sideWidth) - side
            left[index + 1] = distance(b.mainWidth, a.sideWidth, baseB.mainWidth, baseA.sideWidth) - side
        }
        sidePrefix = prefix
        leftCorrection = left
        rightCorrection = right
    }

    func removing(at index: Int) -> PromoCarouselSpacing {
        var cards = cards
        var baseline = baselineCards
        cards.remove(at: index)
        baseline.remove(at: index)
        return PromoCarouselSpacing(cards: cards, viewportWidth: viewportWidth, baselineCards: baseline)
    }

    /// Семь слотов нужны уже при появлении края третьего соседа.
    /// Минимум по всему набору исключает переключение пяти/семи при свайпе.
    var sevenCardMinimumWidth: CGFloat {
        var threshold = CGFloat.infinity
        for anchor in cards.indices {
            for item in [anchor - 3, anchor + 3] where cards.indices.contains(item) {
                let distance = abs(snappedCenter(of: item, anchor: anchor) - viewportWidth / 2)
                threshold = min(threshold, 2 * max(0, distance - cards[item].sideWidth / 2))
            }
        }
        return threshold
    }

    static func projectedWidth(width: CGFloat, height: CGFloat, degrees: Double) -> CGFloat {
        let angle = degrees * .pi / 180
        return abs(cos(angle)) * width + abs(sin(angle)) * height
    }

    func center(of item: CGFloat, scrollPosition: CGFloat) -> CGFloat {
        guard !cards.isEmpty else { return viewportWidth / 2 }
        let position = min(max(scrollPosition, 0), CGFloat(cards.count - 1))
        let lower = Int(position.rounded(.down))
        let upper = min(lower + 1, cards.count - 1)
        let fraction = position - CGFloat(lower)
        let t = fraction * fraction * (3 - 2 * fraction)
        return center(of: item, anchoredAt: lower) * (1 - t)
            + center(of: item, anchoredAt: upper) * t
    }

    private func center(of item: CGFloat, anchoredAt anchor: Int) -> CGFloat {
        let value = min(max(item, 0), CGFloat(cards.count - 1))
        let lower = Int(value.rounded(.down))
        let upper = min(lower + 1, cards.count - 1)
        let t = value - CGFloat(lower)
        return snappedCenter(of: lower, anchor: anchor) * (1 - t)
            + snappedCenter(of: upper, anchor: anchor) * t
    }

    private func snappedCenter(of item: Int, anchor: Int) -> CGFloat {
        let origin = viewportWidth / 2
        guard item != anchor else { return origin }
        let distance = abs(sidePrefix[item] - sidePrefix[anchor])
            + (item > anchor ? rightCorrection[anchor] : leftCorrection[anchor])
        return origin + (item > anchor ? distance : -distance)
    }
}
