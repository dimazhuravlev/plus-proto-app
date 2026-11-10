import SwiftUI
import UIKit

/// Figma 637:44022: compact artwork + title, then artwork + a separate caption below.
@MainActor enum HomeRecentlyInlineLayout {
    static var isEnabled: Bool {
        HomePresentationSettings.shared.recentlyInlineLabelsEnabled && !HomePresentationSettings.shared.hideRecently
    }
    static func smooth(_ value: CGFloat) -> CGFloat {
        let t = min(1, max(0, value))
        return t * t * (3 - 2 * t)
    }
    static func sideOpacity(_ p: CGFloat) -> CGFloat { 1 - smooth((p - 0.03) / 0.27) }
    static func bottomOpacity(_ p: CGFloat) -> CGFloat { smooth((p - 0.62) / 0.38) }
    static func compactScale(_ item: HomeRecentlyExperimentItem) -> CGFloat {
        let height: CGFloat = item.kind == .movie ? 23.177 : (item.kind == .book ? 30.331 : 27.629)
        return height / item.mediaHeight
    }
    static func angle(_ item: HomeRecentlyExperimentItem) -> Double { item.kind == .movie ? -9 : -5 }
    static func labelWidth(_ item: HomeRecentlyExperimentItem) -> CGFloat {
        ceil((item.title.replacingOccurrences(of: "\n", with: " ") as NSString)
            .size(withAttributes: [.font: PlusTextSize.textS.uiFont(.medium)]).width)
    }
    static func mediaWidth(_ item: HomeRecentlyExperimentItem, progress: CGFloat) -> CGFloat {
        let scale = compactScale(item) + (1.4 - compactScale(item)) * progress
        let angle = abs(angle(item)) * (1 - progress) * .pi / 180
        return item.width * scale * cos(angle) + item.mediaHeight * scale * sin(angle)
    }
    static func slotWidth(_ item: HomeRecentlyExperimentItem, progress: CGFloat) -> CGFloat {
        let compact = mediaWidth(item, progress: 0) + 4 + labelWidth(item)
        return compact + (item.width * 1.4 - compact) * progress
    }
}

extension HomeQuickAccess {
    var inlineLabelsRow: some View {
        let items = telegramItems
        let p = HomeRecentlyPullState.shared.progress
        let gap = 4 + 4 * p
        let leading = 10 - 2 * p
        let widths = items.map { HomeRecentlyInlineLayout.slotWidth($0, progress: p) }
        return ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: gap) {
                ForEach(items) { item in inlineLabelsCell(item, progress: p) }
            }
            .buttonStyle(.plain)
            .padding(.leading, leading)
            .padding(.trailing, ServiceTopNavLayout.side)
            .background {
                HomeRecentlyInlineAnchor(widths: widths, gap: gap, leading: leading)
            }
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .frame(height: HomeQuickAccessLayout.rowHeight, alignment: .top)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Recently")
        .accessibilityIdentifier("recently-inline-row")
    }

    private func inlineLabelsCell(_ item: HomeRecentlyExperimentItem, progress p: CGFloat) -> some View {
        let mediaWidth = HomeRecentlyInlineLayout.mediaWidth(item, progress: p)
        let slotHeight = 32 + 80 * p
        let width = HomeRecentlyInlineLayout.slotWidth(item, progress: p)
        let scale = HomeRecentlyInlineLayout.compactScale(item) + (1.4 - HomeRecentlyInlineLayout.compactScale(item)) * p
        let sideOpacity = HomeRecentlyInlineLayout.sideOpacity(p)
        let bottomOpacity = HomeRecentlyInlineLayout.bottomOpacity(p)
        return Button {
            if let book = item.book {
                actionBar.read(book)
            } else if let movie = item.movie, item.progress != nil {
                actionBar.watch(movie)
            } else if let route = item.route {
                navigation.open(route)
            } else if item.id == "wave", actionBar.music.map({ MyVibeTracks.isVibe($0.id) }) == true {
                actionBar.toggleMusicPlayback()
            } else {
                actionBar.openMyVibe()
            }
        } label: {
            ZStack(alignment: .topLeading) {
                telegramThumbnail(item)
                    .compositingGroup()
                    .overlay {
                        if item.hasOutline {
                            RoundedRectangle(cornerRadius: item.radius * 1.4, style: .continuous)
                                .strokeBorder(Color.surfaceTwo.opacity(1 - p), lineWidth: 1.2 * 1.4 / scale)
                                .frame(height: item.mediaHeight * 1.4)
                        }
                    }
                    .frame(width: item.width * 1.4, height: 112)
                    .scaleEffect(scale / 1.4)
                    .rotationEffect(.degrees(HomeRecentlyInlineLayout.angle(item) * (1 - p)))
                    .frame(width: mediaWidth, height: slotHeight)

                // Fixed typography in two independent placements; only opacity changes.
                Text(item.title.replacingOccurrences(of: "\n", with: " "))
                    .plusText(.textS, .medium)
                    .foregroundStyle(Color.fillOne)
                    .lineLimit(1)
                    .fixedSize()
                    .frame(height: 16)
                    .offset(x: mediaWidth + 4, y: (slotHeight - 16) / 2)
                    .opacity(sideOpacity)
                    .accessibilityHidden(true)
                    .accessibilityIdentifier("recent-inline-side-\(item.id)")

                FadingCardCaption(title: item.title, width: item.width * 1.4)
                    .frame(width: mediaWidth)
                    .clipped()
                    .offset(y: slotHeight + 4)
                    .opacity(bottomOpacity)
                    .accessibilityHidden(true)
                    .accessibilityIdentifier("recent-inline-bottom-\(item.id)")
            }
            .frame(width: width, height: HomeQuickAccessLayout.rowHeight, alignment: .topLeading)
            .contentShape(Rectangle())
        }
        .accessibilityLabel(item.title)
        .accessibilityIdentifier("recent-inline-\(item.id)")
    }
}

/// Keep the same content point under the viewport centre while the two layouts interpolate.
/// At offset zero the leading edge stays pinned. UIKit owns normal horizontal gestures.
private struct HomeRecentlyInlineAnchor: UIViewRepresentable {
    let widths: [CGFloat]
    let gap: CGFloat
    let leading: CGFloat
    func makeUIView(context: Context) -> Probe {
        let view = Probe(); view.isUserInteractionEnabled = false; return view
    }
    func updateUIView(_ view: Probe, context: Context) {
        view.configure(widths: widths, gap: gap, leading: leading)
    }
    static func dismantleUIView(_ view: Probe, coordinator: ()) { view.disconnect() }
    final class Probe: UIView {
        private weak var scroll: UIScrollView?
        private var requestedExpansion = false
        private var observation: NSKeyValueObservation?
        private var widths: [CGFloat] = []
        private var gap: CGFloat = 0
        private var leading: CGFloat = 0
        private var previous: (widths: [CGFloat], gap: CGFloat, leading: CGFloat)?
        private var changing = false
        func configure(widths: [CGFloat], gap: CGFloat, leading: CGFloat) {
            self.widths = widths; self.gap = gap; self.leading = leading
            connect(); reconcile()
        }
        override func didMoveToWindow() { super.didMoveToWindow(); connect() }
        override func layoutSubviews() { super.layoutSubviews(); reconcile() }
        private func connect() {
            guard scroll == nil else { return }
            var ancestor = superview
            while let view = ancestor {
                if let found = view as? UIScrollView {
                    scroll = found
                    found.panGestureRecognizer.addTarget(self, action: #selector(horizontalPanChanged(_:)))
                    observation = found.observe(\.contentSize) { [weak self] _, _ in
                        MainActor.assumeIsolated { self?.reconcile() }
                    }
                    return
                }
                ancestor = view.superview
            }
        }
        func disconnect() {
            scroll?.panGestureRecognizer.removeTarget(self, action: #selector(horizontalPanChanged(_:)))
            observation = nil
            scroll = nil
            previous = nil
        }
        @objc private func horizontalPanChanged(_ pan: UIPanGestureRecognizer) {
            if pan.state == .began { requestedExpansion = false }
            guard pan.state == .began || pan.state == .changed,
                  !requestedExpansion, HomeRecentlyInlineLayout.isEnabled,
                  !HomeRecentlyPullState.shared.responsiveExpanded else { return }
            let translation = pan.translation(in: scroll)
            // Observe the native horizontal pan without stealing it from scrolling.
            guard abs(translation.x) >= 8, abs(translation.x) > abs(translation.y) else { return }
            requestedExpansion = true
            HomeRecentlyTelegramState.shared.expansionRequests += 1
        }
        private func reconcile() {
            guard !changing, let scroll, !widths.isEmpty else { return }
            let total = leading + widths.reduce(0, +) + CGFloat(widths.count - 1) * gap + ServiceTopNavLayout.side
            guard abs(scroll.contentSize.width - total) < 1 else { return }
            defer { previous = (widths, gap, leading) }
            guard let old = previous, old.widths.count == widths.count,
                  old.widths != widths || old.gap != gap || old.leading != leading else { return }
            let offset = scroll.contentOffset.x
            guard offset > 0.01 else { return }
            let point = offset + scroll.bounds.width / 2
            var oldX = old.leading, newX = leading
            var mapped = point
            for index in widths.indices {
                let oldLength = old.widths[index] + old.gap
                let newLength = widths[index] + gap
                if point <= oldX + oldLength {
                    mapped = newX + (point - oldX) / max(1, oldLength) * newLength
                    break
                }
                oldX += oldLength; newX += newLength
            }
            changing = true
            scroll.contentOffset.x = min(max(0, mapped - scroll.bounds.width / 2), max(0, total - scroll.bounds.width))
            changing = false
        }
    }
}
