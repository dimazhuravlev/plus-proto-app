import SwiftUI

/// Геометрия промокарусели на базе402pt; медиаконтент растёт в пределах60…120%.
/// Тексты и контролы сохраняют исходные размеры, дополнительная ширина открывает соседей.
enum ShowcasePromoLayout {
    /// Адаптер настроек к одному чистому расчёту; остальные свойства только читают результат.
    @MainActor
    static var geometry: PromoCarouselGeometry { geometry(viewportWidth: PlusMetrics.screenWidth) }

    @MainActor
    static func geometry(viewportWidth: CGFloat) -> PromoCarouselGeometry {
        let settings = HomePresentationSettings.shared
        return PromoCarouselGeometry(
            viewportWidth: viewportWidth,
            movieWidth: CGFloat(settings.width(for: .movie)),
            bookWidth: CGFloat(settings.width(for: .book)),
            albumWidth: CGFloat(settings.width(for: .album)),
            artistWidth: CGFloat(settings.width(for: .artist)),
            stationWidth: CGFloat(settings.width(for: .station))
        )
    }
    @MainActor static var scale: CGFloat { geometry.scale }
    @MainActor static var step: CGFloat { geometry.step }

    @MainActor static var cardCenterY: CGFloat { geometry.centerY }
    @MainActor static var carouselHeight: CGFloat { geometry.centerY * 2 }
    @MainActor static var height: CGFloat { geometry.height }
    @MainActor static var poster: CGSize { geometry.movie.main }
    @MainActor static var posterRadius: CGFloat { geometry.cornerRadius }
    @MainActor static var album: CGFloat { geometry.album.main.width }
    @MainActor static var albumHeight: CGFloat { geometry.album.main.height }
    @MainActor static var artist: CGFloat { geometry.artist.main.width }
    @MainActor static var albumRadius: CGFloat { geometry.cornerRadius }
    @MainActor static var stationSize: CGSize { geometry.station.main }
    @MainActor static var stationCaptionWidth: CGFloat { geometry.stationCaptionWidth }
    @MainActor static var stationCaptionOrigin: CGPoint { geometry.stationCaptionOrigin }
    @MainActor static var stationScale: CGFloat { geometry.station.main.width / PromoStationLayout.frame.width }
    @MainActor static var bookWidth: CGFloat { geometry.book.main.width }
    @MainActor static var book: (geometry: BookFigureGeometry, coverWidth: CGFloat) {
        let size = geometry.book.main
        return (BookFigureGeometry(coverHeight: size.height), size.width)
    }

    /// Величина наклона у каждой карточки своя, случайная: по центру 2…4°, сбоку 4.5…6.5°.
    /// Знак — от места в ряду, а не от карточки: по центру минус, у соседей плюс, через одну
    /// снова минус, как в макете (−3° у центральной, +5.03° и +5.94° у соседей). Ряд
    /// всегда «+ − + −» (правка пользователя 2026-10-09: со случайным знаком соседи
    /// клонились в одну сторону).
    static let centerTilt: ClosedRange<Double> = 2...4
    static let sideTilt: ClosedRange<Double> = 4.5...6.5

    @MainActor
    static var pairLeading: CGFloat { geometry.scaled(25) }
    @MainActor
    static var pairBelow: CGFloat { geometry.scaled(28) }
    @MainActor
    static var albumPairTrailing: CGFloat { geometry.scaled(14) }
    @MainActor
    static var albumPairAbove: CGFloat { geometry.scaled(23) }

    static let artistPairAngle: Angle = .degrees(26)
    @MainActor
    static var artistPairOffset: CGSize {
        let radius = artist / 2
        let halfSpan = (PlusMetrics.circleButton + PlusMetrics.circleButtonGap) / 2
        let distance = (radius * radius - halfSpan * halfSpan).squareRoot()
        let angle = artistPairAngle.radians
        return CGSize(width: (distance * CGFloat(sin(angle))).rounded(), height: (-distance * CGFloat(cos(angle))).rounded())
    }

    @MainActor
    static var albumCaptionLeading: CGFloat { geometry.scaled(3) }
    @MainActor
    static var albumCaptionGap: CGFloat { geometry.captionGap }
    @MainActor
    static var albumCaptionWidth: CGFloat { geometry.scaled(227) }
    @MainActor
    static var albumCaptionTrailing: CGFloat { geometry.scaled(8) }
    @MainActor
    static var albumCaptionSpacing: CGFloat { geometry.scaled(8) }
    static let albumCaptionLineOverlap: CGFloat = 2
    @MainActor
    static var albumAvatar: CGFloat { geometry.avatar }

    @MainActor
    static var centeredCaptionTop: CGFloat {
        geometry.artistCaptionGap
    }


    /// Где слот относительно центра видимой ленты: 0 — по центру, ±1 — на месте соседа.
    /// Считается от рамки скролла, а не экрана: ширина устройства не важна. Шаг приходит
    /// параметром — вызывается из `visualEffect`, где `step` (ширина-зависимый) недоступен.
    static func position(of proxy: GeometryProxy, step: CGFloat) -> CGFloat {
        guard let viewport = proxy.bounds(of: .scrollView) else { return 0 }
        return (proxy.size.width / 2 - viewport.midX) / step
    }

    /// Smoothstep от доли сдвига: у линейной рампы излом в центре и на месте соседа —
    /// карточка начинала расти и наклоняться щелчком, а не плавно (правило проекта для
    /// скролл-эффектов).
    static func ease(_ u: CGFloat) -> CGFloat {
        let x = min(max(u, 0), 1)
        return x * x * (3 - 2 * x)
    }
}

extension PromoCarouselGeometry {
    func card(for kind: HomePromoKind) -> Card {
        switch kind {
        case .movie: movie
        case .book: book
        case .album: album
        case .artist: artist
        case .station: station
        }
    }
}

enum ShowcasePromoMotion {
    /// Пара ✕/✓ (и подпись альбома) проявляются вместе (правка пользователя 2026-10-08) и не
    /// сразу, а когда карточка встала в центр: пауза, затем короткий сильный ease-out.
    /// Без паузы — сразу как лента встала (правка пользователя 2026-10-13; было 50, до этого
    /// 100 и 250): задержку и так даёт доводка ленты до места.
    static let revealDelay: Duration = .zero
    static let revealIn: Animation = .timingCurve(0.23, 1, 0.32, 1, duration: 0.3)
    /// Свайп начался — уходят быстро: они отвечают только за центральную карточку.
    static let revealOut: Animation = .easeOut(duration: 0.15)
    static let pairHiddenScale: CGFloat = 0.9
    /// Тап по соседу — он доезжает в центр
    static let step: Animation = .smooth(duration: 0.4)
    /// ✕: карточка гаснет, как при смене айтема в ленте (`ShowcaseFeedbackMotion.swapOut`,
    /// 400 мс), затем ряд схлопывается — правая карточка едет в центр, зазор закрывается
    /// тем же движением (задача пользователя 2026-10-08). Движение по экрану — ease-in-out.
    static let collapse: Animation = .timingCurve(0.4, 0, 0.2, 1, duration: 0.45)
    /// Сдвиг начинается на хвосте угасания, когда карточки почти не видно (ease-in-out
    /// к 300 мс из 400 прошёл ~93 %): после полного угасания стояла мёртвая пауза
    /// с пустым центром (кадр 2026-10-08).
    static let collapseDelay: Duration = .milliseconds(300)
    /// Перестановка набора перед ✕-схлопыванием должна лечь в свой проход, и только потом
    /// стартует `collapse`: в одном проходе подмена вью получала неявный переход.
    static let editSettle: Duration = .milliseconds(40)
}
