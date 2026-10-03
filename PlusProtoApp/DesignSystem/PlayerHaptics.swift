import UIKit

/// Хаптика кнопок плееров — киноплеера и плеера музыки (просьбы пользователя 2026-10-03).
enum PlayerHaptics {
    /// Нажатие любой кнопки плеера — impact light, как у play/pause мини-плеера.
    static func tap() {
        UIImpactFeedbackGenerator(style: .light)
            .impactOccurred(intensity: ActionBarMotion.transportHapticIntensity)
    }
}

/// Трещотка перемотки — серия лёгких тиков, пока головка таймлайна едет под пальцем
/// («как пулемётная очередь», просьба пользователя 2026-10-03). Общая у киноплеера
/// и плеера музыки, числа у каждого свои.
///
/// Тик привязан к ходу **головки**, а не пальца: у краёв дорожки головка упирается,
/// и очередь стихает вместе с ней. Частота ограничена сверху — быстрая протяжка даёт
/// ровную очередь, а не гул, который Taptic Engine всё равно не отыграл бы.
@MainActor
final class ScrubRatchet {
    /// Ход головки между тиками, pt.
    private let step: CGFloat
    /// Минимальный промежуток между тиками.
    private let interval: TimeInterval
    private let intensity: CGFloat
    private let generator = UIImpactFeedbackGenerator(style: .light)
    private var lastX: CGFloat?
    private var travel: CGFloat = 0
    private var lastTick = Date.distantPast

    init(step: CGFloat, interval: TimeInterval, intensity: CGFloat) {
        self.step = step
        self.interval = interval
        self.intensity = intensity
    }

    /// Положение головки на дорожке, pt. Первый вызов за жест — хват: тик сразу,
    /// чтобы касание отозвалось ещё до того, как палец сдвинулся.
    func move(to x: CGFloat) {
        guard let lastX else {
            self.lastX = x
            tick()
            return
        }
        travel += abs(x - lastX)
        self.lastX = x
        guard travel >= step, Date.now.timeIntervalSince(lastTick) >= interval else { return }
        travel = 0
        tick()
    }

    func end() {
        lastX = nil
        travel = 0
    }

    private func tick() {
        generator.impactOccurred(intensity: intensity)
        lastTick = .now
        // Следующий тик может прийти через десятки миллисекунд — движок держим разогретым.
        generator.prepare()
    }
}
