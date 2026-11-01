import SwiftUI

/// Течение под пальцем — точки поля как водоросли (просьба пользователя 2026-11-01: «как
/// будто проводим рукой по листьям водорослей под водой»).
///
/// Каждая точка привязана к своему месту невидимой пружиной. Палец, двигаясь, толкает
/// воду: точки рядом отклоняются по ходу движения и чуть расступаются от пальца, потом
/// покачиваются и возвращаются с лёгким перехлёстом. Медленное ведение почти не колышет,
/// резкий мах раскачивает сильнее — сопротивление воды растёт со скоростью.
///
/// **Без покадрового состояния** (правило 2 CLAUDE.md). Движения пальца пишутся только
/// по событиям касания (`record`), а смещение точки на кадре — аналитическая функция
/// времени (`sway`): сумма откликов затухающей пружины на недавние толчки. Таймлайн
/// крутится, пока палец на поле, и ещё `window` после — пока не улягутся колебания.
@MainActor
final class TaskalkaFlow {
    /// Толчок — сдвиг пальца между двумя событиями касания, в долях поля.
    struct Impulse {
        let time: TimeInterval
        let point: CGPoint
        let move: CGVector
    }

    /// Сколько живёт отклик толчка: за это время колебание затухает до ~2 %.
    static let window: TimeInterval = 1.3
    /// События чаще этого сливаются в один толчок — и вычислений на кадр меньше.
    private static let mergeInterval: TimeInterval = 1.0 / 60

    private(set) var impulses: [Impulse] = []
    private var last: (time: TimeInterval, point: CGPoint)?

    static var now: TimeInterval { Date.timeIntervalSinceReferenceDate }

    /// Палец коснулся — отсюда считаются сдвиги. Прежние толчки доигрывают своё.
    func begin(at point: CGPoint) {
        last = (Self.now, point)
    }

    func record(_ point: CGPoint) {
        let now = Self.now
        guard let last else {
            self.last = (now, point)
            return
        }
        self.last = (now, point)
        let move = CGVector(dx: point.x - last.point.x, dy: point.y - last.point.y)
        guard move.dx != 0 || move.dy != 0 else { return }
        if let previous = impulses.last, now - previous.time < Self.mergeInterval {
            impulses[impulses.count - 1] = Impulse(
                time: now,
                point: point,
                move: CGVector(dx: previous.move.dx + move.dx, dy: previous.move.dy + move.dy)
            )
        } else {
            impulses.append(Impulse(time: now, point: point, move: move))
        }
        impulses.removeAll { now - $0.time > Self.window }
    }

    func end() {
        last = nil
    }
}

/// Числа течения. Пружина — «стебель»: полтора качания в секунду, затухание с лёгким
/// перехлёстом; толчок раскладывается на «увлечь по ходу» и «расступиться от пальца».
/// Сила сдвига поднята на треть по просьбе пользователя 2026-11-01 («офсет немного
/// увеличим»): было 0.12 / 0.08 и потолок 10.
enum TaskalkaFlowStyle {
    /// Собственная частота стебля, рад/с (~1.5 Гц)
    static let omega: Double = 2 * .pi * 1.5
    /// Затухание: меньше единицы — с перехлёстом (~25 %), как лист, а не как дверной доводчик
    static let damping: Double = 0.4
    /// Дальность течения, pt (сигма гауссианы вокруг пальца)
    static let reach: Double = 40
    /// Доля сдвига пальца, на которую точку увлекает по ходу движения
    static let along: Double = 0.16
    /// Доля, на которую точка расступается от пальца поперёк
    static let apart: Double = 0.11
    /// Потолок отклонения, pt: дальше точка не уходит, как бы ни мах
    static let maxOffset: Double = 13
    /// Вытягивание вдоль собственного движения: +1 к длине на столько pt/с скорости,
    /// не больше `maxStretch` — на ходу эллипс, в покое снова круг
    static let stretchSpeed: Double = 220
    static let maxStretch: Double = 0.5
    /// Размытие в движении: доля мягкого края — скорость (pt/с) ÷ `blurSpeed`, не больше
    /// `maxBlur`. Ядро сужается на `blurCore` от размытия, круг растёт на `blurGrowth`,
    /// ядро уходит вперёд по ходу на `blurLead` радиуса — хвост мягче переднего края
    /// Заметнее по просьбе пользователя 2026-11-01: было 260 / 0.55 / 0.6
    static let blurSpeed: Double = 180
    static let maxBlur: Double = 0.7
    static let blurCore: CGFloat = 1.6
    static let blurGrowth: CGFloat = 0.7
    static let blurLead: CGFloat = 0.3
}

extension TaskalkaFlow {
    /// Толчок в пунктах поля.
    struct Resolved {
        let time: TimeInterval
        let x: Double
        let y: Double
        let mx: Double
        let my: Double
        let length: Double
    }

    /// Отклонение точки и его скорость.
    struct Sway {
        var dx: Double = 0
        var dy: Double = 0
        var vx: Double = 0
        var vy: Double = 0

        var isVisible: Bool { abs(dx) + abs(dy) > 0.15 }
    }

    /// Толчки окна в пунктах поля.
    func resolved(in panel: CGRect, now: TimeInterval) -> [Resolved] {
        impulses.compactMap { impulse in
            guard now - impulse.time < Self.window, now >= impulse.time else { return nil }
            let mx = Double(impulse.move.dx * panel.width)
            let my = Double(impulse.move.dy * panel.height)
            return Resolved(
                time: impulse.time,
                x: Double(panel.minX + impulse.point.x * panel.width),
                y: Double(panel.minY + impulse.point.y * panel.height),
                mx: mx,
                my: my,
                length: (mx * mx + my * my).squareRoot()
            )
        }
    }

    /// Отклонение точки в момент `now` — сумма откликов пружины на толчки рядом.
    /// Отклик на единичный толчок: e^(−ζωτ)·sin(ω_d·τ), его производная — скорость.
    static func sway(at x: Double, _ y: Double, impulses: [Resolved], now: TimeInterval) -> Sway {
        typealias Style = TaskalkaFlowStyle
        let decayRate = Style.damping * Style.omega
        let omegaD = Style.omega * (1 - Style.damping * Style.damping).squareRoot()
        let reach2 = 2 * Style.reach * Style.reach
        let cutoff2 = 9 * Style.reach * Style.reach
        var sway = Sway()
        for impulse in impulses {
            let rx = x - impulse.x, ry = y - impulse.y
            let d2 = rx * rx + ry * ry
            guard d2 < cutoff2 else { continue }
            let weight = exp(-d2 / reach2)
            let tau = now - impulse.time
            let decay = exp(-decayRate * tau)
            let sine = sin(omegaD * tau), cosine = cos(omegaD * tau)
            let h = decay * sine
            let hp = decay * (omegaD * cosine - decayRate * sine)
            // По ходу движения и поперёк — от пальца; у самого пальца направление не определено.
            let distance = max(d2.squareRoot(), 1)
            let jx = Style.along * impulse.mx + Style.apart * impulse.length * rx / distance
            let jy = Style.along * impulse.my + Style.apart * impulse.length * ry / distance
            sway.dx += weight * jx * h
            sway.dy += weight * jy * h
            sway.vx += weight * jx * hp
            sway.vy += weight * jy * hp
        }
        let offset = (sway.dx * sway.dx + sway.dy * sway.dy).squareRoot()
        if offset > Style.maxOffset {
            let scale = Style.maxOffset / offset
            sway.dx *= scale
            sway.dy *= scale
            sway.vx *= scale
            sway.vy *= scale
        }
        return sway
    }
}
