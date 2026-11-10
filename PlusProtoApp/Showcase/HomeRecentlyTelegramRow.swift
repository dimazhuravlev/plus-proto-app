import SwiftUI

/// Figma 633:41388. Only presentation changes; the existing pull policy owns the gesture.
@MainActor enum HomeRecentlyTelegramLayout {
    static var isEnabled: Bool {
        HomePresentationSettings.shared.recentlyTelegramEnabled && !HomePresentationSettings.shared.recentlyInlineLabelsEnabled && !HomePresentationSettings.shared.hideRecently
    }

    static func compactScale(_ item: HomeRecentlyExperimentItem) -> CGFloat {
        (item.kind == .movie ? 27.692 : 33.23) / item.mediaHeight
    }

    static func trailingProgress(_ progress: CGFloat, index: Int) -> CGFloat {
        let delay = 0.05 + CGFloat(min(max(0, index - 3), 6)) * 0.025
        return min(1, max(0, (progress - delay) / (1 - delay)))
    }

    static func reveal(_ progress: CGFloat, index: Int) -> CGFloat {
        let travel = trailingProgress(progress, index: index)
        let t = min(1, max(0, (travel - 0.12) / 0.58))
        return t * t * (3 - 2 * t)
    }
}

@MainActor @Observable final class HomeRecentlyTelegramState {
    static let shared = HomeRecentlyTelegramState()
    var headerFrame: CGRect = .zero
    var expansionRequests = 0
    var rowOrigin: CGPoint = .zero
    var horizontalOffset: CGFloat = 0

}

extension HomeQuickAccess {
    var telegramItems: [HomeRecentlyExperimentItem] {
        var items = experimentItems
        guard let waveIndex = items.firstIndex(where: { $0.id == "wave" }) else { return items }
        let wave = items.remove(at: waveIndex)
        let firstThree = items.indices.filter { items[$0].canJoinStack }.prefix(3)
        items.insert(wave, at: firstThree.last.map { $0 + 1 } ?? items.endIndex)
        return items
    }

    var telegramRow: some View {
        let items = telegramItems
        let clusterItems = Array(items.filter(\.canJoinStack).prefix(3))
        let clusterIDs = Set(clusterItems.map(\.id))
        let progress = HomeRecentlyPullState.shared.progress
        return ScrollView(.horizontal) {
            HStack(spacing: HomeQuickAccessLayout.gap) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    telegramCell(item, cluster: clusterIDs.contains(item.id), index: index)
                        .zIndex(clusterIDs.contains(item.id) ? Double(10 + index) : 0)
                }
            }
            .buttonStyle(.plain)
            .padding(.leading, HomeQuickAccessLayout.leading)
            .padding(.trailing, ServiceTopNavLayout.side)
            .frame(height: HomeQuickAccessLayout.rowHeight, alignment: .top)
            .backgroundPreferenceValue(HomeRecentlyWidths.self) { widths in
                HomeRecentlyHorizontalAnchor(widths: widths, scale: HomeQuickAccessLayout.scale)
            }
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .scrollDisabled(progress < 0.999)
        .allowsHitTesting(progress >= 0.999)
        .accessibilityHidden(progress < 0.999)
        .frame(height: HomeQuickAccessLayout.rowHeight, alignment: .top)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Быстрый доступ")
        .accessibilityIdentifier("recently-telegram-row")
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: {
            HomeRecentlyTelegramState.shared.rowOrigin = $0.origin
        }
        .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.x } action: { _, offset in
            HomeRecentlyTelegramState.shared.horizontalOffset = offset
        }
    }

    private func telegramCell(_ item: HomeRecentlyExperimentItem, cluster: Bool, index: Int) -> some View {
        let progress = HomeRecentlyPullState.shared.progress
        let reveal = cluster ? 1 : HomeRecentlyTelegramLayout.reveal(progress, index: index)
        return Button {
            if let book = item.book {
                actionBar.read(book)
            } else if let movie = item.movie, item.progress != nil {
                actionBar.watch(movie)
            } else if let route = item.route {
                navigation.open(route)
            } else if item.id == "wave",
                      actionBar.music.map({ MyVibeTracks.isVibe($0.id) }) == true {
                actionBar.toggleMusicPlayback()
            } else {
                actionBar.openMyVibe()
            }
        } label: {
            captioned(item.title, width: item.width) {
                // Artwork is rendered once above the header and feed, for every item.
                Color.clear.frame(width: item.width * HomeQuickAccessLayout.scale,
                                  height: HomeQuickAccessLayout.height)

            }
            .opacity(reveal)
            .visualEffect { view, geometry in
                let amount = cluster || UIAccessibility.isReduceMotionEnabled ? 0 :
                    1 - HomeRecentlyTelegramLayout.trailingProgress(progress, index: index)
                return view.offset(x: (HomeRecentlyTelegramState.shared.headerFrame.maxX - 8 - geometry.frame(in: .global).midX) * amount)
            }
        }
        .accessibilityLabel(item.title)
        .accessibilityIdentifier("recent-telegram-\(item.id)")
    }

    @ViewBuilder func telegramThumbnail(_ item: HomeRecentlyExperimentItem) -> some View {
        if item.id == "wave" {
            vibeButton.allowsHitTesting(false)
        } else {
            experimentThumbnail(item)
        }
    }


    var telegramOverlay: some View {
        let items = telegramItems
        return GeometryReader { proxy in
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                telegramFloatingThumbnail(item, index: index, items: items,
                                          origin: proxy.frame(in: .global).origin)
            }
        }
        .clipped()
        .transaction { $0.animation = nil }
    }

    private func telegramFloatingThumbnail(_ item: HomeRecentlyExperimentItem, index: Int,
                                           items: [HomeRecentlyExperimentItem], origin: CGPoint) -> some View {
        let progress = HomeRecentlyPullState.shared.progress
        let isCluster = index < 3
        let cluster = Array(items.prefix(3))
        let p = isCluster ? progress : HomeRecentlyTelegramLayout.trailingProgress(progress, index: index)
        let state = HomeRecentlyTelegramState.shared
        let header = state.headerFrame
        let compact = HomeRecentlyTelegramLayout.compactScale(item)
        let clusterWidth = cluster.reduce(CGFloat.zero) { $0 + $1.width * HomeRecentlyTelegramLayout.compactScale($1) } - CGFloat(max(0, cluster.count - 1)) * 4
        let fit = min(1, header.width / max(1, clusterWidth))
        let preceding = cluster.prefix(index).reduce(CGFloat.zero) { $0 + $1.width * HomeRecentlyTelegramLayout.compactScale($1) - 4 }
        let sourceX = isCluster ? header.minX + (preceding + item.width * compact / 2) * fit : header.maxX - 8
        let expandedScale = HomeQuickAccessLayout.expandedHeight / 80
        let precedingExpanded = items.prefix(index).reduce(CGFloat.zero) { $0 + $1.width * expandedScale + HomeQuickAccessLayout.gap }
        let targetX = state.rowOrigin.x + HomeQuickAccessLayout.leading + precedingExpanded
            + item.width * expandedScale / 2 - state.horizontalOffset
        let targetY = state.rowOrigin.y + HomeQuickAccessLayout.expandedHeight / 2
        let reduceMotion = UIAccessibility.isReduceMotionEnabled
        let amount = reduceMotion ? (p < 0.5 ? 1.0 : 0.0) : 1 - p
        let scale = compact * fit / expandedScale * amount + (1 - amount)
        let ring = isCluster ? max(0, 1 - p / 0.65) : 0
        let alpha = isCluster ? 1 : HomeRecentlyTelegramLayout.reveal(progress, index: index)
        return telegramThumbnail(item)
            .compositingGroup()
            .overlay {
                RoundedRectangle(cornerRadius: item.radius * expandedScale, style: .continuous)
                    .strokeBorder(.white.opacity(ring), lineWidth: 1.385 / max(scale, 0.01))
                    .frame(height: item.mediaHeight * expandedScale)
            }
            .frame(width: item.width * expandedScale, height: HomeQuickAccessLayout.expandedHeight)
            .scaleEffect(scale)
            .rotationEffect(.degrees(isCluster ? (index % 2 == 0 ? -5 : 5) * amount : 0))
            .position(x: targetX + (sourceX - targetX) * amount - origin.x,
                      y: targetY + (header.midY - targetY) * amount - origin.y)
            .opacity(header.width == 0
                     ? 0 : alpha * (reduceMotion ? abs(2 * p - 1) : 1))
            .zIndex(isCluster ? Double(100 + index) : Double(100 - index))
    }
}
