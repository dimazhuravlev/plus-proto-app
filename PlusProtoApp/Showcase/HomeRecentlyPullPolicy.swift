import Foundation

enum HomeRecentlyPullConfig {
    static let activationStartLimit: CGFloat = 32
    static let travel: CGFloat = 64
}

/// Два независимых процесса, как у Telegram: вытягивание и пороговое раскрытие.
struct HomeRecentlyResponsivePullPolicy {
    struct Update {
        let pullRatio: CGFloat
        let overstretch: CGFloat
        let scrollOffset: CGFloat?
        let expandedChanged: Bool?
    }
    static let expandThreshold: CGFloat = 0.72
    static let collapseThreshold: CGFloat = 0.68
    static let previewFriction: CGFloat = 0.15
    static let pullGain: CGFloat = 0.55
    private(set) var expanded = false
    private(set) var startRatio: CGFloat = 0
    private var lastRatio: CGFloat = 0
    private var origin: CGFloat = 0
    private var approach: CGFloat = 0
    private var eligible = false

    mutating func begin(offset: CGFloat, pullRatio: CGFloat, expanded: Bool) {
        startRatio = min(1, max(0, pullRatio))
        lastRatio = startRatio
        self.expanded = expanded
        origin = max(0, offset)
        approach = startRatio == 0 ? origin : 0
        eligible = offset < HomeRecentlyPullConfig.activationStartLimit || startRatio > 0
    }

    mutating func move(offset: CGFloat, translation: CGFloat) -> Update? {
        if startRatio == 0, offset >= HomeRecentlyPullConfig.activationStartLimit { eligible = false }
        guard eligible else { return nil }
        // Обе стороны используют одну шкалу хода пальца и одинаковое сопротивление.
        let finger = startRatio * HomeRecentlyPullConfig.travel / Self.pullGain + translation - approach
        let softLimit = HomeRecentlyPullConfig.travel / Self.pullGain
        let distance = finger <= softLimit ? finger * Self.pullGain
            : HomeRecentlyPullConfig.travel + (finger - softLimit) * 0.08
        let ratio = min(1, max(0, distance / HomeRecentlyPullConfig.travel))
        var changed: Bool?
        if !expanded, ratio > lastRatio, ratio >= Self.expandThreshold {
            expanded = true
            changed = true
        } else if expanded, ratio < lastRatio, ratio <= Self.collapseThreshold {
            expanded = false
            changed = false
        }
        lastRatio = ratio
        let corrected = startRatio > 0 && translation <= 0 ? origin + max(0, -finger) : nil
        let extra = max(0, distance - HomeRecentlyPullConfig.travel)
        return Update(pullRatio: ratio, overstretch: 6 * (1 - exp(-extra / 12)),
                      scrollOffset: corrected, expandedChanged: changed)
    }

    static func visualProgress(pullRatio: CGFloat, expansion: CGFloat) -> CGFloat {
        let expansion = min(1, max(0, expansion))
        return min(1, max(0, pullRatio)) * (previewFriction + (1 - previewFriction) * expansion)
    }

    static func captionOpacity(_ progress: CGFloat) -> CGFloat {
        let low = expandThreshold * previewFriction
        let t = min(1, max(0, (progress - low) / (collapseThreshold - low)))
        return t * t * (3 - 2 * t)
    }
}

/// Ограниченная по времени доводка. Раскрытие и возврат скролла имеют свои каналы.
struct HomeRecentlyResponsiveTransition {
    let start: CGFloat
    let target: CGFloat
    let duration: TimeInterval

    func value(at elapsed: TimeInterval) -> CGFloat {
        guard duration > 0, elapsed < duration else { return target }
        let t = CGFloat(max(0, elapsed) / duration)
        // Нормализованная затухающая пружина с точным конечным положением.
        let damping: CGFloat = 0.82
        let frequency: CGFloat = 8
        let root = sqrt(1 - damping * damping)
        func response(_ t: CGFloat) -> CGFloat {
            1 - exp(-damping * frequency * t)
                * (cos(frequency * root * t) + damping / root * sin(frequency * root * t))
        }
        let fraction = response(t) / response(1)
        return start + (target - start) * fraction
    }

    static func openingPulse(at elapsed: TimeInterval) -> CGFloat {
        let t = CGFloat(elapsed / 0.35)
        guard t > 0, t < 1 else { return 0 }
        return sin(.pi * t) * exp(-1.5 * t)
    }
}
