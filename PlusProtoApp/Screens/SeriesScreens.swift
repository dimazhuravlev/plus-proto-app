import SwiftUI
import UIKit

// MARK: - Кадры и запуск серий

/// Кадры серий: свой кадр серии из Кинопоиска, иначе — случайный кадр самого тайтла
/// (правка пользователя 2026-10-20). Случайный, но один и тот же от запуска к запуску:
/// колода кадров тайтла перемешивается затравкой от id сериала, и соседние серии
/// не повторяют кадр, пока колоды хватает.
enum SeriesStills {
    static func assign(_ episodes: [SeriesEpisode], titleStills: [URL], seed: Int) -> [SeriesEpisode.ID: URL] {
        var rng = SeededGenerator(seed: UInt64(truncatingIfNeeded: seed))
        var deck: [URL] = []
        var previous: URL?
        var result: [SeriesEpisode.ID: URL] = [:]
        for episode in episodes {
            if let still = episode.still {
                result[episode.id] = still
                previous = still
                continue
            }
            guard !titleStills.isEmpty else { continue }
            if deck.isEmpty {
                deck = titleStills.shuffled(using: &rng)
                // Стык колод: новая не начинается тем кадром, которым кончилась прежняя.
                if deck.count > 1, deck.first == previous { deck.swapAt(0, 1) }
            }
            let still = deck.removeFirst()
            result[episode.id] = still
            previous = still
        }
        return result
    }
}

/// Серия с кадром, которым её показывают (свой или кадр тайтла, `SeriesStills`).
struct EpisodeWithStill {
    let episode: SeriesEpisode
    let still: ArtworkSource?
}

extension MovieInProgress {
    /// Серия в киноплеер — те же поля, что у «Смотреть» экрана тайтла; кадр чипа бара
    /// и карточек ПП — кадр серии.
    static func playing(_ episode: SeriesEpisode, of series: EntityRef, details: MovieDetails?, still: ArtworkSource?) -> MovieInProgress {
        MovieInProgress(
            id: series.id,
            still: still ?? details?.backdrop.map { ArtworkSource.remote($0) } ?? series.artwork,
            title: details?.title ?? series.title,
            subtitle: details?.playerSubtitle,
            runtime: episode.runtime,
            poster: (details?.coverPoster ?? details?.poster).map { ArtworkSource.remote($0) },
            season: episode.season,
            episode: episode.number
        )
    }
}

extension WatchHistory.Entry {
    /// Запись истории — про эту серию: прогресс и остаток показываются только у неё.
    func isAbout(_ episode: SeriesEpisode) -> Bool {
        movie.season == episode.season && movie.episode == episode.number
    }
}

extension CollectionItem {
    /// Тайтл в «Моё» с экрана тайтла и его серий: постер — карусели «Любимого», кадр
    /// и хронометраж — карточке «Скачанного кино». Моковый тайтл без id Кинопоиска
    /// в коллекцию не ложится.
    static func title(_ entity: EntityRef, details: MovieDetails) -> CollectionItem? {
        guard entity.kinopoiskID != nil else { return nil }
        return .movie(
            EntityRef(id: entity.id, title: details.title, subtitle: "", artwork: entity.artwork),
            poster: details.poster.map { ArtworkSource.remote($0) },
            year: details.year,
            still: details.backdrop.map { ArtworkSource.remote($0) },
            runtime: details.isSeries ? nil : details.runtime,
            isSeries: details.isSeries
        )
    }
}

/// Тап по серии — сразу киноплеер с этой серией: у серии своего экрана нет.
@MainActor
enum SeriesPlayback {
    static func play(_ episode: SeriesEpisode, of series: EntityRef, details: MovieDetails?, still: ArtworkSource?, actionBar: ActionBarState) {
        UIImpactFeedbackGenerator(style: .medium)
            .impactOccurred(intensity: ShowcaseMotion.tapHapticIntensity)
        actionBar.open(.movie(.playing(episode, of: series, details: details, still: still)))
    }
}

// MARK: - Карусель экрана тайтла

/// «Сезоны и Эпизоды» экрана сериала — `carousel / Movies` `2052:10621`: шапка 52
/// с шевроном (все серии — `SeriesEpisodesScreen`), лента карточек 252 с полями 16:
/// целая и половина следующей. Карточка — `PPMovieCard.large`: кадр серии, время
/// (у начатой — остаток и таймлайн), подпись «Сезон 1, серия 1». Тап — серия в плеере.
///
/// Серии едут запросом (`SeriesCatalog`) — до ответа стоит скелетон той же геометрии;
/// серий нет (ключей нет, квота, пустой ответ) — нет и секции.
struct MovieEpisodesSection: View {
    let entity: EntityRef
    let details: MovieDetails

    @Environment(ActionBarState.self) private var actionBar
    @Environment(AppNavigationState.self) private var navigation
    @Environment(\.entityZoomNamespace) private var zoomNamespace

    private enum Layout {
        static let skeletonCards = 2
        /// Поле под лентой — до описания ниже (правка пользователя 2026-10-20: +24)
        static let bottomPadding: CGFloat = 24
    }

    private var series: EntityRef {
        EntityRef(id: entity.id, title: details.title, subtitle: "", artwork: entity.artwork)
    }

    private var rowHeight: CGFloat { PPMovieCard.rowHeight(.large, lines: 1) }

    /// Id — из деталей, а не из маршрута: детали и есть тайтл экрана (под `-debugMovieId`
    /// маршрут — карточка, с которой открыли).
    var body: some View {
        content(SeriesCatalog.shared.status(details.id))
            .task(id: details.id) { await SeriesCatalog.shared.load(details.id, episodeLength: details.episodeLength) }
    }

    @ViewBuilder
    private func content(_ status: SeriesCatalog.Status?) -> some View {
        switch status {
        case .loaded(let info):
            VStack(spacing: 0) {
                header
                carousel(info)
            }
            .padding(.bottom, Layout.bottomPadding)
        case .failed:
            EmptyView()
        case .loading, nil:
            VStack(spacing: 0) {
                EntitySectionHeaderSkeleton(lineHeight: ServiceCarouselLayout.headerLine)
                skeleton
            }
            .padding(.bottom, Layout.bottomPadding)
        }
    }

    private var header: some View {
        let route = EntityRoute.episodes(series)
        return Button { navigation.open(route) } label: {
            EntitySectionHeader(title: "Сезоны и Эпизоды", lineHeight: ServiceCarouselLayout.headerLine)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        // Экран всех серий разворачивается из шапки — зуму слоя нужен источник,
        // иначе он вырос бы из центра экрана.
        .modifier(ZoomSource(route: route, namespace: zoomNamespace))
    }

    private func carousel(_ info: SeriesInfo) -> some View {
        let episodes = info.episodes
        let stills = SeriesStills.assign(episodes, titleStills: details.stills, seed: details.id)
        let entry = actionBar.watchHistory.entries.first { $0.id == entity.id }
        return ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: ServiceCarouselLayout.cardGap) {
                ForEach(episodes) { episode in
                    let still = stills[episode.id].map { ArtworkSource.remote($0) }
                    let current = entry?.isAbout(episode) == true ? entry : nil
                    Button {
                        SeriesPlayback.play(episode, of: series, details: details, still: still, actionBar: actionBar)
                    } label: {
                        PPMovieCard(
                            still: still,
                            title: episode.seasonTitle,
                            size: .large,
                            progress: current?.progress,
                            remaining: current?.remaining ?? episode.runtime
                        )
                    }
                    .buttonStyle(PressScaleButtonStyle(pressedScale: PressMotion.cardScale))
                    .accessibilityLabel(episode.seasonTitle)
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned)
        .contentMargins(.horizontal, ServiceCarouselLayout.side, for: .scrollContent)
        .frame(height: rowHeight)
    }

    /// Ряд скелетонов шире экрана — оверлеем на распорке во всю ширину: своим размером
    /// он раздвигал ленту экрана, и весь скелетон тайтла разъезжался в стороны.
    private var skeleton: some View {
        let width = PPMovieCard.width(.large)
        return Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: rowHeight)
            .overlay(alignment: .topLeading) {
                HStack(alignment: .top, spacing: ServiceCarouselLayout.cardGap) {
                    ForEach(0..<Layout.skeletonCards, id: \.self) { _ in
                        VStack(alignment: .leading, spacing: PPMovieCard.Layout.captionGap) {
                            RoundedRectangle(cornerRadius: PPMovieCard.radius(.large), style: .continuous)
                                .fill(PlusSkeleton.fill)
                                .frame(width: width, height: PPMovieCard.stillHeight(width: width))
                            SkeletonBar(width: width / 2, height: EntitySectionLayout.skeletonBar)
                                .frame(height: CinemaLayout.captionLine)
                        }
                    }
                }
                .padding(.horizontal, ServiceCarouselLayout.side)
                .fixedSize()
            }
            .clipped()
            .accessibilityHidden(true)
    }
}

/// Источник зума, если namespace есть: секции не положено падать вне слоя.
private struct ZoomSource: ViewModifier {
    let route: EntityRoute
    let namespace: Namespace.ID?

    func body(content: Content) -> some View {
        if let namespace {
            content.matchedTransitionSource(id: route, in: namespace)
        } else {
            content
        }
    }
}

// MARK: - Строка с кадром

/// Числа строк с кадром — строка полного списка коллекции (`CollectionListLayout`):
/// кадр 16:9 высотой обложки строки, скругление и низ кадра — как у карточки коллекции
/// (`2859:75998`).
enum StillRowLayout {
    static var stillHeight: CGFloat { CollectionListLayout.cover }
    static var stillWidth: CGFloat { stillHeight * 480 / 270 }
    /// Заголовок сезона над его строками — серым, как в «Загрузках» Кинопоиска
    static let seasonTop: CGFloat = EntitySectionLayout.headerTop
    static let seasonBottom: CGFloat = CollectionListLayout.rowPadding
}

/// Строка списка с кадром — «Скачанное кино», скачанные серии, все серии: кадр со временем
/// и таймлайном, название в две строки, серым — размер или хронометраж, справа — свой
/// контрол. Разделители и просадка — как у строк полного списка коллекции.
struct StillListRow<Trailing: View>: View {
    let still: ArtworkSource?
    let title: String
    var detail: String?
    var progress: Double?
    var remaining: TimeInterval?
    let isFirst: Bool
    let action: () -> Void
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: CollectionListLayout.textGap) {
            stillView

            VStack(alignment: .leading, spacing: EntitySectionLayout.textStackGap) {
                Text(title)
                    .plusText(.textM, .medium)
                    .foregroundStyle(Color.fillOne)
                    .lineLimit(CollectionListLayout.titleLines)
                if let detail {
                    Text(detail)
                        .plusText(.textM, .medium)
                        .foregroundStyle(Color.fillSubtitle)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            trailing()
        }
        .padding(.horizontal, CollectionListLayout.side)
        .padding(.vertical, CollectionListLayout.rowPadding)
        .frame(minHeight: StillRowLayout.stillHeight + 2 * CollectionListLayout.rowPadding)
        .contentShape(.rect)
        // Проседает строка, а черты стоят: просевшая черта короче соседних и съезжает.
        .pressScale(PressMotion.rowScale)
        .overlay(alignment: .bottom) { divider }
        .overlay(alignment: .top) { if isFirst { divider } }
        .onTapGesture(perform: action)
    }

    private var stillView: some View {
        let shape = RoundedRectangle(cornerRadius: PPMovieCard.Layout.compactRadius, style: .continuous)
        return PlusSkeleton.fill
            .overlay { if let still { SkeletonArtwork(source: still) } }
            .overlay(alignment: .bottom) {
                PPMovieStripFooter(width: StillRowLayout.stillWidth, progress: progress, remaining: remaining)
            }
            .frame(width: StillRowLayout.stillWidth, height: StillRowLayout.stillHeight)
            .clipShape(shape)
            .coverBorder(shape)
    }

    private var divider: some View {
        Rectangle()
            .fill(CollectionLayout.divider)
            .frame(height: 0.5)
            .padding(.horizontal, CollectionListLayout.side)
    }
}

/// Серый заголовок сезона над его строками — «1 сезон, 2 серии».
struct SeriesSeasonHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .plusText(.textM, .medium)
            .foregroundStyle(Color.fillSubtitle)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, CollectionListLayout.side)
            .padding(.top, StillRowLayout.seasonTop)
            .padding(.bottom, StillRowLayout.seasonBottom)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Все серии

/// Все серии сериала — по сезонам: под навбаром закреплённые чипсы сезонов с числом
/// серий («1 сезон, 6 серий», задача пользователя 2026-10-20), под ними серии
/// выбранного сезона строкой каждая: кадр, «1. Заезд», хронометраж и «Скачать» справа
/// (загрузка по сериям, решение пользователя 2026-10-20). Открывается на сезоне, который
/// смотрят, иначе на первом; смена сезона — старый список гаснет, новый проявляется.
/// Тап по строке — серия в плеере. Вход — шеврон «Сезонов и Эпизодов» экрана тайтла
/// (в его слое) и «Загрузить другие серии» скачанного сериала (в стеке «Моего»).
struct SeriesEpisodesScreen: View {
    let entity: EntityRef

    @State private var store = MovieDetailsStore()
    @State private var scrollOffset: CGFloat = 0
    @State private var scrollPosition = ScrollPosition(edge: .top)
    /// Выбранный чипс и показанный сезон; `nil` — стартовый (`defaultSeason`).
    @State private var season: Int?
    @State private var shownSeason: Int?
    @State private var listOpacity: Double = 1
    @State private var swap: Task<Void, Never>?
    @Environment(CollectionStore.self) private var collection
    @Environment(ActionBarState.self) private var actionBar

    private enum Layout {
        static let skeletonRows = 6
    }

    var body: some View {
        ZStack {
            Color.surfaceOne.ignoresSafeArea()

            ScrollView {
                content
            }
            .scrollIndicators(.hidden)
            .contentMargins(.top, EntityNavBarGeometry.barHeight, for: .scrollContent)
            .scrollPosition($scrollPosition)
            .trackNavBarScroll(into: $scrollOffset)
        }
        .overlay(alignment: .top) {
            EntityNavBar(title: entity.title, scrollOffset: scrollOffset, thresholds: PinnedFilterChipsLayout.navThresholds)
        }
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: season) { _, selected in swapSeason(to: selected) }
        // Идемпотентно: под полноэкранным плеером экран уходит с окна и задача стартует снова.
        .task {
            await store.load(entity)
            guard let id = entity.kinopoiskID else { return }
            await SeriesCatalog.shared.load(id, episodeLength: store.details?.episodeLength)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch entity.kinopoiskID.flatMap({ SeriesCatalog.shared.status($0) }) {
        case .loaded(let info):
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                Section {
                    list(info, season: shownSeason ?? defaultSeason(info))
                        .padding(.top, CollectionListLayout.listTop)
                        // Другой сезон — новый список целиком, смена — прозрачностью.
                        .id(shownSeason)
                        .opacity(listOpacity)
                } header: {
                    PinnedFilterChips(
                        options: info.seasons.map(\.number),
                        selection: Binding(get: { season ?? defaultSeason(info) }, set: { season = $0 }),
                        title: { chipTitle($0, info: info) },
                        scrollOffset: scrollOffset
                    )
                }
            }
        case .failed:
            Text("Здесь пока ничего нет")
                .plusText(.textM, .medium)
                .foregroundStyle(Color.fillSubtitle)
                .frame(maxWidth: .infinity)
                .padding(.top, CollectionListLayout.listTop + StillRowLayout.seasonTop)
        case .loading, nil:
            VStack(spacing: 0) {
                FilterChipsSkeleton()
                skeleton
                    .padding(.top, CollectionListLayout.listTop)
            }
        }
    }

    /// Сезон, который смотрят (запись истории), иначе первый.
    private func defaultSeason(_ info: SeriesInfo) -> Int {
        let watched = actionBar.watchHistory.entries.first { $0.id == entity.id }?.movie.season
        if let watched, info.seasons.contains(where: { $0.number == watched }) { return watched }
        return info.seasons.first?.number ?? 1
    }

    /// «1 сезон, 6 серий» — тем же текстом, что заголовки сезонов скачанных серий.
    private func chipTitle(_ number: Int, info: SeriesInfo) -> String {
        let count = info.seasons.first { $0.number == number }?.episodes.count ?? 0
        return "\(number) сезон, \(SeriesCopy.episodes(count))"
    }

    /// Старый сезон гаснет, в паузе подменяется и уезжает к началу, новый проявляется.
    /// Быстрые нажатия подряд прерывают незаконченную смену: показан последний выбранный.
    private func swapSeason(to selected: Int?) {
        swap?.cancel()
        guard selected != shownSeason else {
            withAnimation(CollectionListMotion.fadeIn) { listOpacity = 1 }
            return
        }
        swap = Task { @MainActor in
            withAnimation(CollectionListMotion.fadeOut) { listOpacity = 0 }
            try? await Task.sleep(for: CollectionListMotion.fadeOutDuration)
            guard !Task.isCancelled else { return }
            shownSeason = selected
            scrollPosition.scrollTo(edge: .top)
            withAnimation(CollectionListMotion.fadeIn) { listOpacity = 1 }
        }
    }

    private func list(_ info: SeriesInfo, season number: Int) -> some View {
        let details = store.details
        // Раздача кадров — по всем сериям сериала, как в карусели тайтла: кадр серии
        // один и тот же, откуда её ни открой.
        let stills = SeriesStills.assign(info.episodes, titleStills: details?.stills ?? [], seed: entity.kinopoiskID ?? 0)
        let entry = actionBar.watchHistory.entries.first { $0.id == entity.id }
        let item = details.flatMap { CollectionItem.title(entity, details: $0) }
        let episodes = info.seasons.first { $0.number == number }?.episodes ?? []
        return LazyVStack(spacing: 0) {
            ForEach(episodes) { episode in
                let still = stills[episode.id].map { ArtworkSource.remote($0) }
                let current = entry?.isAbout(episode) == true ? entry : nil
                StillListRow(
                    still: still,
                    title: episode.listTitle,
                    detail: episode.runtime.map(PPMovieCard.remainingText),
                    progress: current?.progress,
                    remaining: current?.remaining ?? episode.runtime,
                    isFirst: episode.id == episodes.first?.id
                ) {
                    SeriesPlayback.play(episode, of: entity, details: details, still: still, actionBar: actionBar)
                } trailing: {
                    downloadButton(episode, item: item, still: still)
                }
            }
        }
    }

    /// «Скачать» серии — круг plain M под отрицательным отступом: в раскладке — глиф.
    /// Пока детали тайтла не доехали, записи коллекции нет — кнопка только откликается.
    private func downloadButton(_ episode: SeriesEpisode, item: CollectionItem?, still: ArtworkSource?) -> some View {
        let isDownloaded = item.map { collection.isEpisodeDownloaded($0.id, episode.id) } ?? false
        return PlusButton(
            type: .plain,
            size: .m,
            accessibilityTitle: isDownloaded ? "Удалить из скачанного" : "Скачать"
        ) {
            guard let item else { return }
            collection.toggleEpisode(item, episode, still: still)
        } icon: {
            DownloadGlyph(isDownloaded: isDownloaded, box: PlusButtonSize.m.iconBox, offColor: Color.fillFive)
        }
        .padding(-TrackMoreLabel.hitInset)
    }

    private var skeleton: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(0..<Layout.skeletonRows, id: \.self) { _ in
                HStack(spacing: CollectionListLayout.textGap) {
                    RoundedRectangle(cornerRadius: PPMovieCard.Layout.compactRadius, style: .continuous)
                        .fill(PlusSkeleton.fill)
                        .frame(width: StillRowLayout.stillWidth, height: StillRowLayout.stillHeight)
                    SkeletonBar(width: EntitySectionLayout.skeletonHeaderWidth, height: EntitySectionLayout.skeletonBar)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, CollectionListLayout.side)
                .padding(.vertical, CollectionListLayout.rowPadding)
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Скачанные серии

/// Скачанные серии сериала — тап по сериалу в «Скачанном кино». `seriesID` — id записи
/// коллекции (`movie:kp-…`).
struct SeriesDownloadsRoute: Hashable {
    let seriesID: String
}

/// Скачанные серии сериала — как в «Загрузках» Кинопоиска: навбар с названием сериала,
/// по сезонам серый заголовок «1 сезон, 2 серии» и строки серий (кадр со временем,
/// «1. Заезд», размер), ниже — «Загрузить другие серии»: все серии сериала. Тап по строке
/// — серия в плеере, «ещё» — удалить из скачанного.
struct SeriesDownloadsScreen: View {
    let route: SeriesDownloadsRoute

    @State private var scrollOffset: CGFloat = 0
    @Environment(CollectionStore.self) private var collection
    @Environment(ActionBarState.self) private var actionBar
    @Environment(AppNavigationState.self) private var navigation
    @Environment(\.stackZoomNamespace) private var zoom

    private var item: CollectionItem? { collection.item(route.seriesID) }

    private struct Season: Identifiable {
        let number: Int
        let episodes: [DownloadedEpisode]
        var id: Int { number }
    }

    private var seasons: [Season] {
        let episodes = (item?.episodes ?? []).sorted {
            ($0.episode.season, $0.episode.number) < ($1.episode.season, $1.episode.number)
        }
        return Dictionary(grouping: episodes, by: \.episode.season)
            .map { Season(number: $0.key, episodes: $0.value) }
            .sorted { $0.number < $1.number }
    }

    var body: some View {
        ZStack {
            Color.surfaceOne.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    LazyVStack(spacing: 0) {
                        ForEach(seasons) { season in
                            SeriesSeasonHeader(title: "\(season.number) сезон, \(SeriesCopy.episodes(season.episodes.count))")
                            ForEach(season.episodes) { downloaded in
                                row(downloaded, isFirst: downloaded.id == season.episodes.first?.id)
                            }
                        }
                    }
                    // Строки съезжают плавно, когда серию удалили в этом же списке.
                    .animation(CollectionMotion.itemsChange, value: item?.episodes?.map(\.id))

                    if seasons.isEmpty {
                        Text("Здесь пока ничего нет")
                            .plusText(.textM, .medium)
                            .foregroundStyle(Color.fillSubtitle)
                            .padding(.top, StillRowLayout.seasonTop)
                    }
                    moreButton
                        .padding(.top, StillRowLayout.seasonTop)
                }
                .padding(.top, CollectionListLayout.listTop)
            }
            .scrollIndicators(.hidden)
            .contentMargins(.top, EntityNavBarGeometry.barHeight, for: .scrollContent)
            .trackNavBarScroll(into: $scrollOffset)
        }
        .overlay(alignment: .top) {
            EntityNavBar(title: item?.title ?? "", scrollOffset: scrollOffset, thresholds: CollectionListScreen.navThresholds)
        }
        .toolbar(.hidden, for: .navigationBar)
        // Названия и длина серий — из каталога (один запрос на сериал за всё время).
        .task {
            guard let id = item?.kinopoiskID else { return }
            await SeriesCatalog.shared.load(id, episodeLength: nil)
        }
    }

    private func row(_ downloaded: DownloadedEpisode, isFirst: Bool) -> some View {
        let episode = item.map { CollectionDownloadMeta.fresh(downloaded.episode, of: $0) } ?? downloaded.episode
        let entry = actionBar.watchHistory.entries.first { $0.id == item?.route?.ref.id }
        let current = entry?.isAbout(episode) == true ? entry : nil
        return StillListRow(
            still: downloaded.still,
            title: episode.listTitle,
            detail: DownloadSize.text(episode.runtime),
            progress: current?.progress,
            remaining: current?.remaining ?? episode.runtime,
            isFirst: isFirst
        ) {
            guard let series = item?.route?.ref else { return }
            SeriesPlayback.play(episode, of: series, details: nil, still: downloaded.still, actionBar: actionBar)
        } trailing: {
            Menu {
                deleteButton(episode)
            } label: {
                // Вид `PlusButton` plain M; круг 40 — под отрицательным отступом.
                TrackMoreLabel()
                    .pressScale(PressMotion.buttonScale)
            }
            .simultaneousGesture(TapGesture().onEnded { PlayerHaptics.tap() })
            .padding(-TrackMoreLabel.hitInset)
            .accessibilityLabel("Ещё")
        }
        .contextMenu { deleteButton(episode) }
    }

    private func deleteButton(_ episode: SeriesEpisode) -> some View {
        Button {
            guard let item else { return }
            collection.toggleEpisode(item, episode, still: nil)
        } label: {
            Label("Удалить из скачанного", systemImage: "trash")
        }
    }

    /// «Загрузить другие серии» — все серии сериала; экран разворачивается из кнопки.
    @ViewBuilder
    private var moreButton: some View {
        if let series = item?.route?.ref {
            let target = EntityRoute.episodes(series)
            PlusButton("Загрузить другие серии", icon: "iconDownload", type: .secondary, size: .m) {
                navigation.open(target)
            }
            .modifier(ZoomSource(route: target, namespace: zoom))
        }
    }
}

// MARK: - Скачанное кино

/// Подписи скачанного: у фильма — размер («1,24 ГБ»), у сериала — серии и их размер
/// («2 серии, 1,2 ГБ»), как в «Загрузках» Кинопоиска.
@MainActor
enum CollectionDownloadMeta {
    static func text(_ item: CollectionItem) -> String? {
        if let episodes = item.episodes, item.isSeries == true {
            let count = SeriesCopy.episodes(episodes.count)
            guard let size = DownloadSize.text(episodes: episodes.map { fresh($0.episode, of: item) }) else { return count }
            return "\(count), \(size)"
        }
        return DownloadSize.text(item.runtime)
    }

    /// Серия, скачанная до того, как доехали сезоны, — без названия и длины: свежее
    /// берётся из каталога серий.
    static func fresh(_ episode: SeriesEpisode, of item: CollectionItem) -> SeriesEpisode {
        item.kinopoiskID.flatMap { SeriesCatalog.shared.info($0)?.episode(episode.season, episode.number) } ?? episode
    }
}

/// Скачанный фильм или сериал: фильм тапом сразу играет (досмотреть скачанное),
/// сериал открывает свои скачанные серии.
@MainActor
enum CollectionDownloadAction {
    static func open(_ item: CollectionItem, actionBar: ActionBarState, navigation: AppNavigationState) {
        if item.isSeries == true {
            navigation.push(SeriesDownloadsRoute(seriesID: item.id))
            return
        }
        guard let ref = item.route?.ref else { return }
        UIImpactFeedbackGenerator(style: .medium)
            .impactOccurred(intensity: ShowcaseMotion.tapHapticIntensity)
        actionBar.open(.movie(MovieInProgress(
            id: ref.id,
            still: item.still ?? item.artwork ?? ref.artwork,
            title: item.title,
            runtime: item.runtime,
            poster: item.artwork
        )))
    }

    /// Прогресс и остаток фильма — из истории просмотра; у сериала времени на кадре нет:
    /// серий несколько.
    static func progress(_ item: CollectionItem, history: WatchHistory) -> (progress: Double?, remaining: TimeInterval?) {
        guard item.isSeries != true else { return (nil, nil) }
        let entry = history.entries.first { $0.id == item.route?.ref.id }
        return (entry?.progress, entry?.remaining ?? item.runtime)
    }
}

/// Карточка «Скачанного кино» — горизонтальная карточка коллекции (`PPMovieCard.medium`,
/// задача пользователя 2026-10-20): кадр, название и серым размер.
struct CollectionDownloadCard: View {
    let item: CollectionItem

    @Environment(ActionBarState.self) private var actionBar
    @Environment(AppNavigationState.self) private var navigation

    var body: some View {
        let time = CollectionDownloadAction.progress(item, history: actionBar.watchHistory)
        Button {
            CollectionDownloadAction.open(item, actionBar: actionBar, navigation: navigation)
        } label: {
            PPMovieCard(
                still: item.still ?? item.artwork,
                title: item.title,
                subtitle: CollectionDownloadMeta.text(item),
                size: .medium,
                progress: time.progress,
                remaining: time.remaining
            )
        }
        .buttonStyle(PressScaleButtonStyle(pressedScale: PressMotion.cardScale))
        .accessibilityLabel(item.title)
        .contextMenu { CollectionItemMenu(item: item) }
    }
}

/// Строка «Скачанного кино» в полном списке: фильм — «ещё» с действиями записи, сериал —
/// шеврон к его скачанным сериям.
struct CollectionDownloadRow: View {
    let item: CollectionItem
    let isFirst: Bool

    @Environment(ActionBarState.self) private var actionBar
    @Environment(AppNavigationState.self) private var navigation

    var body: some View {
        let time = CollectionDownloadAction.progress(item, history: actionBar.watchHistory)
        StillListRow(
            still: item.still ?? item.artwork,
            title: item.title,
            detail: CollectionDownloadMeta.text(item),
            progress: time.progress,
            remaining: time.remaining,
            isFirst: isFirst
        ) {
            CollectionDownloadAction.open(item, actionBar: actionBar, navigation: navigation)
        } trailing: {
            if item.isSeries == true {
                // Правый шеврон — отзеркаленный `icon / dropleft`, как у шапок секций.
                Image("iconDropleft")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: EntitySectionLayout.chevronBox, height: EntitySectionLayout.chevronBox)
                    .scaleEffect(x: -1)
                    .foregroundStyle(Color.fillSubtitle)
                    .accessibilityHidden(true)
            } else {
                Menu {
                    CollectionItemMenu(item: item)
                } label: {
                    TrackMoreLabel()
                        .pressScale(PressMotion.buttonScale)
                }
                .simultaneousGesture(TapGesture().onEnded { PlayerHaptics.tap() })
                .padding(-TrackMoreLabel.hitInset)
                .accessibilityLabel("Ещё")
            }
        }
        .contextMenu { CollectionItemMenu(item: item) }
    }
}
