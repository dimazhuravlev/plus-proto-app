import Foundation

/// Непрерывное раскрытие и расход хода жеста до начала прокрутки страницы.
struct HomeRecentlyPullPolicy {
    enum Phase { case idle, tracking, interacting, settling }
    enum Feedback { case expanded, collapsed }
    struct Update {
        var progress: CGFloat
        /// Нормализованный offset после расхода движения на сворачивание.
        var scrollOffset: CGFloat?
        var feedback: Feedback?
    }

    private(set) var phase: Phase = .idle
    private var eligible = false
    private var consumesScroll = false
    private var closedDuringGesture = false

    mutating func begin(at offset: CGFloat, progress: CGFloat) {
        phase = .tracking
        eligible = offset <= HomeRecentlyPullConfig.topTolerance
        consumesScroll = progress > 0
        closedDuringGesture = false
    }

    mutating func setPhase(_ next: Phase, offset: CGFloat, progress: CGFloat) {
        if next == .tracking || (next == .interacting && phase != .tracking && phase != .interacting) {
            begin(at: offset, progress: progress)
        }
        phase = next
        if next == .idle || next == .settling { eligible = false }
    }

    mutating func move(to offset: CGFloat, progress: CGFloat) -> Update? {
        guard phase == .interacting || (phase == .settling && consumesScroll) else { return nil }
        if consumesScroll && offset > 0 {
            return consume(offset, progress: progress)
        }
        if offset > HomeRecentlyPullConfig.topTolerance { eligible = false }
        guard phase == .interacting, eligible, !closedDuringGesture, offset < 0 else { return nil }
        // Возврат пружины после нового оттяга не считается закрывающим свайпом.
        consumesScroll = false
        let next = min(1, -offset / HomeRecentlyPullConfig.travel)
        guard next > progress else { return nil }
        return Update(progress: next, feedback: next == 1 ? .expanded : nil)
    }

    /// Явное движение пальца в контент закрывает режим даже после отскока
    /// или при начале жеста чуть ниже нуля. Открытие по-прежнему только от верха.
    mutating func consume(_ travel: CGFloat, progress: CGFloat) -> Update? {
        guard travel > 0, progress > 0 else { return nil }
        let consumed = min(travel, progress * HomeRecentlyPullConfig.travel)
        let remainder = max(0, progress - consumed / HomeRecentlyPullConfig.travel)
        let remaining: CGFloat = remainder < 0.000001 ? 0 : remainder
        consumesScroll = remaining > 0
        eligible = false
        closedDuringGesture = true
        return Update(progress: remaining, scrollOffset: max(0, travel - consumed),
                      feedback: remaining == 0 ? .collapsed : nil)
    }

    mutating func reset() { self = Self() }
}

enum HomeRecentlyPullConfig {
    static let topTolerance: CGFloat = 2
    static let travel: CGFloat = 64
}
