import SwiftUI

/// Полный список коллекции — переход из заголовка карусели: вид полки или секция
/// экранов «Кино» и «Книги» (`CollectionServiceScreen`).
struct CollectionListRoute: Hashable {
    enum Source: Hashable {
        /// Вид полки — «Альбомы» «Любимого», «Кино» «Скачанного», «Буду смотреть»…
        case shelf(CollectionItem.Kind, CollectionStore.Shelf)
        /// Плейлисты «Любимого» — с чипсами «Мои» и «Любимые» (задача пользователя
        /// 2026-10-20); значение — чипс, с которым экран открывается
        case playlists(CollectionPlaylistFilter)
        /// «Покупки» — стартовый набор (`CollectionSeeds.purchases`)
        case purchases
        /// «Мои оценки» — оценённые фильмы (`MovieRatings`)
        case ratings
        /// «Читаю» — начатые книги (`ReadingHistory`)
        case reading
        /// «Прочитано» — стартовый набор (`CollectionSeeds.read`)
        case read
    }

    let source: Source
    /// Название в навбаре — заголовок карусели, из которой пришли
    let title: String
}

/// Чипсы списка плейлистов «Любимого».
enum CollectionPlaylistFilter: Hashable, CaseIterable {
    /// Свои плейлисты — первой строкой «Создать новый плейлист» (создание не делаем,
    /// решение пользователя 2026-10-20), дальше стартовый набор `MyPlaylists`.
    case mine
    /// Отмеченные «нравится» — плейлисты полки
    case liked

    /// Короткие названия — правка пользователя 2026-10-20 (были «Мои плейлисты»
    /// и «Понравившиеся плейлисты»).
    var title: String {
        switch self {
        case .mine: "Мои"
        case .liked: "Любимые"
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

    /// Книга — наша проекция шириной 80 вместе с выступом страниц справа; высота
    /// обложки — от её пропорций, поэтому строки книг разной высоты.
    static func book(aspect: CGFloat?) -> BookFigureGeometry {
        let range = BookFigureGeometry.aspectRange
        let clamped = min(max(aspect ?? BookFigureGeometry.defaultAspect, range.lowerBound), range.upperBound)
        // Кадр книги — обложка и выступ страниц: 2 на каждые 128 высоты.
        return BookFigureGeometry(coverHeight: cover / (clamped + 2 / BookFigureGeometry.referenceHeight))
    }
    static let side: CGFloat = 16
    static let rowPadding: CGFloat = 8
    static let textGap: CGFloat = 12
    static let controlsGap: CGFloat = 8
    static let titleLines = 2
    /// Список — на 8 ниже навбара (`stack` макета)
    static let listTop: CGFloat = 8
    /// «+» в квадрате строки «Создать новый плейлист» (`2871:77052`)
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
    @State private var filter: CollectionPlaylistFilter?
    @State private var shownFilter: CollectionPlaylistFilter?
    @State private var listOpacity: Double = 1
    @State private var swap: Task<Void, Never>?

    init(route: CollectionListRoute) {
        self.route = route
        if case .playlists(let start) = route.source {
            _filter = State(initialValue: start)
            _shownFilter = State(initialValue: start)
        }
    }

    private var items: [CollectionItem] {
        switch route.source {
        case .shelf(let kind, let shelf): collection.items(kind, on: shelf)
        case .playlists:
            // «Мои» — стартовый набор своих плейлистов (`MyPlaylists`), «Любимые» — полка.
            shownFilter == .liked ? collection.items(.playlist, on: .favorites) : MyPlaylists.items
        case .purchases: CollectionSeeds.purchases
        case .ratings: MovieRatings.shared.entries.map(\.item)
        case .reading: CollectionMix.readingItems(actionBar.readingHistory)
        case .read: CollectionSeeds.read
        }
    }

    /// Строка-действие первой в списке: «Создать новый плейлист» у «Моих плейлистов»
    /// (`2871:77052`), «Добавить исполнителей» у любимых исполнителей (`2877:77621`).
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
                // только откликается.
                if filter != nil {
                    PlusButton(icon: "iconAdd", type: .chrome, size: .m, accessibilityTitle: "Создать плейлист") {}
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: filter) { _, selected in swapList(to: selected) }
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
                        // «Читаю» — сразу читалка (правка пользователя 2026-10-20).
                        readBook: route.source == .reading ? CollectionMix.readBook(item.id, in: actionBar.readingHistory) : nil,
                        rating: route.source == .ratings ? MovieRatings.shared.rating(for: item.id) : nil
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
            options: CollectionPlaylistFilter.allCases,
            selection: Binding(get: { filter ?? .mine }, set: { filter = $0 }),
            title: \.title,
            scrollOffset: scrollOffset
        )
    }

    /// Старый список гаснет, в паузе подменяется и уезжает к началу, новый проявляется.
    /// Быстрые нажатия подряд прерывают незаконченную смену: показан последний выбранный.
    private func swapList(to selected: CollectionPlaylistFilter?) {
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

/// Строка-действие в начале полного списка.
enum CollectionListAction {
    /// «Создать новый плейлист» — `2871:77052`
    case createPlaylist
    /// «Добавить исполнителей» — `2877:77621`
    case addArtists

    var title: String {
        switch self {
        case .createPlaylist: "Создать новый плейлист"
        case .addArtists: "Добавить исполнителей"
        }
    }

    /// Вторая строка серым — Text S, перенос — как в макете.
    var subtitle: String? {
        switch self {
        case .createPlaylist: nil
        case .addArtists: "Чем их больше, тем лучше\nрекомендации"
        }
    }

    /// Обложка — круг у исполнителей, квадрат r12 у плейлиста: форма строк списка.
    var isCircle: Bool { self == .addArtists }
}

/// Строка-действие — `list-item / music` (`2871:77052`, `2877:77621`): квадрат 80 r12
/// (у исполнителей — круг) с заливкой Fill/Nine и «+» 24 по центру, название Text M
/// и серым Text S, справа шеврон. Действий пока нет (решения пользователя 2026-10-20) —
/// строка только откликается нажатием и хаптикой.
private struct CollectionActionRow: View {
    let action: CollectionListAction

    private enum Layout {
        /// Название — описание (`gap-[2px]` text-label)
        static let titleToSubtitle: CGFloat = 2
    }

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

            VStack(alignment: .leading, spacing: Layout.titleToSubtitle) {
                Text(action.title)
                    .plusText(.textM, .medium)
                    .foregroundStyle(Color.fillOne)
                    .lineLimit(1)
                if let subtitle = action.subtitle {
                    Text(subtitle)
                        .plusText(.textS, .medium)
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

    @ViewBuilder
    private var cover: some View {
        if action.isCircle {
            Circle().fill(Color.fillNine)
        } else {
            RoundedRectangle(cornerRadius: CollectionListLayout.coverRadius, style: .continuous)
                .fill(Color.fillNine)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(CollectionLayout.divider)
            .frame(height: 0.5)
            .padding(.horizontal, CollectionListLayout.side)
    }
}

// MARK: - Строка

/// Строка полного списка — `list-item / music`: обложка 80 (квадрат r12, у исполнителя
/// круг, у фильма постер 2:3, у книги наша проекция), название Text M в две строки
/// с бейджем 18+, деталь серым; справа отметка «скачано» и «ещё». Разделители 0.5.
private struct CollectionListRow: View {
    let item: CollectionItem
    /// Треки показанного списка — очередь, если строка сама трек.
    let queue: [MusicNowPlaying]
    let isFirst: Bool
    /// Начатая книга «Читаю»: тап — читалка, а не экран книги.
    var readBook: BookInProgress? = nil
    /// «Мои оценки» — эмодзи оценки над углом постера, как у карточки карусели.
    var rating: MovieRating? = nil

    @Environment(CollectionStore.self) private var collection
    @Environment(AppNavigationState.self) private var navigation
    @Environment(ActionBarState.self) private var actionBar
    @Environment(\.stackZoomNamespace) private var zoom

    var body: some View {
        HStack(spacing: CollectionListLayout.textGap) {
            thumbnail

            VStack(alignment: .leading, spacing: EntitySectionLayout.textStackGap) {
                HStack(spacing: 6) {
                    Text(item.title)
                        .plusText(.textM, .medium)
                        .foregroundStyle(Color.fillOne)
                        .lineLimit(CollectionListLayout.titleLines)
                    if item.isExplicit == true {
                        EntityExplicitBadge()
                    }
                }
                if !item.subtitle.isEmpty {
                    Text(item.subtitle)
                        .plusText(.textM, .medium)
                        .foregroundStyle(Color.fillSubtitle)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: CollectionListLayout.controlsGap) {
                if collection.isDownloaded(item.id) {
                    Image("iconDownload")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: CollectionLayout.downloadIcon, height: CollectionLayout.downloadIcon)
                        .foregroundStyle(Color.accentPrimary)
                        .accessibilityLabel("Скачано")
                }
                Menu {
                    CollectionItemMenu(item: item)
                } label: {
                    // Вид `PlusButton` plain M; круг 40 — под отрицательным отступом.
                    // Своё нажатие у «ещё» — и палец на нём не просаживает строку.
                    TrackMoreLabel()
                        .pressScale(PressMotion.buttonScale)
                }
                // Хаптика — как у кнопок ДС: меню открывается системой, тап ловим рядом.
                .simultaneousGesture(TapGesture().onEnded { PlayerHaptics.tap() })
                .padding(-TrackMoreLabel.hitInset)
                .accessibilityLabel("Ещё")
            }
        }
        .padding(.horizontal, CollectionListLayout.side)
        .padding(.vertical, CollectionListLayout.rowPadding)
        .frame(minHeight: CollectionListLayout.cover + 2 * CollectionListLayout.rowPadding)
        .contentShape(.rect)
        // Проседает строка, а черты стоят: просевшая черта короче соседних и съезжает.
        .pressScale(PressMotion.rowScale)
        .overlay(alignment: .bottom) { divider }
        .overlay(alignment: .top) { if isFirst { divider } }
        .onTapGesture(perform: open)
        .contextMenu { CollectionItemMenu(item: item) }
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
            .overlay(alignment: .topLeading) {
                if let rating { MovieRatingBadge(rating: rating) }
            }
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
        let geometry = CollectionListLayout.book(aspect: item.aspect)
        return BookFigure(geometry: geometry, coverWidth: geometry.coverWidth(aspect: item.aspect), readingID: item.route?.ref.id) {
            if let artwork = item.artwork {
                SkeletonArtwork(source: artwork)
            }
        }
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

    private var divider: some View {
        Rectangle()
            .fill(CollectionLayout.divider)
            .frame(height: 0.5)
            .padding(.horizontal, CollectionListLayout.side)
    }

    /// Трек и плейлист играют сразу, остальные открывают свой экран.
    private func open() {
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
