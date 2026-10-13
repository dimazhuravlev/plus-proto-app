import SwiftUI

// MARK: - Геометрия

/// Орб карточки «Моя Волна» — `2004:10733`, figma-screen1 §3.5. Общий у карточки ленты
/// (`MyVibeCard`) и станции промо «Главной» (`ShowcasePromo`, задача 64).
/// Координаты — в системе кадра карточки ленты: по X — кадра витрины (орб уходит за левый
/// край на 15), по Y из спеки вычтен верх слота. Числа — макет на 402; на экране они
/// умножаются на масштаб места применения (`VibeOrb.scale`).
enum VibeOrbGeometry {
    static let slot = ShowcaseLayout.Slot.vibe

    /// `2004:10735` — эллипс гало 150.48² в (59.46, 1101.92). Он же — кадр орба:
    /// слои рисования далеко выходят за него, а нажимается и подсаживается ровно круг.
    static let haloSize: CGFloat = 150.48
    static let haloOrigin = CGPoint(x: 59.46, y: 1101.92 - slot.top)
    static let haloCenter = CGPoint(x: haloOrigin.x + haloSize / 2, y: haloOrigin.y + haloSize / 2)
    /// Ассет отрисован по границам, до которых блюр раздувает эллипс: спилл −53.33% на сторону,
    /// то есть 150.48 × 2.0666 = 311 (PNG @3x = 933px). Блюр запечён — живьём не повторяем.
    static let haloBleed: CGFloat = 311

    /// `2004:10736` — прямоугольник шума 317×316 в (−15, 1008), color-dodge 0.70.
    static let grainBox = CGRect(x: -15, y: 0, width: 317, height: 316)

    /// `2004:10737` — глиф «Моя Волна» 100.32² в (83.29, 1127).
    static let glyphSize: CGFloat = 100.32
    static let glyphOrigin = CGPoint(x: 83.29, y: 1127 - slot.top)

    /// Слои внутри орба расставлены от его центра, а координаты макета — от угла карточки.
    /// Пересчитываем здесь, чтобы в вёрстке не появилось второго набора чисел.
    static let grainOffset = CGSize(
        width: grainBox.midX - haloCenter.x,
        height: grainBox.midY - haloCenter.y
    )
    static let glyphOffset = CGSize(
        width: glyphOrigin.x + glyphSize / 2 - haloCenter.x,
        height: glyphOrigin.y + glyphSize / 2 - haloCenter.y
    )

    /// Центр орба в кадре зерна, в долях: маска зерна (`fadesGrain`) считается от него.
    static let grainMaskCenter = UnitPoint(
        x: 0.5 - grainOffset.width / grainBox.width,
        y: 0.5 - grainOffset.height / grainBox.height
    )
}

// MARK: - Движение орба

/// Орб живой (решение 2026-08-22): гало дышит, зерно медленно плывёт, глиф статичен —
/// иначе движение читается как дрожание (приём `YasminaAvatar` из MusicPlayer).
/// Все величины — чистые функции времени: запись в `@State` на каждом кадре в этом проекте
/// уже вешала рендер на 100% CPU (замер action bar).
private enum VibeOrbMotion {
    /// Шаг таймлайна. Движение медленное, 30 Гц от 120 неотличимы, а кадров ленте оставляет вчетверо больше.
    static let tick: Double = 1.0 / 30

    /// Дыхание гало: масштаб и яркость в противофазе на четверть периода
    static let haloPeriod: Double = 6.2
    static let haloScale: ClosedRange<Double> = 0.94...1.06
    static let haloOpacity: ClosedRange<Double> = 0.78...1.0
    static let haloOpacityPhase: Double = .pi / 3

    /// Дрейф зерна по фигуре Лиссажу: периоды взаимно непериодичны, поэтому рисунок не зацикливается
    static let grainPeriodX: Double = 23
    static let grainPeriodY: Double = 31
    /// Амплитуда сдвига; на столько же ассет берётся крупнее кадра, чтобы не открывался край
    static let grainDrift: CGFloat = 14
    static let grainPeriodOpacity: Double = 8.7
    static let grainOpacity: ClosedRange<Double> = 0.56...0.70
}

/// Плавное колебание в границах диапазона — синус, приведённый к 0…1.
private func wave(
    _ t: TimeInterval,
    period: Double,
    _ range: ClosedRange<Double>,
    phase: Double = 0
) -> Double {
    let unit = (sin(2 * .pi * t / period + phase) + 1) / 2
    return range.lowerBound + (range.upperBound - range.lowerBound) * unit
}

// MARK: - Орб

/// Неоновый орб «Моей Волны»: три слоя снизу вверх — гало → зерно в color-dodge → глиф.
/// В таймлайне живут только первые два, глиф вынесен наружу и не перерисовывается.
///
/// Гаснут при смене по ✕ слои по отдельности, а зерно — до своего наложения. Блюр
/// и прозрачность на всём орбе сводили его в отдельный прозрачный слой, color-dodge
/// там смешивался с пустотой вместо фона, и зерно вспыхивало серым квадратом в начале
/// и в конце смены (кадр 2026-10-09). Поэтому `showcaseSwappable()` снаружи орба не вешать.
///
/// Кадр — круг гало, слои расставлены от его центра: зерно 317×316 и раздутое блюром
/// гало 311 выходят за кадр далеко, и если отдать кнопке их габарит, она ловила бы тапы
/// по пустому месту, а просадка под пальцем считалась бы вокруг чужого центра.
struct VibeOrb: View {
    let art: VibeArt
    /// Дышит ли орб. Не дышит — таймлайн на паузе, стоит последний кадр: в ленте — пока
    /// карточка за экраном, в промо — у всех копий, кроме центральной.
    let isAnimating: Bool
    /// Множитель геометрии макета: у ленты `ShowcaseLayout.scale`, у промо
    /// `ShowcasePromoLayout.scale`.
    let scale: CGFloat
    /// Зерно под радиальной маской — в промо «Главной». В ленте под орбом чёрный, и
    /// color-dodge по нему — no-op; в промо под ним размытый фон, и прямоугольник зерна
    /// высветлял бы его целиком. Маска непрозрачна на круге гало и уходит в прозрачность
    /// к краю его спилла (`haloBleed / 2`).
    var fadesGrain = false

    var body: some View {
        ZStack {
            TimelineView(.animation(minimumInterval: VibeOrbMotion.tick, paused: !isAnimating)) { context in
                let t = context.date.timeIntervalSinceReferenceDate

                ZStack {
                    halo(t)
                        .showcaseSwappable()
                    grain(t)
                }
            }

            Image(art.glyph)
                .resizable()
                .frame(width: VibeOrbGeometry.glyphSize * scale, height: VibeOrbGeometry.glyphSize * scale)
                .showcaseSwappable()
                .offset(x: VibeOrbGeometry.glyphOffset.width * scale, y: VibeOrbGeometry.glyphOffset.height * scale)
        }
        .frame(width: VibeOrbGeometry.haloSize * scale, height: VibeOrbGeometry.haloSize * scale)
        .contentShape(Circle())
    }

    /// Гало: PNG с запечённым блюром, дышит масштабом и яркостью.
    private func halo(_ t: TimeInterval) -> some View {
        Image("vibeColorEllipse")
            .resizable()
            .frame(
                width: VibeOrbGeometry.haloBleed * scale,
                height: VibeOrbGeometry.haloBleed * scale
            )
            // Тон — под иллюстрацию волны; меняется плавно, той же кривой, что проявление
            // новой волны после ✕, а не щелчком на подмене блока.
            .hueRotation(art.haloHue)
            .animation(ShowcaseFeedbackMotion.swapIn, value: art)
            .scaleEffect(wave(t, period: VibeOrbMotion.haloPeriod, VibeOrbMotion.haloScale))
            .opacity(
                wave(
                    t,
                    period: VibeOrbMotion.haloPeriod,
                    VibeOrbMotion.haloOpacity,
                    phase: VibeOrbMotion.haloOpacityPhase
                )
            )
    }

    /// Зерно: текстура шума поверх гало в color-dodge. Фон текстуры чёрный, а color-dodge
    /// по чёрному — no-op, поэтому в ленте маска не нужна и прямоугольник кладётся на весь
    /// кадр (в промо — см. `fadesGrain`). Сдвигаем ассет, взятый с запасом, и режем по
    /// кадру — так дрейф не открывает край текстуры.
    private func grain(_ t: TimeInterval) -> some View {
        let drift = VibeOrbMotion.grainDrift
        let dx = drift * CGFloat(wave(t, period: VibeOrbMotion.grainPeriodX, -1...1))
        let dy = drift * CGFloat(wave(t, period: VibeOrbMotion.grainPeriodY, -1...1))

        return Image("mockVibeNoise")
            .resizable()
            .frame(
                width: VibeOrbGeometry.grainBox.width * scale + drift * 2,
                height: VibeOrbGeometry.grainBox.height * scale + drift * 2
            )
            .offset(x: dx, y: dy)
            .frame(width: VibeOrbGeometry.grainBox.width * scale, height: VibeOrbGeometry.grainBox.height * scale)
            .clipped()
            .modifier(VibeGrainFade(isOn: fadesGrain, scale: scale))
            .opacity(wave(t, period: VibeOrbMotion.grainPeriodOpacity, VibeOrbMotion.grainOpacity))
            .showcaseSwappable()
            .blendMode(.colorDodge)
            .offset(x: VibeOrbGeometry.grainOffset.width * scale, y: VibeOrbGeometry.grainOffset.height * scale)
    }
}

/// Радиальная маска зерна вокруг центра орба (`VibeOrb.fadesGrain`): на круге гало
/// зерно как в ленте, дальше — в прозрачность к краю спилла гало. Вешается на сам слой
/// зерна, до наложения. Выключена — слой без маски, ровно как в ленте.
private struct VibeGrainFade: ViewModifier {
    let isOn: Bool
    let scale: CGFloat

    func body(content: Content) -> some View {
        if isOn {
            content.mask {
                RadialGradient(
                    stops: [
                        .init(color: .black, location: 0),
                        .init(color: .black, location: VibeOrbGeometry.haloSize / VibeOrbGeometry.haloBleed),
                        .init(color: .clear, location: 1),
                    ],
                    center: VibeOrbGeometry.grainMaskCenter,
                    startRadius: 0,
                    endRadius: VibeOrbGeometry.haloBleed / 2 * scale
                )
            }
        } else {
            content
        }
    }
}
