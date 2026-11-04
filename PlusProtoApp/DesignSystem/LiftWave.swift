import SwiftUI

/// Числа волны «подъёма» — на ширине 402; на месте применения умножаются на масштаб
/// карточки (`LiftWave.scale`).
enum LiftWaveConfig {
    /// Волна — редкое событие (запуск «Моей волны»), не отклик на нажатие: дольше
    /// UI-анимаций. При 0.7 с и 650 pt/с она проходила «почти незаметно», а с нарастанием
    /// за 0.12 и затуханием за 0.9 с — «очень резкий старт»: плавность нужна одинаковая
    /// на всём протяжении (правки пользователя 2026-11-04). Поэтому сила — симметричный
    /// колокол sin² на всю длительность: с нуля и в ноль без излома, пик посередине.
    /// 1.6 с — «чуть быстрее» (правка пользователя 2026-11-04).
    static let duration: Double = 1.3
    /// pt/с, постоянная: к пику силы (0.65 с) кольцо в ~160 pt от пальца — посреди
    /// лепестка, к концу — в ~325 pt, за его краем.
    static let speed: Float = 250
    /// Ширина гребня
    static let width: Float = 64
    /// Сила линзы: на гребне картинка крупнее в 1 / (1 − amplitude / width) ≈ 1.6 раза.
    /// Больше ширины — картинка на гребне выворачивается.
    static let amplitude: Float = 24
    /// Свет на склонах — добавка яркости до ~0.28. Капля — гладкий градиент, линза
    /// на нём не видна: волну по капле показывает свет, линза — по иллюстрации и тексту.
    static let shade: Float = 0.32
    /// «Уменьшение движения»: вместо бегущего кольца — ровная мягкая вспышка.
    static let reducedFlash: Float = 0.08
}

/// Волна «подъёма» по поверхности: от точки касания расходится кольцо, на гребне
/// картинка чуть крупнее и светлее спереди — как будто волна приподнимает поверхность
/// к глазу (ripple-эффект iOS). Шейдер `liftWave` (`Shaders/LiftWave.metal`).
///
/// `layerEffect` двигает пиксели растра, поэтому под ним — только SwiftUI: UIKit-вью
/// (стекло кнопок, системный блюр, видео) в растр не попадают — их держать вне вью
/// с волной. Растр — по кадру вью: рисунок, вылезающий за кадр, обрезался бы, пока
/// идёт волна, — под него `overflow`.
///
/// Время — аналитически, `keyframeAnimator` по смене `trigger`: в `@State` на кадре
/// ничего не пишется, а в покое шейдер выключен, и пиксели исходные.
struct LiftWave: ViewModifier {
    /// Смена значения пускает волну
    let trigger: Int
    /// Точка касания — в координатах вью без `overflow`
    let origin: CGPoint
    /// Поле под рисунок за кадром вью
    var overflow = EdgeInsets()
    /// Масштаб чисел `LiftWaveConfig` — у лепестка промо `stationScale`
    var scale: CGFloat = 1

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private typealias Config = LiftWaveConfig

    func body(content: Content) -> some View {
        let center = CGPoint(x: origin.x + overflow.leading, y: origin.y + overflow.top)
        let factor = Float(scale)
        let amplitude = reduceMotion ? 0 : Config.amplitude * factor
        content
            .padding(overflow)
            .keyframeAnimator(initialValue: 0.0, trigger: trigger) { view, time in
                view.layerEffect(
                    ShaderLibrary.liftWave(
                        .float2(center),
                        .float(Float(time)),
                        .float(Config.speed * factor),
                        .float(Config.width * factor),
                        .float(amplitude),
                        .float(reduceMotion ? 0 : Config.shade),
                        .float(reduceMotion ? Config.reducedFlash : 0),
                        .float(Float(Config.duration))
                    ),
                    maxSampleOffset: CGSize(width: CGFloat(amplitude), height: CGFloat(amplitude)),
                    isEnabled: time > 0 && time < Config.duration
                )
            } keyframes: { _ in
                MoveKeyframe(0)
                LinearKeyframe(Config.duration, duration: Config.duration)
            }
            .padding(EdgeInsets(
                top: -overflow.top,
                leading: -overflow.leading,
                bottom: -overflow.bottom,
                trailing: -overflow.trailing
            ))
    }
}
