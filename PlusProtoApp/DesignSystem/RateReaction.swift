import SwiftUI
import UIKit

/// Реакция в блоке оценки (задача пользователя 2026-10-03): выбранная кнопка плавно
/// встаёт на белый фон, а из неё вверх улетают такие же эмодзи — как воздушные шарики,
/// лёгкой синусоидой, и растворяются наверху. Сколько улетает — по силе оценки:
/// «Шедевр» 6, «Супер» 2, «Ну такое» и «Нет» по одному. Хаптик — на каждый шарик.
///
/// Общая у двух блоков: «Что думаешь?» на витрине и «Уже смотрели? Как вам?»
/// на экране фильма. Оценка по-прежнему никуда не отправляется — это отклик кнопки.
enum RateReactionMotion {
    /// Белый фон выбранной — смена цвета, а не движение: обычный ease-out 250 мс.
    static let select: Animation = .easeOut(duration: 0.25)
    /// Между вылетами шариков одной стайки. Тики хаптика идут с тем же шагом:
    /// 90 мс — каждый слышен отдельно, а шестёрка «Шедевра» укладывается в полсекунды.
    static let stagger: Duration = .milliseconds(90)
    /// Полёт одного шарика — дольше UI-анимаций намеренно: это не отклик на тап
    /// (его дают фон и сам вылет), а украшение, и оно ничего не держит.
    static let flight: ClosedRange<Double> = 1.6...2.0
    /// Высота подъёма, pt
    static let rise: ClosedRange<CGFloat> = 150...210
    /// Размах синусоиды, pt, и сколько волн за полёт
    static let sway: ClosedRange<CGFloat> = 6...10
    static let swayCycles: ClosedRange<Double> = 1.1...1.6
    /// Снос в сторону к концу полёта, pt: стайка расходится веером, а не идёт столбом
    static let drift: ClosedRange<CGFloat> = -12...12
    /// Наклон в сторону качания, градусы — шарик «ведёт» верхушкой
    static let tilt: Double = 10
    /// Доля полёта, за которую наклон набирает полный размах
    static let tiltRamp: Double = 0.15
    /// Рост к концу полёта: шарик чуть «надувается», пока растворяется
    static let growth: CGFloat = 0.12
    /// Доля полёта, после которой шарик начинает таять
    static let fadeStart: Double = 0.4
    /// Подъём — пополам линейный и ease-out: шарик срывается с кнопки сразу (скорость
    /// в 1.5 раза выше средней), а к концу не тормозит до нуля — уходит вверх, пока
    /// тает. Чистый ease-out останавливал его наверху, и он читался «приземлившимся»
    /// (ревью анимации 2026-10-03).
    static let riseLinearShare: Double = 0.5
    /// Потолок шариков в воздухе у одной кнопки: частые тапы не копят толпу
    static let maxInFlight = 18
    static let hapticIntensity: CGFloat = 0.8
}

/// Круг реакции: эмодзи на серой подложке, выбранная — на белой.
struct RateReactionChip: View {
    let emoji: String
    let isSelected: Bool
    let diameter: CGFloat
    let emojiSize: CGFloat

    var body: some View {
        Image(emoji)
            .resizable()
            .frame(width: emojiSize, height: emojiSize)
            .frame(width: diameter, height: diameter)
            .background(Circle().fill(isSelected ? Color.white : Color.buttonsSecondary))
            .animation(RateReactionMotion.select, value: isSelected)
            .accessibilityHidden(true)
    }
}

/// Стайка эмодзи над кругом реакции. Кадр — ровно круг: ставится поверх него, а шарики
/// улетают за кадр вверх. Живёт **снаружи** кнопки — иначе сжатие нажатия
/// (`PressScaleButtonStyle`) тянуло бы за собой и шарики в полёте.
struct RateBalloons: View {
    let emoji: String
    let emojiSize: CGFloat
    let diameter: CGFloat
    /// Сколько шариков в стайке
    let burst: Int
    /// Счётчик нажатий: каждое новое — новая стайка
    let launches: Int

    @State private var balloons: [Balloon] = []
    @State private var haptics = UIImpactFeedbackGenerator(style: .light)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            ForEach(balloons) { balloon in
                BalloonEmoji(emoji: emoji, size: emojiSize, balloon: balloon)
            }
        }
        .frame(width: diameter, height: diameter)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: launches) { release() }
    }

    /// Стайка: шарики вылетают по одному, хаптик — с каждым. С «уменьшением движения»
    /// полёта нет, остаются фон кнопки и хаптик той же длины.
    private func release() {
        haptics.prepare()
        let count = burst
        Task { @MainActor in
            for index in 0..<count {
                if index > 0 { try? await Task.sleep(for: RateReactionMotion.stagger) }
                haptics.impactOccurred(intensity: RateReactionMotion.hapticIntensity)
                haptics.prepare()
                guard !reduceMotion, balloons.count < RateReactionMotion.maxInFlight else { continue }
                let balloon = Balloon.random()
                balloons.append(balloon)
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(balloon.duration))
                    balloons.removeAll { $0.id == balloon.id }
                }
            }
        }
    }
}

/// Траектория одного шарика. Случайная в пределах `RateReactionMotion`: шесть
/// одинаковых синусоид читались бы строем, а не стайкой.
private struct Balloon: Identifiable {
    let id = UUID()
    let duration: Double
    let rise: CGFloat
    let sway: CGFloat
    let cycles: Double
    /// Фаза и направление первой волны: одни уходят влево, другие вправо
    let phase: Double
    let drift: CGFloat

    static func random() -> Balloon {
        Balloon(
            duration: .random(in: RateReactionMotion.flight),
            rise: .random(in: RateReactionMotion.rise),
            sway: .random(in: RateReactionMotion.sway),
            cycles: .random(in: RateReactionMotion.swayCycles),
            phase: Bool.random() ? 0 : .pi,
            drift: .random(in: RateReactionMotion.drift)
        )
    }
}

private struct BalloonEmoji: View {
    let emoji: String
    let size: CGFloat
    let balloon: Balloon
    @State private var progress: Double = 0

    var body: some View {
        Image(emoji)
            .resizable()
            .frame(width: size, height: size)
            .modifier(BalloonFlight(progress: progress, balloon: balloon))
            .onAppear {
                // Шкала времени линейная: синусоида качания равномерна во времени,
                // кривую подъёма и таяния считает сам модификатор.
                withAnimation(.linear(duration: balloon.duration)) { progress = 1 }
            }
    }
}

/// Полёт по шкале 0…1 — каждый кадр: подъём с ease-out, качание синусоидой
/// с наклоном в её сторону, снос веером, рост и таяние во второй половине.
/// Только transform и прозрачность — раскладку полёт не трогает.
private struct BalloonFlight: ViewModifier, Animatable {
    var progress: Double
    let balloon: Balloon

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let t = min(max(progress, 0), 1)
        let share = RateReactionMotion.riseLinearShare
        let rise = balloon.rise * CGFloat(share * t + (1 - share) * (1 - pow(1 - t, 2)))
        let angle = 2 * .pi * balloon.cycles * t + balloon.phase
        // Вычитаем стартовую фазу — шарик срывается ровно из центра кнопки.
        let sway = balloon.sway * CGFloat(sin(angle) - sin(balloon.phase))
        // Наклон нарастает с отрыва: на старте копия лежит ровно на эмодзи кнопки.
        let tilt = RateReactionMotion.tilt * cos(angle) * min(1, t / RateReactionMotion.tiltRamp)
        let fade = max(0, (t - RateReactionMotion.fadeStart) / (1 - RateReactionMotion.fadeStart))
        let opacity = pow(1 - fade, 1.5)
        let scale = 1 + RateReactionMotion.growth * CGFloat(1 - pow(1 - t, 2))

        content
            .scaleEffect(scale)
            .rotationEffect(.degrees(tilt))
            .offset(x: sway + balloon.drift * CGFloat(t), y: -rise)
            .opacity(opacity)
    }
}
