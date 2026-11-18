import SwiftUI
import UIKit

/// Только состояние показа; жесты не записываются в настройки девменю.
@MainActor @Observable final class HomeRecentlyPullState {
    static let shared = HomeRecentlyPullState()
    private(set) var progress: CGFloat = 0
    private(set) var labelOpacity: CGFloat = 0
    @ObservationIgnored private var responsiveDisplayLink: CADisplayLink?
    private(set) var responsivePullRatio: CGFloat = 0
    private(set) var responsiveExpanded = false
    private(set) var responsiveNativePull: CGFloat = 0
    private(set) var responsivePulse: CGFloat = 0
    private(set) var responsiveContentPull: CGFloat = 0
    /// Scrolling spent on folding the panel, applied visually until touch-up.
    private(set) var responsiveScrollCompensation: CGFloat = 0
    @ObservationIgnored private var responsiveExpansion: CGFloat = 0
    @ObservationIgnored private var responsiveExpansionTransition: HomeRecentlyResponsiveTransition?
    @ObservationIgnored private var responsiveExpansionStart: CFTimeInterval = 0
    @ObservationIgnored private var responsiveReturn: HomeRecentlyResponsiveTransition?
    @ObservationIgnored private var responsiveReturnStart: CFTimeInterval = 0
    @ObservationIgnored private var responsivePulseStart: CFTimeInterval?
    func reset() {
        stopResponsiveSettling()
        responsivePullRatio = 0
        responsiveExpanded = false
        responsiveExpansion = 0
        responsiveNativePull = 0
        responsivePulse = 0
        responsiveContentPull = 0
        responsiveScrollCompensation = 0
        progress = 0
        labelOpacity = 0
    }


    /// Touch-down берёт текущий ход скролла, не обрывая доводку миниатюр.
    func interruptResponsiveReturn() {
        responsiveReturn = nil
    }

    func updateResponsivePull(_ ratio: CGFloat, contentPull: CGFloat) {
        responsivePullRatio = min(1, max(0, ratio))
        responsiveContentPull = contentPull
        refreshResponsiveGeometry()
    }

    func updateResponsiveContentPull(_ value: CGFloat) {
        var instant = Transaction(); instant.disablesAnimations = true
        withTransaction(instant) { responsiveContentPull = max(0, value) }
    }

    func updateResponsiveScrollCompensation(_ value: CGFloat) {
        var instant = Transaction(); instant.disablesAnimations = true
        withTransaction(instant) { responsiveScrollCompensation = max(0, value) }
    }

    func updateResponsiveNativePull(_ value: CGFloat) {
        let value = max(0, value)
        guard abs(responsiveNativePull - value) > 0.001 else { return }
        var instant = Transaction(); instant.disablesAnimations = true
        withTransaction(instant) { responsiveNativePull = value }
    }

    func setResponsiveExpanded(_ expanded: Bool) {
        guard responsiveExpanded != expanded else { return }
        responsiveExpanded = expanded
        responsivePulse = 0
        let duration = expanded ? ((HomeRecentlyTelegramLayout.isEnabled) ? 0.42 : 0.35) : 0.25
        if UIAccessibility.isReduceMotionEnabled {
            responsiveExpansion = expanded ? 1 : 0
            refreshResponsiveGeometry()
            return
        }
        responsiveExpansionTransition = .init(start: responsiveExpansion, target: expanded ? 1 : 0, duration: duration)
        responsiveExpansionStart = CACurrentMediaTime()
        responsivePulseStart = expanded ? responsiveExpansionStart : nil
        startResponsiveFrames()
    }

    func finishResponsivePull() {
        if UIAccessibility.isReduceMotionEnabled {
            responsivePullRatio = responsiveExpanded ? 1 : 0
            refreshResponsiveGeometry()
            return
        }
        responsiveReturn = .init(start: responsivePullRatio, target: responsiveExpanded ? 1 : 0,
                                 duration: responsiveExpanded ? 0.28 : 0.22)
        responsiveReturnStart = CACurrentMediaTime()
        startResponsiveFrames()
    }

    func stopResponsiveSettling() {
        responsiveDisplayLink?.invalidate()
        responsiveDisplayLink = nil
        responsiveExpansionTransition = nil
        responsiveReturn = nil
        responsivePulseStart = nil
        responsivePulse = 0
    }

    private func startResponsiveFrames() {
        guard responsiveDisplayLink == nil else { return }
        let link = CADisplayLink(target: HomeRecentlyFrameTarget(state: self), selector: #selector(HomeRecentlyFrameTarget.frame(_:)))
        let fps = Float(UIScreen.main.maximumFramesPerSecond)
        link.preferredFrameRateRange = CAFrameRateRange(minimum: min(60, fps), maximum: fps, preferred: fps)
        responsiveDisplayLink = link
        link.add(to: .main, forMode: .common)
    }

    fileprivate func advanceResponsiveSpring(_ timestamp: CFTimeInterval) {
        if let transition = responsiveExpansionTransition {
            let elapsed = timestamp - responsiveExpansionStart
            responsiveExpansion = transition.value(at: elapsed)
            if elapsed >= transition.duration { responsiveExpansionTransition = nil }
        }
        if let transition = responsiveReturn {
            let elapsed = timestamp - responsiveReturnStart
            responsivePullRatio = min(1, max(0, transition.value(at: elapsed)))
            if elapsed >= transition.duration { responsiveReturn = nil }
        }
        if let start = responsivePulseStart {
            responsivePulse = HomeRecentlyResponsiveTransition.openingPulse(at: timestamp - start)
            if timestamp - start >= 0.35 { responsivePulseStart = nil; responsivePulse = 0 }
        }
        refreshResponsiveGeometry()
        if responsiveExpansionTransition == nil, responsiveReturn == nil, responsivePulseStart == nil {
            responsiveDisplayLink?.invalidate()
            responsiveDisplayLink = nil
        }
    }

    private func refreshResponsiveGeometry() {
        var instant = Transaction(); instant.disablesAnimations = true
        withTransaction(instant) {
            if HomeRecentlyTelegramLayout.isEnabled {
                progress = 0.45 * min(1, max(0, responsivePullRatio)) + 0.55 * min(1, max(0, responsiveExpansion))
            } else {
                progress = HomeRecentlyResponsivePullPolicy.visualProgress(pullRatio: responsivePullRatio, expansion: responsiveExpansion)
            }
            if HomeRecentlyTelegramLayout.isEnabled {
                let t = min(1, max(0, (progress - 0.72) / 0.28))
                labelOpacity = t * t * (3 - 2 * t)
            } else {
                labelOpacity = HomeRecentlyResponsivePullPolicy.captionOpacity(progress)
            }
        }
    }


}

/// Верхняя лента «Главной», Figma NS7mKDEaIwxlgTdds2h5s6 / 328:43468.
/// Миниатюры имеют постоянный размер, остаток ряда доступен горизонтальным скроллом.
enum HomeQuickAccessLayout {
    @MainActor static var isStandard: Bool {
        HomePresentationSettings.shared.recentlyMode == .standard
    }
    @MainActor static var isVisible: Bool {
        HomePresentationSettings.shared.recentlyMode != .hidden && (!isStandard || !RecentlyConsumed.shared.items.isEmpty)
    }
    @MainActor static var cornerRadius: CGFloat { 6 + 6 * HomeRecentlyPullState.shared.progress }

    // Все миниатюры масштабируются от одной высоты: 68 pt в покое, 112 pt после раскрытия.
    static let mediaBaseHeight: CGFloat = 80
    // Фильмы и сериалы — 3:2: 102 × 68 pt и 168 × 112 pt.
    static let movieWidth: CGFloat = mediaBaseHeight * 3 / 2
    @MainActor static var layoutProgress: CGFloat {
        HomeRecentlyResponsivePullPolicy.reservationProgress(HomeRecentlyPullState.shared.responsivePullRatio)
    }
    static let expandedHeight: CGFloat = 112
    static let captionHeight: CGFloat = 32
    static let captionGap: CGFloat = 4
    static var captionSpace: CGFloat { captionHeight + captionGap }
    static let collapsedHeight: CGFloat = 68
    @MainActor static var height: CGFloat {
        if HomeRecentlyTelegramLayout.isEnabled { return expandedHeight }
        return collapsedHeight + (expandedHeight - collapsedHeight) * HomeRecentlyPullState.shared.progress
    }
    @MainActor static var labelProgress: CGFloat {
        HomeRecentlyPullState.shared.labelOpacity
    }
    @MainActor static var scale: CGFloat { height / mediaBaseHeight }
    @MainActor static var mediaPulse: CGFloat {
        HomeRecentlyTelegramLayout.isEnabled ? 0 : HomeRecentlyPullState.shared.responsivePulse
    }
    static let gap: CGFloat = 8
    static let leading: CGFloat = 8
    @MainActor static var top: CGFloat {
        let base = HomePresentationSettings.shared.headerGapEnabled ? CGFloat(HomePresentationSettings.shared.headerGap) : 16
        return base
    }
    @MainActor static var bottom: CGFloat {
        let settings = HomePresentationSettings.shared
        let base = settings.heroGapEnabled ? CGFloat(settings.heroGap) : 16
        return base
    }
    @MainActor static var captionReservation: CGFloat { HomeRecentlyPullState.shared.labelOpacity }
    @MainActor static var rowHeight: CGFloat {
        if HomeRecentlyTelegramLayout.isEnabled {
            return (expandedHeight + captionSpace) * layoutProgress
        }
        return standardRowHeight
    }
    @MainActor static var standardRowHeight: CGFloat {
        // Скролл освобождает место по ходу оттяга; миниатюры догоняют его доводкой.
        collapsedHeight + (expandedHeight + captionSpace - collapsedHeight) * layoutProgress
    }
    @MainActor static var occupiedHeight: CGFloat { isVisible ? top + rowHeight + bottom : 0 }
    static let feedback = Animation.smooth(duration: 0.3)
    static var progressColor: Color { Color(paletteRed: 216 / 255, green: 141 / 255, blue: 252 / 255) }
}


@MainActor private final class HomeRecentlyFrameTarget: NSObject {
    private weak var state: HomeRecentlyPullState?
    init(state: HomeRecentlyPullState) { self.state = state }
    @objc func frame(_ link: CADisplayLink) { state?.advanceResponsiveSpring(link.timestamp) }
}
