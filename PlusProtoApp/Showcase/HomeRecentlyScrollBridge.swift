import SwiftUI
import UIKit

/// Нативный скролл расходует первые пункты свайпа на сворачивание Recently.
/// Его delegate и распознаватели SwiftUI остаются владельцами обычной прокрутки.
@MainActor final class HomeRecentlyScrollController {
    private var policy = HomeRecentlyPullPolicy()
    private weak var scrollView: UIScrollView?
    private var observation: NSKeyValueObservation?
    private var isAdjustingOffset = false
    private var collapseTravel: CGFloat?
    private var consumedTravel: CGFloat = 0
    private var collapseOrigin: CGFloat = 0
    private var gestureActive = false
    private var didCollapse = false

    private func beginGesture(at offset: CGFloat) {
        guard !gestureActive else { return }
        gestureActive = true
        let progress = HomeRecentlyPullState.shared.progress
        collapseTravel = progress > 0 ? progress * HomeRecentlyPullConfig.travel : nil
        collapseOrigin = max(0, offset)
        consumedTravel = 0
        didCollapse = false
        policy.begin(at: offset, progress: progress)
    }

    func attach(_ scroll: UIScrollView) {
        guard scrollView !== scroll else { return }
        detach()
        scrollView = scroll
        observation = scroll.observe(\.contentOffset, options: [.new]) { [weak self] scroll, _ in
            // UIScrollView меняет геометрию на главном потоке; синхронная коррекция
            // нужна до отрисовки кадра, иначе страница сначала дёрнется вверх.
            MainActor.assumeIsolated { self?.didScroll(scroll) }
        }
    }

    func phaseChanged(_ phase: ScrollPhase, offset: CGFloat) {
        let next: HomeRecentlyPullPolicy.Phase
        switch phase {
        case .idle: next = .idle
        case .tracking: next = .tracking
        case .interacting: next = .interacting
        default: next = .settling
        }
        if next == .tracking || next == .interacting {
            beginGesture(at: offset)
        } else if next == .idle || next == .settling {
            collapseTravel = nil
            gestureActive = false
        }
        if next == .idle, didCollapse, HomeRecentlyPullState.shared.progress > 0 {
            // Короткий закрывающий свайп без инерции тоже завершает режим,
            // а не оставляет ленту навсегда в промежуточном размере.
            let progress = HomeRecentlyPullState.shared.progress
            _ = policy.consume(progress * HomeRecentlyPullConfig.travel, progress: progress)
            withAnimation(UIAccessibility.isReduceMotionEnabled ? nil : .smooth(duration: 0.2)) {
                HomeRecentlyPullState.shared.progress = 0
            }
            HomeInteractionHaptics.action()
        }
        policy.setPhase(next, offset: offset, progress: HomeRecentlyPullState.shared.progress)
        if next == .interacting, let scrollView { didScroll(scrollView) }
    }

    private func didScroll(_ scroll: UIScrollView) {
        guard !isAdjustingOffset else { return }
        let offset = scroll.contentOffset.y + scroll.adjustedContentInset.top
        if scroll.isDragging { beginGesture(at: offset) }
        // В первом кадре UIKit уже двигается, а SwiftUI ещё может сообщать tracking.
        if policy.phase == .tracking && scroll.isDragging {
            policy.setPhase(.interacting, offset: offset, progress: HomeRecentlyPullState.shared.progress)
        }
        let update: HomeRecentlyPullPolicy.Update?
        let correctedOffset: CGFloat?
        let forward = max(0, -scroll.panGestureRecognizer.translation(in: scroll).y)
        if let travel = collapseTravel, policy.phase == .interacting,
           forward > 0 || consumedTravel > 0 {
            // Считаем ход пальца, а не повторные contentOffset после нашей коррекции.
            // После закрытия остаток того же свайпа сразу передаётся странице.
            let consumed = min(forward, travel)
            let delta = max(0, consumed - consumedTravel)
            consumedTravel = max(consumedTravel, consumed)
            if delta > 0 { didCollapse = true }
            update = policy.consume(delta, progress: HomeRecentlyPullState.shared.progress)
            correctedOffset = collapseOrigin + max(0, forward - travel)
        } else {
            let origin = didCollapse ? collapseOrigin : 0
            update = policy.move(to: offset - origin, progress: HomeRecentlyPullState.shared.progress)
            correctedOffset = update?.scrollOffset.map { $0 + origin }
        }
        guard update != nil || correctedOffset != nil else { return }
        isAdjustingOffset = true
        defer { isAdjustingOffset = false }
        if let corrected = correctedOffset {
            scroll.contentOffset.y = corrected - scroll.adjustedContentInset.top
        }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        if let update {
            withTransaction(transaction) { HomeRecentlyPullState.shared.progress = update.progress }
            if update.feedback != nil { HomeInteractionHaptics.action() }
        }
    }

    func reset() {
        policy.reset()
        collapseTravel = nil
        consumedTravel = 0
        collapseOrigin = 0
        gestureActive = false
        didCollapse = false
        HomeRecentlyPullState.shared.progress = 0
    }

    func detach() {
        observation?.invalidate()
        observation = nil
        scrollView = nil
    }
}

/// Ставится внутри контента вертикального ScrollView, ищет только его предка.
struct HomeRecentlyScrollBridge: UIViewRepresentable {
    let controller: HomeRecentlyScrollController

    func makeUIView(context: Context) -> Probe {
        let view = Probe()
        view.isUserInteractionEnabled = false
        view.controller = controller
        return view
    }

    func updateUIView(_ view: Probe, context: Context) {
        if view.controller !== controller {
            view.controller?.detach()
            view.controller = controller
        }
        view.connect()
    }
    static func dismantleUIView(_ view: Probe, coordinator: ()) { view.controller?.detach() }

    final class Probe: UIView {
        weak var controller: HomeRecentlyScrollController?
        override func didMoveToWindow() { super.didMoveToWindow(); connect() }
        override func layoutSubviews() { super.layoutSubviews(); connect() }

        func connect() {
            var ancestor = superview
            while let view = ancestor {
                if let scroll = view as? UIScrollView {
                    controller?.attach(scroll)
                    return
                }
                ancestor = view.superview
            }
        }
    }
}
