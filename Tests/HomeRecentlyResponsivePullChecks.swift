import Foundation

@main enum HomeRecentlyResponsivePullChecks {
    static func close(_ actual: CGFloat, _ expected: CGFloat) {
        precondition(abs(actual - expected) < 0.000001, "Expected \(expected), got \(actual)")
    }
    static func main() {
        close(HomeRecentlyResponsivePullPolicy.reservationProgress(0), 0)
        close(HomeRecentlyResponsivePullPolicy.reservationProgress(0.72), 1)
        close(HomeRecentlyResponsivePullPolicy.reservationProgress(1), 1)
        for ratio: CGFloat in [0.1, 0.5, 0.68, 0.72, 1] {
            let height = 68 + 80 * HomeRecentlyResponsivePullPolicy.reservationProgress(ratio)
            // Even while the thumbnail spring advances, the same finger position owns the same row height.
            for step in 0...100 {
                let media = 68 + 44 * HomeRecentlyResponsivePullPolicy.visualProgress(pullRatio: ratio, expansion: CGFloat(step) / 100)
                precondition(media <= height + 0.000001)
            }
        }
        let travel: CGFloat = 64
        let gain = HomeRecentlyResponsivePullPolicy.pullGain
        var pull = HomeRecentlyResponsivePullPolicy()
        pull.begin(offset: 0, pullRatio: 0, expanded: false)
        let first = pull.move(offset: -0.1, translation: 0.1 / gain)!
        precondition(first.pullRatio > 0 && first.expandedChanged == nil)
        let before = pull.move(offset: -40, translation: 0.71 * travel / gain)!
        close(before.pullRatio, 0.71)
        precondition(before.expandedChanged == nil && !pull.expanded)
        let prepare = HomeRecentlyResponsivePullPolicy.visualProgress(pullRatio: before.pullRatio, expansion: 0)
        close(prepare, 0.71 * 0.15)
        let crossing = pull.move(offset: -47, translation: 0.73 * travel / gain)!
        precondition(crossing.expandedChanged == true && pull.expanded, "Commit happens while moving, before release")
        let held = pull.move(offset: -47, translation: 0.73 * travel / gain)!
        precondition(held.expandedChanged == nil, "Holding does not restart the catch-up animation")
        let opening = HomeRecentlyResponsiveTransition(start: 0, target: 1, duration: 0.35)
        let halfway = HomeRecentlyResponsivePullPolicy.visualProgress(pullRatio: held.pullRatio, expansion: opening.value(at: 0.175))
        let completed = HomeRecentlyResponsivePullPolicy.visualProgress(pullRatio: held.pullRatio, expansion: opening.value(at: 0.35))
        precondition(halfway > prepare && completed > prepare + 0.5, "Thumbnails catch up under a stationary finger")
        close(completed, 0.73)
        precondition(pull.move(offset: -45, translation: 0.70 * travel / gain)!.expandedChanged == nil)
        precondition(pull.expanded, "Hysteresis preserves the expanded state")
        precondition(pull.move(offset: -42, translation: 0.67 * travel / gain)!.expandedChanged == false)
        precondition(pull.move(offset: -42, translation: 0.67 * travel / gain)!.expandedChanged == nil)
        precondition(pull.move(offset: -48, translation: 0.74 * travel / gain)!.expandedChanged == true)

        for start: CGFloat in [31.999, 32, 150] {
            var boundary = HomeRecentlyResponsivePullPolicy()
            boundary.begin(offset: start, pullRatio: 0, expanded: false)
            precondition((boundary.move(offset: -64, translation: 200) != nil) == (start < 32))
        }
        var boundary = HomeRecentlyResponsivePullPolicy()
        boundary.begin(offset: 0, pullRatio: 0, expanded: false)
        precondition(boundary.move(offset: 32, translation: -32) == nil)
        precondition(boundary.move(offset: -64, translation: 200) == nil)

        // Pull open and reverse before lifting the finger. UIKit can cross the
        // activation boundary in one fast callback while the panel is still open.
        var rapid = HomeRecentlyResponsivePullPolicy()
        rapid.begin(offset: 0, pullRatio: 0, expanded: false)
        precondition(rapid.move(offset: -70, translation: 140)!.expandedChanged == true)
        guard let rapidFold = rapid.move(offset: 60, translation: -40) else {
            fatalError("An acquired pull must keep updating across the activation boundary")
        }
        close(rapidFold.pullRatio, 0)
        precondition(rapidFold.expandedChanged == false)
        precondition(rapid.move(offset: -70, translation: 140)!.expandedChanged == true,
                     "Repeated reversals within one gesture must not freeze the panel")

        var closing = HomeRecentlyResponsivePullPolicy()
        closing.begin(offset: 12, pullRatio: 1, expanded: true)
        let partial = closing.move(offset: 30, translation: -32 / gain)!
        close(partial.pullRatio, 0.5); close(partial.scrollOffset!, 12)
        precondition(partial.expandedChanged == false)
        let remainder = closing.move(offset: 60, translation: -(64 / gain + 20))!
        close(remainder.pullRatio, 0); close(remainder.scrollOffset!, 32)
        let reverse = closing.move(offset: 12, translation: -8 / gain)!
        close(reverse.pullRatio, 0.875)
        precondition(reverse.expandedChanged == true)
        // The same physical motion has the same gain in both directions.
        var symmetrical = HomeRecentlyResponsivePullPolicy()
        symmetrical.begin(offset: 0, pullRatio: 0.5, expanded: false)
        let down = symmetrical.move(offset: -10, translation: 10)!.pullRatio
        let up = symmetrical.move(offset: 10, translation: -10)!.pullRatio
        close(down - 0.5, 0.5 - up)

        var over = HomeRecentlyResponsivePullPolicy()
        over.begin(offset: 0, pullRatio: 1, expanded: true)
        let small = over.move(offset: -10, translation: 20)!
        let large = over.move(offset: -100, translation: 2000)!
        precondition(small.contentPull > 8 && large.contentPull < 120 && small.contentPull < large.contentPull)
        close(large.pullRatio, 1)
        close(small.pullRatio, 1)
        close(HomeRecentlyResponsivePullPolicy.visualProgress(pullRatio: large.pullRatio, expansion: 1), 1)
        let released = HomeRecentlyNativeReturn(contentPull: large.contentPull, nativePull: 180)
        close(released.value(nativePull: 180), large.contentPull)
        close(released.value(nativePull: 0), 0)
        close(released.value(nativePull: -1), 0)
        // No timer may replace the scroll view's velocity-dependent spring.
        for native: CGFloat in [180, 160, 115, 64, 24, 5, 0.3] {
            close(released.value(nativePull: native) / large.contentPull, native / 180)
        }
        close(HomeRecentlyNativeReturn(contentPull: 20, nativePull: 0).value(nativePull: 0), 0)
        let returning = released.value(nativePull: 115)
        var regrab = HomeRecentlyResponsivePullPolicy()
        regrab.begin(offset: -returning, pullRatio: 1, expanded: true, contentPull: returning)
        let stationary = regrab.move(offset: -returning, translation: 0)!
        close(stationary.contentPull, returning)
        precondition(stationary.scrollOffset == nil, "Regrab must not reset native bounce mid-overpull")
        let less = regrab.move(offset: -returning, translation: -10)!
        precondition(less.contentPull > 0 && less.contentPull < returning)
        close(less.pullRatio, 1)
        let folded = regrab.move(offset: 0, translation: -1000)!
        close(folded.contentPull, 0)
        close(folded.pullRatio, 0)
        precondition(folded.expandedChanged == false)
        var continuous = HomeRecentlyResponsivePullPolicy()
        continuous.begin(offset: 0, pullRatio: 0, expanded: false)
        let full = continuous.move(offset: -64, translation: travel / gain)!
        close(full.pullRatio, 1); close(full.contentPull, 0)
        let extra = continuous.move(offset: -80, translation: travel / gain + 20)!
        close(extra.contentPull, small.contentPull)
        close(extra.pullRatio, 1)
        for progress: CGFloat in [0, 0.108, 0.3, 0.68, 1] {
            let alpha = HomeRecentlyResponsivePullPolicy.captionOpacity(progress)
            precondition(alpha >= 0 && alpha <= 1)
        }
        close(HomeRecentlyResponsivePullPolicy.captionOpacity(0.108), 0)
        close(HomeRecentlyResponsivePullPolicy.captionOpacity(0.68), 1)
        close(opening.value(at: 0), 0)
        close(opening.value(at: 0.35), 1)
        close(opening.value(at: 1), 1)
        let interrupted = opening.value(at: 0.1)
        let reversed = HomeRecentlyResponsiveTransition(start: interrupted, target: 0, duration: 0.25)
        close(reversed.value(at: 0), interrupted)
        close(reversed.value(at: 0.25), 0)
        close(HomeRecentlyResponsiveTransition.openingPulse(at: 0), 0)
        close(HomeRecentlyResponsiveTransition.openingPulse(at: 0.35), 0)
        precondition(HomeRecentlyResponsiveTransition.openingPulse(at: 0.1) > 0)
        print("PASS: in-gesture commit, held-finger catch-up, 72/68 hysteresis, symmetric resistance, reversal, residual scrolling, bounded overpull, retargeting and captions")
    }
}
