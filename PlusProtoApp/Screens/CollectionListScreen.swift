import SwiftUI

/// Полный список коллекции — переход из заголовка карусели: вид полки или секция
/// экранов «Кино» и «Книги» (`CollectionServiceScreen`).
struct CollectionListRoute: Hashable {
    enum Source: Hashable {
        /// Вид полки — «Альбомы» «Любимого», «Кино» «Скачанного», «Буду смотреть»…
        case shelf(CollectionItem.Kind, CollectionStore.Shelf)
        /// Плейлисты «Любимого» — с чипсами «Мои» и «Любимые» (задача пользователя
        /// 2026-10-20); значение — чипс, с которым экран открывается
        case playlists(CollectionListFilter)
        /// «Покупки» — стартовый набор (`CollectionSeeds.purchases`)
        case purchases
        /// «Читаю» — начатые книги (`ReadingHistory`)
        case reading
        /// «Прочитано» — стартовый набор (`CollectionSeeds.read`)
        case read
    }

    let source: Source
    /// Название в навбаре — заголовок карусели, из которой пришли
    let title: String
}

extension CollectionListRoute.Source {
    /// Полка, чьи отметки показывает список, — её снимает «Удалить» в шторке записи.
    /// «Покупки», «Читаю», «Прочитано» и свои плейлисты — без отметок.
    var shelf: CollectionStore.Shelf? {
        switch self {
        case .shelf(_, let shelf): shelf
        case .playlists(let filter): filter == .liked ? .favorites : nil
        case .purchases, .reading, .read: nil
        }
    }
}

/// Чипсы полных списков: плейлисты «Любимого» и «Буду смотреть».
enum CollectionListFilter: Hashable {
    /// Свои плейлисты — первой строкой «Новый плейлист» (создание не делаем,
    /// решение пользователя 2026-10-20), дальше стартовый набор `MyPlaylists`.
    case mine
    /// Отмеченные «нравится» — плейлисты полки
    case liked
    /// «Буду смотреть» целиком
    case all
    /// Только то, что есть в Кинопоиске (`MovieAvailability`, 2026-10-22)
    case watchable

    /// Чипсы источника; `nil` — список без чипсов.
    static func options(for source: CollectionListRoute.Source) -> [CollectionListFilter]? {
        switch source {
        case .playlists: [.mine, .liked]
        case .shelf(.movie, .favorites): [.all, .watchable]
        default: nil
        }
    }

    /// Короткие названия — правка пользователя 2026-10-20 (были «Мои плейлисты»
    /// и «Понравившиеся плейлисты»).
    var title: String {
        switch self {
        case .mine: "Мои"
        case .liked: "Любимые"
        case .all: "Все"
        case .watchable: "Можно посмотреть"
        }
    }
}

/// Числа полных списков — `list-item / music` макета Музыки (`2128:94020`).
enum CollectionListLayout {
    /// Строка 96: обложка 80 и поля 8, между обложкой и текстом 12
    static let cover: CGFloat = 80
    static let coverRadius: CGFloat = 12
    /// Постер фильма и книга — той же ширины, что обложка альбома и плейлиста, а высота —
    /// своя (правка пользователя 2026-10-04): постер 2:3 — 80 × 120, строка выше
    static let posterHeight: CGFloat = cover * 3 / 2

    /// Книга — карточка книги (`card / book`) шириной 80, как обложка альбома; высота —
    /// от пропорций обложки, поэтому строки книг разной высоты.
    static func book(aspect: CGFloat?) -> BookFigureGeometry {
        BookFigureGeometry.fitting(width: cover, aspect: aspect).geometry
    }
    static let side: CGFloat = 16
    static let rowPadding: CGFloat = 8
    static let textGap: CGFloat = 12
    static let controlsGap: CGFloat = 8
    static let titleLines = 2
    /// Список — на 8 ниже навбара (`stack` макета)
    static let listTop: CGFloat = 8
    /// «+» в квадрате строки «Новый плейлист» (`18122:11880`)
    static let addIcon: CGFloat = 24
}

/// Полные списки коллекции «Моё» — по макету полных списков Музыки (`2128:94020`,
/// задача пользователя 2026-10-04), с нашим навбаром: «назад» и название карусели,
/// из которой пришли. Чипсов других видов нет (задача пользователя 2026-10-19): у «Кино»
/// и «Книг» свои экраны, у остальных видов — свой список.
///
/// Строки — `list-item / music`: обложка 80, название в две строки и деталь, справа
/// отметка «скачано» и «ещё» с действиями записи; тап открывает сущность, трек
/// и плейлист — играют.
struct CollectionListScreen: View {
    let route: CollectionListRoute

    @Environment(CollectionStore.self) private var collection
    @Environment(ActionBarState.self) private var actionBar
    @State private var scrollOffset: CGFloat = 0
    @State private var scrollPosition = ScrollPosition(edge: .top)
    /// Выбранный чипс и показанный список: смена — старый гаснет, новый проявляется.
    @State private var filter: CollectionListFilter?
    @State private var shownFilter: CollectionListFilter?
    @State private var listOpacity: Double = 1
    @State private var swap: Task<Void, Never>?

    init(route: CollectionListRoute) {
        self.route = route
        if case .playlists(let start) = route.source {
            _filter = State(initialValue: start)
            _shownFilter = State(initialValue: start)
        } else if let first = CollectionListFilter.options(for: route.source)?.first {
            _filter = State(initialValue: first)
            _shownFilter = State(initialValue: first)
        }
    }

    private var filterOptions: [CollectionListFilter] {
        CollectionListFilter.options(for: route.source) ?? []
    }

    private var items: [CollectionItem] {
        switch route.source {
        case .shelf(let kind, let shelf):
            // «Можно посмотреть» — только то, что есть в Кинопоиске.
            shownFilter == .watchable
                ? collection.items(kind, on: shelf).filter {
                    // Сериалы смотреть можно всегда — ограничение только у фильмов (решение
                    // пользователя 2026-10-31).
                    $0.isSeries == true || ($0.kinopoiskID.map(MovieAvailability.shared.isAvailable) ?? false)
                }
                : collection.items(kind, on: shelf)
        case .playlists:
            // «Мои» — стартовый набор своих плейлистов (`MyPlaylists`), «Любимые» — полка.
            shownFilter == .liked ? collection.items(.playlist, on: .favorites) : MyPlaylists.items
        case .purchases: CollectionSeeds.purchases
        case .reading: CollectionMix.readingItems(actionBar.readingHistory)
        case .read: CollectionSeeds.read
        }
    }

    /// Строка-действие первой в списке: «Новый плейлист» у «Моих плейлистов»
    /// (`18122:11880`), «Кого ещё слушаете?» у любимых исполнителей (`18122:12950`).
    private var leadingAction: CollectionListAction? {
        if shownFilter == .mine { return .createPlaylist }
        if case .shelf(.artist, .favorites) = route.source { return .addArtists }
        return nil
    }

    private var showsCreateRow: Bool { leadingAction != nil }

    var body: some View {
        let items = items
        ZStack {
            Color.surfaceOne.ignoresSafeArea()

            ScrollView {
                // Чипсы — закреплённым заголовком внутри ленты (`PinnedFilterChips`).
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    Section {
                        list(items)
                    } header: {
                        if filter != nil { chips }
                    }
                }
            }
            .scrollIndicators(.hidden)
            .contentMargins(.top, EntityNavBarGeometry.barHeight, for: .scrollContent)
            .scrollPosition($scrollPosition)
            .trackNavBarScroll(into: $scrollOffset)

            // Пустой список гаснет и проявляется вместе со строками — той же прозрачностью.
            if items.isEmpty, !showsCreateRow {
                Text("Здесь пока ничего нет")
                    .plusText(.textM, .medium)
                    .foregroundStyle(Color.fillSubtitle)
                    .opacity(listOpacity)
            }
        }
        .overlay(alignment: .top) {
            EntityNavBar(
                title: route.title,
                scrollOffset: scrollOffset,
                thresholds: filter == nil ? Self.navThresholds : PinnedFilterChipsLayout.navThresholds
            ) {
                // «+» у плейлистов — создать плейлист (правка пользователя 2026-10-20):
                // круг того же вида, что «назад». Само создание пока не делаем — кнопка
                // только откликается. Только у плейлистов: у «Буду смотреть» чипсы есть,
                // а «+» нет (правка пользователя 2026-10-22).
                if case .playlists = route.source {
                    PlusButton(icon: "iconAdd", type: .chrome, size: .m, accessibilityTitle: "Создать плейлист") {}
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: filter) { _, selected in swapList(to: selected) }
        // «Буду смотреть»: где смотреть — заранее, к тапу по «Можно посмотреть» уже известно.
        .task {
            guard case .shelf(.movie, .favorites) = route.source else { return }
            await MovieAvailability.shared.load(collection.items(.movie, on: .favorites).compactMap(\.kinopoiskID))
        }
    }

    private func list(_ items: [CollectionItem]) -> some View {
        LazyVStack(spacing: 0) {
            if let leadingAction {
                CollectionActionRow(action: leadingAction)
            }
            // Очередь — треки списка по порядку.
            let queue = items.filter { $0.kind == .track }.compactMap(\.playable)
            ForEach(items) { item in
                let isFirst = !showsCreateRow && item.id == items.first?.id
                // «Скачанное кино» — строками с кадром, как «Загрузки» Кинопоиска.
                if case .shelf(.movie, .downloads) = route.source {
                    CollectionDownloadRow(item: item, isFirst: isFirst)
                } else {
                    CollectionListRow(
                        item: item,
                        queue: queue,
                        isFirst: isFirst,
                        shelf: route.source.shelf,
                        // «Читаю» — сразу читалка (правка пользователя 2026-10-20).
                        readBook: route.source == .reading ? CollectionMix.readBook(item.id, in: actionBar.readingHistory) : nil
                    )
                }
            }
        }
        .padding(.top, CollectionListLayout.listTop)
        // Строки съезжают плавно, когда отметку сняли в этом же списке.
        .animation(CollectionMotion.itemsChange, value: items.map(\.id))
        // Список другого чипса — новый целиком, а не те же строки с другим содержимым:
        // смена — одной прозрачностью (правка пользователя 2026-10-04).
        .id(shownFilter)
        .opacity(listOpacity)
    }

    private var chips: some View {
        PinnedFilterChips(
            options: filterOptions,
            selection: Binding(get: { filter ?? filterOptions[0] }, set: { filter = $0 }),
            title: \.title,
            scrollOffset: scrollOffset
        )
    }

    /// Старый список гаснет, в паузе подменяется и уезжает к началу, новый проявляется.
    /// Быстрые нажатия подряд прерывают незаконченную смену: показан последний выбранный.
    private func swapList(to selected: CollectionListFilter?) {
        swap?.cancel()
        guard selected != shownFilter else {
            withAnimation(CollectionListMotion.fadeIn) { listOpacity = 1 }
            return
        }
        swap = Task { @MainActor in
            withAnimation(CollectionListMotion.fadeOut) { listOpacity = 0 }
            try? await Task.sleep(for: CollectionListMotion.fadeOutDuration)
            guard !Task.isCancelled else { return }
            shownFilter = selected
            scrollPosition.scrollTo(edge: .top)
            withAnimation(CollectionListMotion.fadeIn) { listOpacity = 1 }
        }
    }


    /// Название карусели в баре — всегда, и при оттяге тоже: это свой тип навбара, а не
    /// название сущности, проявляющееся по скроллу (правка пользователя 2026-10-04).
    /// Подложка проявляется с первых пунктов скролла — чипсов с их подложкой больше нет.
    static let navThresholds = EntityNavBarThresholds(
        backgroundStart: 0,
        backgroundRamp: ServiceTopNavMotion.backdropRamp,
        titleStart: -.greatestFiniteMagnitude,
        titleRamp: 0
    )
}

/// Смена полок коллекции — те же 300 + 300 мс, что у полной выдачи поиска.
enum CollectionListMotion {
    static let fadeOutDuration: Duration = .milliseconds(300)
    static let fadeOut: Animation = .easeInOut(duration: 0.3)
    static let fadeIn: Animation = .easeInOut(duration: 0.3)
}

// MARK: - Строка-действие

/// Строка-действие в начале полного списка — тексты макета «Общей коллекции»
/// (решение пользователя 2026-10-28).
enum CollectionListAction {
    /// «Новый плейлист» — «Плейлисты · Мои», `18122:11480`
    case createPlaylist
    /// «Кого ещё слушаете?» — переход в визард любимых исполнителей, «Исполнители»,
    /// `18122:12585`
    case addArtists

    var title: String {
        switch self {
        case .createPlaylist: "Новый плейлист"
        case .addArtists: "Кого ещё слушаете?"
        }
    }

    /// Вторая строка серым — Text M, перенос — как в макете.
    var subtitle: String? {
        switch self {
        case .createPlaylist: nil
        case .addArtists: "Добавьте любимых —\nрекомендации станут точнее"
        }
    }

    /// Обложка — круг у исполнителей, квадрат r12 у плейлиста: форма строк списка.
    var isCircle: Bool { self == .addArtists }
}

/// Строка-действие — `list-item / music` (`18122:11880`, `18122:12950`): квадрат 80 r12
/// (у исполнителей — круг) с заливкой и бордером Fill/Nine и «+» 24 по центру, название
/// Text M и вплотную под ним серым Text M, справа шеврон. Действий пока нет (решения
/// пользователя 2026-10-20) — строка только откликается нажатием и хаптикой.
private struct CollectionActionRow: View {
    let action: CollectionListAction

    var body: some View {
        HStack(spacing: CollectionListLayout.textGap) {
            cover
                .frame(width: CollectionListLayout.cover, height: CollectionListLayout.cover)
                .overlay {
                    Image("iconAdd")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: CollectionListLayout.addIcon, height: CollectionListLayout.addIcon)
                        .foregroundStyle(Color.fillFive)
                }

            VStack(alignment: .leading, spacing: 0) {
                Text(action.title)
                    .plusText(.textM, .medium)
                    .foregroundStyle(Color.fillOne)
                    .lineLimit(1)
                if let subtitle = action.subtitle {
                    Text(subtitle)
                        .plusText(.textM, .medium)
                        .foregroundStyle(Color.fillSubtitle)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Правый шеврон — отзеркаленный `icon / dropleft`, как у шапок секций.
            Image("iconDropleft")
                .renderingMode(.template)
                .resizable()
                .frame(width: EntitySectionLayout.chevronBox, height: EntitySectionLayout.chevronBox)
                .scaleEffect(x: -1)
                .foregroundStyle(Color.fillFive)
        }
        .padding(.horizontal, CollectionListLayout.side)
        .padding(.vertical, CollectionListLayout.rowPadding)
        .contentShape(.rect)
        .pressScale(PressMotion.rowScale)
        .overlay(alignment: .top) { divider }
        .overlay(alignment: .bottom) { divider }
        .onTapGesture { PlayerHaptics.tap() }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    /// Подложка обложки — Fill/Nine и бордер обложек внутрь (`. / card / image-music`).
    @ViewBuilder
    private var cover: some View {
        if action.isCircle {
            Circle().fill(Color.fillNine).coverBorder(Circle())
        } else {
            let shape = RoundedRectangle(cornerRadius: CollectionListLayout.coverRadius, style: .continuous)
            shape.fill(Color.fillNine).coverBorder(shape)
        }
    }

    private var divider: some View {
        ListDivider()
            .padding(.horizontal, CollectionListLayout.side)
    }
}

// MARK: - Строка

/// Строка полного списка — `list-item / music`: обложка 80 (у книги — карточка книги
/// шириной 80), название Text M в две строки с бейджем 18+, деталь серым; справа — свои
/// контролы места. Разделители 0.5, проседает строка, а не черты. Общая у полных списков
/// «Моего» и книг писателя (задача пользователя 2026-10-30: «как в коллекции, но со своими
/// props»): что справа и что по тапу — у вызывающего.
struct CollectionListItem<Thumbnail: View, Trailing: View>: View {
    let title: String
    var subtitle: String = ""
    /// Подпись частями через точку — вместо `subtitle` («Альбом · Blur», таб «Музыка»
    /// выдачи поиска, макет `19151:18648`).
    var caption: [CaptionPart] = []
    var isExplicit = false
    let isFirst: Bool
    /// Строка внутри кнопки — проседает под пальцем; без перехода — стоит.
    var isPressable = true
    @ViewBuilder var thumbnail: Thumbnail
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: CollectionListLayout.textGap) {
            thumbnail

            VStack(alignment: .leading, spacing: EntitySectionLayout.textStackGap) {
                HStack(spacing: 6) {
                    Text(title)
                        .plusText(.textM, .medium)
                        .foregroundStyle(Color.fillOne)
                        .lineLimit(CollectionListLayout.titleLines)
                    if isExplicit {
                        EntityExplicitBadge()
                    }
                }
                if !caption.isEmpty {
                    DotCaptionLine(parts: caption)
                } else if !subtitle.isEmpty {
                    Text(subtitle)
                        .plusText(.textM, .medium)
                        .foregroundStyle(Color.fillSubtitle)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            trailing
        }
        .padding(.horizontal, CollectionListLayout.side)
        .padding(.vertical, CollectionListLayout.rowPadding)
        .frame(minHeight: CollectionListLayout.cover + 2 * CollectionListLayout.rowPadding)
        .contentShape(.rect)
        // Проседает строка, а черты стоят: просевшая черта короче соседних и съезжает.
        .pressScale(PressMotion.rowScale, isEnabled: isPressable)
        .overlay(alignment: .bottom) { divider }
        .overlay(alignment: .top) { if isFirst { divider } }
    }

    private var divider: some View {
        ListDivider()
            .padding(.horizontal, CollectionListLayout.side)
    }
}

/// Обложка книги в строке списка — карточка книги (`card / book`) шириной 80, высота —
/// от пропорций обложки. `nil` — скелетон.
struct CollectionListBookCover: View {
    let artwork: ArtworkSource?
    let aspect: CGFloat?

    var body: some View {
        let book = BookFigureGeometry.fitting(width: CollectionListLayout.cover, aspect: aspect)
        BookFigure(geometry: book.geometry, coverWidth: book.coverWidth) {
            if let artwork {
                SkeletonArtwork(source: artwork)
            }
        }
    }
}

/// Скелетон строки с книгой — того же габарита, пока список собирается.
struct CollectionListBookSkeletonRow: View {
    let isFirst: Bool

    var body: some View {
        CollectionListItem(title: "", isFirst: isFirst, isPressable: false) {
            CollectionListBookCover(artwork: nil, aspect: nil)
        } trailing: {
            EmptyView()
        }
        .overlay(alignment: .leading) {
            VStack(alignment: .leading, spacing: 8) {
                SkeletonBar(width: 160)
                SkeletonBar(width: 100)
            }
            .padding(.leading, CollectionListLayout.side + CollectionListLayout.cover + CollectionListLayout.textGap)
        }
        .accessibilityHidden(true)
    }
}

/// Строка полного списка — `list-item / music`: обложка 80 (квадрат r12, у исполнителя
/// круг, у фильма постер 2:3, у книги наша проекция), название Text M в две строки
/// с бейджем 18+, деталь серым; справа отметка «скачано» и «ещё». Разделители 0.5.
private struct CollectionListRow: View {
    let item: CollectionItem
    /// Треки показанного списка — очередь, если строка сама трек.
    let queue: [MusicNowPlaying]
    let isFirst: Bool
    /// Полка списка — для действий записи (`nil` — список без отметок).
    let shelf: CollectionStore.Shelf?
    /// Начатая книга «Читаю»: тап — читалка, а не экран книги.
    var readBook: BookInProgress? = nil

    @Environment(CollectionStore.self) private var collection
    @Environment(AppNavigationState.self) private var navigation
    @Environment(ActionBarState.self) private var actionBar
    @Environment(\.stackZoomNamespace) private var zoom

    var body: some View {
        CollectionListItem(
            title: item.title,
            subtitle: item.subtitle,
            isExplicit: item.isExplicit == true,
            isFirst: isFirst
        ) {
            thumbnail
        } trailing: {
            HStack(spacing: CollectionListLayout.controlsGap) {
                if collection.isDownloaded(item.id) {
                    Image("iconDownload")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: CollectionLayout.downloadIcon, height: CollectionLayout.downloadIcon)
                        .foregroundStyle(Color.accentPrimary)
                        .accessibilityLabel("Скачано")
                }
                CollectionItemMoreButton(item: item, shelf: shelf)
            }
        }
        .onTapGesture(perform: open)
        .collectionItemActions(item, shelf: shelf)
    }

    @ViewBuilder
    private var thumbnail: some View {
        switch item.kind {
        case .movie:
            source(CollectionArtwork(
                source: item.artwork,
                width: CollectionListLayout.cover,
                height: CollectionListLayout.posterHeight,
                shape: RoundedRectangle(cornerRadius: CollectionListLayout.coverRadius, style: .continuous)
            ))
        case .book where item.isAudiobook:
            // Аудиокнига — квадрат, как в каруселях (`AudiobookFigure`); в строке — тем же
            // квадратом, что альбомы и треки списка (просьба пользователя 2026-10-31).
            source(CollectionArtwork(
                source: item.artwork,
                width: CollectionListLayout.cover,
                height: CollectionListLayout.cover,
                shape: RoundedRectangle(cornerRadius: CollectionListLayout.coverRadius, style: .continuous)
            ))
        case .book:
            source(bookFigure)
        case .artist:
            source(CollectionArtwork(
                source: item.artwork,
                width: CollectionListLayout.cover,
                height: CollectionListLayout.cover,
                shape: Circle()
            ))
        case .track, .album, .playlist:
            source(CollectionArtwork(
                source: item.artwork,
                width: CollectionListLayout.cover,
                height: CollectionListLayout.cover,
                shape: RoundedRectangle(cornerRadius: CollectionListLayout.coverRadius, style: .continuous)
            ))
        }
    }

    private var bookFigure: some View {
        CollectionListBookCover(artwork: item.artwork, aspect: item.aspect)
    }

    /// Обложка — источник зума в экран сущности, как карточки коллекции.
    @ViewBuilder
    private func source(_ view: some View) -> some View {
        if let route = item.route, item.kind != .track, let zoom {
            view.matchedTransitionSource(id: route, in: zoom)
        } else {
            view
        }
    }


    /// Трек и плейлист играют сразу, остальные открывают свой экран.
    private func open() {
        // Отпускание после долгого нажатия, открывшего шторку, — не тап.
        guard !ActionSheetState.shared.isPresented else { return }
        if let readBook {
            UIImpactFeedbackGenerator(style: .medium)
                .impactOccurred(intensity: ShowcaseMotion.tapHapticIntensity)
            actionBar.open(.book(readBook))
        } else if item.kind != .track, let route = item.route {
            navigation.open(route)
        } else if let playable = item.playable {
            PlayerHaptics.tap()
            // Очередь — только у трека: плейлист в неё не входит и играет один.
            actionBar.open(.music(playable), queue: item.kind == .track ? queue : [])
        }
    }
}
