import SwiftUI

/// Выдача кросс-сервисного поиска — карусели по макету `2118:17378`: секция на домен,
/// внутри горизонтальная лента карточек.
///
/// Карточек два вида, и это не украшательство, а форма самого контента: у музыки
/// обложка квадратная (у исполнителя — круглая), у кино и книг постер 2:3. Ширина
/// колонки одна на оба вида — 109, поэтому ленты разных секций стоят по одной сетке.
///
/// Слой живёт **между затемнением и action bar**: расфокусивающий тап по затемнению
/// остаётся рабочим вокруг выдачи, а бар с полем ввода рисуется поверх и не перекрыт.
///
/// Пока запрос короче двух символов, на месте выдачи — нулевое состояние: карусель
/// «Искали недавно» (`SearchRecents`, макет `2118:17378`).
struct SearchResultsView: View {
    /// Показывать ли слой. Считает корень: признак шире клавиатуры — поиск остаётся
    /// на экране и пока пользователь возвращается из открытой карточки
    /// (см. `AppRootView.isSearchShown`).
    let isShown: Bool
    @Environment(SearchState.self) private var search
    @Environment(AppNavigationState.self) private var navigation
    @Environment(ActionBarState.self) private var actionBar
    @Environment(KeyboardObserver.self) private var keyboard
    @Environment(\.stackZoomNamespace) private var zoom

    /// Что в слое — выдача или «Искали недавно». Следует за запросом, пока поиск
    /// открыт; на закрытии замирает: «Назад» стирает запрос тем же движением, что
    /// гасит слой, и на гаснущей выдаче на миг проявлялась бы лента «Искали недавно».
    @State private var showsResults = false

    #if DEBUG
    @MainActor private static var didDebugTapHit = false
    @MainActor private static var didDebugExpand = false
    #endif

    /// Переход в полную выдачу раздела и обратно — как пуш: раздел въезжает справа,
    /// обзор отъезжает влево и гаснет. Кривая — iOS-шторка: быстрый старт, долгое
    /// торможение, ни один край не дёргается.
    private enum SectionMotion {
        static let push: Animation = .timingCurve(0.32, 0.72, 0, 1, duration: 0.4)
        /// Обзор гаснет быстрее, чем въезжает раздел: иначе скелетон раздела 0.4s
        /// лежал поверх ещё видимых обложек обзора и казался ярче каруселей
        /// (жалоба пользователя 2026-10-03, поймано на записи).
        static let overviewFade: Animation = .easeOut(duration: 0.15)
        /// На сколько отъезжает обзор: намёк на глубину, а не полный уезд.
        static let overviewShift: CGFloat = 80
    }

    /// Смена «Искали недавно» ↔ выдача на втором символе запроса и обратно —
    /// почти последовательно: уходящее гаснет быстро, приходящее проявляется чуть
    /// позже и дольше. Обе стоят в одном месте под статус-баром, и полным кроссфейдом
    /// две ленты на миг лежали бы друг на друге.
    private enum RecentsMotion {
        static let disappear: Animation = .easeOut(duration: 0.12)
        static let appear: Animation = .easeOut(duration: 0.2).delay(0.08)
        static var swap: AnyTransition {
            .asymmetric(
                insertion: .opacity.animation(appear),
                removal: .opacity.animation(disappear)
            )
        }
    }

    /// Габариты, которые зависят от размера карточек выдачи.
    private struct CardMetrics {
        /// Ширина колонки карусели
        let card: CGFloat
        /// Высота обложки книги — ширина её карточки идёт от неё по пропорциям обложки
        let bookCoverHeight: CGFloat
        /// Карточек в скелетоне: видимые целиком и та, что торчит из-под края
        let skeletonCards: Int
        /// Собственное поле секции по вертикали
        let sectionVertical: CGFloat
        /// Правое поле подписи у постеров и книг; у квадратов оно всегда 8
        let posterLabelTrailing: CGFloat

        /// Прежний размер — макеты `2118:17378` (карусели) и `2311:25096` (книги):
        /// три карточки целиком и четвёртая из-под края. Поле секции 2 вместо
        /// макетных 8 — правка пользователя 2026-08-25.
        static let regular = CardMetrics(
            card: 109,
            bookCoverHeight: 156,
            skeletonCards: 4,
            sectionVertical: 2,
            posterLabelTrailing: 8
        )
        /// Small — макет `2385:33949`: четыре карточки целиком и пятая из-под края
        /// (шаг 94 на экране 402). Секции стоят вплотную, подпись постера и книги —
        /// во всю ширину карточки: так в макете.
        static let small = CardMetrics(
            card: 86,
            bookCoverHeight: 128,
            skeletonCards: 5,
            sectionVertical: 0,
            posterLabelTrailing: 0
        )
    }

    private enum Layout {
        /// Размер карточек выдачи — small (правка пользователя 2026-10-03, макет
        /// `2385:33949`). Прежний остаётся `CardMetrics.regular`.
        static let size = CardMetrics.small
        /// Ширина колонки карусели
        static var card: CGFloat { size.card }
        static let cardGap: CGFloat = 8
        /// Боковые поля выдачи — 16, а не общие 24 экрана: в макете `2118:17378`
        /// карусель и заголовки стоят на x = 16 (правка пользователя 2026-10-03).
        static let side: CGFloat = 16
        /// Обложка → подписи
        static let coverGap: CGFloat = 6
        /// Постер кино и книги — 2:3 (макеты: 109 × 163.5, у small 86 × 129)
        static let posterAspect: CGFloat = 109.0 / 163.5
        static let coverRadius = PlusRadius.movieChip
        /// Собственное поле секции — по размеру карточек (`CardMetrics`). Поля
        /// самого заголовка (16/12) макетные у обоих размеров.
        static var sectionVertical: CGFloat { size.sectionVertical }
        static let headerTop: CGFloat = 16
        static let headerBottom: CGFloat = 12
        /// Строка заголовка — 28, как в `header / static` обоих макетов (56 = 16 + 28
        /// + 12). Стиль UI kit — 24 при интерлиньяже 100 %, поэтому строку держит рамка,
        /// а текст стоит по её центру — на той же базовой линии, что в Фигме. Без рамки
        /// заголовок сидел на 2 выше, а карусель под ним — на 4.
        static let headerLine: CGFloat = 28
        /// Зазор «заголовок ↔ шеврон» из макета
        static let headerGap: CGFloat = 2
        static let chevronBox: CGFloat = 20
        /// Зазор между низом выдачи и верхом поднятого бара
        static let barGap: CGFloat = 12
        static var skeletonCards: Int { size.skeletonCards }
        /// Правое поле подписи квадратной карточки: в макете текст уже колонки на 8
        static let labelTrailing: CGFloat = 8
        /// Подпись всегда высотой под максимум — две строки названия и строка
        /// подписи (Text S, 16): скелетон и загруженная карточка одного габарита,
        /// и пришедшая выдача не двигает карусели под собой (жалоба 2026-10-03).
        static let labelHeight: CGFloat = 3 * PlusTextSize.textS.lineHeight
        /// Полоски скелетона на месте строк: 12 из 16, по центру строки.
        static let skeletonBar: CGFloat = 12
        static let skeletonBarInset: CGFloat = (PlusTextSize.textS.lineHeight - skeletonBar) / 2
        /// Полосы подписи — доли ширины карточки: 88 и 60 у прежней колонки 109,
        /// у small 69 и 47 — иначе верхняя вылезала бы за карточку.
        static var skeletonTitleBar: CGFloat { (card * 0.8).rounded() }
        static var skeletonSubtitleBar: CGFloat { (card * 0.55).rounded() }
        /// Полоса на месте заголовка секции — 16 по высоте глифов кегля 24 (пропорция
        /// та же, что у полос подписи). Ширина — под название средней длины.
        static let skeletonHeaderBar: CGFloat = 16
        static let skeletonHeaderWidth: CGFloat = 96
        /// Обложка проявляется поверх бледной заливки скелетона, без второго,
        /// яркого серого (правка пользователя 2026-10-03) — общим `PlusSkeleton`.
        static let coverAppear: Animation = PlusSkeleton.appear

        // Карточка книги — макеты `2311:25096` и `2385:33949`: книга в небольшой проекции.
        /// Высота обложки — по размеру карточек; ширина — по её пропорциям, обложка
        /// не режется.
        static var bookCoverHeight: CGFloat { size.bookCoverHeight }
        /// Пропорции, пока своих нет, — постер 2:3.
        static let bookDefaultAspect: CGFloat = 2.0 / 3.0
        /// Крайние пропорции: дальше обложка уже режется — иначе альбомный скан
        /// растянул бы карточку на пол-экрана, а узкий сжал бы подпись в столбик.
        static let bookAspectRange: ClosedRange<CGFloat> = 0.55...1.0
        /// Подложка-блок страниц выглядывает из-за обложки на 2 сверху и на 3 справа.
        static let bookPagesTop: CGFloat = 2
        static let bookPagesRight: CGFloat = 3
        /// Сколько из этих 3 карточка забирает в свою ширину — `pr-[2px]` макета;
        /// последний пункт уходит в зазор до соседа.
        static let bookPagesInset: CGFloat = 2
        static let bookCoverRadius: CGFloat = 8
        /// Скругление серой подложки — 10, у обложки 8 (правка пользователя 2026-10-03;
        /// в экспорте макета было 16).
        static let bookPagesRadius: CGFloat = 10
        /// Скошенный верх корешка у подложки: 4.1 % её ширины по горизонтали, 1.93 вниз.
        static let bookSpineBevel = CGSize(width: 0.0406, height: 1.93)
        static let bookPagesFill = Color.white.opacity(0.15)
        static let bookHingeWidth: CGFloat = 10

        /// «Искали недавно» — лента вперемешку: обложки разной высоты стоят на одном
        /// низе, а подписи — на одной линии (`cover` макета: 129 и квадрат внизу).
        /// Бокс — по самой высокой обложке: книга с блоком страниц (130) чуть выше
        /// постера (129).
        static var recentsCoverBox: CGFloat {
            max(card / posterAspect, bookCoverHeight + bookPagesTop)
        }
    }

    private static let recentsTitle = "Искали недавно"

    var body: some View {
        // Признак общий с затемнением (`SearchOverlay`) — иначе слои разъезжались бы.
        ZStack {
            // Распорка под наблюдатели: им нужна живая вью и тогда, когда слоя нет.
            Color.clear
                .allowsHitTesting(false)
                .onChange(of: search.isActive, initial: true) { _, active in
                    // Пока слой гаснет, поддерево заморожено — менять можно смело.
                    if isSearchOpen || !isShown { showsResults = active }
                }
                .onChange(of: isShown) { _, shown in
                    // Погасший слой встретит следующее открытие уже нужной лентой.
                    if !shown { showsResults = search.isActive }
                }

            if isShown { layer }
        }
        // Слой проявляется и гаснет **той же кривой, что затемнение** под ним
        // (`SearchOverlayConfig.fade`), — одним движением с экраном поиска. Без
        // неё он вставал по транзакции, в которой сменился признак: фокус ставится
        // без анимации, и «Искали недавно» появлялась раньше затемнения, мгновенно
        // (жалоба пользователя 2026-10-03). Модификатором, а не анимацией на переходе:
        // его гасит `disablesAnimations` — тап по своему табу снимает поиск сразу.
        .animation(SearchOverlayConfig.fade, value: isShown)
    }

    /// Поиск открыт: поле в фокусе, просмотр без клавиатуры или уход в карточку.
    /// Не открыт, а слой ещё стоит — значит, закрывается: его держит уезжающая
    /// клавиатура.
    private var isSearchOpen: Bool {
        actionBar.isSearchFocused || search.isBrowsing || search.isSuspended
    }

    private var layer: some View {
        ZStack {
            if showsResults {
                results
                    .transition(RecentsMotion.swap)
            } else {
                recentsSection
                    .transition(RecentsMotion.swap)
            }
        }
        // Кривая — у родителя (`.animation(_, value: isShown)` в `body`).
        .transition(.opacity)
            #if DEBUG
            // `-debugExpandSection music|movies|books` — раскрыть раздел, когда
            // выдача пришла: тапнуть по заголовку из шелла нечем. Один раз за запуск.
            .task(id: search.sections.first?.domain.hits.first?.id) {
                guard let raw = UserDefaults.standard.string(forKey: "debugExpandSection"),
                      !Self.didDebugExpand,
                      search.sections.contains(where: { !$0.domain.hits.isEmpty })
                else { return }
                let kind: SearchState.Section.Kind? = switch raw {
                case "music": .music
                case "movies": .movies
                case "books": .books
                default: nil
                }
                guard let kind else { return }
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, !Self.didDebugExpand else { return }
                Self.didDebugExpand = true
                search.expand(kind)
            }
            // `-debugTapSearchHit <n>` — открыть первую карточку n-й непустой
            // секции выдачи (1 — первая): тапнуть по симулятору из шелла нечем,
            // а возврат в поиск иначе не проверить. В паре с `-debugCloseEntity`
            // даёт полный круг «ушёл — вернулся». Один раз за запуск: на возврате
            // выдача появляется снова, и тап повторился бы по кругу.
            .task(id: search.sections.first?.domain.hits.first?.id) {
                let section = UserDefaults.standard.integer(forKey: "debugTapSearchHit")
                guard section > 0, !Self.didDebugTapHit else { return }
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled, !Self.didDebugTapHit else { return }
                let filled = search.sections.filter { !$0.domain.hits.isEmpty }
                // Первая нажимаемая: персона (первой в карусели) экрана не имеет.
                guard filled.indices.contains(section - 1),
                      let route = filled[section - 1].domain.hits.first(where: { $0.route != nil })?.route
                else { return }
                Self.didDebugTapHit = true
                open(route)
            }
            #endif
    }

    /// Выдача: обзор каруселями и раскрытый раздел над ним.
    private var results: some View {
        // Обзор остаётся в дереве под разделом — со своей позицией скролла: «Назад»
        // возвращает туда же, где пользователь был. Раздел вставляется поверх.
        ZStack {
            content
                .opacity(search.expanded == nil ? 1 : 0)
                .animation(SectionMotion.overviewFade, value: search.expanded)
                .offset(x: search.expanded == nil ? 0 : -SectionMotion.overviewShift)
                .allowsHitTesting(search.expanded == nil)
                .accessibilityHidden(search.expanded != nil)

            if let kind = search.expanded {
                SearchSectionView(kind: kind, open: open, zoom: zoom)
                    .transition(.move(edge: .trailing))
            }
        }
        .animation(SectionMotion.push, value: search.expanded)
    }

    private var content: some View {
        ZStack {
            overviewList
            if search.isEmptyResult {
                SearchEmptyState()
            }
        }
    }

    // MARK: Искали недавно

    /// Нулевое состояние поиска — одна карусель вперемешку, сразу под статус-баром,
    /// как первая секция выдачи. Видна всегда: за найденным стоит стартовый набор.
    ///
    /// Шеврон в заголовке — по макету (`header / static`); полного списка истории
    /// пока нет, заголовок не нажимается.
    private var recentsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            header(Self.recentsTitle)
                .accessibilityAddTraits(.isHeader)

            let recents = search.recents
            let zoomSources = Self.firstPerRoute(recents)
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: Layout.cardGap) {
                    ForEach(recents) { hit in
                        // Тап отсюда историю не переставляет: лента сдвинулась бы
                        // под зумом открытой карточки, и на возврате он сворачивался
                        // бы не в ту карточку.
                        card(
                            hit,
                            coverBox: Layout.recentsCoverBox,
                            remembers: false,
                            zooms: zoomSources.contains(hit.id)
                        )
                    }
                }
                .padding(.horizontal, Layout.side)
            }
            .scrollIndicators(.hidden)
            // Как у каруселей выдачи: скролл уводит клавиатуру, поиск остаётся
            // на экране без неё (`SearchState.isBrowsing`).
            .onScrollPhaseChange { _, phase in dismissKeyboardOnScroll(phase) }
        }
        .padding(.vertical, Layout.sectionVertical)
        // Пустое место вокруг ленты не ловит касаний: тап мимо неё — по затемнению,
        // он закрывает поиск.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// Карточки, которым быть источником зума: первая на каждый маршрут. Трек ведёт
    /// на свой альбом, и трек с альбомом в истории — два источника с одним id:
    /// зум выбирал бы из них наугад (ревью 2026-10-03). Остальные с тем же маршрутом
    /// открываются без источника — из центра экрана.
    private static func firstPerRoute(_ hits: [SearchHit]) -> Set<String> {
        var seen: Set<EntityRoute> = []
        return Set(hits.filter { hit in
            guard let route = hit.route else { return false }
            return seen.insert(route).inserted
        }.map(\.id))
    }

    private var overviewList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Порядок секций даёт состояние: выдача приходит целиком, когда
                // ответили все три домена, и уже отранжированной по релевантности
                // запросу (см. `SearchState.sections`) — блоки не переставляются.
                ForEach(search.sections) { section in
                    carousel(section)
                }

            }
            // Кадр списка — во весь экран, а отступ только у содержимого: выдача
            // **уходит под** поле и клавиатуру и просвечивает сквозь их стекло (правка
            // пользователя 2026-08-25; прежде кадр поджимался и список обрывался над
            // баром). Отступ всё равно нужен: без него последняя карточка не
            // выкручивается из-под клавиатуры.
            //
            // Именно отступ содержимого, а не `safeAreaPadding` кадра: тот входит
            // в минимальную высоту списка, а с клавиатурой он больше места над ней
            // (553 против 477). Экран-носитель переполнялся, SwiftUI ставил стопку
            // по центру, и выдача с клавиатурой стояла на 38pt выше, чем без неё
            // (замер 2026-10-03).
            .padding(.bottom, keyboard.overlap + PlusMetrics.actionBarHeight + Layout.barGap)
        }
        .scrollIndicators(.hidden)
        // Клавиатура уходит с первого движения скролла — и вертикального, и каруселей
        // (правка пользователя 2026-10-03; прежде — только протяжкой в саму клавиатуру).
        // Убираем её сами и мягко (`dismissKeyboardOnScroll`), системный уход выключен:
        // он рывком — почти весь путь за первые ~0.17s, а за клавиатурой и поле (жалоба
        // 2026-10-03).
        // Фокус снимается вместе с ней, и выдача остаётся на экране без клавиатуры
        // (`SearchState.isBrowsing`).
        .scrollDismissesKeyboard(.never)
        .onScrollPhaseChange { _, phase in dismissKeyboardOnScroll(phase) }
        // Сверху — ровно безопасная зона, без добавки: в макете `2118:17378` выдача
        // начинается сразу под статус-баром. Прежний `safeAreaPadding(.top)` клал
        // сверху ещё 16pt системного поля.
    }

    // MARK: Секция

    @ViewBuilder
    private func carousel(_ section: SearchState.Section) -> some View {
        let domain = section.domain
        if domain.isLoading || !domain.hits.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                if domain.isLoading {
                    skeletonHeader
                } else {
                    // Заголовок с шевроном — переход в полную выдачу раздела (задача
                    // пользователя 2026-10-03).
                    Button {
                        search.expand(section.id)
                        // В полный список — без клавиатуры (правка пользователя
                        // 2026-10-03): тем же мягким уходом, выдача — в просмотр.
                        if actionBar.isSearchFocused { keyboard.dismissSmoothly() }
                    } label: {
                        header(section.title)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(section.title)
                    .accessibilityHint("Вся выдача раздела")
                }

                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: Layout.cardGap) {
                        if domain.hits.isEmpty {
                            // Скелетон повторяет форму карточек своей секции, иначе
                            // приход выдачи перекладывал бы ленту.
                            ForEach(0..<Layout.skeletonCards, id: \.self) { _ in
                                skeletonCard(section.id)
                            }
                        } else {
                            ForEach(domain.hits) { hit in card(hit) }
                        }
                    }
                    .padding(.horizontal, Layout.side)
                }
                .scrollIndicators(.hidden)
                .onScrollPhaseChange { _, phase in dismissKeyboardOnScroll(phase) }
            }
            .padding(.vertical, Layout.sectionVertical)
        }
    }

    /// Заголовок секции с шевроном — `header / static` из макета: 24/28 и глиф 20
    /// сразу за текстом, а не у правого края.
    private func header(_ title: String) -> some View {
        HStack(spacing: Layout.headerGap) {
            Text(title)
                .plusHeadline(.m)
                .foregroundStyle(Color.fillOne)

            // Правый шеврон — отзеркаленный `icon / dropleft`: своего ассета нет,
            // а глиф тот же (приём «не плодить зеркальные ассеты»).
            Image("iconDropleft")
                .renderingMode(.template)
                .resizable()
                .frame(width: Layout.chevronBox, height: Layout.chevronBox)
                .scaleEffect(x: -1)
                .foregroundStyle(Color.fillSubtitle)
                .offset(y: PlusMetrics.headerChevronDrop)
        }
        .frame(height: Layout.headerLine)
        .padding(.top, Layout.headerTop)
        .padding(.bottom, Layout.headerBottom)
        .padding(.horizontal, Layout.side)
    }

    /// Заголовок секции в скелетоне — полоса без шеврона. Название врало бы
    /// о порядке: он известен, только когда ответили все домены, и до этого
    /// секции стоят в порядке по умолчанию (правка пользователя 2026-10-03).
    /// Габарит — как у настоящего заголовка: строка той же высоты и те же поля.
    private var skeletonHeader: some View {
        Rectangle()
            .fill(PlusSkeleton.fill)
            .frame(width: Layout.skeletonHeaderWidth, height: Layout.skeletonHeaderBar)
            .frame(height: Layout.headerLine)
            .padding(.top, Layout.headerTop)
            .padding(.bottom, Layout.headerBottom)
            .padding(.horizontal, Layout.side)
            .accessibilityHidden(true)
    }

    // MARK: Карточка

    /// Карточка карусели. `coverBox` — общая высота места под обложку (лента
    /// вперемешку, «Искали недавно»): обложка стоит на его низу. `remembers` —
    /// переход кладёт айтем в «Искали недавно» (из выдачи — да, из самой ленты — нет).
    /// `zooms` — карточка источник зума своего экрана (см. `firstPerRoute`).
    @ViewBuilder
    private func card(
        _ hit: SearchHit,
        coverBox: CGFloat? = nil,
        remembers: Bool = true,
        zooms: Bool = true
    ) -> some View {
        if let route = hit.route {
            Button {
                if remembers { search.remember(hit) }
                open(route)
            } label: {
                if hit.kind == .book {
                    bookCardBody(hit, coverBox: coverBox)
                } else {
                    cardBody(hit, coverBox: coverBox)
                }
            }
            .buttonStyle(PressScaleButtonStyle())
            // Источник зума экрана сущности — как миниатюра на витрине: экран
            // разворачивается из карточки и на возврате сворачивается обратно в неё.
            // Без источника зум шёл из центра экрана и сворачивался в никуда.
            .modifier(SearchZoomSource(route: route, zoom: zooms ? zoom : nil))
        } else if hit.kind == .book {
            bookCardBody(hit, coverBox: coverBox)
        } else {
            cardBody(hit, coverBox: coverBox)
        }
    }

    /// Уход в сущность из выдачи. Клавиатура опускается, но сам поиск не сбрасывается:
    /// запомнили точку, и на возврате та же выдача встанет на экран — без клавиатуры,
    /// с полем внизу (`SearchState.isBrowsing`).
    private func open(_ route: EntityRoute) {
        search.suspend(tab: navigation.activeTab, depth: navigation.depth)
        actionBar.isSearchFocused = false
        // Обычным способом: карточка фильма встаёт слоем поверх хрома, альбом
        // и книга пушатся в стек — и там, и там выдача остаётся под открытым
        // экраном, потому что живёт на том, с которого поиск открыли
        // (`SearchLayers`, глубина в `SearchState.hostDepth`).
        navigation.open(route)
    }

    private func cardBody(_ hit: SearchHit, coverBox: CGFloat? = nil) -> some View {
        // Исполнитель по макету центрирован — и обложка кругом, и подпись по центру.
        let isArtist = hit.kind.isRoundArtwork

        return VStack(alignment: isArtist ? .center : .leading, spacing: Layout.coverGap) {
            cover(hit)
                .frame(height: coverBox, alignment: .bottom)

            VStack(alignment: isArtist ? .center : .leading, spacing: 0) {
                Text(hit.title)
                    .plusText(.textS, .medium)
                    .foregroundStyle(Color.fillOne)
                    .lineLimit(2)
                    .multilineTextAlignment(isArtist ? .center : .leading)

                if !hit.subtitle.isEmpty {
                    Text(hit.subtitle)
                        .plusText(.textS, .medium)
                        .foregroundStyle(Color.fillSubtitle)
                        .lineLimit(1)
                }
            }
            // Подпись — своей высоты, а не той, что предлагает рамка 48: строки YS Text
            // после округления до пикселя чуть выше 16, две строки названия в 48
            // не влезали на доли пункта, и SwiftUI обрезал их до одной (замер
            // 2026-10-03, в макете — две). Габарит карточки держит рамка ниже.
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: isArtist ? .center : .leading)
            // В макете подпись уже колонки: длинное название обрывается раньше
            // правого края карточки (у квадратов; см. `labelTrailing`).
            .padding(.trailing, labelTrailing(hit.kind))
            .frame(height: Layout.labelHeight, alignment: .top)
        }
        .frame(width: Layout.card)
        .contentShape(.rect)
    }

    private func cover(_ hit: SearchHit) -> some View {
        let shape: AnyShape = hit.kind.isRoundArtwork
            ? AnyShape(Circle())
            : AnyShape(RoundedRectangle(cornerRadius: Layout.coverRadius, style: .continuous))

        // Заливка — ровно та же, что у скелетона: карточка встаёт на его место
        // без смены цвета. Плейсхолдер загрузчика прозрачный — у `ArtworkImage`
        // он свой, ярче, и ложился поверх заливки вторым серым.
        return PlusSkeleton.fill
            .frame(width: Layout.card)
            .frame(height: coverHeight(hit.kind))
            .overlay {
                if let source = hit.artwork {
                    ResolvedArtwork(source: source, appear: Layout.coverAppear) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Color.clear
                    }
                }
            }
            .clipShape(shape)
            .overlay { shape.stroke(PlusSkeleton.fill, lineWidth: PlusMetrics.hairline) }
    }

    // MARK: Карточка книги

    /// Книга в небольшой проекции — макет `2311:25096`: обложка своих пропорций
    /// (ширина карточки по ней, обложка не режется), за ней выглядывает блок страниц,
    /// у корешка — притенённый сгиб.
    private func bookCardBody(_ hit: SearchHit, coverBox: CGFloat? = nil) -> some View {
        let coverWidth = Self.bookCoverWidth(hit.artworkAspect)
        return VStack(alignment: .leading, spacing: Layout.coverGap) {
            bookFigure(coverWidth: coverWidth) {
                if let source = hit.artwork {
                    ResolvedArtwork(source: source, appear: Layout.coverAppear) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Color.clear
                    }
                }
            }
            .frame(height: coverBox, alignment: .bottom)

            VStack(alignment: .leading, spacing: 0) {
                Text(hit.title)
                    .plusText(.textS, .medium)
                    .foregroundStyle(Color.fillOne)
                    .lineLimit(2)
                if !hit.subtitle.isEmpty {
                    Text(hit.subtitle)
                        .plusText(.textS, .medium)
                        .foregroundStyle(Color.fillSubtitle)
                        .lineLimit(1)
                }
            }
            // Своей высоты — см. `cardBody`.
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, labelTrailing(.book))
            .frame(height: Layout.labelHeight, alignment: .top)
        }
        .frame(width: coverWidth + Layout.bookPagesInset)
        .contentShape(.rect)
    }

    /// Ширина обложки книги — по её пропорциям в допустимых пределах.
    private static func bookCoverWidth(_ aspect: CGFloat?) -> CGFloat {
        let range = Layout.bookAspectRange
        let clamped = min(max(aspect ?? Layout.bookDefaultAspect, range.lowerBound), range.upperBound)
        return (Layout.bookCoverHeight * clamped).rounded()
    }

    /// Книга целиком: блок страниц, обложка с бордером на трёх сторонах, сгиб у корешка.
    /// Обложку подставляет вызывающий — у скелетона на её месте только заливка.
    private func bookFigure(coverWidth: CGFloat, @ViewBuilder cover: () -> some View) -> some View {
        let coverShape = UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: Layout.bookCoverRadius,
            topTrailingRadius: Layout.bookCoverRadius,
            style: .continuous
        )
        let pages = BookPagesShape(
            radius: Layout.bookPagesRadius,
            bevel: Layout.bookSpineBevel
        )
        return ZStack(alignment: .topLeading) {
            pages
                .fill(Layout.bookPagesFill)
                .overlay { pages.stroke(PlusSkeleton.fill, lineWidth: PlusMetrics.hairline) }
                .frame(
                    width: coverWidth + Layout.bookPagesRight,
                    height: Layout.bookCoverHeight + Layout.bookPagesTop
                )

            PlusSkeleton.fill
                .overlay { cover() }
                .frame(width: coverWidth, height: Layout.bookCoverHeight)
                .clipShape(coverShape)
                .overlay {
                    // Бордер только сверху, справа и снизу: слева корешок.
                    BookCoverEdge(radius: Layout.bookCoverRadius)
                        .stroke(PlusSkeleton.fill, lineWidth: PlusMetrics.hairline)
                }
                .overlay(alignment: .leading) {
                    BookHingeShade.gradient
                        .frame(width: Layout.bookHingeWidth)
                        .allowsHitTesting(false)
                }
                .padding(.top, Layout.bookPagesTop)
        }
        // Кадр книги — без последнего пункта подложки справа: он уходит в зазор
        // до соседней карточки, как в макете.
        .frame(
            width: coverWidth + Layout.bookPagesInset,
            height: Layout.bookCoverHeight + Layout.bookPagesTop,
            alignment: .topLeading
        )
    }

    /// Скролл выдачи начался — клавиатура уходит мягко (`KeyboardDismissMotion`).
    /// Фаза `.interacting`, а не `.tracking`: касание без движения ещё не скролл.
    private func dismissKeyboardOnScroll(_ phase: ScrollPhase) {
        guard phase == .interacting, actionBar.isSearchFocused else { return }
        keyboard.dismissSmoothly()
    }

    /// Правое поле подписи: у квадратов — 8 (текст уже колонки), у исполнителя
    /// подпись по центру, у постеров и книг — по размеру карточек (в small его нет).
    private func labelTrailing(_ kind: SearchHit.Kind) -> CGFloat {
        switch kind {
        case .artist: 0
        case .track, .album, .playlist: Layout.labelTrailing
        case .movie, .book, .director, .writer: Layout.size.posterLabelTrailing
        }
    }

    /// Квадрат у музыки, постер 2:3 у кино и книг. Режиссёр — постером, как соседи
    /// по карусели; писатель — во всю высоту книги с блоком страниц, чтобы верх и низ
    /// фото стояли вровень с книгами (макет пользователя 2026-10-03).
    private func coverHeight(_ kind: SearchHit.Kind) -> CGFloat {
        switch kind {
        case .track, .album, .artist, .playlist: Layout.card
        case .movie, .book, .director: Layout.card / Layout.posterAspect
        case .writer: Layout.bookCoverHeight + Layout.bookPagesTop
        }
    }

    /// Источник зума — только когда есть namespace (корень приложения). Общий
    /// с полной выдачей раздела (`SearchSectionView`).
    struct SearchZoomSource: ViewModifier {
        let route: EntityRoute
        let zoom: Namespace.ID?

        func body(content: Content) -> some View {
            if let zoom {
                content.matchedTransitionSource(id: route, in: zoom)
            } else {
                content
            }
        }
    }

    /// Скелетон — того же габарита, что карточка: обложка той же высоты, подпись
    /// той же фиксированной высоты, тот же хайрлайн по кромке обложки. У книг —
    /// та же книга в проекции, только без обложки.
    @ViewBuilder
    private func skeletonCard(_ kind: SearchState.Section.Kind) -> some View {
        if kind == .books {
            let coverWidth = Self.bookCoverWidth(nil)
            VStack(alignment: .leading, spacing: Layout.coverGap) {
                bookFigure(coverWidth: coverWidth) { EmptyView() }
                skeletonLabel
            }
            .frame(width: coverWidth + Layout.bookPagesInset)
            .accessibilityLabel("Загрузка")
        } else {
            let shape = RoundedRectangle(cornerRadius: Layout.coverRadius, style: .continuous)
            VStack(alignment: .leading, spacing: Layout.coverGap) {
                shape
                    .fill(PlusSkeleton.fill)
                    .overlay { shape.stroke(PlusSkeleton.fill, lineWidth: PlusMetrics.hairline) }
                    .frame(width: Layout.card)
                    .frame(height: kind == .movies ? Layout.card / Layout.posterAspect : Layout.card)
                skeletonLabel
            }
            .frame(width: Layout.card)
            .accessibilityLabel("Загрузка")
        }
    }

    /// Полоски на месте строк названия и подписи — по центру своих строк.
    private var skeletonLabel: some View {
        VStack(alignment: .leading, spacing: 2 * Layout.skeletonBarInset) {
            Rectangle().fill(PlusSkeleton.fill).frame(width: Layout.skeletonTitleBar, height: Layout.skeletonBar)
            Rectangle().fill(PlusSkeleton.fill).frame(width: Layout.skeletonSubtitleBar, height: Layout.skeletonBar)
        }
        .padding(.top, Layout.skeletonBarInset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: Layout.labelHeight, alignment: .top)
    }
}

// MARK: - Книга в проекции

/// Блок страниц за обложкой — `bg` макета `2311:25096`: правые углы скруглены
/// сильнее обложки, левый верхний скошен — это верх корешка, видный в проекции.
private struct BookPagesShape: Shape {
    let radius: CGFloat
    /// Скос: доля ширины по горизонтали и пункты по вертикали.
    let bevel: CGSize

    func path(in rect: CGRect) -> Path {
        let body = UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: radius,
            topTrailingRadius: radius,
            style: .continuous
        ).path(in: rect)
        var corner = Path()
        corner.move(to: CGPoint(x: rect.minX, y: rect.minY))
        corner.addLine(to: CGPoint(x: rect.minX + rect.width * bevel.width, y: rect.minY))
        corner.addLine(to: CGPoint(x: rect.minX, y: rect.minY + bevel.height))
        corner.closeSubpath()
        return body.subtracting(corner)
    }
}

/// Бордер обложки на трёх сторонах — сверху, справа и снизу: слева корешок,
/// и кромки там нет (макет `2311:25096`). Линия внутри кадра, как `border` макета.
private struct BookCoverEdge: Shape {
    let radius: CGFloat
    var lineWidth: CGFloat = PlusMetrics.hairline

    func path(in rect: CGRect) -> Path {
        let inset = lineWidth / 2
        let top = rect.minY + inset
        let bottom = rect.maxY - inset
        let right = rect.maxX - inset
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: top))
        path.addArc(
            tangent1End: CGPoint(x: right, y: top),
            tangent2End: CGPoint(x: right, y: bottom),
            radius: radius - inset
        )
        path.addArc(
            tangent1End: CGPoint(x: right, y: bottom),
            tangent2End: CGPoint(x: rect.minX, y: bottom),
            radius: radius - inset
        )
        path.addLine(to: CGPoint(x: rect.minX, y: bottom))
        return path
    }
}

/// Притенённый сгиб у корешка — полоска `Rectangle 240661877` макета, снятая
/// по пикселям: блик у самой кромки, тень с пиком 15 % в 3pt от неё, спад к 10-му.
/// Мягче, чем у объёмной книги витрины: книга в выдаче почти анфас.
private enum BookHingeShade {
    static let gradient = LinearGradient(
        stops: [
            .init(color: .white.opacity(0.02), location: 0.05),
            .init(color: .white.opacity(0.03), location: 0.15),
            .init(color: .black.opacity(0.11), location: 0.25),
            .init(color: .black.opacity(0.15), location: 0.35),
            .init(color: .black.opacity(0.13), location: 0.45),
            .init(color: .black.opacity(0.11), location: 0.55),
            .init(color: .black.opacity(0.08), location: 0.65),
            .init(color: .black.opacity(0.06), location: 0.75),
            .init(color: .black.opacity(0.035), location: 0.85),
            .init(color: .clear, location: 1),
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
}

// MARK: - Пустая выдача

/// Пустая выдача — макет `2448:30715`: «Ничего такого / не нашлось», Headline S,
/// белый 35 %, по центру. По вертикали — ровно посередине между статус-баром и верхом
/// бара поиска (задача пользователя 2026-10-03): с клавиатурой бар над ней, в просмотре
/// выдачи — внизу, и текст переезжает вместе с ним — кривой клавиатуры, потому что
/// отступ считается от её состояния.
struct SearchEmptyState: View {
    @Environment(KeyboardObserver.self) private var keyboard

    /// Белый 35 % макета — разовый цвет, токена нет.
    private static let color = Color.white.opacity(0.35)

    var body: some View {
        Text("Ничего такого\nне нашлось")
            .plusHeadline(.s)
            .multilineTextAlignment(.center)
            .foregroundStyle(Self.color)
            // Кадр слоя — безопасная зона: сверху статус-бар уже учтён, снизу
            // поджимаем до верха бара.
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, barInset)
            .allowsHitTesting(false)
    }

    /// Сколько бар поиска занимает над нижней безопасной зоной.
    private var barInset: CGFloat {
        let safeBottom = PlusChromeMetrics.bottomSafeArea
        let barTopFromScreenBottom = keyboard.isUp
            // Бар над клавиатурой: её высота, зазор 12 и сам бар.
            ? keyboard.overlap + PlusChromeMetrics.focusKeyboardGap + PlusMetrics.actionBarHeight
            // Просмотр выдачи: бар опущен на место таббара — низом на безопасную зону.
            : safeBottom + PlusMetrics.actionBarHeight
        return max(0, barTopFromScreenBottom - safeBottom)
    }
}

