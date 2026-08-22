import SwiftUI

// MARK: - Геометрия

/// Карточка «Моя Волна» — `2004:10733`, figma-screen1 §3.5.
/// Кадр карточки — слот витрины: ширина 402, высота 316. По X координаты остаются
/// в системе кадра витрины (орб уходит за левый край на 15), по Y из спеки вычтен верх слота.
private enum VibeGeometry {
    static let slot = ShowcaseLayout.Slot.vibe
    static let size = CGSize(width: ShowcaseLayout.designWidth, height: slot.height)

    /// `2004:10735` — эллипс гало 150.48² в (59.46, 1101.92).
    static let haloCenter = CGPoint(x: 59.46 + 150.48 / 2, y: 1101.92 - slot.top + 150.48 / 2)
    /// Ассет отрисован по границам, до которых блюр раздувает эллипс: спилл −53.33% на сторону,
    /// то есть 150.48 × 2.0666 = 311 (PNG @3x = 933px). Блюр запечён — живьём не повторяем.
    static let haloBleed: CGFloat = 311

    /// `2004:10736` — прямоугольник шума 317×316 в (−15, 1008), color-dodge 0.70.
    static let grainBox = CGRect(x: -15, y: 0, width: 317, height: 316)

    /// `2004:10737` — глиф «Моя Волна» 100.32² в (83.29, 1127).
    static let glyphSize: CGFloat = 100.32
    static let glyphOrigin = CGPoint(x: 83.29, y: 1127 - slot.top)

    /// `2004:10738` — текстовая колонка в (208, 1118), внутренний зазор 12.
    static let textOrigin = CGPoint(x: 208, y: 1118 - slot.top)
    static let textGap: CGFloat = 12
    static let titleWidth: CGFloat = 115
    /// Подзаголовок в макете шире колонки — перенос строк считается по 124.
    static let subtitleWidth: CGFloat = 124
    static let subtitleOpacity: Double = 0.6

    /// Доля карточки на экране, с которой орб оживает.
    static let visibilityThreshold: Double = 0.1
}

// MARK: - Движение орба

/// Орб живой (решение 2026-08-22): гало дышит, зерно медленно плывёт, глиф статичен —
/// иначе движение читается как дрожание (приём `YasminaAvatar` из MusicPlayer).
/// Все величины — чистые функции времени: запись в `@State` на каждом кадре в этом проекте
/// уже вешала рендер на 100% CPU (DECISIONS, замер action bar).
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

// MARK: - Карточка

/// «Моя Волна»: неоновый орб слева, заголовок с подзаголовком и пара ♥/✕ справа.
/// Кнопки без логики — по решению из DECISIONS витрина пока только вёрстка.
struct MyVibeCard: View {
    let block: VibeBlock

    /// Орб анимируется только пока карточка на экране: таймлайн вхолостую съедает кадры ленты.
    @State private var isVisible = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            orb
            textColumn
        }
        .frame(width: VibeGeometry.size.width, height: VibeGeometry.size.height, alignment: .topLeading)
        .onScrollVisibilityChange(threshold: VibeGeometry.visibilityThreshold) { isVisible = $0 }
    }

    // MARK: Орб

    /// Три слоя снизу вверх: гало → зерно в color-dodge → глиф.
    /// В таймлайне живут только первые два, глиф вынесен наружу и не перерисовывается.
    private var orb: some View {
        ZStack(alignment: .topLeading) {
            TimelineView(.animation(minimumInterval: VibeOrbMotion.tick, paused: !isVisible)) { context in
                let t = context.date.timeIntervalSinceReferenceDate

                ZStack(alignment: .topLeading) {
                    halo(t)
                    grain(t)
                }
            }

            Image("vibeGlyph")
                .resizable()
                .frame(width: VibeGeometry.glyphSize, height: VibeGeometry.glyphSize)
                .offset(x: VibeGeometry.glyphOrigin.x, y: VibeGeometry.glyphOrigin.y)
        }
        .allowsHitTesting(false)
    }

    /// Гало: PNG с запечённым блюром, дышит масштабом и яркостью.
    private func halo(_ t: TimeInterval) -> some View {
        Image("vibeColorEllipse")
            .resizable()
            .frame(width: VibeGeometry.haloBleed, height: VibeGeometry.haloBleed)
            .scaleEffect(wave(t, period: VibeOrbMotion.haloPeriod, VibeOrbMotion.haloScale))
            .opacity(
                wave(
                    t,
                    period: VibeOrbMotion.haloPeriod,
                    VibeOrbMotion.haloOpacity,
                    phase: VibeOrbMotion.haloOpacityPhase
                )
            )
            .offset(
                x: VibeGeometry.haloCenter.x - VibeGeometry.haloBleed / 2,
                y: VibeGeometry.haloCenter.y - VibeGeometry.haloBleed / 2
            )
    }

    /// Зерно: текстура шума поверх гало в color-dodge. Фон текстуры чёрный, а color-dodge
    /// по чёрному — no-op, поэтому маска не нужна и прямоугольник кладётся на весь кадр (DECISIONS).
    /// Сдвигаем ассет, взятый с запасом, и режем по кадру — так дрейф не открывает край текстуры.
    private func grain(_ t: TimeInterval) -> some View {
        let drift = VibeOrbMotion.grainDrift
        let dx = drift * CGFloat(wave(t, period: VibeOrbMotion.grainPeriodX, -1...1))
        let dy = drift * CGFloat(wave(t, period: VibeOrbMotion.grainPeriodY, -1...1))

        return Image("mockVibeNoise")
            .resizable()
            .frame(
                width: VibeGeometry.grainBox.width + drift * 2,
                height: VibeGeometry.grainBox.height + drift * 2
            )
            .offset(x: dx, y: dy)
            .frame(width: VibeGeometry.grainBox.width, height: VibeGeometry.grainBox.height)
            .clipped()
            .opacity(wave(t, period: VibeOrbMotion.grainPeriodOpacity, VibeOrbMotion.grainOpacity))
            .blendMode(.colorDodge)
            .offset(x: VibeGeometry.grainBox.minX, y: VibeGeometry.grainBox.minY)
    }

    // MARK: Текст

    private var textColumn: some View {
        VStack(alignment: .leading, spacing: VibeGeometry.textGap) {
            GradientText(block.title, from: .fillOne, to: .white.opacity(0.7))
                .plusTextM()
                .frame(width: VibeGeometry.titleWidth, alignment: .leading)

            GradientText(block.subtitle, from: .fillOne, to: .white.opacity(0.6))
                .plusTextM()
                .frame(width: VibeGeometry.subtitleWidth, alignment: .leading)
                .opacity(VibeGeometry.subtitleOpacity)

            LikeDismissPair()
        }
        .offset(x: VibeGeometry.textOrigin.x, y: VibeGeometry.textOrigin.y)
    }
}

#Preview {
    // ScrollView обязателен: без него `onScrollVisibilityChange` не сработает и орб не оживёт.
    ScrollView {
        MyVibeCard(block: VibeBlock(
            id: "my-vibe",
            title: "Моя Волна",
            subtitle: "Атмосферный постпанк, когда внутри пасмурно"
        ))
    }
    .background(Color.black)
}
