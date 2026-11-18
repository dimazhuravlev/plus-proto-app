import SwiftUI

/// Process-only diagnostics for gesture regression tests; no persisted settings.
struct HomeRecentlyPullVerification: View {
    let offset: CGFloat
    var body: some View {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-debugRecentlyPullVerification") {
            let state = HomeRecentlyPullState.shared
            Text(String(format: "ratio=%.3f expanded=%d compensation=%.3f pull=%.3f offset=%.3f",
                        Double(state.responsivePullRatio), state.responsiveExpanded ? 1 : 0,
                        Double(state.responsiveScrollCompensation), Double(state.responsiveContentPull), Double(offset)))
                .font(.system(size: 7, design: .monospaced))
                .accessibilityIdentifier("recently-pull-verification")
                .allowsHitTesting(false)
        }
        #endif
    }
}
