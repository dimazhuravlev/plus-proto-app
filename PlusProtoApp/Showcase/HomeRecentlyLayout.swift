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
    private(set) var responsiveStretch: CGFloat = 0
    @ObservationIgnored private var responsiveExpansion: CGFloat = 0
    @ObservationIgnored private var responsiveExpansionTransition: HomeRecentlyResponsiveTransition?
    @ObservationIgnored private var responsiveExpansionStart: CFTimeInterval = 0
    @ObservationIgnored private var responsiveReturn: HomeRecentlyResponsiveTransition?
    @ObservationIgnored private var responsiveReturnStart: CFTimeInterval = 0
    @ObservationIgnored private var responsiveReturnStretch: CGFloat = 0
    @ObservationIgnored private var responsivePulseStart: CFTimeInterval?
    func reset() {
        stopResponsiveSettling()
        responsivePullRatio = 0
        responsiveExpanded = false
        responsiveExpansion = 0
        responsiveNativePull = 0
        responsivePulse = 0
        responsiveStretch = 0
        progress = 0
        labelOpacity = 0
    }


    /// Touch-down берёт текущий ход скролла, не обрывая доводку миниатюр.
    func interruptResponsiveReturn() {
        responsiveReturn = nil
        responsiveReturnStretch = 0
    }

    func updateResponsivePull(_ ratio: CGFloat, overstretch: CGFloat) {
        responsivePullRatio = min(1, max(0, ratio))
        responsiveStretch = overstretch
        refreshResponsiveGeometry()
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
        let duration = expanded ? 0.35 : 0.25
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
            responsiveStretch = 0
            refreshResponsiveGeometry()
            return
        }
        responsiveReturn = .init(start: responsivePullRatio, target: responsiveExpanded ? 1 : 0,
                                 duration: responsiveExpanded ? 0.28 : 0.22)
        responsiveReturnStart = CACurrentMediaTime()
        responsiveReturnStretch = responsiveStretch
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
            responsiveStretch = responsiveReturnStretch * max(0, 1 - CGFloat(elapsed / transition.duration))
            if elapsed >= transition.duration { responsiveReturn = nil; responsiveStretch = 0 }
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
            progress = HomeRecentlyResponsivePullPolicy.visualProgress(pullRatio: responsivePullRatio, expansion: responsiveExpansion)
            labelOpacity = HomeRecentlyResponsivePullPolicy.captionOpacity(progress)
        }
    }


}

/// Верхняя лента «Главной», Figma NS7mKDEaIwxlgTdds2h5s6 / 328:43468.
/// Миниатюры имеют постоянный размер, остаток ряда доступен горизонтальным скроллом.
enum HomeQuickAccessLayout {
    static let expandedHeight: CGFloat = 112
    static let captionHeight: CGFloat = 32
    static let captionGap: CGFloat = 4
    static var captionSpace: CGFloat { captionHeight + captionGap }
    static let collapsedHeight: CGFloat = 64
    @MainActor static var height: CGFloat {
        collapsedHeight + (expandedHeight - collapsedHeight) * HomeRecentlyPullState.shared.progress
    }
    @MainActor static var labelProgress: CGFloat {
        HomeRecentlyPullState.shared.labelOpacity
    }
    @MainActor static var scale: CGFloat { height / 80 }
    @MainActor static var mediaPulse: CGFloat {
        HomeRecentlyPullState.shared.responsivePulse
    }
    @MainActor static var mediaStretch: CGFloat {
        HomeRecentlyPullState.shared.responsiveStretch
    }
    static let gap: CGFloat = 8
    static let leading: CGFloat = 8
    @MainActor static var top: CGFloat {
        HomePresentationSettings.shared.headerGapEnabled ? CGFloat(HomePresentationSettings.shared.headerGap) : 16
    }
    @MainActor static var bottom: CGFloat {
        let settings = HomePresentationSettings.shared
        if settings.heroGapEnabled { return CGFloat(settings.heroGap) }
        return 16
    }
    @MainActor static var captionReservation: CGFloat { HomeRecentlyPullState.shared.labelOpacity }
    @MainActor static var rowHeight: CGFloat {
        // Скролл освобождает место по ходу оттяга; миниатюры догоняют его доводкой.
        max(height + captionSpace * captionReservation,
            collapsedHeight + HomeRecentlyPullConfig.travel * HomeRecentlyPullState.shared.responsivePullRatio)
    }
    @MainActor static var occupiedHeight: CGFloat { top + rowHeight + bottom }
    static let feedback = Animation.smooth(duration: 0.3)
    static let progressColor = Color(red: 216 / 255, green: 141 / 255, blue: 252 / 255)
}


@MainActor private final class HomeRecentlyFrameTarget: NSObject {
    private weak var state: HomeRecentlyPullState?
    init(state: HomeRecentlyPullState) { self.state = state }
    @objc func frame(_ link: CADisplayLink) { state?.advanceResponsiveSpring(link.timestamp) }
}
