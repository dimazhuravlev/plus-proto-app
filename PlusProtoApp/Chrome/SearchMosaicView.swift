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
    /// Колонка делит ширину экрана при постоянных полях и зазорах (правило 4 CLAUDE.md):
    /// на 402 — (402 − 2 × 16 − 2 × 8) / 3 = 118; `static var`, иначе значение
    /// зафиксируется при первом чтении. Совпадает с шириной колонки `MosaicGrid`.
    @MainActor
    static var card: CGFloat {
        PlusGrid.column(columns: columns, side: side, gap: columnGap)
    }
    /// Постер кино и персон — 2:3, 118 × 177
    static let posterAspect: CGFloat = 2.0 / 3.0
    static let coverRadius = PlusRadius.movieChip
    /// Кнопка play на обложке трека: вид `PlusButton` secondary M в натуральный размер —
    /// с отступом 6 от кромок (правка пользователя 2026-10-05; в макете `2479:25744` — 30 и 4).
    static let playButton = PlusButtonSize.m
    static let playInset: CGFloat = 6
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
    @MainActor
    static var skeletonTitleBar: CGFloat { (card * 0.8).rounded() }
    @MainActor
    static var skeletonSubtitleBar: CGFloat { (card * 0.55).rounded() }
    /// Скелетон первой выдачи — вперемешку, как будущая лента. Порядок разделов ещё
    /// неизвестен, поэтому формы чередуются, а не повторяют какой-то из них. Первым —
    /// круг исполнителя, третьим — квадрат альбома (правки пользователя 2026-10-05).
    static let skeletonPattern: [MosaicSkeletonShape] = [
        .round, .poster, .square, .book, .poster, .square,
        .book, .poster, .square, .round, .book, .poster,
    ]
}

/// Движение сетки и табов выдачи.
enum MosaicMotion {
    /// Смена таба, чипса и выдачи — последовательно, как у полных списков (правки
    /// пользователя 2026-10-03/04, 2026-10-31): старое гаснет за 300 мс, затем новое
    /// проявляется за 300 мс.
    /// Одновременный кроссфейд положил бы две сетки друг на друга, а перелёт карточек
    /// на новые места пользователь у списков уже отклонил.
    static let fadeOutDuration: Duration = .milliseconds(300)
    static let fadeOut: Animation = .easeInOut(duration: 0.3)
    static let fadeIn: Animation = .easeInOut(duration: 0.3)
    /// Пауза между подменой карточек и проявлением — пара кадров. В одном апдейте
    /// с проявлением подмена уезжала под его анимацию: карточки, оставшиеся под новым
    /// фильтром, перелетали на новые места — сквозь клавиатуру было видно, как они
    /// мечутся в стороны (правка пользователя 2026-10-05). Подмена должна закоммититься
    /// без анимации, пока сетки не видно.
    static let swapCommit: Duration = .milliseconds(32)
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
/// Сверху закреплены табы первого уровня — Всё, Музыка, Кино, Книги (макеты
/// `19151:18648`, `19184:22008`, `19191:22495`, задача пользователя 2026-10-31): «Всё» —
/// сетка, таб раздела — его полная выдача строками (`SearchTabRows`) и над ней чипсы
/// второго уровня. Лента «Всего» идёт порциями (`MosaicLayout.chunk`): следующая
/// дописывается на подходе к низу, а когда карточки выдачи кончаются, сетка просит
/// добор (`SearchState.extendMosaic`) и держит внизу скелетоны, пока он в пути.
///
/// Любая смена содержимого — таб, чипс, новый запрос — последовательно, как везде:
/// старое гаснет, в паузе подменяется (с начала ленты), новое проявляется. Табы
/// и чипсы подсвечиваются сразу по нажатию, содержимое догоняет. Первая выдача встаёт
/// на место скелетона без смены.
struct SearchMosaicView: View {
    /// Уход в сущность — тот же, что из каруселей: отметка ухода, клавиатура вниз.
    let open: (EntityRoute) -> Void
    let zoom: Namespace.ID?

    @Environment(SearchState.self) private var search
    @Environment(KeyboardObserver.self) private var keyboard
    @Environment(ActionBarState.self) private var actionBar

    /// Сетка на экране — снимок `search.mosaicHits`. Новый запрос сменяет его не сразу,
    /// а последовательно (правка пользователя 2026-10-05: «при обновлении выдачи плавнее» —
    /// прежде карточки перепрыгивали на новые места в один кадр). Добор того же запроса
    /// дописывается в снимок сразу — карточки встают в конец; первая выдача сменяет
    /// скелетон на месте.
    @State private var displayedHits: [SearchHit] = []
    /// Текст показанной выдачи; `nil` — первой ещё нет, на экране скелетон.
    @State private var displayedText: String?
    /// Таб показанного содержимого — догоняет выбранный (`search.tab`), когда старое погасло.
    @State private var shownTab: SearchTab = .all
    /// Выдача раздела на экране; `nil` — первая ещё собирается, на экране скелетон строк.
    @State private var displayedSection: SearchState.TabResults?
    /// Чипс второго уровня показанного списка — догоняет выбранный (`search.subfilter`).
    @State private var shownSubfilter: SearchSubfilter = .all
    @State private var contentOpacity: Double = 1
    /// Ряд чипсов второго уровня гаснет вместе со списком, когда меняется сам: смена
    /// таба, новая выдача раздела с другими чипсами. На смене чипса он стоит.
    @State private var chipsOpacity: Double = 1
    /// Смена в пути и куда она ведёт — до подмены. Повторный запрос той же смены
    /// её не перезапускает: подмена возьмёт то, что успело приехать.
    @State private var swap: Task<Void, Never>?
    @State private var swapTarget: ContentSwap?
    /// Подменённое содержимое — с начала ленты; счётчик, а не флаг: каждая подмена своя.
    @State private var scrollResets = 0
    /// Сколько карточек сетки показано: растёт порциями.
    @State private var revealed = MosaicLayout.chunk
    /// До низа ленты меньше `prefetchDistance`.
    @State private var isNearEnd = false
    /// Сколько проскроллено — от него проявляется подложка шапки.
    @State private var scrolled: CGFloat = 0

    private static let topAnchor = "mosaic-top"

    private static var instant: Transaction {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        return transaction
    }

    var body: some View {
        ZStack {
            ScrollViewReader { proxy in
                ScrollView {
                    // Стопка без зазоров: якорь и лента в стопке скролла по умолчанию
                    // разделены 8 pt — над шапкой стояла лишняя полоса, и на старте
                    // скролла ряд сперва съезжал на неё, а потом закреплялся (правка
                    // пользователя 2026-10-05).
                    VStack(spacing: 0) {
                        Color.clear.frame(height: 0).id(Self.topAnchor)
                        // Табы и чипсы закреплены заголовком секции — как у полной выдачи.
                        LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                            Section {
                                content
                                    .opacity(contentOpacity)
                            } header: {
                                header
                            }
                        }
                    }
                    // Как у каруселей: лента уходит под поле и клавиатуру, последний ряд
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
                .onChange(of: contentKey, initial: true) { old, new in
                    // Первый вызов — на появлении (старое значение равно новому).
                    reconcile(isAppearing: old == new)
                }
                // Содержимое погашено сменой — к началу: новое начинается сверху. Скролл —
                // до подмены (`scrollToTopBeforeSwap`), а не после.
                .onChange(of: scrollResets) {
                    proxy.scrollTo(Self.topAnchor, anchor: .top)
                }
                // Добор приехал, пока низ на виду, — сразу следующая порция.
                .onChange(of: items.count) { requestMore() }
                #if DEBUG
                // `-debugSearchTab music|movies|books` — таб раздела, когда выдача пришла;
                // `-debugSearchFilter <n>` — n-й чипс второго уровня (0 — «Всё»), когда
                // пришла выдача раздела: тапнуть из шелла нечем.
                .task(id: search.shownText) {
                    guard let raw = UserDefaults.standard.string(forKey: "debugSearchTab"),
                          search.shownText != nil else { return }
                    let tab: SearchTab? = switch raw {
                    case "music": .music
                    case "movies": .movies
                    case "books": .books
                    default: nil
                    }
                    try? await Task.sleep(for: .milliseconds(500))
                    guard !Task.isCancelled, let tab else { return }
                    search.selectTab(tab)
                }
                .task(id: search.tabResults?.text) {
                    let index = UserDefaults.standard.integer(forKey: "debugSearchFilter")
                    guard index > 0, let options = search.tabResults?.options else { return }
                    try? await Task.sleep(for: .milliseconds(500))
                    guard !Task.isCancelled, options.indices.contains(index) else { return }
                    search.subfilter = options[index]
                }
                #endif
            }
            // В табе или под чипсом ничего — тот же текст и в той же точке, что у пустой
            // выдачи целиком (макеты `19151:18721`, `19211:18594`).
            SearchEmptyState(isShown: isSectionEmpty)
                // Текст — часть содержимого таба: гаснет и проявляется с ним на сменах.
                .opacity(contentOpacity)
        }
    }

    // MARK: Содержимое

    @ViewBuilder
    private var content: some View {
        if let kind = shownTab.kind {
            SearchTabRows(kind: kind, results: displayedSection, filter: shownSubfilter, open: open, zoom: zoom)
        } else {
            grid
                .padding(.horizontal, MosaicLayout.side)
                .padding(.top, MosaicLayout.gridTop)
        }
    }

    /// Карточки сетки — в порядке смешанной выдачи.
    private var items: [SearchHit] {
        displayedHits
    }

    private var grid: some View {
        let items = items
        let visible = Array(items.prefix(revealed))
        // Трек играет сам и экран не открывает — источником зума его альбома он не будет.
        let zoomSources = visible.filter { $0.kind != .track }.firstPerRouteIDs
        return MosaicGrid(
            columns: MosaicLayout.columns,
            columnSpacing: MosaicLayout.columnGap,
            rowSpacing: MosaicLayout.rowGap
        ) {
            if displayedText == nil {
                // Первая выдача в пути — скелетон вперемешку (уточнение запроса держит
                // прежнюю выдачу, и скелетона не будет).
                ForEach(MosaicLayout.skeletonPattern.indices, id: \.self) { index in
                    MosaicSkeletonCard(shape: MosaicLayout.skeletonPattern[index])
                }
            } else {
                ForEach(visible) { hit in
                    MosaicCard(
                        hit: hit,
                        zoom: zoomSources.contains(hit.id) ? zoom : nil,
                        open: { route in
                            search.remember(hit)
                            open(route)
                        },
                        play: { track in
                            // Включённый трек — тот же выбор из выдачи, что переход.
                            search.remember(track)
                            playSearchTrack(track, queue: items, actionBar: actionBar)
                        }
                    )
                    .transition(.opacity)
                }
                if search.isExtendingMosaic, !items.isEmpty, revealed >= items.count {
                    ForEach(0..<MosaicLayout.tailSkeletons, id: \.self) { index in
                        MosaicSkeletonCard(shape: MosaicLayout.skeletonPattern[index])
                            .transition(.opacity)
                    }
                }
            }
        }
    }

    // MARK: Шапка

    /// Табы первого уровня и, у раздела, чипсы второго. Подложка — прогрессивный блюр
    /// на оба ряда, проявляется, когда лента уходит под них.
    private var header: some View {
        VStack(spacing: 0) {
            tabsRow
            if showsChips {
                subfilterChips
                    .opacity(chipsOpacity)
            }
        }
        // Пустая выдача всех табов — только текст «ничего не нашлось», табов нет
        // (макет `19192:42623`). Шапка гаснет вместе со старым содержимым, пока на его
        // месте встаёт текст пустой выдачи.
        .opacity(isSearchEmpty ? 0 : 1)
        .animation(MosaicMotion.fadeOut, value: isSearchEmpty)
        .allowsHitTesting(!isSearchEmpty)
        .background(alignment: .top) {
            PinnedChipsBackdrop(rows: headerHeight)
                .opacity(NavBarRamp.progress(scrolled, start: 0, length: MosaicLayout.backdropRamp))
        }
        // Оттяг — как у навигации витрин: шапка едет за лентой вчетверо медленнее.
        // Заголовок секции при оттяге едет вместе с лентой — сдвиг возвращает разницу.
        .offset(y: ServiceTopNavMotion.pullShift(for: scrolled) - max(0, -scrolled))
    }

    private var headerHeight: CGFloat {
        ServiceTopNavLayout.rowHeight + (showsChips ? FilterChipsLayout.rowHeight : 0)
    }

    /// Чипсы второго уровня — у раздела, в котором хоть что-то нашлось (правило
    /// пользователя 2026-10-31); пока выдача раздела собирается — тоже: пустые разделы
    /// публикуются сразу, без сборки (`SearchState.startTab`).
    private var showsChips: Bool {
        shownTab != .all && displayedSection?.isEmpty != true
    }

    /// Табы — лента навигации витрин (`TopNavTabStrip`): Headline S, пилюля переезжает
    /// на выбранный сразу, содержимое догоняет. Аватара нет — лента до поля экрана.
    /// Все четыре всегда, и пустые: в пустом табе — «Ничего такого не нашлось» (правило
    /// пользователя 2026-10-31).
    private var tabsRow: some View {
        let tabs = SearchTab.allCases
        // Выбранный читается здесь, а не в замыкании привязки: ручной `Binding`
        // зависимость не регистрирует.
        let selected = tabs.firstIndex(of: search.tab) ?? 0
        return TopNavTabStrip(
            titles: tabs.map(\.title),
            selection: Binding(
                get: { selected },
                set: { index in
                    guard tabs.indices.contains(index) else { return }
                    search.selectTab(tabs[index])
                }
            ),
            trailingFade: ServiceTopNavLayout.side
        )
        .frame(height: ServiceTopNavLayout.rowHeight)
    }

    /// Чипсы второго уровня — общий ряд (`FilterChipsRow`): все чипсы раздела, и пустые.
    private var subfilterChips: some View {
        let options = subfilterOptions
        let selected = search.subfilter
        return FilterChipsRow(
            options: options,
            selection: Binding(get: { selected }, set: { search.subfilter = $0 }),
            title: \.title
        )
        .modifier(DismissKeyboardOnScroll())
        // Другой таб — другой ряд: лента чипсов с начала.
        .id(shownTab)
    }

    private var subfilterOptions: [SearchSubfilter] {
        guard let kind = shownTab.kind else { return [] }
        return displayedSection?.options ?? SearchSubfilter.options(for: kind)
    }

    /// Выдача пуста целиком — по поиску, а не по снимку: текст пустой выдачи
    /// (`SearchResultsView`) встаёт сразу, и шапка уходит вместе с ним.
    private var isSearchEmpty: Bool {
        search.isMosaicEmpty
    }

    /// Выдача раздела пришла, а под показанным чипсом в ней ничего. Пустая выдача целиком —
    /// не здесь: её текст стоит выше, по центру всего экрана (`SearchResultsView`).
    private var isSectionEmpty: Bool {
        guard shownTab != .all, !isSearchEmpty, let section = displayedSection else { return false }
        if shownSubfilter == .all, section.wizard != nil { return false }
        return section.rows(shownSubfilter).isEmpty
    }

    // MARK: Смены

    /// Что сверять экрану с поиском: таб, текст и размер сетки (добор), выдача раздела, чипс.
    private var contentKey: MosaicContentKey {
        MosaicContentKey(
            tab: search.tab,
            text: search.shownText,
            count: search.mosaicHits.count,
            section: search.tabResults.map { "\($0.kind)|\($0.text)" },
            subfilter: search.subfilter
        )
    }

    /// Какая смена нужна, чтобы экран догнал поиск; `nil` — хватит правки на месте.
    private var desiredSwap: ContentSwap? {
        if search.tab != shownTab { return .tab(search.tab) }
        if shownTab == .all {
            if let text = search.shownText, let shown = displayedText, text != shown { return .text(text) }
            return nil
        }
        if let results = search.tabResults, let shown = displayedSection, results.text != shown.text {
            return .section(results.text)
        }
        if search.subfilter != shownSubfilter { return .subfilter(search.subfilter) }
        return nil
    }

    /// Свести экран с поиском. Смена — по фазам: старое гаснет, в паузе подменяется
    /// с начала ленты, новое проявляется; быстрые нажатия и набор прерывают незаконченную —
    /// встанет последнее. Правки на месте — сразу: добор сетки, первая выдача на месте
    /// скелетона (правка пользователя 2026-10-05: скелетон гас, и выдача проявлялась
    /// следом), сетка под табом раздела (её не видно).
    private func reconcile(isAppearing: Bool) {
        guard let target = desiredSwap else {
            // Вернулись к тому, что на экране, пока старое гасло, — проявить обратно.
            if swapTarget != nil {
                swap?.cancel()
                swapTarget = nil
                withAnimation(MosaicMotion.fadeIn) {
                    contentOpacity = 1
                    chipsOpacity = 1
                }
            }
            applyInPlace()
            return
        }
        guard target != swapTarget else { return }
        swap?.cancel()
        if isAppearing {
            withTransaction(Self.instant) {
                commit(target)
                contentOpacity = 1
                chipsOpacity = 1
            }
            swapTarget = nil
            return
        }
        swapTarget = target
        let fadesChips = fadesChips(for: target)
        swap = Task { @MainActor in
            withAnimation(MosaicMotion.fadeOut) {
                contentOpacity = 0
                if fadesChips { chipsOpacity = 0 }
            }
            try? await Task.sleep(for: MosaicMotion.fadeOutDuration)
            guard !Task.isCancelled else { return }
            await scrollToTopBeforeSwap()
            guard !Task.isCancelled else { return }
            // Подмена — пока содержимого не видно, без анимации: карточки не перелетают
            // и не проявляются по одной под прозрачностью.
            withTransaction(Self.instant) { commit(target) }
            swapTarget = nil
            // Пауза — пара кадров: в одном апдейте с проявлением подмена уезжала под его
            // анимацию (`MosaicMotion.swapCommit`).
            try? await Task.sleep(for: MosaicMotion.swapCommit)
            guard !Task.isCancelled else { return }
            withAnimation(MosaicMotion.fadeIn) {
                contentOpacity = 1
                chipsOpacity = 1
            }
        }
    }

    /// Подменить невидимое содержимое на то, что сейчас в поиске. Подмена берёт и то,
    /// что успело приехать, пока старое гасло.
    private func commit(_ target: ContentSwap) {
        switch target {
        case .tab:
            shownTab = search.tab
            if shownTab == .all {
                setGrid()
            } else {
                displayedSection = search.tabResults
            }
        case .text:
            setGrid()
        case .section:
            // Новый запрос — список с «Всего» (`SearchState.subfilter`).
            displayedSection = search.tabResults
            search.subfilter = .all
        case .subfilter:
            break
        }
        guard shownTab != .all else { return }
        if displayedSection == nil { displayedSection = search.tabResults }
        shownSubfilter = validSubfilter()
        // Сетка под табом раздела не видна — держим её свежей, чтобы «Всё» встало сразу.
        if displayedText != search.shownText { setGrid() }
    }

    /// Правки на месте, без смены по фазам.
    private func applyInPlace() {
        if let text = search.shownText {
            if text == displayedText {
                // Добор того же запроса — карточки встают в конец сразу.
                displayedHits = search.mosaicHits
            } else {
                // Первая выдача — на месте скелетона; или новый запрос под табом раздела,
                // когда сетки не видно.
                withTransaction(Self.instant) { setGrid() }
            }
        }
        // Выдача раздела пришла на скелетон — строки встают на его место.
        if shownTab != .all, displayedSection == nil, let results = search.tabResults {
            withTransaction(Self.instant) {
                displayedSection = results
                shownSubfilter = validSubfilter()
            }
        }
    }

    private func setGrid() {
        displayedText = search.shownText
        displayedHits = search.mosaicHits
        revealed = MosaicLayout.chunk
    }

    /// Выбранный чипс, если он есть в показанной выдаче раздела; нет (выбран над скелетоном,
    /// а в выдаче пусто) — «Всё».
    private func validSubfilter() -> SearchSubfilter {
        let selected = search.subfilter
        guard selected != .all, let section = displayedSection, !section.options.contains(selected) else { return selected }
        search.subfilter = .all
        return .all
    }

    /// Гаснет ли ряд чипсов со списком: на смене таба — всегда (ряд появляется, уходит
    /// или становится другим), на новой выдаче раздела — если ряд появляется или уходит
    /// или выбран не «Всё», на смене чипса — нет.
    private func fadesChips(for target: ContentSwap) -> Bool {
        switch target {
        case .tab: true
        case .text, .subfilter: false
        case .section: shownSubfilter != .all || search.tabResults?.isEmpty != displayedSection?.isEmpty
        }
    }

    /// Лента у низа: следующая порция, а когда показано всё — добор. Только у сетки и не
    /// во время смены: снимок ещё прежний, а добор просился бы для нового текста.
    private func requestMore() {
        guard shownTab == .all, isNearEnd, let text = displayedText, text == search.shownText else { return }
        let total = items.count
        if revealed < total {
            // Пока сетка погашена сменой, порция встаёт без анимации: иначе её транзакция
            // подхватила бы и перестановку только что подменённых карточек — они
            // перелетали бы на свои места.
            withAnimation(contentOpacity < 1 ? nil : MosaicMotion.reveal) {
                revealed = min(total, revealed + MosaicLayout.chunk)
            }
        } else if search.canExtendMosaic {
            search.extendMosaic()
        }
    }

    /// К началу ленты — до подмены, пока лента прежней длины. Лента, долистанная до конца,
    /// держит скролл за низ: короткая подмена вставала прижатой к низу экрана, и следом
    /// шапка с содержимым прыгали наверх через весь экран (правка пользователя
    /// 2026-10-05). Содержимое в этот момент погашено, а закреплённая шапка в начале
    /// ленты стоит там же, где на глубине, — глазу нечего заметить.
    private func scrollToTopBeforeSwap() async {
        guard scrolled > 0 else { return }
        withTransaction(Self.instant) { scrollResets += 1 }
        try? await Task.sleep(for: MosaicMotion.swapCommit)
    }
}

/// Смена содержимого выдачи сеткой — куда она ведёт.
private enum ContentSwap: Equatable {
    case tab(SearchTab)
    /// Новый запрос на «Всём»
    case text(String)
    /// Новая выдача раздела на его табе
    case section(String)
    case subfilter(SearchSubfilter)
}

/// Что сверять экрану выдачи сеткой с поиском (`SearchMosaicView.contentKey`).
private struct MosaicContentKey: Equatable {
    let tab: SearchTab
    let text: String?
    let count: Int
    let section: String?
    let subfilter: SearchSubfilter
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

    @Environment(ActionBarState.self) private var actionBar
    @Environment(SearchState.self) private var search
    @Environment(KeyboardObserver.self) private var keyboard
    @State private var gridOpacity: Double = 1

    private enum Layout {
        /// Заголовок — строка 28; сверху 8, а не 16 (правка пользователя 2026-10-05),
        /// снизу 20 — на 8 больше, чем у ленты каруселей (правка пользователя 2026-10-31).
        static let headerTop: CGFloat = 8
        static var headerLine: CGFloat { EntitySectionLayout.headerLine }
        static let headerBottom: CGFloat = 20
    }

    var body: some View {
        let items = search.history
        // Трек экран не открывает — источником зума его альбома он не будет.
        let zoomSources = items.filter { $0.kind != .track }.firstPerRouteIDs
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Справа — крестик удаления истории (правка пользователя 2026-10-30:
                // вместо кнопки «Удалить историю поиска» под сеткой).
                HStack(spacing: 0) {
                    Text("Искали недавно")
                        .plusHeadline(.s)
                        .foregroundStyle(Color.fillOne)
                    Spacer(minLength: 0)
                    SearchHistoryClearButton {
                        clearSearchHistoryFading($gridOpacity, search: search)
                    }
                }
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
                        // Трек играет и отсюда — но историю не переставляет, как и переход.
                        MosaicCard(
                            hit: hit,
                            zoom: zoomSources.contains(hit.id) ? zoom : nil,
                            open: open,
                            play: { track in playSearchTrack(track, queue: items, actionBar: actionBar) }
                        )
                    }
                }
                .padding(.horizontal, MosaicLayout.side)
            }
            .opacity(gridOpacity)
            // Историю удалили целиком — показывать нечего, на месте ленты пустое
            // нулевое состояние (`SearchDiscovery`).
            .opacity(items.isEmpty ? 0 : 1)
            // Как у выдачи: сетка уходит под поле и клавиатуру, низ выкручивается из-под них.
            .padding(.bottom, keyboard.overlap + PlusMetrics.actionBarHeight + MosaicLayout.barGap)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.never)
        .modifier(DismissKeyboardOnScroll())
    }
}

/// Крестик в шапке «Искали недавно» — удалить историю целиком, с системным
/// подтверждением (правка пользователя 2026-10-30: вместо кнопки «Удалить историю
/// поиска» под лентой; работает так же). Plain M — глиф 20, как шеврон заголовка;
/// круг 40 — под отрицательным отступом, раскладка шапки держит глиф.
struct SearchHistoryClearButton: View {
    /// Подтвердили — вызывающий гасит свою ленту и стирает историю
    /// (`clearSearchHistoryFading`).
    let onConfirm: () -> Void
    @State private var isConfirming = false

    var body: some View {
        PlusButton(type: .plain, size: .m, accessibilityTitle: "Удалить историю поиска", haptic: .inAction) {
            // Хаптика ✕ — medium.
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            isConfirming = true
        } icon: {
            // Fill/Five — тише заголовка (правка пользователя 2026-10-30).
            Image("iconCross")
                .renderingMode(.template)
                .resizable()
                .foregroundStyle(Color.fillFive)
        }
        .padding(-(PlusButtonSize.m.height - PlusButtonSize.m.iconBox) / 2)
        .alert("Точно удалить историю?", isPresented: $isConfirming) {
            Button("Да, удалить", role: .destructive, action: onConfirm)
            Button("Назад", role: .cancel) {}
        }
    }
}

/// История гаснет целиком — шапка и лента — той же кривой, что сетка на смене фильтра,
/// и стирается, когда её уже не видно; на её месте проявляется пустое нулевое состояние
/// (`SearchDiscovery`). Прозрачность возвращается сразу: пустая история скрыта сама,
/// а новое найденное встанет уже видимым.
@MainActor
func clearSearchHistoryFading(_ opacity: Binding<Double>, search: SearchState) {
    Task { @MainActor in
        withAnimation(MosaicMotion.fadeOut) { opacity.wrappedValue = 0 }
        try? await Task.sleep(for: MosaicMotion.fadeOutDuration)
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) {
            search.clearHistory()
            opacity.wrappedValue = 1
        }
    }
}

/// Трек выдачи — сразу в плеер бара, без перехода в альбом (правка пользователя
/// 2026-10-05, макет `2479:25744`; строки таба «Музыка» — так же, тапом по всей строке,
/// 2026-10-31). Уже стоящий в плеере — на паузу и обратно, как кнопка мини-плеера;
/// иначе запуск, как у строки полной выдачи (`startTrack`).
@MainActor
func playSearchTrack(_ track: SearchHit, queue: [SearchHit], actionBar: ActionBarState) {
    if actionBar.isMiniPlayerVisible, actionBar.music?.id == track.id {
        PlayerHaptics.tap()
        actionBar.toggleMusicPlayback()
    } else {
        startTrack(track, queue: queue, in: actionBar)
    }
}

/// Сколько осталось до низа ленты. Меняется и с высотой содержимого: дописанная
/// порция заново проверяет, не пора ли следующая, — короткая выдача добирается
/// до заполнения экрана сама.
private struct MosaicTail: Equatable {
    let contentHeight: CGFloat
    let isNear: Bool
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
    /// Тап по треку — сразу в плеер, без перехода в альбом (`playSearchTrack`).
    let play: (SearchHit) -> Void

    @Environment(ActionBarState.self) private var actionBar

    /// Постер и подпись проявились (`MosaicMotion.contentAppear`). Один раз на карточку:
    /// та же карточка в уточнённой выдаче (тот же id) не мигает заново.
    @State private var isContentShown = false

    /// Люди — кругом, с подписью по центру: исполнитель по макету, режиссёр и писатель —
    /// так же (в каруселях они постерами, в ряд с работами; в сетке рядов нет, и круг
    /// сразу отличает человека от фильма и книги).
    private var isPerson: Bool {
        switch hit.kind {
        case .artist, .director, .writer, .actor: true
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
        case .actor: "Актёр"
        case .track, .album, .artist, .playlist, .movie, .book: ""
        }
    }

    var body: some View {
        if hit.kind == .track {
            // Трек — сразу в плеер (макет `2479:25744`): кнопка play на обложке говорит,
            // что это песня, а не альбом. Нажимается вся карточка, как и остальные.
            Button { play(hit) } label: { content }
                .buttonStyle(PressScaleButtonStyle(pressedScale: PressMotion.cardScale))
                .accessibilityHint("Включить трек")
        } else if let route = hit.route {
            Button { open(route) } label: { content }
                .buttonStyle(PressScaleButtonStyle(pressedScale: PressMotion.cardScale))
                // Экран сущности разворачивается из карточки и сворачивается в неё — как
                // из каруселей.
                .modifier(SearchResultsView.SearchZoomSource(route: route, zoom: zoom))
        } else {
            content
        }
    }

    /// Этот трек сейчас играет — на кнопке пауза.
    private var isPlayingThisTrack: Bool {
        hit.kind == .track && actionBar.isMiniPlayerVisible
            && actionBar.music?.id == hit.id && actionBar.isMusicPlaying
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
                .coverArtworkMissing(hit.artwork == nil)
                .clipShape(shape)
                .coverBorder(shape)
                .overlay(alignment: .bottomLeading) {
                    if hit.kind == .track {
                        MosaicPlayBadge(isPlaying: isPlayingThisTrack)
                            .padding(MosaicLayout.playInset)
                            .opacity(isContentShown ? 1 : 0)
                    }
                }
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
        case .track, .album, .artist, .playlist, .director, .writer, .actor: MosaicLayout.card
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

/// Кнопка play на обложке трека — `button` макета `2479:25744`: вид `PlusButton`
/// secondary, слева снизу (в сетке M с отступом 6, в строке таба «Музыка» S с отступом 4).
/// Сама не нажимается: нажимается вся карточка, кнопка — знак, что это трек. Играет
/// этот трек — на ней пауза, сменой как в плеере.
struct MosaicPlayBadge: View {
    let isPlaying: Bool
    var size: PlusButtonSize = MosaicLayout.playButton

    var body: some View {
        PlusButtonLabel(type: .secondary, size: size) {
            PlayPauseGlyph(isPlaying: isPlaying, box: size.iconBox)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Скелетон

/// Форма скелетона сетки — виды будущих карточек.
enum MosaicSkeletonShape {
    case poster, square, round, book
}

/// Скелетон — того же габарита, что карточка своего вида: обложка той же формы, без
/// кромки (у скелетонов её нет нигде), и полоски на месте строк подписи.
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
                .frame(width: MosaicLayout.card, height: MosaicLayout.card)
        case .poster, .square:
            let rect = RoundedRectangle(cornerRadius: MosaicLayout.coverRadius, style: .continuous)
            rect
                .fill(PlusSkeleton.fill)
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
