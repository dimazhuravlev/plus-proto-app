import SwiftUI

/// Объём карточек промо «Главной» под свайп (референс пользователя — ramp.design,
/// 2026-11-04): ряд стоит на вогнутой дуге — у соседей внешний край ближе к глазу, —
/// соседи чуть откинуты назад, а слои над обложкой (пара ✕/✓, подписи, бадж, иллюстрация
/// лепестка) на свайпе уходят к центру ряда сильнее самой карточки, как будто висят
/// над ней. Всё — чистая функция места в ряду (`visualEffect`): центральная в покое
/// плоская, по тапу ничего не вращается. Силы ненавязчивые: объём чувствуется,
/// но внимания не тянет. С «уменьшением движения» объёма нет — как параллакс системы.
enum PromoDepthMotion {
    /// Поворот вокруг вертикали на месте соседа, градусы. Силы — на четверть больше
    /// первого варианта (16°, 3°, 0.5, слои 5–12): «чуть более заметно» (правка
    /// пользователя 2026-11-04).
    static let yaw: Double = 20
    /// Наклон назад на месте соседа, градусы
    static let pitch: Double = 4
    /// Перспектива `rotation3DEffect`: 1 — точка схода на размере карточки, ближний край
    /// соседа заметно раздувается; слабее — объём без «рыбьего глаза».
    static let perspective: CGFloat = 0.6

    /// Насколько слой над обложкой уходит к центру на месте соседа, pt на 402.
    /// Чем выше слой, тем больше: иллюстрация лепестка — над каплей, пара и бадж фильма,
    /// книги и альбома — над подписью; подписи и текст лепестка (с его парой) — ниже всех.
    static let artDepth: CGFloat = 15
    static let pairDepth: CGFloat = 11
    static let captionDepth: CGFloat = 6

    /// Ход поворота от места в ряду: нечётный, почти линейный у центра и без излома
    /// на месте соседа — дальше не растёт.
    static func swing(_ position: CGFloat) -> CGFloat {
        sin(min(max(position, -1), 1) * .pi / 2)
    }
}

extension EnvironmentValues {
    /// Сдвиг ряда при схлопывании по ✕ (`ShowcasePromo.remove`): слои над обложкой
    /// считают место в ряду с ним, как сама карточка (`PromoCardMotion`), — иначе
    /// в конце схлопывания перескочили бы.
    @Entry var promoDepthShift: CGFloat = 0
}

extension View {
    /// Слой над обложкой промо: на свайпе уходит к центру ряда на `depth` (на месте
    /// соседа) — к повороту карточки, как будто висит над её поверхностью. Рамка —
    /// во всю карточку, раскладка — по `alignment`, как у оверлея: место в ряду
    /// считается от центра карточки, а не слоя.
    @ViewBuilder
    func promoLayer(enabled: Bool, depth: CGFloat, alignment: Alignment) -> some View {
        if enabled {
            frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
                .modifier(PromoLayerDepth(depth: depth))
        } else {
            self
        }
    }
}

/// Читает сдвиг ряда и отдаёт его анимируемому эффекту: при схлопывании он меняется
/// анимацией, и слой едет вместе с карточкой.
private struct PromoLayerDepth: ViewModifier {
    let depth: CGFloat
    @Environment(\.promoDepthShift) private var shift
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.modifier(PromoLayerDepthEffect(
            depth: reduceMotion ? 0 : depth * ShowcasePromoLayout.scale,
            shift: shift
        ))
    }
}

private struct PromoLayerDepthEffect: ViewModifier, Animatable {
    let depth: CGFloat
    var shift: CGFloat

    var animatableData: CGFloat {
        get { shift }
        set { shift = newValue }
    }

    func body(content: Content) -> some View {
        // Ширина-зависимое — здесь, на главном потоке: замыкание `visualEffect` не изолировано.
        let step = ShowcasePromoLayout.step
        return content.visualEffect { [depth, shift] content, proxy in
            let position = ShowcasePromoLayout.position(of: proxy, step: step) - shift
            // Слева от центра карточка повёрнута к центру — слой над ней уходит вправо.
            return content.offset(x: -depth * PromoDepthMotion.swing(position))
        }
    }
}
