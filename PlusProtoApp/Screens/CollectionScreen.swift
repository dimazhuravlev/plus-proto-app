import SwiftUI

/// Числа коллекции «Моё» — макет `2351:17327`. Кадр макета 375, карточки и поля
/// перенесены как есть: на холсте 402 следующая карточка просто выглядывает больше.
enum CollectionLayout {
    /// Лента — сразу под навигацией: контент на y 101 при высоте `top` 100
    static let contentTop: CGFloat = ServiceTopNavLayout.rowHeight + 1
    /// Воздух под последней секцией сверх клиренса хрома
    static let feedBottom: CGFloat = 16
    /// Между секциями — 8
    static let sectionGap: CGFloat = 8
    static let side: CGFloat = 16
    static let cardGap: CGFloat = 8
    /// Подпись — 6 под обложкой, Text S
    static let captionGap: CGFloat = 6
    static var captionLine: CGFloat { PlusTextSize.textS.lineHeight }
    /// Подпись под кругом исполнителя — с полем 8 справа, как в компоненте макета
    static let artistCaptionTrailing: CGFloat = 8

    /// Карточки — 86: постер 2:3 (86 × 129), квадрат альбома и плейлиста, круг исполнителя
    static let cardWidth: CGFloat = 86
    static let posterHeight: CGFloat = (cardWidth * 3 / 2).rounded()
    static let cardRadius: CGFloat = 8
    /// Книга — та же проекция, что карточка выдачи: обложка 128 (`book card small`)
    static let book = BookFigureGeometry(coverHeight: 128)

    /// Название карточки — до двух строк, деталь (год, автор, исполнитель) — в одну
    /// (правка пользователя 2026-10-04)
    static let titleLines = 2
    /// Высоты лент — карточка с подписью на пределе строк: название и деталь у кино,
    /// книг и альбомов, одно название у исполнителей и плейлистов
    static var posterRowHeight: CGFloat { posterHeight + captionGap + 3 * captionLine }
    static var bookRowHeight: CGFloat { book.frameSize(coverWidth: 0).height + captionGap + 3 * captionLine }
    static var squareRowHeight: CGFloat { cardWidth + captionGap + 3 * captionLine }
    static var titleOnlyRowHeight: CGFloat { cardWidth + captionGap + 2 * captionLine }

    /// Треки — колонки по три строки (`track stack` 335 с полями 16), строка — обложка
    /// 48 r6 и поля 8 между строками; следующая колонка выглядывает справа
    static let trackColumnWidth: CGFloat = 335
    static let tracksPerColumn = 3
    static let trackCover: CGFloat = 48
    static let trackCoverRadius: CGFloat = 6
    static let trackRowGap: CGFloat = 8
    static let trackTextGap: CGFloat = 12
    static let trackControlsGap: CGFloat = 8
    static let downloadIcon: CGFloat = 16
    static let moreIcon: CGFloat = 20
    static var tracksHeight: CGFloat {
        CGFloat(tracksPerColumn) * trackCover + CGFloat(tracksPerColumn - 1) * 2 * trackRowGap
    }
    /// Шапка треков: кнопка 40, названия 24 + 20, поля 16 сверху и 12 снизу; блок
    /// заканчивается полем 8
    static let tracksHeaderTop: CGFloat = 16
    static let tracksHeaderBottom: CGFloat = 12
    static let tracksHeaderGap: CGFloat = 12
    static let tracksBlockBottom: CGFloat = 8
    static let playButton: CGFloat = 40
    static let playIcon: CGFloat = 20

    /// Разделитель строк треков — Fill/Eight, 0.5
    static let divider = Color.white.opacity(0.15)
    /// «Ещё» у строки трека — белый 60 %
    static let more = Color.white.opacity(0.6)
}

enum CollectionMotion {
    /// Смена полки — кроссфейдом: два набора секций разной высоты не переезжают
    /// друг в друга
    static let shelfSwap: Animation = .smooth(duration: 0.3)
    /// Отмеченное или снятое встаёт и уходит в карусели плавно
    static let itemsChange: Animation = .smooth(duration: 0.35)
}

/// Коллекция «Моё» — содержимое пятого таба (макет `2351:17327`, задача пользователя
/// 2026-10-04): общая для кино, книг и музыки. Сверху — общая навигация сервисов
/// с полками «Любимое» и «Скачанное», ниже — секции по видам: кино, книги, треки
/// колонками, исполнители, альбомы, плейлисты. Пустая секция не показывается, пустая
/// полка — подсказкой.
///
/// Данные — `CollectionStore`: отмечают их сердца, «Позже» и «Скачать» по всему
/// приложению, и коллекция меняется на лету. Шеврон секции открывает её полным списком.
struct CollectionScreen: View {
    @Environment(CollectionStore.self) private var collection
    @Environment(AppNavigationState.self) private var navigation

    @State private var shelfIndex = 0
    @State private var scrollOffset: CGFloat = 0
    @State private var scrollPosition = ScrollPosition(edge: .top)

    private var shelf: CollectionStore.Shelf {
        CollectionStore.Shelf(rawValue: shelfIndex) ?? .favorites
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            // Лента одна на обе полки — меняется только её содержимое. Пока у каждой
            // полки была своя, на смене обе разом докладывали свой сдвиг, и подложка
            // навигации моргала (жалоба пользователя 2026-10-04).
            ScrollView {
                ZStack(alignment: .top) {
                    shelfContent(shelf)
                        .id(shelf)
                        .transition(.opacity)
                }
                .animation(CollectionMotion.shelfSwap, value: shelf)
                .padding(.bottom, CollectionLayout.feedBottom)
            }
            .scrollIndicators(.hidden)
            .contentMargins(.top, CollectionLayout.contentTop, for: .scrollContent)
            .scrollPosition($scrollPosition)
            .trackNavBarScroll(into: $scrollOffset)
        }
        .overlay(alignment: .top) {
            ServiceTopNav(
                filters: CollectionStore.Shelf.allCases.map(\.title),
                selection: $shelfIndex,
                scrollOffset: scrollOffset
            )
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: CollectionListRoute.self) { route in
            // Слои поиска — и на пуше, как у экранов сущностей: поиск, открытый
            // со списка, обязан лечь поверх него.
            SearchLayers(host: .pushed) {
                CollectionListScreen(route: route)
            }
            .ignoresSafeArea(.keyboard)
        }
        .onChange(of: shelfIndex) {
            // Новая полка — с начала, тем же движением, что смена содержимого.
            withAnimation(CollectionMotion.shelfSwap) { scrollPosition.scrollTo(edge: .top) }
        }
        // Повторный тап по табу на корне — к началу ленты, как на витринах.
        .onChange(of: navigation.scrollToTopRequests[.collection]) {
            withAnimation(ShowcaseScrollMotion.toTop) { scrollPosition.scrollTo(edge: .top) }
        }
        #if DEBUG
        // `-debugCollectionList <movie|book|track|artist|album|playlist>` — через 1.5 с
        // открыть полный список с этим фильтром: тапнуть заголовок из шелла нечем.
        // Один раз за процесс: на возврате корень появляется снова, и задача
        // открыла бы список опять.
        .task {
            guard !Self.didDebugOpenList,
                  let raw = UserDefaults.standard.string(forKey: "debugCollectionList"),
                  let kind = CollectionItem.Kind(rawValue: raw) else { return }
            Self.didDebugOpenList = true
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            navigation.push(CollectionListRoute(kind: kind, shelf: shelf))
        }
        #endif
    }

    #if DEBUG
    private static var didDebugOpenList = false
    #endif

    @ViewBuilder
    private func shelfContent(_ shelf: CollectionStore.Shelf) -> some View {
        let kinds = CollectionItem.Kind.allCases.filter { !collection.items($0, on: shelf).isEmpty }
        if kinds.isEmpty {
            // Подсказка — по центру видимой части ленты.
            CollectionEmptyState(shelf: shelf)
                .containerRelativeFrame(.vertical) { length, _ in length - CollectionLayout.contentTop }
        } else {
            VStack(spacing: CollectionLayout.sectionGap) {
                ForEach(kinds, id: \.self) { kind in
                    section(kind, on: shelf)
                }
            }
            .animation(CollectionMotion.itemsChange, value: kinds)
        }
    }

    @ViewBuilder
    private func section(_ kind: CollectionItem.Kind, on shelf: CollectionStore.Shelf) -> some View {
        let items = collection.items(kind, on: shelf)
        let openAll = { navigation.push(CollectionListRoute(kind: kind, shelf: shelf)) }
        switch kind {
        case .track:
            CollectionTracksBlock(items: items, openAll: openAll)
        case .movie:
            CollectionCarousel(title: kind.title, height: CollectionLayout.posterRowHeight, items: items, openAll: openAll) { item in
                CollectionPosterCard(item: item)
            }
        case .book:
            CollectionCarousel(title: kind.title, height: CollectionLayout.bookRowHeight, items: items, openAll: openAll) { item in
                CollectionBookCard(item: item)
            }
        case .artist:
            CollectionCarousel(title: kind.title, height: CollectionLayout.titleOnlyRowHeight, items: items, openAll: openAll) { item in
                CollectionArtistCard(item: item)
            }
        case .album:
            CollectionCarousel(title: kind.title, height: CollectionLayout.squareRowHeight, items: items, openAll: openAll) { item in
                CollectionSquareCard(item: item, showsSubtitle: true)
            }
        case .playlist:
            CollectionCarousel(title: kind.title, height: CollectionLayout.titleOnlyRowHeight, items: items, openAll: openAll) { item in
                CollectionSquareCard(item: item, showsSubtitle: false)
            }
        }
    }
}

// MARK: - Секция-карусель

/// Секция карточками: заголовок 56 с шевроном — переход в полный список, ниже лента
/// с полями 16 и зазором 8 (`carousel / Movies` макета). Высота ленты — явная, из
/// размеров карточки: своей `LazyHStack` здесь не меряет (`ServiceCarousel`).
private struct CollectionCarousel<Card: View>: View {
    let title: String
    let height: CGFloat
    let items: [CollectionItem]
    let openAll: () -> Void
    @ViewBuilder var card: (CollectionItem) -> Card

    var body: some View {
        VStack(spacing: 0) {
            Button(action: openAll) {
                EntitySectionHeader(title: title)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)

            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: CollectionLayout.cardGap) {
                    ForEach(items) { item in
                        card(item)
                    }
                }
                .scrollTargetLayout()
                .animation(CollectionMotion.itemsChange, value: items.map(\.id))
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
            .contentMargins(.horizontal, CollectionLayout.side, for: .scrollContent)
            .frame(height: height)
        }
    }
}

// MARK: - Карточки

/// Фильм — постер 86 × 129 r8, под ним название и год.
private struct CollectionPosterCard: View {
    let item: CollectionItem

    @Environment(AppNavigationState.self) private var navigation
    @Environment(\.stackZoomNamespace) private var zoom

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: CollectionLayout.captionGap) {
                CollectionArtwork(
                    source: item.artwork,
                    width: CollectionLayout.cardWidth,
                    height: CollectionLayout.posterHeight,
                    shape: RoundedRectangle(cornerRadius: CollectionLayout.cardRadius, style: .continuous)
                )
                .collectionZoomSource(item.route, in: zoom)

                CollectionCaption(title: item.title, subtitle: item.subtitle)
            }
            .frame(width: CollectionLayout.cardWidth, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(PressScaleButtonStyle(pressedScale: 0.97))
        .contextMenu { CollectionItemMenu(item: item) }
    }

    private func open() {
        guard let route = item.route else { return }
        navigation.open(route)
    }
}

/// Книга — наша проекция с обложкой 128 (`BookFigure`), под ней название и автор.
private struct CollectionBookCard: View {
    let item: CollectionItem

    @Environment(AppNavigationState.self) private var navigation
    @Environment(\.stackZoomNamespace) private var zoom

    var body: some View {
        let geometry = CollectionLayout.book
        let coverWidth = geometry.coverWidth(aspect: item.aspect)
        let width = geometry.frameSize(coverWidth: coverWidth).width
        Button(action: open) {
            VStack(alignment: .leading, spacing: CollectionLayout.captionGap) {
                BookFigure(geometry: geometry, coverWidth: coverWidth) {
                    if let artwork = item.artwork {
                        SkeletonArtwork(source: artwork)
                    }
                }
                .collectionZoomSource(item.route, in: zoom)

                CollectionCaption(title: item.title, subtitle: item.subtitle)
            }
            .frame(width: width, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(PressScaleButtonStyle(pressedScale: 0.97))
        .contextMenu { CollectionItemMenu(item: item) }
    }

    private func open() {
        guard let route = item.route else { return }
        navigation.open(route)
    }
}

/// Альбом и плейлист — квадрат 86 r8, под ним название (у альбома — и исполнитель).
/// Альбом открывает свой экран, плейлист — играет: экрана плейлиста в прототипе нет.
private struct CollectionSquareCard: View {
    let item: CollectionItem
    let showsSubtitle: Bool

    @Environment(AppNavigationState.self) private var navigation
    @Environment(ActionBarState.self) private var actionBar
    @Environment(\.stackZoomNamespace) private var zoom

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: CollectionLayout.captionGap) {
                CollectionArtwork(
                    source: item.artwork,
                    width: CollectionLayout.cardWidth,
                    height: CollectionLayout.cardWidth,
                    shape: RoundedRectangle(cornerRadius: CollectionLayout.cardRadius, style: .continuous)
                )
                .collectionZoomSource(item.route, in: zoom)

                CollectionCaption(title: item.title, subtitle: showsSubtitle ? item.subtitle : nil)
            }
            .frame(width: CollectionLayout.cardWidth, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(PressScaleButtonStyle(pressedScale: 0.97))
        .contextMenu { CollectionItemMenu(item: item) }
    }

    private func open() {
        if let route = item.route {
            navigation.open(route)
        } else if let playable = item.playable {
            PlayerHaptics.tap()
            actionBar.open(.music(playable))
        }
    }
}

/// Исполнитель — круг 86, под ним имя по центру.
private struct CollectionArtistCard: View {
    let item: CollectionItem

    @Environment(AppNavigationState.self) private var navigation
    @Environment(\.stackZoomNamespace) private var zoom

    var body: some View {
        Button(action: open) {
            VStack(spacing: CollectionLayout.captionGap) {
                CollectionArtwork(
                    source: item.artwork,
                    width: CollectionLayout.cardWidth,
                    height: CollectionLayout.cardWidth,
                    shape: Circle()
                )
                .collectionZoomSource(item.route, in: zoom)

                CollectionCaption(title: item.title, isCentered: true)
                    .padding(.trailing, CollectionLayout.artistCaptionTrailing)
            }
            .frame(width: CollectionLayout.cardWidth)
            .contentShape(.rect)
        }
        .buttonStyle(PressScaleButtonStyle(pressedScale: 0.97))
        .contextMenu { CollectionItemMenu(item: item) }
    }

    private func open() {
        guard let route = item.route else { return }
        navigation.open(route)
    }
}

/// Обложка карточки на скелетоне: картинка проявляется на месте серой заливки,
/// хайрлайн — как у всех карточек проекта.
struct CollectionArtwork<S: InsettableShape>: View {
    let source: ArtworkSource?
    let width: CGFloat
    let height: CGFloat
    let shape: S

    var body: some View {
        PlusSkeleton.fill
            .overlay {
                if let source {
                    SkeletonArtwork(source: source)
                }
            }
            .frame(width: width, height: height)
            .clipShape(shape)
            .overlay { shape.strokeBorder(PlusSkeleton.fill, lineWidth: PlusMetrics.hairline) }
    }
}

/// Подпись карточки — Text S: название белым до двух строк, деталь серым в строку.
private struct CollectionCaption: View {
    let title: String
    var subtitle: String? = nil
    var isCentered = false

    var body: some View {
        VStack(alignment: isCentered ? .center : .leading, spacing: 0) {
            Text(title)
                .plusText(.textS, .medium)
                .foregroundStyle(Color.fillOne)
                .lineLimit(CollectionLayout.titleLines)
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .plusText(.textS, .medium)
                    .foregroundStyle(Color.fillSubtitle)
                    .lineLimit(1)
            }
        }
        .multilineTextAlignment(isCentered ? .center : .leading)
        .frame(maxWidth: .infinity, alignment: isCentered ? .center : .leading)
    }
}

private extension View {
    /// Источник зума в экран сущности — как у карточек витрин.
    @ViewBuilder
    func collectionZoomSource(_ route: EntityRoute?, in zoom: Namespace.ID?) -> some View {
        if let route, let zoom {
            matchedTransitionSource(id: route, in: zoom)
        } else {
            self
        }
    }
}

// MARK: - Треки

/// Треки — блок `carousel / Music / opened playlist`: шапка с круглой «play», названием
/// и числом треков, под ней колонки по три строки, листаются вбок по колонке.
/// Тап по строке включает трек, «play» шапки — с первого трека полки.
private struct CollectionTracksBlock: View {
    let items: [CollectionItem]
    let openAll: () -> Void

    @Environment(ActionBarState.self) private var actionBar

    private var columns: [[CollectionItem]] {
        stride(from: 0, to: items.count, by: CollectionLayout.tracksPerColumn).map {
            Array(items[$0..<min($0 + CollectionLayout.tracksPerColumn, items.count)])
        }
    }

    /// Играет ли сейчас трек этой полки — тогда «play» шапки — пауза.
    private var isPlayingShelf: Bool {
        guard actionBar.mode == .music, actionBar.isMusicPlaying, let id = actionBar.music?.id else { return false }
        return items.contains { $0.playable?.id == id }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 0) {
                    ForEach(columns.indices, id: \.self) { index in
                        let column = columns[index]
                        VStack(spacing: 0) {
                            ForEach(column.indices, id: \.self) { row in
                                CollectionTrackRow(
                                    item: column[row],
                                    isFirst: row == 0,
                                    isLast: row == column.count - 1
                                )
                            }
                        }
                        .frame(width: CollectionLayout.trackColumnWidth, alignment: .top)
                    }
                }
                .scrollTargetLayout()
                .animation(CollectionMotion.itemsChange, value: items.map(\.id))
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
            .frame(height: CollectionLayout.tracksHeight, alignment: .top)
        }
        .padding(.bottom, CollectionLayout.tracksBlockBottom)
    }

    private var header: some View {
        HStack(spacing: CollectionLayout.tracksHeaderGap) {
            Button(action: togglePlayback) {
                Image(isPlayingShelf ? "iconPause" : "iconPlay")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: CollectionLayout.playIcon, height: CollectionLayout.playIcon)
                    .foregroundStyle(Color.fillOne)
                    .frame(width: CollectionLayout.playButton, height: CollectionLayout.playButton)
                    .secondaryButtonSurface(Circle(), fill: .buttonsSecondary)
                    .contentShape(Circle())
            }
            .buttonStyle(PressScaleButtonStyle())
            .accessibilityLabel(isPlayingShelf ? "Пауза" : "Слушать")

            // Название — переход в полный список, как шеврон у карусельных секций.
            Button(action: openAll) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(CollectionItem.Kind.track.title)
                        .plusHeadline(.m)
                        .foregroundStyle(Color.fillOne)
                    Text(CollectionCopy.tracks(items.count))
                        .plusText(.textM, .medium)
                        .foregroundStyle(Color.fillSubtitle)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, CollectionLayout.side)
        .padding(.top, CollectionLayout.tracksHeaderTop)
        .padding(.bottom, CollectionLayout.tracksHeaderBottom)
    }

    private func togglePlayback() {
        PlayerHaptics.tap()
        if isPlayingShelf {
            actionBar.toggleMusicPlayback()
        } else if let first = items.first?.playable {
            actionBar.open(.music(first))
        }
    }
}

/// Строка трека — `list-item / music`: обложка 48 r6, название и исполнитель Text M
/// (бейдж 18+ у названия), справа отметка «скачано» и «ещё». Между строками колонки —
/// разделитель 0.5.
private struct CollectionTrackRow: View {
    let item: CollectionItem
    let isFirst: Bool
    let isLast: Bool

    @Environment(CollectionStore.self) private var collection
    @Environment(ActionBarState.self) private var actionBar

    var body: some View {
        HStack(spacing: 0) {
            CollectionArtwork(
                source: item.artwork,
                width: CollectionLayout.trackCover,
                height: CollectionLayout.trackCover,
                shape: RoundedRectangle(cornerRadius: CollectionLayout.trackCoverRadius, style: .continuous)
            )

            HStack(spacing: CollectionLayout.trackTextGap) {
                VStack(alignment: .leading, spacing: EntitySectionLayout.textStackGap) {
                    HStack(spacing: 6) {
                        Text(item.title)
                            .plusText(.textM, .medium)
                            .foregroundStyle(Color.fillOne)
                            .lineLimit(1)
                        if item.isExplicit == true {
                            EntityExplicitBadge()
                        }
                    }
                    Text(item.subtitle)
                        .plusText(.textM, .medium)
                        .foregroundStyle(Color.fillSubtitle)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: CollectionLayout.trackControlsGap) {
                    if collection.isDownloaded(item.id) {
                        Image("iconDownload")
                            .renderingMode(.template)
                            .resizable()
                            .frame(width: CollectionLayout.downloadIcon, height: CollectionLayout.downloadIcon)
                            .foregroundStyle(Color.moviesAccent)
                            .accessibilityLabel("Скачано")
                    }
                    Menu {
                        CollectionItemMenu(item: item)
                    } label: {
                        Image("iconMore")
                            .renderingMode(.template)
                            .resizable()
                            .frame(width: CollectionLayout.moreIcon, height: CollectionLayout.moreIcon)
                            .foregroundStyle(CollectionLayout.more)
                            .padding(10)
                            .contentShape(.rect)
                    }
                    .padding(-10)
                    .accessibilityLabel("Ещё")
                }
            }
            .padding(.leading, CollectionLayout.trackTextGap)
        }
        .padding(.horizontal, CollectionLayout.side)
        .padding(.top, isFirst ? 0 : CollectionLayout.trackRowGap)
        .padding(.bottom, isLast ? 0 : CollectionLayout.trackRowGap)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle()
                    .fill(CollectionLayout.divider)
                    .frame(height: 0.5)
                    .padding(.horizontal, CollectionLayout.side)
            }
        }
        .contentShape(.rect)
        .onTapGesture(perform: play)
        .contextMenu { CollectionItemMenu(item: item) }
    }

    private func play() {
        guard let playable = item.playable else { return }
        PlayerHaptics.tap()
        actionBar.open(.music(playable))
    }
}

// MARK: - Меню записи

/// Действия с записью — по долгому нажатию на карточку и из «ещё» строки трека:
/// отметки коллекции и переход к альбому трека.
struct CollectionItemMenu: View {
    let item: CollectionItem

    @Environment(CollectionStore.self) private var collection
    @Environment(AppNavigationState.self) private var navigation

    var body: some View {
        let isFavorite = collection.isFavorite(item.id)
        Button {
            collection.toggleFavorite(item)
        } label: {
            Label(isFavorite ? "Убрать из любимого" : "В любимое", systemImage: isFavorite ? "heart.slash" : "heart")
        }
        // Исполнителя скачать нельзя — у него нет своего контента в прототипе.
        if item.kind != .artist {
            let isDownloaded = collection.isDownloaded(item.id)
            Button {
                collection.toggleDownload(item)
            } label: {
                Label(isDownloaded ? "Удалить из скачанного" : "Скачать", systemImage: isDownloaded ? "trash" : "arrow.down.circle")
            }
        }
        if item.kind == .track, let route = item.route {
            Button {
                navigation.open(route)
            } label: {
                Label("Перейти к альбому", systemImage: "square.stack")
            }
        }
    }
}

// MARK: - Пустая полка

/// Полка пуста — подсказка, откуда в неё попадают.
private struct CollectionEmptyState: View {
    let shelf: CollectionStore.Shelf

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .plusHeadline(.m)
                .foregroundStyle(Color.fillOne)
            Text(hint)
                .plusText(.textM, .medium)
                .foregroundStyle(Color.fillSubtitle)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var title: String {
        switch shelf {
        case .favorites: "Здесь будет любимое"
        case .downloads: "Скачанного пока нет"
        }
    }

    private var hint: String {
        switch shelf {
        case .favorites: "Отмечайте «Нравится» у музыки и книг и «Позже» у фильмов — всё соберётся здесь"
        case .downloads: "Скачайте фильм, книгу, альбом или трек — они появятся здесь"
        }
    }
}
