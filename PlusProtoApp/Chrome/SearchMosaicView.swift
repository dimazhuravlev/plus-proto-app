import SwiftUI

/// Числа сетки выдачи — макет `2479:24822`: три колонки по 118 с зазором 8, между
/// карточками в колонке 16, поля 16, сетка на 8 ниже чипсов, обложка → подпись 6.
enum MosaicLayout {
    static let columns = 3
    static let side: CGFloat = 16
    static let columnGap: CGFloat = 8
    static let rowGap: CGFloat = 16
    static let gridTop: CGFloat = 8
    static let coverGap: CGFloat = 6
    /// Колонка — от холста 402, а не замером: (402 − 2 × 16 − 2 × 8) / 3 = 118.
    static let card: CGFloat =
        (PlusMetrics.designWidth - 2 * side - CGFloat(columns - 1) * columnGap) / CGFloat(columns)
    /// Постер кино и персон — 2:3, 118 × 177
    static let posterAspect: CGFloat = 2.0 / 3.0
    static let coverRadius = PlusRadius.movieChip
    /// Карточка крупная — пресс мягче кнопочного (0.92): сильный скейл на большой
    /// площади читается прыжком.
    static let pressedScale: CGFloat = 0.97
    /// Порция — четыре ряда. Первая сразу, следующие — на подходе к низу.
    static let chunk = 12
    /// За сколько до низа ленты дописывать следующую порцию — около трёх рядов:
    /// карточки встают за краем экрана, и долистать до пустоты не успеть.
    static let prefetchDistance: CGFloat = 600
    /// Скелетоны внизу, пока едет добор, — ряд на все три колонки.
    static let tailSkeletons = 3
    /// Подложка закреплённых чипсов проявляется за первые 24 скролла — как у полной
    /// выдачи раздела.
    static let backdropRamp: CGFloat = 24
    static let barGap: CGFloat = 12
    /// Полоски скелетона подписи — как у карусели: 12 по центру строки 16.
    static let skeletonBar: CGFloat = 12
    static let skeletonBarInset: CGFloat = (PlusTextSize.textS.lineHeight - skeletonBar) / 2
    static let skeletonTitleBar: CGFloat = (card * 0.8).rounded()
    static let skeletonSubtitleBar: CGFloat = (card * 0.55).rounded()
    /// Скелетон первой выдачи — вперемешку, как будущая лента. Порядок разделов ещё
    /// неизвестен, поэтому формы чередуются, а не повторяют какой-то из них. Первым —
    /// круг исполнителя (правка пользователя 2026-10-05).
    static let skeletonPattern: [MosaicSkeletonShape] = [
        .round, .poster, .book, .square, .poster, .square,
        .book, .poster, .square, .round, .book, .poster,
    ]
}

/// Движение сетки.
enum MosaicMotion {
    /// Смена фильтра — последовательно, как у полных списков (правки пользователя
    /// 2026-10-03/04): старая сетка гаснет за 300 мс, затем новая проявляется за 300 мс.
    /// Одновременный кроссфейд положил бы две сетки друг на друга, а перелёт карточек
    /// на новые места пользователь у списков уже отклонил.
    static let fadeOutDuration: Duration = .milliseconds(300)
    static let fadeOut: Animation = .easeInOut(duration: 0.3)
    static let fadeIn: Animation = .easeInOut(duration: 0.3)
    /// Карточка проявляет содержимое — постер и подпись — за 400 мс (правка пользователя
    /// 2026-10-05: «более плавная загрузка карточек»; прежде постер шёл общими 150 мс
    /// скелетонов, а подпись вставала сразу). Заливка обложки стоит с первого кадра:
    /// она та же, что у скелетона, и карточка встаёт на его место без смены цвета.
    /// Постер, приехавший из сети позже, проявляется той же кривой.
    static let contentAppear: Animation = .easeOut(duration: 0.4)
    /// Дописанная порция проявляется: обычно это за краем экрана, но если низ уже
    /// на виду, карточки встают мягко, а не щелчком, — в такт своему содержимому.
    static let reveal: Animation = .easeOut(duration: 0.4)
}

/// Вторая версия выдачи — сетка вперемешку (masonry, макет `2479:24822`, задача
/// пользователя 2026-10-05). Карусели остаются; вид выбирается в дебаг-меню профиля
/// (`SearchResultsStyle`).
///
/// Все разделы в одной ленте, порядок — `SearchState.mixed`: в первом ряду лучшее
/// из разных API, дальше по весу совпадения с запросом. Карточки одной ширины,
/// высота — по контенту: постер, квадрат, круг исполнителя, книга своих пропорций
/// и подпись своей высоты (строк — как в каруселях: две на название, одна на подпись).
///
/// Сверху закреплены чипсы — Всё, Музыка, Кино, Книги; переходов в полные списки
/// разделов здесь нет. Лента идёт порциями (`MosaicLayout.chunk`): следующая
/// дописывается на подходе к низу, а когда карточки выдачи кончаются, сетка просит
/// добор (`SearchState.extendMosaic`) и держит внизу скелетоны, пока он в пути.
struct SearchMosaicView: View {
    /// Уход в сущность — тот же, что из каруселей: отметка ухода, клавиатура вниз.
    let open: (EntityRoute) -> Void
    let zoom: Namespace.ID?

    @Environment(SearchState.self) private var search
    @Environment(KeyboardObserver.self) private var keyboard

    /// Выбранный фильтр — им подсвечен чипс, сразу по нажатию.
    @State private var filter: MosaicFilter = .all
    /// Фильтр показанной сетки — догоняет выбранный, когда старая сетка погасла.
    @State private var shownFilter: MosaicFilter = .all
    @State private var gridOpacity: Double = 1
    @State private var filterSwap: Task<Void, Never>?
    /// Сколько карточек показано: растёт порциями.
    @State private var revealed = MosaicLayout.chunk
    /// До низа ленты меньше `prefetchDistance`.
    @State private var isNearEnd = false
    /// Сколько проскроллено — от него проявляется подложка чипсов.
    @State private var scrolled: CGFloat = 0

    private static let topAnchor = "mosaic-top"

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                // Стопка без зазоров: якорь и лента в стопке скролла по умолчанию
                // разделены 8 pt — над чипсами стояла лишняя полоса, и на старте
                // скролла ряд сперва съезжал на неё, а потом закреплялся (правка
                // пользователя 2026-10-05).
                VStack(spacing: 0) {
                    Color.clear.frame(height: 0).id(Self.topAnchor)
                    // Чипсы закреплены заголовком секции — как у полной выдачи музыки.
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                        Section {
                            grid
                                .opacity(gridOpacity)
                                .padding(.horizontal, MosaicLayout.side)
                                .padding(.top, MosaicLayout.gridTop)
                        } header: {
                            chips
                        }
                    }
                }
                // Как у каруселей: сетка уходит под поле и клавиатуру, последний ряд
                // выкручивается из-под них.
                .padding(.bottom, keyboard.overlap + PlusMetrics.actionBarHeight + MosaicLayout.barGap)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.never)
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { _, offset in
                scrolled = offset
            }
            .onScrollGeometryChange(for: MosaicTail.self) { geometry in
                MosaicTail(
                    contentHeight: geometry.contentSize.height.rounded(),
                    isNear: geometry.contentSize.height - geometry.visibleRect.maxY < MosaicLayout.prefetchDistance
                )
            } action: { _, tail in
                isNearEnd = tail.isNear
                requestMore()
            }
            .modifier(DismissKeyboardOnScroll())
            .onChange(of: search.shownText) {
                startOver()
                proxy.scrollTo(Self.topAnchor, anchor: .top)
            }
            .onChange(of: shownFilter) {
                // Сетка невидима — к началу: новая начинается сверху.
                proxy.scrollTo(Self.topAnchor, anchor: .top)
            }
            .onChange(of: filter) { _, selected in swapGrid(to: selected) }
            // Добор приехал, пока низ на виду, — сразу следующая порция.
            .onChange(of: items.count) { requestMore() }
            #if DEBUG
            // `-debugSearchFilter <n>` — n-й чипс сетки (0 — «Всё»), когда выдача пришла:
            // тапнуть по чипсу из шелла нечем. Тот же флаг, что у полной выдачи музыки.
            .task(id: search.shownText) {
                let index = UserDefaults.standard.integer(forKey: "debugSearchFilter")
                guard index > 0, search.shownText != nil else { return }
                try? await Task.sleep(for: .milliseconds(500))
                let options = chipOptions
                guard !Task.isCancelled, options.indices.contains(index) else { return }
                filter = options[index]
            }
            #endif
        }
    }

    /// Карточки под показанным фильтром — в порядке смешанной выдачи.
    private var items: [SearchHit] {
        search.mosaicHits.filter(shownFilter.matches)
    }

    private var grid: some View {
        let items = items
        let visible = Array(items.prefix(revealed))
        let zoomSources = visible.firstPerRouteIDs
        return MosaicGrid(
            columns: MosaicLayout.columns,
            columnSpacing: MosaicLayout.columnGap,
            rowSpacing: MosaicLayout.rowGap
        ) {
            if search.shownText == nil {
                // Первая выдача в пути — скелетон вперемешку (уточнение запроса держит
                // прежнюю выдачу, и скелетона не будет).
                ForEach(MosaicLayout.skeletonPattern.indices, id: \.self) { index in
                    MosaicSkeletonCard(shape: MosaicLayout.skeletonPattern[index])
                }
            } else {
                ForEach(visible) { hit in
                    MosaicCard(hit: hit, zoom: zoomSources.contains(hit.id) ? zoom : nil) { route in
                        search.remember(hit)
                        open(route)
                    }
                    .transition(.opacity)
                }
                if search.isExtendingMosaic, revealed >= items.count {
                    ForEach(0..<MosaicLayout.tailSkeletons, id: \.self) { index in
                        MosaicSkeletonCard(shape: MosaicLayout.skeletonPattern[index])
                            .transition(.opacity)
                    }
                }
            }
        }
    }

    /// Чипсы — общий ряд (`FilterChipsRow`): хаптик таббара, капсула меняется на месте.
    /// Подложка — прогрессивный блюр, проявляется, когда сетка уходит под ряд.
    private var chips: some View {
        FilterChipsRow(options: chipOptions, selection: $filter, title: \.title)
            .modifier(DismissKeyboardOnScroll())
            // Пустая выдача — только текст «ничего не нашлось», чипсов без карточек нет.
            .opacity(search.isEmptyResult ? 0 : 1)
            .allowsHitTesting(!search.isEmptyResult)
            .background(alignment: .top) {
                PinnedChipsBackdrop()
                    .opacity(NavBarRamp.progress(scrolled, start: 0, length: MosaicLayout.backdropRamp))
            }
            // Оттяг — как у навигации витрин: ряд едет за лентой вчетверо медленнее.
            // Заголовок секции при оттяге едет вместе с лентой — сдвиг возвращает разницу.
            .offset(y: ServiceTopNavMotion.pullShift(for: scrolled) - max(0, -scrolled))
    }

    /// Чипсы — только разделы, в которых что-то нашлось: пустой фильтр показал бы пустую
    /// сетку. Пока первая выдача в пути — все четыре: пустые разделы ещё неизвестны.
    private var chipOptions: [MosaicFilter] {
        guard search.shownText != nil else { return MosaicFilter.allCases }
        let hits = search.mosaicHits
        return MosaicFilter.allCases.filter { $0 == .all || hits.contains(where: $0.matches) }
    }

    /// Лента у низа: следующая порция, а когда показано всё — добор.
    private func requestMore() {
        guard isNearEnd, search.shownText != nil else { return }
        let total = items.count
        if revealed < total {
            withAnimation(MosaicMotion.reveal) {
                revealed = min(total, revealed + MosaicLayout.chunk)
            }
        } else if search.canExtendMosaic {
            search.extendMosaic()
        }
    }

    /// Пришла выдача нового запроса — сетка с начала: «Всё», первая порция.
    private func startOver() {
        filterSwap?.cancel()
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) {
            filter = .all
            shownFilter = .all
            gridOpacity = 1
            revealed = MosaicLayout.chunk
        }
    }

    /// Старая сетка гаснет, в паузе подменяется, новая проявляется. Быстрые нажатия
    /// подряд прерывают незаконченную смену — показан всегда последний выбранный.
    private func swapGrid(to selected: MosaicFilter) {
        filterSwap?.cancel()
        guard selected != shownFilter else {
            withAnimation(MosaicMotion.fadeIn) { gridOpacity = 1 }
            return
        }
        filterSwap = Task { @MainActor in
            withAnimation(MosaicMotion.fadeOut) { gridOpacity = 0 }
            try? await Task.sleep(for: MosaicMotion.fadeOutDuration)
            guard !Task.isCancelled else { return }
            // Подмена — пока сетки не видно, без анимации: карточки не перелетают
            // и не проявляются по одной под прозрачностью.
            var instant = Transaction()
            instant.disablesAnimations = true
            withTransaction(instant) {
                shownFilter = selected
                revealed = MosaicLayout.chunk
            }
            withAnimation(MosaicMotion.fadeIn) { gridOpacity = 1 }
        }
    }
}

// MARK: - Искали недавно

/// «Искали недавно» сеткой — нулевое состояние поиска в режиме сетки (задача
/// пользователя 2026-10-05; включается тем же пунктом дебаг-меню, что сетка выдачи).
/// Перехода в полный список нет: вся история — найденное и стартовый набор — сразу
/// в сетке, а в её конце «Удалить историю поиска».
///
/// Тапы отсюда историю не переставляют, как и из ленты каруселей: сетка сдвинулась бы
/// под зумом открытой карточки, и на возврате он сворачивался бы не в ту карточку.
struct SearchRecentsMosaicView: View {
    let open: (EntityRoute) -> Void
    let zoom: Namespace.ID?

    @Environment(SearchState.self) private var search
    @Environment(KeyboardObserver.self) private var keyboard
    @State private var isConfirmingClear = false
    @State private var gridOpacity: Double = 1

    private enum Layout {
        /// Заголовок — строка 28, 12 снизу, как у ленты каруселей; сверху 8, а не 16
        /// (правка пользователя 2026-10-05). Шеврона нет, переходить некуда.
        static let headerTop: CGFloat = 8
        static let headerLine: CGFloat = 28
        static let headerBottom: CGFloat = 12
        /// Кнопка — на 24 ниже сетки, как под полным списком истории.
        static let buttonTop: CGFloat = 24
        static let buttonHeight: CGFloat = 48
        /// Капсула по тексту (правка пользователя 2026-10-05: «сжимается по контенту»):
        /// поля 24 по бокам, ширина — сколько займёт надпись.
        static let buttonSide: CGFloat = 24
        static let buttonPressedScale: CGFloat = 0.97
    }

    var body: some View {
        let items = search.history
        let zoomSources = items.firstPerRouteIDs
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Искали недавно")
                    .plusHeadline(.m)
                    .foregroundStyle(Color.fillOne)
                    // Строку держит рамка, текст — по её центру: так же, как у заголовка
                    // карусели, на той же базовой линии, что в Фигме.
                    .frame(height: Layout.headerLine)
                    .padding(.top, Layout.headerTop)
                    .padding(.bottom, Layout.headerBottom)
                    .padding(.horizontal, MosaicLayout.side)

                MosaicGrid(
                    columns: MosaicLayout.columns,
                    columnSpacing: MosaicLayout.columnGap,
                    rowSpacing: MosaicLayout.rowGap
                ) {
                    ForEach(items) { hit in
                        MosaicCard(hit: hit, zoom: zoomSources.contains(hit.id) ? zoom : nil, open: open)
                    }
                }
                .padding(.horizontal, MosaicLayout.side)

                if search.hasHistory {
                    clearButton
                        .frame(maxWidth: .infinity)
                        .padding(.top, Layout.buttonTop)
                }
            }
            .opacity(gridOpacity)
            // Историю удалили целиком — показывать нечего: ни заголовка, ни кнопки.
            .opacity(items.isEmpty ? 0 : 1)
            // Как у выдачи: сетка уходит под поле и клавиатуру, низ выкручивается из-под них.
            .padding(.bottom, keyboard.overlap + PlusMetrics.actionBarHeight + MosaicLayout.barGap)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.never)
        .modifier(DismissKeyboardOnScroll())
        .alert("Точно удалить историю?", isPresented: $isConfirmingClear) {
            Button("Да, удалить", role: .destructive) { clearHistory() }
            Button("Назад", role: .cancel) {}
        }
    }

    /// Вторичная кнопка — стеклянная капсула, как «Удалить историю» под полным списком:
    /// удаление — побочное действие, акцентная кнопка в проекте за главным.
    private var clearButton: some View {
        Button { isConfirmingClear = true } label: {
            Text("Удалить историю поиска")
                .plusText(.textM, .semibold)
                .foregroundStyle(Color.fillOne)
                .padding(.horizontal, Layout.buttonSide)
                .frame(height: Layout.buttonHeight)
                .secondaryButtonSurface(Capsule(style: .continuous))
                .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(PressScaleButtonStyle(pressedScale: Layout.buttonPressedScale))
    }

    /// История гаснет целиком — заголовок, сетка, кнопка — той же кривой, что сетка
    /// на смене фильтра, и стирается, когда её уже не видно. Возвращать прозрачность
    /// можно сразу: пустая история скрыта сама (`items.isEmpty`), а новое найденное
    /// встанет уже видимым.
    private func clearHistory() {
        Task { @MainActor in
            withAnimation(MosaicMotion.fadeOut) { gridOpacity = 0 }
            try? await Task.sleep(for: MosaicMotion.fadeOutDuration)
            var instant = Transaction()
            instant.disablesAnimations = true
            withTransaction(instant) {
                search.clearHistory()
                gridOpacity = 1
            }
        }
    }
}

/// Сколько осталось до низа ленты. Меняется и с высотой содержимого: дописанная
/// порция заново проверяет, не пора ли следующая, — короткая выдача добирается
/// до заполнения экрана сама.
private struct MosaicTail: Equatable {
    let contentHeight: CGFloat
    let isNear: Bool
}

// MARK: - Фильтры

/// Фильтры сетки — `chips-row` макета `2479:24822`: всё вперемешку или один раздел.
/// Фильтр отбирает карточки раздела из смешанной ленты, их порядок не меняется.
enum MosaicFilter: Hashable, CaseIterable {
    case all, music, movies, books

    var title: String {
        switch self {
        case .all: "Всё"
        case .music: "Музыка"
        case .movies: "Кино"
        case .books: "Книги"
        }
    }

    func matches(_ hit: SearchHit) -> Bool {
        switch self {
        case .all: true
        case .music: hit.kind.domain == .music
        case .movies: hit.kind.domain == .movies
        case .books: hit.kind.domain == .books
        }
    }
}

// MARK: - Раскладка

/// Раскладка «кирпичом»: колонки одной ширины, карточка встаёт в самую короткую
/// (при равенстве — в левую). Порядок выдачи читается сверху вниз, а порция,
/// дописанная в конец, не двигает уже стоящие карточки.
///
/// Высоты — замер самих карточек на ширину колонки: подпись своей высоты, и знать
/// её заранее неоткуда. Замер — раз на смену содержимого, а не на кадр скролла,
/// и обратной связи «размер → раскладка → размер» здесь нет: высота карточки
/// от её места в сетке не зависит.
struct MosaicGrid: Layout {
    let columns: Int
    let columnSpacing: CGFloat
    let rowSpacing: CGFloat

    /// Рамки карточек под ширину: `sizeThatFits` и `placeSubviews` идут подряд,
    /// и второй замер всех карточек был бы лишним.
    struct Cache {
        var width: CGFloat = -1
        var frames: [CGRect] = []
    }

    func makeCache(subviews: Subviews) -> Cache { Cache() }

    func updateCache(_ cache: inout Cache, subviews: Subviews) {
        cache = Cache()
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        let width = proposal.width ?? 0
        let frames = frames(width: width, subviews: subviews, cache: &cache)
        return CGSize(width: width, height: frames.map(\.maxY).max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        let frames = frames(width: bounds.width, subviews: subviews, cache: &cache)
        for (subview, frame) in zip(subviews, frames) {
            subview.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(width: frame.width, height: frame.height)
            )
        }
    }

    private func frames(width: CGFloat, subviews: Subviews, cache: inout Cache) -> [CGRect] {
        if cache.width == width, cache.frames.count == subviews.count { return cache.frames }
        let count = CGFloat(columns)
        let columnWidth = max(0, (width - columnSpacing * (count - 1)) / count)
        // Низ каждой колонки; стартовый «минус зазор» ставит первую карточку на 0.
        var bottoms = Array(repeating: -rowSpacing, count: columns)
        var frames: [CGRect] = []
        frames.reserveCapacity(subviews.count)
        for subview in subviews {
            let height = subview.sizeThatFits(ProposedViewSize(width: columnWidth, height: nil)).height
            let column = bottoms.indices.min { bottoms[$0] < bottoms[$1] } ?? 0
            let y = bottoms[column] + rowSpacing
            frames.append(CGRect(
                x: CGFloat(column) * (columnWidth + columnSpacing),
                y: y,
                width: columnWidth,
                height: height
            ))
            bottoms[column] = y + height
        }
        cache = Cache(width: width, frames: frames)
        return frames
    }
}

// MARK: - Карточка

/// Карточка сетки — `movie`, `book`, `album`, `artist` макета: ширина колонки, обложка
/// своего вида, подпись своей высоты.
private struct MosaicCard: View {
    let hit: SearchHit
    /// `nil` — карточка не источник зума (`firstPerRouteIDs`): трек и его альбом
    /// ведут в один экран, и источник у него один.
    let zoom: Namespace.ID?
    let open: (EntityRoute) -> Void

    /// Постер и подпись проявились (`MosaicMotion.contentAppear`). Один раз на карточку:
    /// та же карточка в уточнённой выдаче (тот же id) не мигает заново.
    @State private var isContentShown = false

    /// Люди — кругом, с подписью по центру: исполнитель по макету, режиссёр и писатель —
    /// так же (в каруселях они постерами, в ряд с работами; в сетке рядов нет, и круг
    /// сразу отличает человека от фильма и книги).
    private var isPerson: Bool {
        switch hit.kind {
        case .artist, .director, .writer: true
        case .track, .album, .playlist, .movie, .book: false
        }
    }

    /// Вторая строка: своя у карточки, а у режиссёра и писателя — роль, иначе непонятно,
    /// почему человек стоит среди фильмов и книг.
    private var caption: String {
        guard hit.subtitle.isEmpty else { return hit.subtitle }
        return switch hit.kind {
        case .director: "Режиссёр"
        case .writer: "Писатель"
        case .track, .album, .artist, .playlist, .movie, .book: ""
        }
    }

    var body: some View {
        if let route = hit.route {
            Button { open(route) } label: { content }
                .buttonStyle(PressScaleButtonStyle(pressedScale: MosaicLayout.pressedScale))
                // Экран сущности разворачивается из карточки и сворачивается в неё — как
                // из каруселей.
                .modifier(SearchResultsView.SearchZoomSource(route: route, zoom: zoom))
        } else {
            content
        }
    }

    private var content: some View {
        VStack(alignment: isPerson ? .center : .leading, spacing: MosaicLayout.coverGap) {
            cover
            label
                .opacity(isContentShown ? 1 : 0)
        }
        .frame(maxWidth: .infinity, alignment: isPerson ? .center : .leading)
        .contentShape(.rect)
        .onAppear {
            guard !isContentShown else { return }
            withAnimation(MosaicMotion.contentAppear) { isContentShown = true }
        }
    }

    @ViewBuilder
    private var cover: some View {
        if hit.kind == .book {
            // Книга в проекции — общий рисунок (`BookFigure`), по ширине колонки: высоту
            // дают пропорции обложки, снятые до показа.
            let book = BookFigureGeometry.fitting(width: MosaicLayout.card, aspect: hit.artworkAspect)
            BookFigure(geometry: book.geometry, coverWidth: book.coverWidth) { artwork }
        } else {
            let shape: AnyShape = isPerson
                ? AnyShape(Circle())
                : AnyShape(RoundedRectangle(cornerRadius: MosaicLayout.coverRadius, style: .continuous))
            // Заливка — та же, что у скелетона: карточка встаёт на его место без смены
            // цвета, обложка проявляется поверх.
            PlusSkeleton.fill
                .frame(width: MosaicLayout.card, height: coverHeight)
                .overlay { artwork }
                .clipShape(shape)
                .overlay { shape.stroke(PlusSkeleton.fill, lineWidth: PlusMetrics.hairline) }
        }
    }

    /// Постер: картинка из памяти — в такт подписи, приехавшая из сети позже — своим
    /// проявлением той же кривой.
    @ViewBuilder
    private var artwork: some View {
        if let source = hit.artwork {
            ResolvedArtwork(source: source, appear: MosaicMotion.contentAppear) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color.clear
            }
            .opacity(isContentShown ? 1 : 0)
        }
    }

    /// Квадрат у музыки и людей, постер 2:3 у кино.
    private var coverHeight: CGFloat {
        switch hit.kind {
        case .track, .album, .artist, .playlist, .director, .writer: MosaicLayout.card
        case .movie, .book: MosaicLayout.card / MosaicLayout.posterAspect
        }
    }

    private var label: some View {
        VStack(alignment: isPerson ? .center : .leading, spacing: 0) {
            Text(hit.title)
                .plusText(.textS, .medium)
                .foregroundStyle(Color.fillOne)
                .lineLimit(2)
                .multilineTextAlignment(isPerson ? .center : .leading)

            if !caption.isEmpty {
                Text(caption)
                    .plusText(.textS, .medium)
                    .foregroundStyle(Color.fillSubtitle)
                    .lineLimit(1)
            }
        }
        // Своей высоты: в сетке подпись не держит общую рамку, как в карусели, —
        // карточка кончается там, где кончился текст (16, 32 или 48, как в макете).
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: isPerson ? .center : .leading)
    }
}

// MARK: - Скелетон

/// Форма скелетона сетки — виды будущих карточек.
enum MosaicSkeletonShape {
    case poster, square, round, book
}

/// Скелетон — того же габарита, что карточка своего вида: обложка той же формы
/// и полоски на месте строк подписи.
private struct MosaicSkeletonCard: View {
    let shape: MosaicSkeletonShape

    private var isRound: Bool { shape == .round }

    var body: some View {
        VStack(alignment: isRound ? .center : .leading, spacing: MosaicLayout.coverGap) {
            cover
            bars
        }
        .frame(maxWidth: .infinity, alignment: isRound ? .center : .leading)
        .accessibilityLabel("Загрузка")
    }

    @ViewBuilder
    private var cover: some View {
        switch shape {
        case .book:
            let book = BookFigureGeometry.fitting(width: MosaicLayout.card, aspect: nil)
            BookFigure(geometry: book.geometry, coverWidth: book.coverWidth) { EmptyView() }
        case .round:
            Circle()
                .fill(PlusSkeleton.fill)
                .overlay { Circle().stroke(PlusSkeleton.fill, lineWidth: PlusMetrics.hairline) }
                .frame(width: MosaicLayout.card, height: MosaicLayout.card)
        case .poster, .square:
            let rect = RoundedRectangle(cornerRadius: MosaicLayout.coverRadius, style: .continuous)
            rect
                .fill(PlusSkeleton.fill)
                .overlay { rect.stroke(PlusSkeleton.fill, lineWidth: PlusMetrics.hairline) }
                .frame(
                    width: MosaicLayout.card,
                    height: shape == .poster ? MosaicLayout.card / MosaicLayout.posterAspect : MosaicLayout.card
                )
        }
    }

    /// Полоски — по центру своих строк, как у скелетона карусели; у исполнителя одна.
    private var bars: some View {
        VStack(alignment: isRound ? .center : .leading, spacing: 2 * MosaicLayout.skeletonBarInset) {
            SkeletonBar(width: MosaicLayout.skeletonTitleBar, height: MosaicLayout.skeletonBar)
            if !isRound {
                SkeletonBar(width: MosaicLayout.skeletonSubtitleBar, height: MosaicLayout.skeletonBar)
            }
        }
        .padding(.vertical, MosaicLayout.skeletonBarInset)
    }
}
