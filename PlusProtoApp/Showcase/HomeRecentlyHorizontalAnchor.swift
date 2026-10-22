import SwiftUI
import UIKit

/// Только базовые ширины из самих карточек; геометрия не возвращается в SwiftUI state.
struct HomeRecentlyWidths: PreferenceKey {
    static let defaultValue: [CGFloat] = []
    static func reduce(value: inout [CGFloat], nextValue: () -> [CGFloat]) { value += nextValue() }
}

/// Сохраняет точку под центром viewport при pull-to. Обычная горизонтальная
/// прокрутка, инерция и распознаватели остаются у нативного ScrollView.
struct HomeRecentlyHorizontalAnchor: UIViewRepresentable {
    let widths: [CGFloat]
    let scale: CGFloat

    func makeUIView(context: Context) -> Probe {
        let view = Probe()
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: Probe, context: Context) {
        view.configure(widths: widths, scale: scale)
    }

    static func dismantleUIView(_ view: Probe, coordinator: ()) { view.detach() }

    final class Probe: UIView {
        private weak var scroll: UIScrollView?
        private var observations: [NSKeyValueObservation] = []
        private var widths: [CGFloat] = []
        private var scale: CGFloat = 1
        private var committedScale: CGFloat?
        private var lastOffset: CGFloat = 0
        private var adjusting = false

        func configure(widths: [CGFloat], scale: CGFloat) {
            if self.widths != widths { committedScale = nil }
            self.widths = widths
            self.scale = scale
            connect()
            reconcile()
        }

        override func didMoveToWindow() { super.didMoveToWindow(); connect() }
        override func layoutSubviews() { super.layoutSubviews(); connect(); reconcile() }

        private func connect() {
            var ancestor = superview
            while let view = ancestor {
                if let candidate = view as? UIScrollView {
                    guard scroll !== candidate else { return }
                    detach()
                    scroll = candidate
                    lastOffset = candidate.contentOffset.x
                    observations = [
                        candidate.observe(\.contentSize, options: [.new]) { [weak self] _, _ in
                            MainActor.assumeIsolated { self?.reconcile() }
                        },
                        candidate.observe(\.contentOffset, options: [.new]) { [weak self] scroll, _ in
                            MainActor.assumeIsolated {
                                guard let self, !self.adjusting,
                                      self.committedScale == self.scale,
                                      self.matchesContentSize(scroll, scale: self.scale) else { return }
                                self.lastOffset = scroll.contentOffset.x
                            }
                        }
                    ]
                    return
                }
                ancestor = view.superview
            }
        }

        private func matchesContentSize(_ scroll: UIScrollView, scale: CGFloat) -> Bool {
            let expected = HomeRecentlyCenterAnchor.width(widths, scale: scale,
                gap: HomeQuickAccessLayout.gap, leading: HomeQuickAccessLayout.leading,
                trailing: ServiceTopNavLayout.side)
            return abs(scroll.contentSize.width - expected) < 1
        }

        private func reconcile() {
            guard !adjusting, let scroll, !widths.isEmpty,
                  matchesContentSize(scroll, scale: scale) else { return }
            guard let oldScale = committedScale else {
                committedScale = scale
                lastOffset = scroll.contentOffset.x
                return
            }
            guard oldScale != scale else { return }
            let offset = HomeRecentlyCenterAnchor.offset(lastOffset, viewport: scroll.bounds.width,
                widths: widths, from: oldScale, to: scale,
                gap: HomeQuickAccessLayout.gap, leading: HomeQuickAccessLayout.leading,
                trailing: ServiceTopNavLayout.side)
            adjusting = true
            committedScale = scale
            lastOffset = offset
            scroll.contentOffset.x = offset
            adjusting = false
        }

        func detach() {
            observations.forEach { $0.invalidate() }
            observations.removeAll()
            scroll = nil
            committedScale = nil
        }
    }
}
