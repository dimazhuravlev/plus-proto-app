import SwiftUI
import UIKit

/// Нативный скролл расходует первые пункты свайпа на сворачивание Recently.
/// Его delegate и распознаватели SwiftUI остаются владельцами обычной прокрутки.
@MainActor final class HomeRecentlyScrollController {
    private let responsive = HomeRecentlyResponsiveScrollController()
    private weak var scrollView: UIScrollView?
    private var observation: NSKeyValueObservation?

    func attach(_ scroll: UIScrollView) {
        guard scrollView !== scroll else { return }
        detach()
        scrollView = scroll
        responsive.attach(scroll)
        observation = scroll.observe(\.contentOffset, options: [.new]) { [weak self] scroll, _ in
            // Коррекция нужна на главном потоке до отрисовки следующего кадра.
            MainActor.assumeIsolated { self?.responsive.didScroll(scroll) }
        }
    }

    func phaseChanged(_ phase: ScrollPhase) {
        responsive.phaseChanged(phase)
    }

    func expandFromTap() { responsive.expandFromTap() }

    func reset() {
        responsive.reset()
        HomeRecentlyPullState.shared.reset()
    }

    func detach() {
        responsive.detach()
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

/// Разделяет физический ход списка и пороговую доводку миниатюр.
@MainActor private final class HomeRecentlyResponsiveScrollController: NSObject {
    private weak var scroll: UIScrollView?
    private var policy = HomeRecentlyResponsivePullPolicy()
    private var active = false
    private var adjusting = false
    private var ownsPull = false

    func attach(_ scroll: UIScrollView) {
        guard self.scroll !== scroll else { return }
        detach()
        self.scroll = scroll
        scroll.panGestureRecognizer.addTarget(self, action: #selector(panChanged(_:)))
    }

    func expandFromTap() {
        guard let scroll else { return }
        // A programmatic return to the top must never reuse the last pan translation.
        adjusting = true
        active = false
        ownsPull = false
        policy = HomeRecentlyResponsivePullPolicy()
        scroll.setContentOffset(CGPoint(x: scroll.contentOffset.x, y: -scroll.adjustedContentInset.top), animated: false)
        adjusting = false
        let state = HomeRecentlyPullState.shared
        state.updateResponsiveNativePull(0)
        state.setResponsiveExpanded(true)
        state.finishResponsivePull()
        HomeInteractionHaptics.recently(expanded: true)
    }

    private func begin(_ scroll: UIScrollView) {
        guard !active else { return }
        active = true
        let state = HomeRecentlyPullState.shared
        state.interruptResponsiveReturn()
        policy.begin(offset: scroll.contentOffset.y + scroll.adjustedContentInset.top,
                     pullRatio: state.responsivePullRatio, expanded: state.responsiveExpanded)
        ownsPull = state.responsivePullRatio > 0 || (ownsPull && scroll.contentOffset.y + scroll.adjustedContentInset.top < 0)
        if !ownsPull { state.updateResponsiveNativePull(0) }
        HomeInteractionHaptics.prepareRecently()
    }

    @objc private func panChanged(_ pan: UIPanGestureRecognizer) {
        guard let scroll else { return }
        switch pan.state {
        case .began: begin(scroll)
        case .changed: didScroll(scroll)
        case .ended, .cancelled, .failed: release()
        default: break
        }
    }

    func phaseChanged(_ phase: ScrollPhase) {
        guard !adjusting else { return }
        if phase == .tracking || phase == .interacting, let scroll { begin(scroll) }
        if phase == .idle || phase == .decelerating || phase == .animating { release() }
    }

    func didScroll(_ scroll: UIScrollView) {
        guard !adjusting else { return }
        let state = HomeRecentlyPullState.shared
        let offset = scroll.contentOffset.y + scroll.adjustedContentInset.top
        // Нативный возврат наблюдаем и после отпускания, но он не меняет цель.
        if ownsPull {
            state.updateResponsiveNativePull(max(0, -offset))
            if !active, offset >= -0.01 { ownsPull = false }
        }
        guard scroll.isDragging else { return }
        begin(scroll)
        guard let update = policy.move(offset: offset, translation: scroll.panGestureRecognizer.translation(in: scroll).y) else { return }
        ownsPull = ownsPull || update.pullRatio > 0
        adjusting = true
        defer { adjusting = false }
        if ownsPull { state.updateResponsiveNativePull(max(0, -offset)) }
        state.updateResponsivePull(update.pullRatio, overstretch: update.overstretch)
        if let expanded = update.expandedChanged {
            state.setResponsiveExpanded(expanded)
            HomeInteractionHaptics.recently(expanded: expanded)
            HomeInteractionHaptics.prepareRecently()
        }
        if let corrected = update.scrollOffset,
           abs(scroll.contentOffset.y - (corrected - scroll.adjustedContentInset.top)) > 0.01 {
            scroll.contentOffset.y = corrected - scroll.adjustedContentInset.top
            state.updateResponsiveNativePull(max(0, -corrected))
        }
    }

    private func release() {
        guard active else { return }
        active = false
        let state = HomeRecentlyPullState.shared
        guard ownsPull || state.responsivePullRatio > 0 else { return }
        state.finishResponsivePull()
    }

    func reset() {
        active = false
        ownsPull = false
        policy = HomeRecentlyResponsivePullPolicy()
        HomeRecentlyPullState.shared.stopResponsiveSettling()
    }

    func detach() {
        scroll?.panGestureRecognizer.removeTarget(self, action: #selector(panChanged(_:)))
        scroll = nil
        reset()
    }
}
