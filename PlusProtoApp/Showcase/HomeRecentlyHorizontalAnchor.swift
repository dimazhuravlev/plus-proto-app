import SwiftUI
import UIKit

/// Только базовые ширины из самих карточек; геометрия не возвращается в SwiftUI state.
struct HomeRecentlyWidths: PreferenceKey {
    static let defaultValue: [CGFloat] = []
    static func reduce(value: inout [CGFloat], nextValue: () -> [CGFloat]) { value += nextValue() }
}

/// У нулевого offset держит левый край, после прокрутки — центр viewport при pull-to. Обычная горизонтальная
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
        private var resizeAnchor: (offset: CGFloat, scale: CGFloat)?
        private var adjusting = false

        func configure(widths: [CGFloat], scale: CGFloat) {
            if self.widths != widths {
                committedScale = nil
                resizeAnchor = nil
            }
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
                                      let rendered = self.renderedScale(scroll),
                                      let committed = self.committedScale,
                                      abs(rendered - committed) < 0.0001 else { return }
                                if scroll.isDragging || scroll.isTracking || scroll.isDecelerating {
                                    // Настоящий горизонтальный жест выбирает новую точку.
                                    self.resizeAnchor = nil
                                    self.lastOffset = scroll.contentOffset.x
                                } else if self.resizeAnchor != nil {
                                    self.reconcile()
                                } else {
                                    self.lastOffset = scroll.contentOffset.x
                                }
                            }
                        }
                    ]
                    return
                }
                ancestor = view.superview
            }
        }

        private func renderedScale(_ scroll: UIScrollView) -> CGFloat? {
            HomeRecentlyCenterAnchor.renderedScale(contentWidth: scroll.contentSize.width,
                widths: widths, gap: HomeQuickAccessLayout.gap,
                leading: HomeQuickAccessLayout.leading, trailing: ServiceTopNavLayout.side)
        }

        private func reconcile() {
            guard !adjusting, let scroll, !widths.isEmpty,
                  let rendered = renderedScale(scroll) else { return }
            guard let oldScale = committedScale else {
                // При смене набора ждём его собственную раскладку. Старую ширину
                // контента нельзя интерпретировать как масштаб нового набора.
                let expected = HomeRecentlyCenterAnchor.width(widths, scale: scale,
                    gap: HomeQuickAccessLayout.gap, leading: HomeQuickAccessLayout.leading,
                    trailing: ServiceTopNavLayout.side)
                guard abs(scroll.contentSize.width - expected) < 1 else { return }
                committedScale = rendered
                lastOffset = scroll.contentOffset.x
                return
            }
            guard abs(oldScale - rendered) > 0.0001 || resizeAnchor != nil else { return }
            if resizeAnchor == nil { resizeAnchor = (lastOffset, oldScale) }
            guard let anchor = resizeAnchor else { return }
            let offset = HomeRecentlyCenterAnchor.offset(anchor.offset, viewport: scroll.bounds.width,
                widths: widths, from: anchor.scale, to: rendered,
                gap: HomeQuickAccessLayout.gap, leading: HomeQuickAccessLayout.leading,
                trailing: ServiceTopNavLayout.side)
            adjusting = true
            committedScale = rendered
            lastOffset = offset
            // В той же раскладке, что и изменение ширины, без отдельной анимации
            // contentOffset. Иначе доводка высоты и удержание центра расходятся.
            UIView.performWithoutAnimation {
                if abs(scroll.contentOffset.x - offset) > 0.01 {
                    scroll.setContentOffset(CGPoint(x: offset, y: scroll.contentOffset.y), animated: false)
                }
            }
            if abs(rendered - scale) < 0.0001 { resizeAnchor = nil }
            adjusting = false
        }

        func detach() {
            observations.forEach { $0.invalidate() }
            observations.removeAll()
            scroll = nil
            committedScale = nil
            resizeAnchor = nil
        }
    }
}
