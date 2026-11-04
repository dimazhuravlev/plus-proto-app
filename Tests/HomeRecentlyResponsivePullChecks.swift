import Foundation

@main enum HomeRecentlyResponsivePullChecks {
    static func close(_ actual: CGFloat, _ expected: CGFloat) {
        precondition(abs(actual - expected) < 0.000001, "Expected \(expected), got \(actual)")
    }
    static func main() {
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
        precondition(small.overstretch > 0 && large.overstretch < 6 && small.overstretch < large.overstretch)
        close(large.pullRatio, 1)
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
