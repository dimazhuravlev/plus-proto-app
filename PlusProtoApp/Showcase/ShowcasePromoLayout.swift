import SwiftUI

/// Числа промо-слайдера «Главной» — макет `2532:26618`. Холст макета 440, раскладка
/// перенесена на 402 от центра экрана: размеры карточек и отступы от центра — как есть.
///
/// Числа ниже — макет на 402 (`scale` = 1). Слайдер — центрированная карусель с постоянными
/// краями соседей: на любой ширине из-за края экрана выглядывает ровно столько же сосед,
/// сколько на 402, а растёт вся геометрия карточек (шаг, размеры, высоты, отступы, подпись
/// альбома) на `scale`. Кнопки ✕/✓ 40, шрифты и интерлиньяж подписи — не масштабируются,
/// их позиции — да.
enum ShowcasePromoLayout {
    /// Видимый край соседней карточки на 402: от кромки экрана до внутреннего края соседа
    /// (центр экрана 201 − расстояние до его кромки: шаг 180 − полкарточки соседа 80.8 = 99.2,
    /// итого 101.8). Инвариант на любой ширине.
    static let neighbourEdge: CGFloat = 101.8

    /// Множитель промо: `(screenWidth/2 − край) / (402/2 − край)` — видимый край соседа
    /// не меняется с шириной. 390 → ≈0.940, 402 → 1, 440 → ≈1.192.
    @MainActor
    static var scale: CGFloat {
        (PlusMetrics.screenWidth / 2 - neighbourEdge) / (PlusMetrics.designWidth / 2 - neighbourEdge)
    }

    /// Шаг между центрами карточек: соседи выглядывают из-за краёв экрана
    /// (в макете ±188; на 8 плотнее — правка пользователя 2026-10-13).
    @MainActor
    static var step: CGFloat { 180 * scale }
    /// Соседи меньше центральной: книга сбоку 161.56 против постера в центре 210.16.
    static let sideScale: CGFloat = 0.769
    /// Центр центральной карточки — от верха блока (низа навигации). В макете 185;
    /// на 10 выше — «отступ до навбара немного меньше» (правка пользователя 2026-10-08).
    @MainActor
    static var cardCenterY: CGFloat {
        guard HomePresentationSettings.shared.sizesEnabled else { return 175 * scale }
        let tallest = max(poster.height, book.geometry.frameSize(coverWidth: book.coverWidth).height, albumHeight, artist, PromoStationLayout.frame.height * stationScale)
        return max(175 * scale, tallest / 2 + 17.4 * scale)
    }
    @MainActor
    static var carouselHeight: CGFloat { cardCenterY * 2 }

    /// Величина наклона у каждой карточки своя, случайная: по центру 2…4°, сбоку 4.5…6.5°.
    /// Знак — от места в ряду, а не от карточки: по центру минус, у соседей плюс, через одну
    /// снова минус, как в макете (−3° у центральной, +5.03° и +5.94° у соседей). Ряд
    /// всегда «+ − + −» (правка пользователя 2026-10-09: со случайным знаком соседи
    /// клонились в одну сторону).
    static let centerTilt: ClosedRange<Double> = 2...4
    static let sideTilt: ClosedRange<Double> = 4.5...6.5
    /// Соседи ниже центральной — на 6…16, у каждой карточки своё (в макете 16 и 6).
    static let sideDrop: ClosedRange<Double> = 6...16   // на 402, умножается на `scale`

    /// Карточки по центру — по виду. Сбоку они те же, уменьшенные на `sideScale`:
    /// альбом сбоку 169, скругление 18 — в центре 219.8 и 23.4.
    @MainActor
    static var poster: CGSize {
        let width = CGFloat(HomePresentationSettings.shared.width(for: .movie)) * scale
        return CGSize(width: width, height: width * 315.235 / 210.155)
    }
    @MainActor
    static var posterRadius: CGFloat { 16.358 * scale }
    @MainActor
    static var album: CGFloat { CGFloat(HomePresentationSettings.shared.width(for: .album)) * scale }
    @MainActor
    static var albumHeight: CGFloat { album }
    @MainActor
    static var artist: CGFloat { CGFloat(HomePresentationSettings.shared.width(for: .artist)) * scale }
    @MainActor
    static var stationScale: CGFloat { scale * HomePresentationSettings.shared.multiplier(for: .station) }
    /// Скругление альбома — как у постера, а не макетные 23.4: «немного уменьшить»
    /// (правка пользователя 2026-10-09), и углы карточек в ряду одинаковые.
    @MainActor
    static var albumRadius: CGFloat { posterRadius }
    @MainActor
    static var bookWidth: CGFloat { CGFloat(HomePresentationSettings.shared.width(for: .book)) * scale }
    /// Книга ряда — карточка книги (`card / book`) шириной слота. Скругление правых углов —
    /// как у постера и альбома ряда (правка пользователя 2026-10-09).
    @MainActor
    static var book: (geometry: BookFigureGeometry, coverWidth: CGFloat) {
        var figure = BookFigureGeometry.fitting(width: bookWidth, aspect: nil)
        figure.geometry.radiusTrim = figure.geometry.coverRadius - posterRadius
        return figure
    }

    /// Пара ✕/✓ у фильма и книги — у нижней кромки карточки: левый край на 24.6 от её
    /// левой кромки, низ пары — на 27.6 ниже низа карточки (заходит на неё на 12).
    @MainActor
    static var pairLeading: CGFloat { 24.6 * scale }
    @MainActor
    static var pairBelow: CGFloat { 27.6 * scale }
    /// У альбома — у верхней кромки справа (макет `2537:27595`): правый край на 14.5
    /// от правой кромки обложки, верх — на 22.5 выше её верха. Замер — в системе
    /// координат повёрнутой обложки.
    @MainActor
    static var albumPairTrailing: CGFloat { 14.5 * scale }
    @MainActor
    static var albumPairAbove: CGFloat { 22.5 * scale }

    /// Кнопка «Продолжить» у начатого фильма и книги (задача 69, макет `2698:28639`) —
    /// вместо пары: левый край на 15.2 от левой кромки постера (у книги — обложки),
    /// середина высоты — на нижней кромке. Сама капсула не масштабируется, её место — да.
    @MainActor
    static var continueLeading: CGFloat { 15.2 * scale }
    /// `PlusButton` secondary M
    static var continueHeight: CGFloat { PlusButtonSize.m.height }

    /// У исполнителя пара — по касательной к кругу (правка пользователя 2026-10-13): центры
    /// обеих кнопок на окружности, середина пары — на φ по часовой от 12 часов, пара
    /// вместе с иконками повёрнута на φ.
    static let artistPairAngle: Angle = .degrees(26)
    /// Сдвиг середины пары от центра круга: `(d·sin φ, −d·cos φ)`, ось y вниз. `d` — до
    /// середины хорды между центрами кнопок, `sqrt(r² − 23²)`: 23 — половина расстояния
    /// между ними (40 + 6), и оба центра ровно на окружности. Кнопки не масштабируются.
    @MainActor
    static var artistPairOffset: CGSize {
        let radius = artist / 2
        let halfSpan = (PlusMetrics.circleButton + PlusMetrics.circleButtonGap) / 2
        let distance = (radius * radius - halfSpan * halfSpan).squareRoot()
        let angle = artistPairAngle.radians
        return CGSize(width: distance * CGFloat(sin(angle)), height: -distance * CGFloat(cos(angle)))
    }

    /// Подпись альбома (макет `2537:27595`) — аватар исполнителя 40, справа название
    /// альбома и исполнитель Text M. Наклонена вместе с обложкой: левый край на 3.3
    /// правее её левой кромки, верх — на 7.2 ниже низа (замер в системе обложки).
    /// Ширина 227 с полем справа 8; строки заходят друг на друга на 2.
    @MainActor
    static var albumCaptionLeading: CGFloat { 3.3 * scale }
    @MainActor
    static var albumCaptionGap: CGFloat { 7.2 * scale }
    @MainActor
    static var albumCaptionWidth: CGFloat { 227 * scale }
    @MainActor
    static var albumCaptionTrailing: CGFloat { 8 * scale }
    @MainActor
    static var albumCaptionSpacing: CGFloat { 8 * scale }
    /// Строки подписи заходят друг на друга на 2 — это интерлиньяж шрифта, не геометрия.
    static let albumCaptionLineOverlap: CGFloat = 2
    @MainActor
    static var albumAvatar: CGFloat { 40 * scale }

    /// Подпись исполнителя (задача 64) — одна строка Text M по центру колонки
    /// шириной с квадрат альбома, на месте верхней строки подписи альбома: полоса подписи
    /// начинается на `albumCaptionGap` под квадратом, а две строки альбома стоят в ней
    /// по центру высоты аватара. Отсчёт — от низа квадрата до верха строки.
    @MainActor
    static var centeredCaptionTop: CGFloat {
        let albumLines = 2 * PlusTextSize.textM.lineHeight - albumCaptionLineOverlap
        return albumCaptionGap + (albumAvatar - albumLines) / 2
    }

    /// Пустое место под самой высокой карточкой, постером. Было 39.4 + 64 под описание;
    /// описание убрано, пустое место ужато на 56 — правка пользователя 2026-10-10.
    @MainActor
    static var belowCards: CGFloat { max(47.4 * scale, 80) }

    /// Высота блока — до низа постера плюс `belowCards`: место держится всегда, и лента
    /// ниже не прыгает от айтема к айтему.
    @MainActor
    static var height: CGFloat {
        guard HomePresentationSettings.shared.sizesEnabled else { return cardCenterY + poster.height / 2 + belowCards }
        let bookHeight = book.geometry.frameSize(coverWidth: book.coverWidth).height
        let tallest = max(poster.height, bookHeight, albumHeight + 2 * albumAvatar, artist + 2 * centeredCaptionTop, PromoStationLayout.frame.height * stationScale)
        return cardCenterY + tallest / 2 + belowCards
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
