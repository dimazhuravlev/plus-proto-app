import SwiftUI

/// Числа главной Кинопоиска — макет `2269:16939`. Кадр в макете 375: поля и размеры
/// карточек перенесены как есть (описание компонента: «меняйте размер карусели,
/// а не постера»), на холсте 402 следующая карточка просто выглядывает больше.
enum CinemaLayout {
    /// Лента начинается под навигацией: ряд 56 и зазор 4 (`content` на y 104 при `top` 100)
    static let contentTop: CGFloat = ServiceTopNavLayout.rowHeight + 4
    /// Воздух под последней каруселью сверх клиренса хрома
    static let feedBottom: CGFloat = 16
    static let side: CGFloat = 16
    static let sectionPad: CGFloat = 8
    /// Строка заголовка карусели — Headline M при 100 % (шапка 52 = 16 + 24 + 12)
    static let headerLine: CGFloat = 24
    static let cardGap: CGFloat = 8
    static let cardRadius: CGFloat = 12
    static let captionGap: CGFloat = 8
    static let captionTrailing: CGFloat = 8
    static var captionLine: CGFloat { PlusTextSize.textS.lineHeight }

    /// «Смотреть дальше» — кадр 16:9 шириной 252 (`card / watching / history`)
    static let historyWidth: CGFloat = 252
    static let historyHeight: CGFloat = historyWidth * 270 / 480
    static let historyLabelPadding: CGFloat = 8
    static let historyProgressHeight: CGFloat = 4
    /// Затемнение под временем — 80 снизу: 40 полосы прогресса и 40 над ней
    static let historyFadeHeight: CGFloat = 80
    static let historyProgressTrack = Color.white.opacity(0.15)
    /// `accent/sugar-grape` — цвет прогресса Кинопоиска
    static let historyProgressFill = Color(red: 0x9C / 255, green: 0x38 / 255, blue: 1)

    /// Постер 2:3 шириной 148 (`card / poster / default`), подпись — до двух строк
    static let posterWidth: CGFloat = 148
    static let posterHeight: CGFloat = posterWidth * 3 / 2
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
            Color.black.ignoresSafeArea()

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
            CinemaPromoCarousel(promos: catalog.promos)
        }
        history
        ForEach(catalog.rows) { row in
            CinemaPosterRow(row: row)
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
        // Название — строка, год с жанром — вторая, если хоть у кого-то он есть.
        let lines = entries.contains { $0.movie.subtitle != nil } ? 2 : 1
        ServiceCarousel(
            title: "Смотреть дальше",
            cardHeight: CinemaLayout.historyHeight + CinemaLayout.captionGap
                + CGFloat(lines) * CinemaLayout.captionLine
        ) {
            ForEach(entries) { entry in
                CinemaHistoryCard(entry: entry)
            }
        }
    }
}

/// Подборка — постеры с названием.
private struct CinemaPosterRow: View {
    let row: CinemaCatalog.Row

    var body: some View {
        // Высота подписи — по всей подборке, а не по карточке: `LazyHStack` меряет ряд
        // по уже созданным карточкам, и длинное название дальше по ленте резалось бы
        // в одну строку (та же беда, что у каруселей персон карточки тайтла).
        let lines = row.titles
            .map { TileCaptionRuler.lines($0.title, width: CinemaLayout.posterWidth - CinemaLayout.captionTrailing) }
            .max() ?? 1
        let captionHeight = CGFloat(lines) * CinemaLayout.captionLine
        ServiceCarousel(
            title: row.title,
            cardHeight: CinemaLayout.posterHeight + CinemaLayout.captionGap + captionHeight
        ) {
            ForEach(row.titles) { title in
                CinemaPosterCard(title: title, captionHeight: captionHeight)
            }
        }
    }
}

// MARK: - Карточки

/// Карточка «Смотреть дальше»: кадр со временем до конца и полосой прогресса,
/// под ним название и год с жанром. Тап **сразу открывает киноплеер** с этим фильмом
/// и продолжает с места, где остановились (правка пользователя 2026-10-04) —
/// исключение из правила «карточка ведёт на экран тайтла»: продолжить просмотр
/// и есть смысл этой карусели.
private struct CinemaHistoryCard: View {
    let entry: WatchHistory.Entry

    @Environment(ActionBarState.self) private var actionBar

    var body: some View {
        Button(action: resume) {
            VStack(alignment: .leading, spacing: CinemaLayout.captionGap) {
                still

                VStack(alignment: .leading, spacing: 0) {
                    Text(entry.movie.title)
                        .plusText(.textS, .medium)
                        .foregroundStyle(Color.fillOne)
                        .lineLimit(1)
                    if let subtitle = entry.movie.subtitle {
                        Text(subtitle)
                            .plusText(.textS, .medium)
                            .foregroundStyle(Color.fillSubtitle)
                            .lineLimit(1)
                    }
                }
                .padding(.trailing, CinemaLayout.captionTrailing)
            }
            .frame(width: CinemaLayout.historyWidth, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(PressScaleButtonStyle(pressedScale: 0.97))
    }

    /// Тот же вход в плеер, что у «Смотреть», — позиция приезжает с записью истории.
    private func resume() {
        UIImpactFeedbackGenerator(style: .medium)
            .impactOccurred(intensity: ShowcaseMotion.tapHapticIntensity)
        actionBar.open(.movie(entry.movie))
    }

    private var still: some View {
        let shape = RoundedRectangle(cornerRadius: CinemaLayout.cardRadius, style: .continuous)
        return PlusSkeleton.fill
            .overlay { SkeletonArtwork(source: entry.movie.still) }
            .overlay(alignment: .bottom) { progressBlock }
            .frame(width: CinemaLayout.historyWidth, height: CinemaLayout.historyHeight)
            .clipShape(shape)
            .overlay { shape.strokeBorder(PlusSkeleton.fill, lineWidth: PlusMetrics.hairline) }
    }

    /// Низ кадра: затемнение под временем, время до конца и полоса прогресса.
    /// Не начинали — полосы нет, только хронометраж (вторая карточка макета).
    private var progressBlock: some View {
        VStack(spacing: 0) {
            if let remaining = entry.remaining {
                Text(Self.remainingText(remaining))
                    .plusText(.textS, .medium)
                    .foregroundStyle(Color.fillFour)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal, CinemaLayout.historyLabelPadding)
                    .padding(.bottom, CinemaLayout.historyLabelPadding)
            }
            if let progress = entry.progress {
                CinemaLayout.historyProgressTrack
                    .overlay(alignment: .leading) {
                        CinemaLayout.historyProgressFill
                            .frame(width: CinemaLayout.historyWidth * progress)
                    }
                    .frame(height: CinemaLayout.historyProgressHeight)
            }
        }
        .background(alignment: .bottom) {
            HistoryFade()
                .frame(height: CinemaLayout.historyFadeHeight)
        }
    }

    /// «41 мин», «1 ч 5 мин», «2 ч» — с округлением вверх: последняя неполная
    /// минута тоже осталась.
    static func remainingText(_ seconds: TimeInterval) -> String {
        let minutes = max(1, Int((seconds / 60).rounded(.up)))
        let hours = minutes / 60
        let rest = minutes % 60
        if hours == 0 { return "\(minutes) мин" }
        if rest == 0 { return "\(hours) ч" }
        return "\(hours) ч \(rest) мин"
    }
}

/// Затемнение под временем на кадре — два градиента макета (`fade` 252×80):
/// диагональный из правого нижнего угла, где стоит время, и слабый вертикальный.
private struct HistoryFade: View {
    private static let stops: [(location: CGFloat, opacity: Double)] = [
        (0, 0.8), (0.4434, 0.1), (0.5043, 0.04), (0.5613, 0), (1, 0),
    ]

    private static func gradient(start: UnitPoint, end: UnitPoint) -> LinearGradient {
        LinearGradient(
            stops: stops.map { Gradient.Stop(color: Color.black.opacity($0.opacity), location: $0.location) },
            startPoint: start,
            endPoint: end
        )
    }

    var body: some View {
        ZStack {
            Self.gradient(start: .bottomTrailing, end: UnitPoint(x: 195.4 / 252, y: -34.35 / 80))
            Self.gradient(start: .bottom, end: UnitPoint(x: 0.5, y: 0.5))
                .opacity(0.2)
        }
        .allowsHitTesting(false)
    }
}

/// Постер подборки с названием.
private struct CinemaPosterCard: View {
    let title: CinemaCatalog.Title
    let captionHeight: CGFloat

    @Environment(AppNavigationState.self) private var navigation
    @Environment(\.stackZoomNamespace) private var zoom

    var body: some View {
        Button { navigation.open(title.route) } label: {
            VStack(alignment: .leading, spacing: CinemaLayout.captionGap) {
                posterSource

                Text(title.title)
                    .plusText(.textS, .medium)
                    .foregroundStyle(Color.fillOne)
                    .lineLimit(CinemaLayout.posterTitleLines)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(height: captionHeight, alignment: .top)
                    .padding(.trailing, CinemaLayout.captionTrailing)
            }
            .frame(width: CinemaLayout.posterWidth, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(PressScaleButtonStyle(pressedScale: 0.97))
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
            .overlay { shape.strokeBorder(PlusSkeleton.fill, lineWidth: PlusMetrics.hairline) }
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
