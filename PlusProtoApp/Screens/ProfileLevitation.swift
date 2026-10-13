import CoreMotion
import SwiftUI

/// Числа левитации героя профиля (просьба пользователя 2026-10-13): аватар, карандаш
/// и бабл баллов слегка покачиваются — от наклона телефона и медленным дрейфом.
enum ProfileLevitationConfig {
    /// Опрос гироскопа — 60 Гц
    static let motionInterval: TimeInterval = 1.0 / 60
    /// Смещение от наклона на пределе — 6 pt по каждой оси, умножается на глубину слоя
    static let tiltAmplitude: CGFloat = 6
    /// Наклон дальше ±15° от опорного смещения не добавляет
    static let tiltLimit: Double = 15 * .pi / 180
    /// Постоянная времени фильтра нижних частот: сырой гироскоп дрожит
    static let smoothing: TimeInterval = 0.3
    /// Дрейф — синусы с периодами 5–7 с; на симуляторе (без гироскопа) он один и двигает героя
    static let driftAmplitude: CGFloat = 2
    /// Плавный вход: амплитуда всего нарастает от нуля за 1.2 с после появления экрана
    static let rampDuration: TimeInterval = 1.2
}

/// Слой героя. Глубина — во сколько раз слой ходит за наклоном сильнее аватара:
/// разные смещения у соседей дают объём.
enum ProfileLevitationLayer: CaseIterable {
    case avatar, pencil, points

    var depth: CGFloat {
        switch self {
        case .avatar: 1
        case .pencil: 1.4
        case .points: 1.2
        }
    }

    /// Периоды дрейфа по осям (с) и фазы (рад): у каждого слоя свои, слои не идут в ногу.
    fileprivate var drift: (periodX: Double, periodY: Double, phaseX: Double, phaseY: Double) {
        switch self {
        case .avatar: (6.0, 7.0, 0.0, 1.9)
        case .pencil: (5.0, 6.3, 2.4, 0.7)
        case .points: (5.6, 6.6, 4.1, 3.3)
        }
    }
}

/// Смещения слоёв на кадр. В покое — нули.
struct ProfileLevitationOffsets {
    var avatar: CGSize = .zero
    var pencil: CGSize = .zero
    var points: CGSize = .zero

    static let rest = ProfileLevitationOffsets()
}

/// Обёртка героя: пока экран виден, отдаёт содержимому смещения слоёв на каждый кадр.
///
/// Покадровое — аналитической функцией времени внутри `TimelineView` (правило 2 CLAUDE.md):
/// в `@State` на кадре ничего не пишется. Гироскоп читается там же, опросом (pull), а фильтр
/// живёт в обычном классе `ProfileLevitationMotion` — его запись вью не инвалидирует.
/// `TimelineView` в дереве, только пока экран на виду: появление включает его и гироскоп,
/// уход (крестик, пуш дебаг-меню) — убирает. Reduce Motion — статично, без гироскопа.
/// Смещения — `offset`, раскладку они не трогают.
struct ProfileLevitation<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Держатель фильтра: объект один на жизнь вью, его поля — не состояние SwiftUI.
    @State private var motion = ProfileLevitationMotion()
    /// Момент появления: от него — нарастание амплитуды и время дрейфа. `nil` — экран не виден.
    @State private var appearance: Date?
    /// Экран на виду — смена Reduce Motion под пушем дебаг-меню гироскоп не включает
    @State private var isVisible = false
    @ViewBuilder let content: (ProfileLevitationOffsets) -> Content

    var body: some View {
        // Контейнер, а не `Group`: модификаторы `Group` легли бы на ветки, и смена ветки
        // звала бы `onDisappear` → `onAppear` по кругу.
        ZStack {
            if let appearance, !reduceMotion {
                TimelineView(.animation) { context in
                    content(motion.offsets(at: context.date, since: appearance))
                }
            } else {
                content(.rest)
            }
        }
        .onAppear {
            isVisible = true
            start()
        }
        .onDisappear {
            isVisible = false
            stop()
        }
        .onChange(of: reduceMotion) { _, isReduced in
            guard isVisible else { return }
            if isReduced { stop() } else { start() }
        }
    }

    private func start() {
        guard !reduceMotion else { return }
        motion.start()
        appearance = .now
    }

    private func stop() {
        motion.stop()
        appearance = nil
    }
}

/// Гироскоп и сглаживание. Обычный класс, не `@Observable`: пишется на каждом кадре из тела
/// `TimelineView`, и запись не должна перерисовывать вью. Живёт на главном потоке.
final class ProfileLevitationMotion {
    private lazy var manager = CMMotionManager()
    /// Опорная ориентация — первый замер после появления: исходный наклон телефона
    /// не даёт скачка, считается только отклонение от него.
    private var reference: CMAttitude?
    /// Сглаженный наклон в долях предела, −1…1 по осям
    private var smoothed = CGVector.zero
    private var lastFrame: Date?

    func start() {
        reference = nil
        smoothed = .zero
        lastFrame = nil
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = ProfileLevitationConfig.motionInterval
        // Без обработчика — опрос: свежий замер берёт кадр `TimelineView`.
        manager.startDeviceMotionUpdates()
    }

    func stop() {
        guard manager.isDeviceMotionActive else { return }
        manager.stopDeviceMotionUpdates()
    }

    /// Смещения слоёв на момент `date`: (наклон × глубина + дрейф) × нарастание входа.
    func offsets(at date: Date, since appearance: Date) -> ProfileLevitationOffsets {
        let tilt = smoothedTilt(at: date)
        let time = max(0, date.timeIntervalSince(appearance))
        let ramp = Self.smoothstep(time / ProfileLevitationConfig.rampDuration)

        func offset(_ layer: ProfileLevitationLayer) -> CGSize {
            let drift = layer.drift
            let swayX = ProfileLevitationConfig.driftAmplitude
                * CGFloat(sin(2 * .pi * time / drift.periodX + drift.phaseX))
            let swayY = ProfileLevitationConfig.driftAmplitude
                * CGFloat(sin(2 * .pi * time / drift.periodY + drift.phaseY))
            let reach = ProfileLevitationConfig.tiltAmplitude * layer.depth
            return CGSize(
                width: (tilt.dx * reach + swayX) * ramp,
                height: (tilt.dy * reach + swayY) * ramp
            )
        }

        return ProfileLevitationOffsets(
            avatar: offset(.avatar),
            pencil: offset(.pencil),
            points: offset(.points)
        )
    }

    /// Фильтр нижних частот по реальному шагу кадра: на 60 и на 120 Гц ведёт себя одинаково.
    private func smoothedTilt(at date: Date) -> CGVector {
        let step = lastFrame.map { max(0, date.timeIntervalSince($0)) } ?? 0
        lastFrame = date
        let target = currentTilt()
        let gain = CGFloat(1 - exp(-step / ProfileLevitationConfig.smoothing))
        smoothed.dx += (target.dx - smoothed.dx) * gain
        smoothed.dy += (target.dy - smoothed.dy) * gain
        return smoothed
    }

    /// Наклон относительно опорного в долях предела. Крен (roll) — по горизонтали: правый край
    /// вниз — слои съезжают вправо; тангаж (pitch) — по вертикали: верх к себе — слои вниз.
    /// Поворот берётся относительным (`multiply(byInverseOf:)`), а не разностью углов:
    /// у телефона в руке тангаж под 90°, и крен там скачет.
    private func currentTilt() -> CGVector {
        // Копия: замер кешируется менеджером и между кадрами может прийти тем же объектом.
        guard let attitude = manager.deviceMotion?.attitude.copy() as? CMAttitude else { return .zero }
        guard let reference else {
            reference = attitude
            return .zero
        }
        attitude.multiply(byInverseOf: reference)
        let limit = ProfileLevitationConfig.tiltLimit
        return CGVector(
            dx: CGFloat(min(max(attitude.roll / limit, -1), 1)),
            dy: CGFloat(min(max(attitude.pitch / limit, -1), 1))
        )
    }

    private static func smoothstep(_ x: Double) -> CGFloat {
        let u = min(max(x, 0), 1)
        return CGFloat(u * u * (3 - 2 * u))
    }
}
