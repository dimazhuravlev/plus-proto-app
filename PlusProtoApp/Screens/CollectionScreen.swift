import SwiftUI
import UIKit

/// Числа коллекции «Моё» — макет `2351:17327`. Кадр макета 375, карточки и поля
/// перенесены как есть: на холсте 402 следующая карточка просто выглядывает больше.
enum CollectionLayout {
    /// Лента — сразу под навигацией: контент на y 101 при высоте `top` 100
    static let contentTop: CGFloat = ServiceTopNavLayout.rowHeight + 1
    /// Воздух под последней секцией сверх клиренса хрома
    static let feedBottom: CGFloat = 16
    /// Между секциями — вплотную: воздух даёт поле 16 над заголовком (правка
    /// пользователя 2026-10-04 — «минус 8 между всеми блоками»; в макете было 8)
    static let sectionGap: CGFloat = 0
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
    /// Высоты лент — карточка с подписью на пределе строк: название и деталь у
    /// альбомов, одно название у исполнителей и плейлистов. У кино и книг подписей нет
    /// вовсе (правка пользователя 2026-10-10) — лента ровно в обложку.
    static var posterRowHeight: CGFloat { posterHeight }
    static var bookRowHeight: CGFloat { book.frameSize(coverWidth: 0).height }
    /// Нижний отступ полок кино и книг (правка пользователя 2026-10-10: без подписей
    /// блок ниже прилипал). Высоты рядов не трогаем — отступ вне ленты, зум и клип целы.
    static let coverOnlyShelfBottom: CGFloat = 16
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
    @Environment(\.scenePhase) private var scenePhase

    @State private var shelfIndex = 0
    @State private var scrollOffset: CGFloat = 0
    @State private var scrollPosition = ScrollPosition(edge: .top)
    /// Режим «изменить порядок»: рабочий порядок, захват и сдвиги блока — одним объектом,
    /// чтобы палец, двигающий блок, перерисовывал только этот блок, а не весь экран.
    @State private var reorder = CollectionReorderState()

    private var shelf: CollectionStore.Shelf {
        CollectionStore.Shelf(rawValue: shelfIndex) ?? .favorites
    }

    /// Виды полки, в которых есть записи, — в порядке пользователя. В режиме порядка —
    /// в рабочем (`draftOrder`): он меняется на глазах, а в хранилище уходит по «Готово».
    private func visibleKinds(_ shelf: CollectionStore.Shelf) -> [CollectionItem.Kind] {
        let order = reorder.isReordering && reorder.shelf == shelf
            ? reorder.draftOrder
            : collection.kindsOrder(on: shelf)
        return order.filter { !collection.items($0, on: shelf).isEmpty }
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
            // Блок в руке — лента стоит: палец двигает блок, а не прокручивает её.
            .scrollDisabled(reorder.heldKind != nil)
            .contentMargins(.top, CollectionLayout.contentTop, for: .scrollContent)
            .scrollPosition($scrollPosition)
            .trackNavBarScroll(into: $scrollOffset)
        }
        .overlay(alignment: .top) {
            ServiceTopNav(
                filters: CollectionStore.Shelf.allCases.map(\.title),
                selection: $shelfIndex,
                scrollOffset: scrollOffset,
                // «Моё» — не витрина: затемнения сверху нет (затемнение — у витрин, 2026-10-10).
                showsTopShade: false,
                trailingAccessory: AnyView(
                    CollectionReorderButton(
                        isEnabled: reorder.isReordering || visibleKinds(shelf).count > 1,
                        action: toggleReordering
                    )
                )
            )
        }
        .environment(reorder)
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
            // Полку сменили посреди редактирования — порядок прежней сохраняется, режим
            // выключается: у новой полки свой порядок и своё «изменить».
            finishReordering()
            // Новая полка — с начала, тем же движением, что смена содержимого.
            withAnimation(CollectionMotion.shelfSwap) { scrollPosition.scrollTo(edge: .top) }
        }
        // Уход с экрана (другой таб, пуш) и фон приложения выключают режим и сохраняют
        // порядок: перестановка уже сделана на глазах, терять её молча — хуже.
        .onDisappear { finishReordering() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { finishReordering() }
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
        // `-debugCollectionReorder 1` — через 2 с войти в режим порядка (как кнопка
        // в навбаре), через 4 с поставить первый блок на второе место (тот же свап, что
        // у драга), через 6 с — «Готово». Один раз за процесс.
        .task {
            guard !Self.didDebugReorder,
                  UserDefaults.standard.bool(forKey: "debugCollectionReorder") else { return }
            Self.didDebugReorder = true
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            toggleReordering()
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            reorder.swapBlocks(0, 1)
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            toggleReordering()
        }
        #endif
    }

    #if DEBUG
    private static var didDebugOpenList = false
    private static var didDebugReorder = false
    #endif

    // MARK: Режим порядка

    /// Кнопка навбара: вход в режим и «Готово» — один тап, одна хаптика.
    private func toggleReordering() {
        PlayerHaptics.tap()
        if reorder.isReordering {
            finishReordering()
        } else {
            reorder.start(shelf: shelf, order: visibleKinds(shelf))
        }
    }

    /// Сохранить рабочий порядок и выйти из режима. Виды, которых на полке сейчас нет
    /// (пустые), держат свои места в сохранённом порядке: видимые занимают места
    /// видимых в порядке рабочего списка.
    private func finishReordering() {
        guard reorder.isReordering, let editedShelf = reorder.shelf else { return }
        var draft = reorder.draftOrder[...]
        let merged = collection.kindsOrder(on: editedShelf).map { kind in
            reorder.draftOrder.contains(kind) ? draft.removeFirst() : kind
        }
        collection.setKindsOrder(merged, on: editedShelf)
        reorder.stop()
    }

    @ViewBuilder
    private func shelfContent(_ shelf: CollectionStore.Shelf) -> some View {
        let kinds = visibleKinds(shelf)
        if kinds.isEmpty {
            // Подсказка — по центру видимой части ленты.
            CollectionEmptyState(shelf: shelf)
                .containerRelativeFrame(.vertical) { length, _ in length - CollectionLayout.contentTop }
        } else {
            VStack(spacing: CollectionLayout.sectionGap) {
                ForEach(kinds, id: \.self) { kind in
                    CollectionReorderBlock(kind: kind) {
                        section(kind, on: shelf)
                    }
                }
            }
            // Пространство жеста порядка стоит на самой ленте: оно не едет вместе
            // с блоком, и сдвиг пальца не искажается сдвигом блока под ним.
            .coordinateSpace(name: CollectionReorderState.feedSpace)
            // Анимируется состав видов; перестановку анимирует сам свап (`swapBlocks`),
            // поэтому значение — множество: порядок его не меняет.
            .animation(CollectionMotion.itemsChange, value: Set(kinds))
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
            .padding(.bottom, CollectionLayout.coverOnlyShelfBottom)
        case .book:
            CollectionCarousel(title: kind.title, height: CollectionLayout.bookRowHeight, items: items, openAll: openAll) { item in
                CollectionBookCard(item: item)
            }
            .padding(.bottom, CollectionLayout.coverOnlyShelfBottom)
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

    @Environment(CollectionReorderState.self) private var reorder

    var body: some View {
        VStack(spacing: 0) {
            Button(action: openAll) {
                EntitySectionHeader(title: title, isChevronCollapsed: reorder.isReordering)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            // Иконка-хват — на правом краю шапки (`2584:29425`: x 339 при поле 16, y 16),
            // шеврон на её время гаснет.
            .overlay(alignment: .topTrailing) {
                CollectionReorderGrip(isVisible: reorder.isReordering)
                    .padding(.top, EntitySectionLayout.headerTop)
                    .padding(.trailing, CollectionLayout.side)
            }

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
            .scrollDisabled(reorder.isReordering)
            .scrollTargetBehavior(.viewAligned)
            .contentMargins(.horizontal, CollectionLayout.side, for: .scrollContent)
            .frame(height: height)
        }
    }
}

// MARK: - Карточки

/// Фильм — постер 86 × 129 r8, без подписи (правка пользователя 2026-10-10): название
/// читает VoiceOver.
private struct CollectionPosterCard: View {
    let item: CollectionItem

    @Environment(AppNavigationState.self) private var navigation
    @Environment(\.stackZoomNamespace) private var zoom

    var body: some View {
        Button(action: open) {
            CollectionArtwork(
                source: item.artwork,
                width: CollectionLayout.cardWidth,
                height: CollectionLayout.posterHeight,
                shape: RoundedRectangle(cornerRadius: CollectionLayout.cardRadius, style: .continuous)
            )
            .collectionZoomSource(item.route, in: zoom)
            .frame(width: CollectionLayout.cardWidth, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(PressScaleButtonStyle(pressedScale: PressMotion.cardScale))
        .accessibilityLabel(item.title)
        .contextMenu { CollectionItemMenu(item: item) }
    }

    private func open() {
        guard let route = item.route else { return }
        navigation.open(route)
    }
}

/// Книга — наша проекция с обложкой 128 (`BookFigure`), без подписи (правка
/// пользователя 2026-10-10): название читает VoiceOver.
private struct CollectionBookCard: View {
    let item: CollectionItem

    @Environment(AppNavigationState.self) private var navigation
    @Environment(\.stackZoomNamespace) private var zoom

    var body: some View {
        let geometry = CollectionLayout.book
        let coverWidth = geometry.coverWidth(aspect: item.aspect)
        let width = geometry.frameSize(coverWidth: coverWidth).width
        Button(action: open) {
            BookFigure(geometry: geometry, coverWidth: coverWidth) {
                if let artwork = item.artwork {
                    SkeletonArtwork(source: artwork)
                }
            }
            .collectionZoomSource(item.route, in: zoom)
            .frame(width: width, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(PressScaleButtonStyle(pressedScale: PressMotion.cardScale))
        .accessibilityLabel(item.title)
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
        .buttonStyle(PressScaleButtonStyle(pressedScale: PressMotion.cardScale))
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
        .buttonStyle(PressScaleButtonStyle(pressedScale: PressMotion.cardScale))
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
            .coverBorder(shape)
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
    @Environment(CollectionReorderState.self) private var reorder

    /// Очередь полки: её треки по порядку — конец превью переключает на следующий.
    private var queue: [MusicNowPlaying] {
        items.compactMap(\.playable)
    }

    private var columns: [[CollectionItem]] {
        stride(from: 0, to: items.count, by: CollectionLayout.tracksPerColumn).map {
            Array(items[$0..<min($0 + CollectionLayout.tracksPerColumn, items.count)])
        }
    }

    /// Играет ли сейчас трек этой полки — тогда «play» шапки — пауза.
    private var isPlayingShelf: Bool {
        guard actionBar.isMiniPlayerVisible, actionBar.isMusicPlaying, let id = actionBar.music?.id else { return false }
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
                                    queue: queue,
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
            .scrollDisabled(reorder.isReordering)
            .scrollTargetBehavior(.viewAligned)
            .frame(height: CollectionLayout.tracksHeight, alignment: .top)
        }
        .padding(.bottom, CollectionLayout.tracksBlockBottom)
    }

    private var header: some View {
        HStack(spacing: CollectionLayout.tracksHeaderGap) {
            Button(action: togglePlayback) {
                PlayPauseGlyph(isPlaying: isPlayingShelf, box: CollectionLayout.playIcon)
                    .foregroundStyle(Color.fillOne)
                    .frame(width: CollectionLayout.playButton, height: CollectionLayout.playButton)
                    .secondaryButtonSurface(Circle(), fill: .buttonsSecondary)
                    .contentShape(Circle())
            }
            .buttonStyle(PressScaleButtonStyle())
            .accessibilityLabel(isPlayingShelf ? "Пауза" : "Слушать")
            // В режиме порядка «play» остаётся на месте, приглушён и недоступен — как
            // выключенная кнопка навбара (одна константа).
            .opacity(reorder.isReordering ? CollectionReorderMotion.disabledOpacity : 1)
            .allowsHitTesting(!reorder.isReordering)
            .animation(CollectionReorderMotion.disabledFade, value: reorder.isReordering)

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
        // Хват — на правом краю, по центру кнопки «play» (в макете у шапки треков
        // его нет: от каруселей — тот же край, а вертикаль — середина ряда 40).
        .overlay(alignment: .topTrailing) {
            CollectionReorderGrip(isVisible: reorder.isReordering)
                .padding(.top, CollectionLayout.tracksHeaderTop + (CollectionLayout.playButton - CollectionReorderGrip.size) / 2)
                .padding(.trailing, CollectionLayout.side)
        }
    }

    private func togglePlayback() {
        PlayerHaptics.tap()
        if isPlayingShelf {
            actionBar.toggleMusicPlayback()
        } else if let first = items.first?.playable {
            actionBar.open(.music(first), queue: queue)
        }
    }
}

/// Строка трека — `list-item / music`: обложка 48 r6, название и исполнитель Text M
/// (бейдж 18+ у названия), справа отметка «скачано» и «ещё». Между строками колонки —
/// разделитель 0.5.
private struct CollectionTrackRow: View {
    let item: CollectionItem
    /// Очередь полки, в которой стоит строка.
    let queue: [MusicNowPlaying]
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
                            // Своё нажатие у «ещё» — и палец на нём не просаживает строку.
                            .pressScale(GlassIconButtonConfig.pressedScale)
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
        .contentShape(.rect)
        // Проседает строка, а черта стоит: просевшая черта короче соседних и съезжает.
        .pressScale(PressMotion.rowScale)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle()
                    .fill(CollectionLayout.divider)
                    .frame(height: 0.5)
                    .padding(.horizontal, CollectionLayout.side)
            }
        }
        .onTapGesture(perform: play)
        .contextMenu { CollectionItemMenu(item: item) }
    }

    private func play() {
        guard let playable = item.playable else { return }
        PlayerHaptics.tap()
        actionBar.open(.music(playable), queue: queue)
    }
}

// MARK: - Порядок блоков

/// Числа режима «изменить порядок». Иконки — макет «Моего»: кнопка навбара
/// `icon / change order` `2584:26578` (20 × 20, x 279, y 62 на кадре 375), хват в шапке
/// блока `icon` `2584:29425` (20 × 20, x 339, y 16). Остальное — решения спеки 35.
enum CollectionReorderMotion {
    /// Соседи уступают место — как сдвиг строк при перестановке на домашнем экране.
    static let swap: Animation = .smooth(duration: 0.3)
    /// Отпущенный блок встаёт в свою ячейку.
    static let settleDuration: Double = 0.3
    static let settle: Animation = .smooth(duration: settleDuration)
    /// Фон стекла проявляется на захвате и гаснет, когда блок уже встал на место.
    static let glassFadeDuration: Double = 0.2
    static let glassFade: Animation = .easeInOut(duration: glassFadeDuration)
    /// Подъём блока в руке — как просадка карточки, только вверх (`PressMotion`).
    static let liftScale: CGFloat = 1.02
    /// Приглушённое состояние недоступного: кнопка навбара при одном блоке и «play» «Треков»
    /// в режиме — одно значение.
    static let disabledOpacity: Double = 0.3
    static let disabledFade: Animation = .easeInOut(duration: 0.2)
    /// Захват — удержание 0.3 с без сдвига больше 10 pt: быстрый свайп раньше этого
    /// уходит в прокрутку ленты.
    static let pressDuration: TimeInterval = 0.3
    static let pressSlop: CGFloat = 10
    /// Автопрокрутка у края, пока блок в руке: зона 80 pt под навбаром и над хромом,
    /// скорость пропорциональна глубине захода, до максимума в pt/с. Reduce Motion её
    /// не отключает — это управление, а не украшение.
    static let autoScrollZone: CGFloat = 80
    static let autoScrollMaxSpeed: CGFloat = 600
    /// Тряска: угол в градусах, подскок в pt, период в секундах, сдвиг фазы между блоками
    /// (по виду) — соседи не качаются в унисон.
    static let shakeAngle: Double = 0.35
    static let shakeLift: Double = 0.6
    static let shakePeriod: Double = 0.26
    static let shakePhaseStep: Double = 2.1
    /// Тряска входит и выходит плавно: резкий останов читался бы как глюк.
    static let shakeFade: Animation = .easeInOut(duration: 0.2)
    /// Часы тряски идут ещё столько после «Готово», пока амплитуда не дойдёт до нуля.
    static let clockLinger: Duration = .milliseconds(400)
    /// Фон блока в руке — скругление.
    static let glassRadius: CGFloat = PlusRadius.readerBlock
    /// Правка пользователя 2026-10-10: без боковых полей — фон и клип блока в руке
    /// от края до края экрана (подъём 1.02 уводит края за кромку — это нормально).
    static let glassInset: CGFloat = 0
    /// Правка пользователя 2026-10-10: фон блока «Плейлисты» в руке выходит на 16 ниже
    /// содержимого — иначе он кончался вплотную под подписями карточек. У остальных
    /// видов поле не нужно (у кино и книг оно и так есть внутри блока). Раскладку это
    /// не меняет: фон и клип рисуются ниже рамки блока, соседи на месте.
    static let glassBottomExtra: CGFloat = 16
    /// Клип вне захвата: шире блока ровно на радиус — дуги углов за кромкой, срезов нет.
    static let restClipInset: CGFloat = -glassRadius
}

/// Состояние режима порядка — один объект на экран: переключение режима перерисовывает
/// блоки, а сдвиг пальца (`dragTranslation`) читает только сам блок в руке — модификатор
/// `CollectionReorderOffset`, поэтому лента не пересобирается на каждое событие жеста.
@MainActor
@Observable
final class CollectionReorderState {
    /// Имя пространства жеста — сама лента: оно не едет вместе с блоком.
    static let feedSpace = "collectionFeed"

    private(set) var isReordering = false
    /// Полка, чей порядок правят.
    private(set) var shelf: CollectionStore.Shelf?
    /// Рабочий порядок видимых видов: меняется на глазах, в хранилище уходит по «Готово».
    private(set) var draftOrder: [CollectionItem.Kind] = []
    /// Блок под пальцем — от долгого нажатия до отпускания.
    private(set) var heldKind: CollectionItem.Kind?
    /// Блок в руке и пока он доезжает на место: выше соседей, со стеклом, без тряски.
    private(set) var liftedKind: CollectionItem.Kind?
    /// Сдвиг пальца — прямо, без анимации: блок идёт 1:1.
    private(set) var dragTranslation: CGFloat = 0
    /// Поправка на свап: ячейка блока при перестановке переезжает на высоту соседа,
    /// поправка уносит ровно столько же обратно — и под пальцем блок не прыгает. Пишется
    /// в той же анимации, что и свап, поэтому сумма ячейки и поправки все 0.3 с постоянна.
    private(set) var dragCompensation: CGFloat = 0
    /// Идут ли часы тряски: `TimelineView` стоит на паузе, пока режим выключен.
    private(set) var isClockRunning = false

    /// Высоты блоков — замер для логики жеста (середины соседей), раскладку они не задают.
    @ObservationIgnored private var heights: [CollectionItem.Kind: CGFloat] = [:]
    @ObservationIgnored private var settleEnd = Date.distantPast
    @ObservationIgnored private var settleTask: Task<Void, Never>?
    @ObservationIgnored private var clockTask: Task<Void, Never>?

    func setHeight(_ height: CGFloat, for kind: CollectionItem.Kind) {
        heights[kind] = height
    }

    // MARK: Режим

    func start(shelf: CollectionStore.Shelf, order: [CollectionItem.Kind]) {
        settleTask?.cancel()
        clockTask?.cancel()
        self.shelf = shelf
        draftOrder = order
        heldKind = nil
        liftedKind = nil
        dragTranslation = 0
        dragCompensation = 0
        isClockRunning = true
        isReordering = true
    }

    func stop() {
        if let heldKind { release(heldKind) }
        isReordering = false
        shelf = nil
        draftOrder = []
        // Часы доживают до нуля амплитуды и уходят на паузу.
        clockTask?.cancel()
        clockTask = Task {
            try? await Task.sleep(for: CollectionReorderMotion.clockLinger)
            guard !Task.isCancelled else { return }
            isClockRunning = false
        }
    }

    // MARK: Жест

    /// Блок оторвался от ленты (долгое нажатие дошло до конца): хаптик medium.
    func grab(_ kind: CollectionItem.Kind) {
        guard isReordering, heldKind == nil, Date.now >= settleEnd else { return }
        settleTask?.cancel()
        heldKind = kind
        liftedKind = kind
        dragTranslation = 0
        dragCompensation = 0
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    /// Палец сдвинулся на `translation` от точки захвата. Блок идёт за ним, а когда его
    /// центр пересекает середину соседа, они меняются местами (`swap`).
    func drag(translation: CGFloat) {
        guard let kind = heldKind else { return }
        dragTranslation = translation
        while let index = draftOrder.firstIndex(of: kind), let height = heights[kind] {
            let origin = draftOrder[..<index].reduce(0) { $0 + (heights[$1] ?? 0) }
            let center = origin + height / 2 + dragTranslation + dragCompensation
            if index + 1 < draftOrder.count,
               let below = heights[draftOrder[index + 1]],
               center > origin + height + below / 2 {
                swap(index, index + 1, compensating: -below)
            } else if index > 0,
                      let above = heights[draftOrder[index - 1]],
                      center < origin - above / 2 {
                swap(index, index - 1, compensating: above)
            } else {
                break
            }
        }
    }

    /// Палец поднят (или жест отменён системой): блок доезжает на место, хаптик light.
    func release(_ kind: CollectionItem.Kind) {
        guard heldKind == kind else { return }
        heldKind = nil
        withAnimation(CollectionReorderMotion.settle) {
            dragTranslation = 0
            dragCompensation = 0
        }
        PlayerHaptics.tap()
        settleEnd = Date.now.addingTimeInterval(CollectionReorderMotion.settleDuration)
        // Блок остаётся наверху, пока стекло под ним не погасло.
        settleTask?.cancel()
        settleTask = Task {
            try? await Task.sleep(for: .seconds(CollectionReorderMotion.settleDuration + CollectionReorderMotion.glassFadeDuration))
            guard !Task.isCancelled else { return }
            liftedKind = nil
        }
    }

    /// Свап соседних блоков — тот же код у драга и у отладочного флага.
    func swapBlocks(_ first: Int, _ second: Int) {
        swap(first, second)
    }

    private func swap(_ first: Int, _ second: Int, compensating delta: CGFloat = 0) {
        guard draftOrder.indices.contains(first), draftOrder.indices.contains(second), first != second else { return }
        withAnimation(CollectionReorderMotion.swap) {
            draftOrder.swapAt(first, second)
            dragCompensation += delta
        }
    }
}

/// Блок коллекции (секция одного вида) — в режиме порядка его можно зажать в любом
/// месте и перетащить. Вне режима — ничего не меняется: жест выключен, содержимое
/// кликабельно, тряски нет. Дерево одно в обоих режимах (без `if`): иначе вход в режим
/// пересоздавал бы карусели и сбрасывал их прокрутку.
private struct CollectionReorderBlock<Content: View>: View {
    let kind: CollectionItem.Kind
    private let content: Content

    @Environment(CollectionReorderState.self) private var reorder
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(kind: CollectionItem.Kind, @ViewBuilder content: () -> Content) {
        self.kind = kind
        self.content = content()
    }

    var body: some View {
        let isReordering = reorder.isReordering
        let isHeld = reorder.heldKind == kind
        content
            // Тапы карточек, прокрутка каруселей и кнопки блока — выключены в режиме.
            .allowsHitTesting(!isReordering)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                reorder.setHeight(height, for: kind)
            }
            // Блок в руке обрезается по своему фону: карточки, уходящие за кромку стекла,
            // не торчат из него. Клип проявляется той же кривой, что и фон; вне захвата
            // он шире блока и ничего не режет.
            .clipShape(CollectionReorderClip(
                inset: isHeld ? CollectionReorderMotion.glassInset : CollectionReorderMotion.restClipInset,
                bottomExtra: bottomExtra
            ))
            .animation(glassAnimation(isHeld: isHeld), value: isHeld)
            .background { glass(isHeld: isHeld) }
            // Распознаватель — на неподвижном слое блока, до сдвига и масштаба:
            // хит-тест и координаты не зависят от того, где блок нарисован сейчас.
            .contentShape(.rect)
            .gesture(CollectionReorderPress(kind: kind, reorder: reorder, isActive: isReordering))
            .scaleEffect(isHeld && !reduceMotion ? CollectionReorderMotion.liftScale : 1)
            .animation(isHeld ? PressMotion.pressIn : PressMotion.release, value: isHeld)
            .modifier(CollectionReorderShake(kind: kind))
            .modifier(CollectionReorderOffset(kind: kind))
            .zIndex(reorder.liftedKind == kind ? 1 : 0)
    }

    /// Сколько фон и клип выходят ниже рамки блока: только у плейлистов.
    private var bottomExtra: CGFloat {
        switch kind {
        case .playlist: CollectionReorderMotion.glassBottomExtra
        case .movie, .book, .track, .artist, .album: 0
        }
    }

    /// Появление — сразу, исчезновение — после посадки блока (задержка = время посадки).
    private func glassAnimation(isHeld: Bool) -> Animation {
        isHeld
            ? CollectionReorderMotion.glassFade
            : CollectionReorderMotion.glassFade.delay(CollectionReorderMotion.settleDuration)
    }

    /// Фон блока в руке — стекло хрома: блюр не пропускает соседей. Проявляется на захвате,
    /// гаснет после того, как блок встал на место (задержка = время посадки).
    private func glass(isHeld: Bool) -> some View {
        Color.clear
            .chromeGlass(RoundedRectangle(cornerRadius: CollectionReorderMotion.glassRadius, style: .continuous))
            .padding(.horizontal, CollectionReorderMotion.glassInset)
            // Ниже рамки блока на `bottomExtra`: отрицательный нижний отступ, раскладка та же.
            .padding(.bottom, -bottomExtra)
            .opacity(isHeld ? 1 : 0)
            .animation(glassAnimation(isHeld: isHeld), value: isHeld)
            .allowsHitTesting(false)
    }
}

/// Захват блока — UIKit-распознаватель долгого нажатия (0.3 с, сдвиг до 10 pt). SwiftUI-
/// жест с нулевой дистанцией на ленте забирал касания у `ScrollView`, и в режиме она
/// не прокручивалась. У `UILongPressGestureRecognizer` быстрый свайп раньше 0.3 с
/// не распознаётся и уходит в пан прокрутки; удержание — захват, и тот же
/// распознаватель дальше отдаёт `.changed` с позицией пальца: это и есть драг.
/// `.ended` и `.cancelled` — отпускание.
///
/// Позиция пальца — в координатах содержимого ленты (`location(in: UIScrollView)`):
/// когда лента прокручивается, а палец стоит, сдвиг блока растёт сам и блок остаётся
/// под пальцем. Пока блок в руке и палец у верха или низа экрана, ленту катит
/// `CADisplayLink` напрямую через `UIScrollView` — покадровое не идёт через `@State`.
private struct CollectionReorderPress: UIGestureRecognizerRepresentable {
    let kind: CollectionItem.Kind
    let reorder: CollectionReorderState
    /// Вне режима распознаватель выключен — блок ведёт себя как обычно.
    let isActive: Bool

    @MainActor
    final class Coordinator: NSObject {
        /// Вертикаль пальца в окне (глобальные координаты конвертера SwiftUI) на захвате и сейчас.
        /// Окно не едет вместе с блоком, сдвиг блока на них не влияет.
        private var startGlobalY: CGFloat = 0
        private var lastGlobalY: CGFloat = 0
        /// Прокрутка ленты на захвате: сдвиг блока — это сдвиг пальца в окне плюс то,
        /// на сколько уехала лента (автопрокрутка).
        private var startOffsetY: CGFloat = 0
        weak var recognizer: UILongPressGestureRecognizer?
        weak var scrollView: UIScrollView?
        var reorder: CollectionReorderState?
        private var link: CADisplayLink?
        private var windowHeight: CGFloat = 0

        #if DEBUG
        /// `-debugReorderTrace 1` — строки `[reorder] …` в лог на каждый шаг жеста.
        private static let isTracing = UserDefaults.standard.bool(forKey: "debugReorderTrace")
        #endif

        /// Сдвиг блока от точки захвата: палец в окне + путь, который проехала лента.
        var translation: CGFloat {
            (lastGlobalY - startGlobalY) + ((scrollView?.contentOffset.y ?? 0) - startOffsetY)
        }

        func begin(_ recognizer: UILongPressGestureRecognizer, globalY: CGFloat, reorder: CollectionReorderState) {
            self.recognizer = recognizer
            self.reorder = reorder
            scrollView = Self.feedScrollView(for: recognizer)
            windowHeight = recognizer.view?.window?.bounds.height ?? 0
            startGlobalY = globalY
            lastGlobalY = globalY
            startOffsetY = scrollView?.contentOffset.y ?? 0
            #if DEBUG
            if Self.isTracing {
                NSLog("[reorder] view=%@", recognizer.view.map { String(describing: type(of: $0)) } ?? "nil")
                if scrollView == nil { NSLog("[reorder] лента не найдена: драг без автопрокрутки") }
            }
            #endif
            trace("began", globalY: globalY)
            // Автопрокрутке нужна лента; без неё драг работает, а часы не заводим.
            guard scrollView != nil else { return }
            link?.invalidate()
            let newLink = CADisplayLink(target: self, selector: #selector(tick(_:)))
            newLink.add(to: .main, forMode: .common)
            link = newLink
        }

        func end(globalY: CGFloat? = nil) {
            trace("ended", globalY: globalY ?? lastGlobalY)
            link?.invalidate()
            link = nil
            recognizer = nil
            scrollView = nil
            reorder = nil
        }

        /// Палец сдвинулся: блок идёт за ним, свап — той же функцией, что и у любого сдвига.
        func update(globalY: CGFloat) {
            lastGlobalY = globalY
            trace("changed", globalY: globalY)
            reorder?.drag(translation: translation)
        }

        /// Лента — вертикальный `UIScrollView` под пальцем. Распознаватель SwiftUI стоит
        /// на служебном виде, который не обязан лежать внутри ленты, поэтому ищем не от него,
        /// а `hitTest` окна по точке касания и поднимаемся по `superview`. Горизонтальные
        /// карусели (содержимое шире рамки) и ленты без запаса прокрутки пропускаем.
        private static func feedScrollView(for recognizer: UILongPressGestureRecognizer) -> UIScrollView? {
            func isFeed(_ view: UIView) -> UIScrollView? {
                guard let scroll = view as? UIScrollView,
                      scroll.contentSize.height > scroll.bounds.height + 1,
                      scroll.contentSize.width <= scroll.bounds.width + 1 else { return nil }
                return scroll
            }
            if let window = recognizer.view?.window {
                var view = window.hitTest(recognizer.location(in: window), with: nil)
                while let current = view {
                    if let scroll = isFeed(current) { return scroll }
                    view = current.superview
                }
            }
            var view = recognizer.view
            while let current = view {
                if let scroll = isFeed(current) { return scroll }
                view = current.superview
            }
            return nil
        }

        private func trace(_ event: String, globalY: CGFloat) {
            #if DEBUG
            guard Self.isTracing else { return }
            NSLog("[reorder] %@ y=%.1f tr=%.1f scroll=%.1f found=%d", event, globalY, translation, scrollView?.contentOffset.y ?? -1, scrollView == nil ? 0 : 1)
            #endif
        }

        @objc private func tick(_ link: CADisplayLink) {
            guard let recognizer, let scrollView, let reorder, reorder.heldKind != nil else {
                // Часы гасим, сам захват не трогаем: его закрывает распознаватель.
                link.invalidate()
                self.link = nil
                return
            }
            let speed = Self.autoScrollSpeed(fingerY: recognizer.location(in: nil).y, windowHeight: windowHeight)
            guard speed != 0 else { return }
            let dt = link.targetTimestamp - link.timestamp
            // Пределы — с учётом полей содержимого (`contentMargins` сверху и под хромом).
            let inset = scrollView.adjustedContentInset
            let minY = -inset.top
            let maxY = max(minY, scrollView.contentSize.height + inset.bottom - scrollView.bounds.height)
            let target = min(maxY, max(minY, scrollView.contentOffset.y + speed * dt))
            guard target != scrollView.contentOffset.y else { return }
            scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: target), animated: false)
            trace("scroll", globalY: lastGlobalY)
            reorder.drag(translation: translation)
        }

        /// Скорость прокрутки, pt/с (плюс — вниз): зона 80 pt под навбаром и над хромом,
        /// скорость пропорциональна глубине захода, до максимума; вне зон — стоп.
        /// Края зон — от констант хрома, а не от замера вью.
        static func autoScrollSpeed(fingerY: CGFloat, windowHeight: CGFloat) -> CGFloat {
            let zone = CollectionReorderMotion.autoScrollZone
            let top = ServiceTopNavLayout.topSafeArea + CollectionLayout.contentTop
            let bottomInset = windowSafeBottom + PlusChromeMetrics.contentBottomInset
            let bottom = windowHeight - bottomInset
            let upDepth = (top + zone - fingerY) / zone
            let downDepth = (fingerY - (bottom - zone)) / zone
            if upDepth > 0 { return -min(1, upDepth) * CollectionReorderMotion.autoScrollMaxSpeed }
            if downDepth > 0 { return min(1, downDepth) * CollectionReorderMotion.autoScrollMaxSpeed }
            return 0
        }

        private static var windowSafeBottom: CGFloat {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first { $0.isKeyWindow }?
                .safeAreaInsets.bottom ?? 0
        }
    }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    func makeUIGestureRecognizer(context: Context) -> UILongPressGestureRecognizer {
        let recognizer = UILongPressGestureRecognizer()
        recognizer.minimumPressDuration = CollectionReorderMotion.pressDuration
        recognizer.allowableMovement = CollectionReorderMotion.pressSlop
        recognizer.isEnabled = isActive
        return recognizer
    }

    func updateUIGestureRecognizer(_ recognizer: UILongPressGestureRecognizer, context: Context) {
        recognizer.isEnabled = isActive
    }

    func handleUIGestureRecognizerAction(_ recognizer: UILongPressGestureRecognizer, context: Context) {
        let coordinator = context.coordinator
        // Позиция — в глобальных координатах конвертера SwiftUI, а не в координатах вида
        // распознавателя: те могут ехать вместе с блоком.
        let globalY = context.converter.location(in: .global).y
        switch recognizer.state {
        case .began:
            coordinator.begin(recognizer, globalY: globalY, reorder: reorder)
            reorder.grab(kind)
        case .changed:
            coordinator.update(globalY: globalY)
        case .ended, .cancelled, .failed:
            coordinator.end(globalY: globalY)
            reorder.release(kind)
        default:
            break
        }
    }
}

/// Клип блока в руке — скруглённый прямоугольник со стеклянным фоном. Отступ от краёв
/// блока анимируется: в покое он отрицательный (клип шире блока на радиус — углы дуги
/// лежат за кромкой и ничего не режут), в руке — поле стекла. Вертикаль — рамка блока
/// и `bottomExtra` ниже неё (то же поле, что у стекла; в покое под рамкой нечего резать).
private struct CollectionReorderClip: Shape {
    var inset: CGFloat
    let bottomExtra: CGFloat

    var animatableData: CGFloat {
        get { inset }
        set { inset = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var frame = rect.insetBy(dx: inset, dy: 0)
        frame.size.height += bottomExtra
        return Path(
            roundedRect: frame,
            cornerRadius: CollectionReorderMotion.glassRadius,
            style: .continuous
        )
    }
}

/// Сдвиг блока в руке: палец — прямо, поправка на свап — вместе с анимацией свапа.
/// Читает сдвиг только у блока в руке, и только этот модификатор перерисовывается на
/// каждое событие жеста — содержимое блока не пересобирается.
private struct CollectionReorderOffset: ViewModifier {
    let kind: CollectionItem.Kind
    @Environment(CollectionReorderState.self) private var reorder

    func body(content: Content) -> some View {
        let isLifted = reorder.liftedKind == kind
        // Два сдвига, а не сумма: у поправки своя анимация, у пальца её нет — одна
        // сумма обрывала бы анимацию поправки на каждом событии жеста.
        content
            .offset(y: isLifted ? reorder.dragCompensation : 0)
            .offset(y: isLifted ? reorder.dragTranslation : 0)
    }
}

/// Тряска блоков, как у иконок iOS в режиме правки: угол `A·sin(2π·t/T + φ)` и подскок
/// `0.6·sin(2π·t/T + φ + π/2)` — аналитическая функция времени, ничего не пишется
/// в `@State`. `TimelineView` стоит в дереве всегда (иначе вход в режим пересоздавал бы
/// содержимое блока), но на паузе, пока режим выключен и амплитуда дошла до нуля, —
/// в покое ни одного тика. Reduce Motion — без тряски.
private struct CollectionReorderShake: ViewModifier {
    let kind: CollectionItem.Kind
    @Environment(CollectionReorderState.self) private var reorder
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let amount: Double = reorder.isReordering && reorder.liftedKind != kind && !reduceMotion ? 1 : 0
        let phase = Double(CollectionItem.Kind.allCases.firstIndex(of: kind) ?? 0) * CollectionReorderMotion.shakePhaseStep
        TimelineView(.animation(paused: !reorder.isClockRunning || reduceMotion)) { timeline in
            content
                .modifier(CollectionShakeEffect(
                    amount: amount,
                    time: timeline.date.timeIntervalSinceReferenceDate,
                    phase: phase
                ))
                .animation(CollectionReorderMotion.shakeFade, value: amount)
        }
    }
}

/// Один кадр тряски. Анимируется только `amount` (вход и выход), время подаёт `TimelineView`.
private struct CollectionShakeEffect: GeometryEffect {
    var amount: Double
    let time: Double
    let phase: Double

    var animatableData: Double {
        get { amount }
        set { amount = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        guard amount > 0 else { return ProjectionTransform(.identity) }
        // Время по модулю периода: иначе у больших значений sin теряет точность.
        let period = CollectionReorderMotion.shakePeriod
        let angle = 2 * Double.pi * time.truncatingRemainder(dividingBy: period) / period + phase
        let rotation = amount * CollectionReorderMotion.shakeAngle * .pi / 180 * sin(angle)
        let lift = amount * CollectionReorderMotion.shakeLift * sin(angle + .pi / 2)
        let transform = CGAffineTransform(translationX: size.width / 2, y: size.height / 2 + lift)
            .rotated(by: rotation)
            .translatedBy(x: -size.width / 2, y: -size.height / 2)
        return ProjectionTransform(transform)
    }
}

/// Иконка-хват в шапке блока (`2584:29425`) — на месте шеврона, появляется кросс-попом.
private struct CollectionReorderGrip: View {
    static let size: CGFloat = 20

    let isVisible: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Image("iconDragHandle")
            .renderingMode(.template)
            .resizable()
            .frame(width: Self.size, height: Self.size)
            .foregroundStyle(Color.fillSubtitle)
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible || reduceMotion ? 1 : ActionBarMotion.iconSwapScale)
            .animation(reduceMotion ? .easeInOut(duration: 0.2) : ActionBarMotion.iconSwap, value: isVisible)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// Кнопка навбара «изменить порядок» ↔ «готово» (`2584:26578`): голая иконка 20 без
/// подложки, зона тапа 40; иконки меняются кросс-попом, как у сердца и play/pause.
private struct CollectionReorderButton: View {
    let isEnabled: Bool
    let action: () -> Void

    @Environment(CollectionReorderState.self) private var reorder
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let box: CGFloat = 20
    /// Зона тапа 40 при иконке 20: поле под отрицательным отступом, раскладка не едет.
    private static let hitInset: CGFloat = 10

    var body: some View {
        let isReordering = reorder.isReordering
        let swapScale = reduceMotion ? 1 : ActionBarMotion.iconSwapScale
        Button(action: action) {
            ZStack {
                glyph("iconChangeOrder", color: .fillSubtitle)
                    .opacity(isReordering ? 0 : 1)
                    .scaleEffect(isReordering ? swapScale : 1)
                glyph("iconDone", color: .moviesAccent)
                    .opacity(isReordering ? 1 : 0)
                    .scaleEffect(isReordering ? 1 : swapScale)
            }
            .animation(reduceMotion ? .easeInOut(duration: 0.2) : ActionBarMotion.iconSwap, value: isReordering)
            .padding(Self.hitInset)
            .contentShape(.rect)
        }
        .buttonStyle(PressScaleButtonStyle())
        .padding(-Self.hitInset)
        .disabled(!isEnabled)
        // Блоков меньше двух — переставлять нечего: кнопка приглушена, место за ней держится.
        .opacity(isEnabled ? 1 : CollectionReorderMotion.disabledOpacity)
        .animation(.easeInOut(duration: 0.2), value: isEnabled)
        .accessibilityLabel(isReordering ? "Готово" : "Изменить порядок")
    }

    /// «Изменить порядок» — приглушённый белый, «Готово» — фиолетовый акцент приложения;
    /// цвет меняется вместе с иконкой, кросс-попом.
    private func glyph(_ name: String, color: Color) -> some View {
        Image(name)
            .renderingMode(.template)
            .resizable()
            .frame(width: Self.box, height: Self.box)
            .foregroundStyle(color)
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
