import SwiftUI
import UIKit

/// Все треки полки — переход из блока «Треки» «Моего» (задача пользователя 2026-10-20).
struct CollectionTracksRoute: Hashable {
    let shelf: CollectionStore.Shelf
}

/// Числа экранов «Любимые треки» и «Скачанные треки» — файл «ЯПС · Mobile · Current
/// State», `17686:20011` и `17686:20022` (холст 375: кавер во всю ширину, поля 16).
enum CollectionTracksLayout {
    /// Кавер — квадрат во всю ширину экрана.
    @MainActor static var cover: CGFloat { PlusMetrics.screenWidth }
    /// Название заходит на кавер снизу (`mb-[-79px]` кавера)
    static let titleOverlap: CGFloat = 79
    /// Затемнение кавера — от этой доли высоты до низа (`inset-[64.27%_0_0_0]`)
    static let shadeStart: CGFloat = 0.6427
    static let side: CGFloat = 16
    static let titleToCount: CGFloat = 2
    static let titleToControls: CGFloat = 12
    static let headerBottom: CGFloat = 24
    static let controlsGap: CGFloat = 6
    /// Список — строками `list-item / music` по 64, без зазоров
    static let divider: CGFloat = 0.5

    /// Пороги навбара — как у альбома: подложка — когда кавер почти ушёл под бар,
    /// название — когда под бар уходит заголовок.
    @MainActor static var navBarThresholds: EntityNavBarThresholds {
        let titleTop = cover - titleOverlap
        return EntityNavBarThresholds(
            backgroundStart: titleTop - 122,
            backgroundRamp: 80,
            titleStart: titleTop - 22,
            titleRamp: 90
        )
    }
}

/// «Любимые треки» и «Скачанные треки» — по макетам Музыки (`17686:20011`,
/// `17686:20022`): квадратный кавер полки во всю ширину с затемнением к низу, на нём
/// название (Headline XXL у «Любимых», XL у «Скачанных» — как в макете), число треков
/// и ряд кнопок: «Слушать» и — у «Любимых» — «Скачать все» и «Поделиться». Ниже
/// строки треков полки (`CollectionTrackRow`), тап включает трек с очередью полки.
/// Кавер тянется за оттягом, его верх приклеен к верху экрана.
struct CollectionTracksScreen: View {
    let route: CollectionTracksRoute

    @Environment(CollectionStore.self) private var collection
    @Environment(ActionBarState.self) private var actionBar
    @State private var scrollOffset: CGFloat = 0

    private typealias L = CollectionTracksLayout

    private var shelf: CollectionStore.Shelf { route.shelf }
    private var items: [CollectionItem] { collection.items(.track, on: shelf) }
    private var queue: [MusicNowPlaying] { items.compactMap(\.playable) }

    private var title: String {
        shelf == .favorites ? "Любимые треки" : "Скачанные треки"
    }

    private var coverAsset: String {
        shelf == .favorites ? "mockLikedTracksCover" : "mockDownloadedTracksCover"
    }

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    trackList
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
            // Хром на экране виден — лента едет под ним, как у альбома.
            .contentMargins(
                .bottom,
                PlusChromeMetrics.contentBottomInset + AlbumLayout.bottomClearance,
                for: .scrollContent
            )
            // Кавер начинается от физического верха экрана.
            .ignoresSafeArea(edges: .top)
            .trackNavBarScroll(into: $scrollOffset)

            EntityNavBar(title: title, scrollOffset: scrollOffset, thresholds: L.navBarThresholds)
        }
        .background(Color.surfaceOne.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: Шапка

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            cover
                .padding(.bottom, -L.titleOverlap)

            VStack(alignment: .leading, spacing: L.titleToControls) {
                VStack(alignment: .leading, spacing: L.titleToCount) {
                    Text(title)
                        .plusHeadline(shelf == .favorites ? .xxl : .xl)
                        .foregroundStyle(Color.fillOne)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(CollectionCopy.tracks(items.count))
                        .plusText(.textM, .medium)
                        .foregroundStyle(Color.fillSubtitle)
                }
                controls
            }
            .padding(.horizontal, L.side)
            .padding(.bottom, L.headerBottom)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(CollectionLayout.divider)
                .frame(height: L.divider)
        }
    }

    /// Оттяг вниз — кавер растёт от нижней кромки, верх остаётся у верха экрана.
    private var pull: CGFloat { max(0, -scrollOffset) }

    private var cover: some View {
        Color.clear
            .frame(width: L.cover, height: L.cover)
            .overlay {
                Image(coverAsset)
                    .resizable()
                    .scaledToFill()
            }
            .overlay(alignment: .bottom) {
                CollectionTracksShade()
                    .frame(height: L.cover * (1 - L.shadeStart))
            }
            .clipped()
            .scaleEffect(1 + pull / L.cover, anchor: .bottom)
            .accessibilityHidden(true)
    }

    private var controls: some View {
        HStack(spacing: 0) {
            EntityPrimaryButton(isPlaying: isPlayingShelf, action: togglePlayback)
            Spacer(minLength: 0)
            // У «Скачанных» ряд — только «Слушать»: в макете справа пусто.
            if shelf == .favorites {
                HStack(spacing: L.controlsGap) {
                    PlusButton(
                        type: .secondary,
                        size: .m,
                        accessibilityTitle: isAllDownloaded ? "Удалить из скачанного" : "Скачать все"
                    ) {
                        toggleDownloadAll()
                    } icon: {
                        DownloadGlyph(isDownloaded: isAllDownloaded, box: PlusButtonSize.m.iconBox)
                    }
                    PlusButton(icon: "iconShare", type: .secondary, size: .m, accessibilityTitle: "Поделиться") {
                        ShareState.shared.present(.playlist(title: title, owner: "", cover: .asset(coverAsset)))
                    }
                }
            }
        }
    }

    // MARK: Действия

    /// Играет ли сейчас трек этой полки — тогда «Слушать» — пауза.
    private var isPlayingShelf: Bool {
        guard actionBar.isMiniPlayerVisible, actionBar.isMusicPlaying, let id = actionBar.music?.id else { return false }
        return items.contains { $0.playable?.id == id }
    }

    private func togglePlayback() {
        UIImpactFeedbackGenerator(style: .medium)
            .impactOccurred(intensity: ShowcaseMotion.tapHapticIntensity)
        if isPlayingShelf {
            actionBar.toggleMusicPlayback()
        } else if let first = items.first?.playable {
            actionBar.open(.music(first), queue: queue)
        }
    }

    /// Скачаны все любимые треки — кнопка залита; тап качает недостающие или, если
    /// скачано всё, удаляет их из скачанного.
    private var isAllDownloaded: Bool {
        !items.isEmpty && items.allSatisfy { collection.isDownloaded($0.id) }
    }

    private func toggleDownloadAll() {
        let target = !isAllDownloaded
        for item in items where collection.isDownloaded(item.id) != target {
            collection.setDownloaded(item, target)
        }
    }

    // MARK: Треки

    private var trackList: some View {
        LazyVStack(spacing: 0) {
            ForEach(items) { item in
                CollectionTrackRow(item: item, queue: queue, isFirst: false, isLast: false)
            }
        }
        // Строки съезжают плавно, когда отметку сняли в этом же списке.
        .animation(CollectionMotion.itemsChange, value: items.map(\.id))
    }
}

/// Затемнение кавера к низу — плавный градиент макета (`bottom overlay`): 16 стопов
/// от прозрачного к чёрному.
private struct CollectionTracksShade: View {
    private static let stops: [(location: CGFloat, opacity: Double)] = [
        (0, 0), (0.1179, 0.008), (0.21384, 0.032), (0.2912, 0.07), (0.35336, 0.121),
        (0.4037, 0.181), (0.4456, 0.251), (0.48243, 0.328), (0.51757, 0.411), (0.5544, 0.497),
        (0.5963, 0.585), (0.64664, 0.674), (0.7088, 0.762), (0.78616, 0.846), (0.8821, 0.926),
        (1, 1),
    ]

    var body: some View {
        LinearGradient(
            stops: Self.stops.map { Gradient.Stop(color: Color.black.opacity($0.opacity), location: $0.location) },
            startPoint: .top,
            endPoint: .bottom
        )
        .allowsHitTesting(false)
    }
}
