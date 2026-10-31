import SwiftUI

/// Числа главной Кинопоиска — макет `2269:16939`. Кадр в макете 375: поля и размеры
/// карточек перенесены как есть (описание компонента: «меняйте размер карусели,
/// а не постера»), на холсте 402 следующая карточка просто выглядывает больше.
///
/// Адаптивность (правило 4 CLAUDE.md): карточки «Смотреть дальше» и постеры считает
/// `CarouselFit` — на любой ширине столько же целых карточек, сколько на 402 (1 и 2),
/// торчащий край следующей прежний (126 и 74), карточка меняет ширину, высота идёт тем же
/// масштабом. На 402 числа прежние: 252×141.75 и 148×222.
enum CinemaLayout {
    /// Лента начинается под навигацией: ряд 56 и зазор 4 (`content` на y 104 при `top` 100)
    static let contentTop: CGFloat = ServiceTopNavLayout.rowHeight + 4
    /// Воздух под последней каруселью сверх клиренса хрома
    static let feedBottom: CGFloat = 16
    static let side: CGFloat = 16
    static let sectionPad: CGFloat = 8
    /// Строка заголовка карусели — Headline S при 100 % (шапка 52 = 16 + 24 + 12)
    static var headerLine: CGFloat { PlusHeadline.s.lineHeight }
    static let cardGap: CGFloat = 8
    static let cardRadius: CGFloat = 12
    static let captionGap: CGFloat = 8
    static let captionTrailing: CGFloat = 8
    static var captionLine: CGFloat { PlusTextSize.textS.lineHeight }

    /// «Смотреть дальше» — кадр 16:9 шириной 252 на 402 (`card / watching / history`):
    /// одна целая карточка, справа торчит 126 следующей.
    static let historyFit = CarouselFit(designCard: 252, whole: 1, side: side, gap: cardGap)
    @MainActor
    static var historyWidth: CGFloat { historyFit.cardWidth }

    /// Постер 2:3 шириной 148 на 402 (`card / poster / default`): две целые, справа
    /// торчит 74 третьего. Подпись — до двух строк.
    static let posterFit = CarouselFit(designCard: 148, whole: 2, side: side, gap: cardGap)
    @MainActor
    static var posterWidth: CGFloat { posterFit.cardWidth }
    @MainActor
    static var posterHeight: CGFloat { posterWidth * 3 / 2 }
    static let posterTitleLines = 2
    static let skeletonPosters = 3
}

/// Главная Кинопоиска — содержимое таба (макет `2269:16939`, задача пользователя
/// 2026-10-04): промоблок по кругу, «Смотреть дальше» из реально запущенного,
/// подборки постерами. Сверху — общая навигация сервисов с табами-фильтрами.
///
/// «Спорт» и «Каналы» в прототипе не спроектированы — под ними название раздела,
/// как у заглушек сервисов.
struct CinemaHomeScreen: View {
    @Environment(CinemaCatalog.self) private var catalog
    @Environment(ActionBarState.self) private var actionBar
    @Environment(AppNavigationState.self) private var navigation

    /// «Детям» — последним, как во всех витринах (правка пользователя 2026-10-04)
    static let filters = ["Кино", "Спорт", "Каналы", "Детям"]

    @State private var filter = 0
    @State private var scrollOffset: CGFloat = 0
    @State private var scrollPosition = ScrollPosition(edge: .top)

    var body: some View {
        ZStack(alignment: .top) {
            Color.surfaceOne.ignoresSafeArea()

            if filter == 0 {
                feed
            } else {
                ServiceFilterStub(title: Self.filters[filter])
            }
        }
        .overlay(alignment: .top) {
            ServiceTopNav(
                filters: Self.filters,
                selection: $filter,
                scrollOffset: filter == 0 ? scrollOffset : 0
            )
        }
        // Лента таба, вернувшаяся после другого фильтра, доложит свой сдвиг сама —
        // прежний, оставшийся от неё, на миг проявил бы подложку навигации.
        .onChange(of: filter) { scrollOffset = 0 }
        .toolbar(.hidden, for: .navigationBar)
        .task { await catalog.loadIfNeeded() }
    }

    private var feed: some View {
        ScrollView {
            // Скелетон и лента сменяются **на месте** — слоями `ZStack`. В `VStack` на время
            // перехода оба стояли друг под другом: лента вставала под скелетоном и, когда
            // тот уходил, прыгала вверх на всю его высоту (жалоба пользователя 2026-10-04:
            // «дёргается при загрузке и первом переходе»).
            ZStack(alignment: .top) {
                if catalog.isLoaded {
                    VStack(spacing: 0) { content }
                        .transition(.opacity)
                } else {
                    VStack(spacing: 0) { skeleton }
                        .transition(.opacity)
                }
            }
            .animation(EntityMotion.reveal, value: catalog.isLoaded)
            .padding(.bottom, CinemaLayout.feedBottom)
        }
        .scrollIndicators(.hidden)
        .contentMargins(.top, CinemaLayout.contentTop, for: .scrollContent)
        .scrollPosition($scrollPosition)
        .trackNavBarScroll(into: $scrollOffset)
        // Повторный тап по табу на корне — к началу ленты, как на витрине.
        .onChange(of: navigation.scrollToTopRequests[.kinopoisk]) {
            withAnimation(ShowcaseScrollMotion.toTop) { scrollPosition.scrollTo(edge: .top) }
        }
        #if DEBUG
        // `-debugCinemaScroll <pt>` — стартовая прокрутка ленты, когда она собралась:
        // нижние карусели иначе не снять скриншотом.
        .task(id: catalog.isLoaded) {
            let offset = UserDefaults.standard.double(forKey: "debugCinemaScroll")
            guard offset > 0, catalog.isLoaded else { return }
            try? await Task.sleep(for: .milliseconds(1500))
            guard !Task.isCancelled else { return }
            scrollPosition.scrollTo(y: offset)
        }
        #endif
    }

    @ViewBuilder
    private var content: some View {
        if !catalog.promos.isEmpty {
            @Bindable var catalog = catalog
            CinemaPromoCarousel(promos: catalog.promos, pull: max(0, -scrollOffset), savedIndex: $catalog.promoIndex)
        }
        history
        if !catalog.topTitles.isEmpty {
            CinemaPosterCarousel(title: CinemaCatalog.topTitle, titles: catalog.topTitles, isRanked: true)
        }
        ForEach(catalog.rows) { row in
            CinemaPosterCarousel(title: row.title, titles: row.titles)
        }
    }

    /// «Смотреть дальше» — только когда есть что продолжить.
    @ViewBuilder
    private var history: some View {
        let entries = actionBar.watchHistory.continuing
        if !entries.isEmpty {
            CinemaHistoryRow(entries: entries)
        }
    }

    @ViewBuilder
    private var skeleton: some View {
        CinemaPromoSkeleton()
        history
        ForEach(0..<2, id: \.self) { _ in
            CinemaRowSkeleton()
        }
    }
}

// MARK: - Карусели

/// «Смотреть дальше» — фильмы, запущенные в киноплеере, свежие первыми.
private struct CinemaHistoryRow: View {
    let entries: [WatchHistory.Entry]

    var body: some View {
        ServiceCarousel(title: "Смотреть дальше", cardHeight: PPMovieCard.rowHeight(.large, movies: entries.map(\.movie))) {
            ForEach(entries) { entry in
                PPMovieResumeCard(entry: entry, size: .large)
            }
        }
    }
}

/// Подборка постерами — общая карусель Кино: главная Кинопоиска и «Главная». С `isRanked` —
/// «Топ-10» (`card / poster / top-10`): первые десять, перед постером цифра места, название
/// в одну строку.
struct CinemaPosterCarousel: View {
    let title: String
    let titles: [CinemaCatalog.Title]
    var isRanked = false
    /// Тап по шапке — на «Главной» ведёт в таб Кинопоиска.
    var headerAction: (() -> Void)? = nil

    var body: some View {
        let items = isRanked ? Array(titles.prefix(ServiceCarouselRank.limit)) : titles
        // Высота подписи — по всей подборке, а не по карточке: `LazyHStack` меряет ряд
        // по уже созданным карточкам, и длинное название дальше по ленте резалось бы
        // в одну строку (та же беда, что у каруселей персон карточки тайтла).
        let lines = isRanked ? 1 : items
            .map { TileCaptionRuler.lines($0.title, width: CinemaLayout.posterWidth - CinemaLayout.captionTrailing) }
            .max() ?? 1
        let captionHeight = CGFloat(lines) * CinemaLayout.captionLine
        ServiceCarousel(
            title: title,
            cardHeight: CinemaLayout.posterHeight + CinemaLayout.captionGap + captionHeight,
            isRanked: isRanked,
            headerAction: headerAction
        ) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, title in
                CinemaPosterCard(title: title, captionHeight: captionHeight, place: isRanked ? index + 1 : nil)
                    .zIndex(isRanked ? ServiceCarouselRank.zIndex(place: index + 1) : 0)
            }
        }
    }
}

// MARK: - Карточки

/// Постер подборки с названием; с местом — карточка «Топ-10»: поле под цифру слева.
private struct CinemaPosterCard: View {
    let title: CinemaCatalog.Title
    let captionHeight: CGFloat
    var place: Int? = nil

    @Environment(AppNavigationState.self) private var navigation
    @Environment(\.stackZoomNamespace) private var zoom

    var body: some View {
        let scale = CinemaLayout.posterFit.scale
        Button { navigation.open(title.route) } label: {
            VStack(alignment: .leading, spacing: CinemaLayout.captionGap) {
                posterSource
                    .overlay(alignment: .topLeading) {
                        if let place {
                            ServiceCarouselRankNumber(place: place, coverCenter: CinemaLayout.posterHeight / 2, scale: scale)
                        }
                    }

                Text(title.title)
                    .plusText(.textS, .medium)
                    .foregroundStyle(Color.fillOne)
                    .lineLimit(place == nil ? CinemaLayout.posterTitleLines : 1)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(height: captionHeight, alignment: .top)
                    .padding(.trailing, CinemaLayout.captionTrailing)
            }
            .frame(width: CinemaLayout.posterWidth, alignment: .leading)
            .padding(.leading, place == nil ? 0 : ServiceCarouselRank.lead * scale)
            .contentShape(.rect)
        }
        .buttonStyle(PressScaleButtonStyle(pressedScale: PressMotion.cardScale))
    }

    @ViewBuilder
    private var posterSource: some View {
        if let zoom {
            poster.matchedTransitionSource(id: title.route, in: zoom)
        } else {
            poster
        }
    }

    private var poster: some View {
        let shape = RoundedRectangle(cornerRadius: CinemaLayout.cardRadius, style: .continuous)
        return PlusSkeleton.fill
            .overlay {
                if let poster = title.poster {
                    SkeletonArtwork(source: poster)
                }
            }
            .frame(width: CinemaLayout.posterWidth, height: CinemaLayout.posterHeight)
            .clipShape(shape)
            .coverBorder(shape)
    }
}

/// Скелетон подборки — того же габарита: шапка-полоса и постеры с двумя строками.
private struct CinemaRowSkeleton: View {
    var body: some View {
        VStack(spacing: 0) {
            EntitySectionHeaderSkeleton(lineHeight: CinemaLayout.headerLine)

            // Ряд постеров шире экрана (3 × 148 + поля = 492), и раскладкой он ленту
            // раздувал: скелетон промо тянулся на всю эту ширину, мета уезжала вправо,
            // а с приходом ленты всё прыгало обратно (запись 2026-10-04). Поэтому ряд —
            // оверлеем на распорке во всю ширину экрана: своей ширины он не предлагает.
            Color.clear
                .frame(height: CinemaLayout.posterHeight + CinemaLayout.captionGap + CinemaLayout.captionLine)
                .overlay(alignment: .topLeading) {
                    HStack(alignment: .top, spacing: CinemaLayout.cardGap) {
                        ForEach(0..<CinemaLayout.skeletonPosters, id: \.self) { _ in
                            VStack(alignment: .leading, spacing: CinemaLayout.captionGap) {
                                RoundedRectangle(cornerRadius: CinemaLayout.cardRadius, style: .continuous)
                                    .plusSkeleton()
                                    .frame(width: CinemaLayout.posterWidth, height: CinemaLayout.posterHeight)
                                SkeletonBar(width: CinemaLayout.posterWidth * 0.7, height: EntitySectionLayout.skeletonBar)
                                    .frame(height: CinemaLayout.captionLine)
                            }
                        }
                    }
                    .padding(.leading, CinemaLayout.side)
                }
                .clipped()
        }
        .padding(.vertical, CinemaLayout.sectionPad)
        .accessibilityHidden(true)
    }
}
