import SwiftUI

/// Transient presentation only; never writes pull gestures into dev preferences.
@MainActor @Observable final class HomeRecentlyPullState {
    static let shared = HomeRecentlyPullState()
    var progress: CGFloat = 0
}

/// Верхняя лента «Главной», Figma NS7mKDEaIwxlgTdds2h5s6 / 328:43468.
/// Миниатюры имеют постоянный размер, остаток ряда доступен горизонтальным скроллом.
enum HomeQuickAccessLayout {
    @MainActor static var height: CGFloat {
        let settings = HomePresentationSettings.shared
        let collapsed = min(CGFloat(settings.recentlyHeight), 96)
        return collapsed + (96 - collapsed) * HomeRecentlyPullState.shared.progress
    }
    @MainActor static var labelProgress: CGFloat {
        HomeRecentlyPullState.shared.progress
    }
    @MainActor static var scale: CGFloat { height / 80 }
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
    @MainActor static var rowHeight: CGFloat { height + 20 * labelProgress }
    @MainActor static var occupiedHeight: CGFloat { top + rowHeight + bottom }
    static let feedback = Animation.smooth(duration: 0.3)
    static let progressColor = Color(red: 216 / 255, green: 141 / 255, blue: 252 / 255)
}
