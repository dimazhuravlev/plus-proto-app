import SwiftUI
import UIKit

/// Числа промо книжной витрины. Макета нет — раскладка по скриншоту Книг (задача
/// пользователя 2026-10-04), книга — наша, в проекции (`BookFigure`).
///
/// Адаптивность: числа сняты на 402, слот растёт с шириной экрана так, что видимые края
/// соседей остаются прежними (`CenteredCarouselFit`), а геометрия книги (обложка, спуск
/// соседей, поля под наклон, поля описания) идёт тем же `scale`. Кнопка, зазор слотов и
/// поля под кнопкой — фиксированные.
@MainActor
enum BooksPromoLayout {
    /// Слот книги в ленте (222 на 402) и зазор: соседи выглядывают из-за краёв на ~50
    static let fit = CenteredCarouselFit(designSlot: 222, gap: 24)
    static var slot: CGFloat { fit.slot }
    static var gap: CGFloat { fit.gap }
    static var step: CGFloat { slot + gap }
    /// Множитель геометрии книги: `slot / 222`
    static var scale: CGFloat { fit.scale }
    /// Книга по центру: обложка 290 по высоте на 402 (было 260 — «немного увеличить», правка
    /// пользователя), пропорции не шире 0.72 — иначе альбомный скан распёр бы слот
    static var geometry: BookFigureGeometry { BookFigureGeometry(coverHeight: 290 * scale) }
    static let maxAspect: CGFloat = 0.72
    /// Соседи меньше и наклонены на 3° наружу — как обложки соседей в большом плеере
    /// музыки (`MusicPlayerLayout.neighborTilt`), угол — от расстояния до центра
    static let sideTilt: Double = 3
    static let sideShrink: CGFloat = 0.14
    /// …и ниже центральной на 16 (правка пользователя 2026-10-04) — тоже за сдвигом
    static var sideDrop: CGFloat { 16 * scale }
    /// Поля над и под книгой — под наклон и тень
    static var carouselTop: CGFloat { 20 * scale }
    static var carouselBottom: CGFloat { 24 * scale }
    static var carouselHeight: CGFloat {
        carouselTop + geometry.frameSize(coverWidth: 0).height + carouselBottom
    }
    /// Описание под книгой — Text M в три строки, по центру; место под три строки
    /// держится всегда, чтобы кнопка не прыгала от книги к книге
    static let blurbLines = 3
    static var blurbHeight: CGFloat { PlusTextSize.textM.lineHeight * CGFloat(blurbLines) }
    static var blurbSide: CGFloat { 32 * scale }
    static let blurbToButton: CGFloat = 20
    static let blurbFade: Animation = .smooth(duration: 0.3)
    static let buttonSize = PlusButtonSize.l
    static var buttonHeight: CGFloat { buttonSize.height }
    /// Ширина текста описания на 402 (402 − 2·32) — от неё полосы скелетона
    static let designBlurbWidth: CGFloat = PlusMetrics.designWidth - 2 * 32
    static var blurbWidth: CGFloat { PlusMetrics.screenWidth - 2 * blurbSide }
    static let buttonBottom: CGFloat = 24
    /// Фон промо — 0.6, приглушённый (правка пользователя 2026-10-04; тем же днём
    /// побывал 0.8 и 1)
    static let backdropOpacity: Double = 0.6
}

/// Карточка книги в карусели темы.
///
/// Обложка 200 по высоте на 402 растёт тем же множителем, что эталонная карточка 2:3
/// (136 pt, две целых и торчащий край ~98): ширины книг других пропорций точного края
/// не дают, но порядок прежний.
@MainActor
enum BooksCardLayout {
    static let fit = CarouselFit(designCard: 136, whole: 2, side: ServiceCarouselLayout.side, gap: ServiceCarouselLayout.cardGap)
    static var geometry: BookFigureGeometry { BookFigureGeometry(coverHeight: 200 * fit.scale) }
    static let captionGap: CGFloat = 8
    static let titleLines = 2
    static var captionHeight: CGFloat { PlusTextSize.textS.lineHeight * CGFloat(titleLines + 1) }
    static var cardHeight: CGFloat {
        geometry.frameSize(coverWidth: 0).height + captionGap + captionHeight
    }
    static let skeletonBooks = 3
}

/// Главная Книг — содержимое таба (задача пользователя 2026-10-04): общая навигация
/// витрин с фильтрами «Книги» и «Аудиокниги» (из навбара скриншота не берём ничего),
/// промо — карусель наших книг с размытой обложкой текущей фоном и «Читать книгу»,
/// ниже — пять каруселей по темам. «Аудиокниги» не спроектированы — название раздела.
struct BooksHomeScreen: View {
    @Environment(BooksHomeCatalog.self) private var catalog
    @Environment(AppNavigationState.self) private var navigation

    /// «Детям» — последним, как во всех витринах (правка пользователя 2026-10-04)
    static let filters = ["Книги", "Аудиокниги", "Детям"]

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
            // Скелетон и лента — слоями, на месте (урок главной Кинопоиска).
            ZStack(alignment: .top) {
                if catalog.isLoaded {
                    VStack(spacing: 0) {
                        if !catalog.promos.isEmpty {
                            @Bindable var catalog = catalog
                            BooksPromoCarousel(
                                books: catalog.promos,
                                pull: max(0, -scrollOffset),
                                savedIndex: $catalog.promoIndex
                            )
                        }
                        if !catalog.top.isEmpty {
                            BooksCarousel(title: BooksHomeCatalog.topTitle, books: catalog.top, isRanked: true)
                        }
                        ForEach(catalog.rows) { row in
                            BooksCarousel(title: row.title, books: row.books)
                        }
                    }
                    .transition(.opacity)
                } else {
                    VStack(spacing: 0) {
                        BooksPromoSkeleton()
                        ForEach(0..<2, id: \.self) { _ in BooksRowSkeleton() }
                    }
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
        .onChange(of: navigation.scrollToTopRequests[.books]) {
            withAnimation(ShowcaseScrollMotion.toTop) { scrollPosition.scrollTo(edge: .top) }
        }
    }
}

// MARK: - Промо

/// Промо — книги по кругу, по одной за свайп; текущая — по центру, соседи меньше
/// и наклонены наружу, угол и размер плавно идут за сдвигом. Фон — размытая обложка
/// текущей книги, под каруселью — «Читать книгу».
private struct BooksPromoCarousel: View {
    let books: [BooksHomeCatalog.Book]
    /// Оттяг ленты вниз — фон тянется за ним вверх, без чёрной полосы (резина, как
    /// у фона альбома и книги — `EntityCoverHeader`)
    let pull: CGFloat
    /// Книга набора, на которой остановились, — в каталоге, на всю сессию.
    @Binding var savedIndex: Int

    @Environment(ActionBarState.self) private var actionBar
    @Environment(AppNavigationState.self) private var navigation
    @Environment(\.stackZoomNamespace) private var zoom

    /// Тот же круг, что у промо Кинопоиска: три копии, работает средняя.
    private static let copies = 3

    @State private var page: Int?

    init(books: [BooksHomeCatalog.Book], pull: CGFloat, savedIndex: Binding<Int>) {
        self.books = books
        self.pull = pull
        _savedIndex = savedIndex
        let count = max(books.count, 1)
        _page = State(initialValue: count + savedIndex.wrappedValue % count)
    }

    private var current: BooksHomeCatalog.Book? {
        guard !books.isEmpty else { return nil }
        let index = page ?? books.count + savedIndex
        return books[((index % books.count) + books.count) % books.count]
    }

    /// Свайп остановился: запомнить книгу и, если это крайняя копия, перескочить
    /// на ту же книгу средней — без анимации, картинка та же.
    private func settle() {
        let count = books.count
        guard count > 0, let current = page else { return }
        let index = ((current % count) + count) % count
        savedIndex = index
        let middle = count + index
        guard current != middle else { return }
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) { page = middle }
    }

    var body: some View {
        VStack(spacing: 0) {
            carousel
            blurb
                .padding(.horizontal, BooksPromoLayout.blurbSide)
                .padding(.bottom, BooksPromoLayout.blurbToButton)
            readButton
                .padding(.bottom, BooksPromoLayout.buttonBottom)
        }
        .background(alignment: .bottom) { backdrop }
    }

    /// Коротко о текущей книге — сменяется вместе с фоном, кроссфейдом через блюр
    /// (системный `.blurReplace`, правка пользователя 2026-10-04).
    private var blurb: some View {
        ZStack(alignment: .top) {
            if let current {
                Text(current.blurb ?? current.author)
                    .plusText(.textM, .medium)
                    .foregroundStyle(Color.fillFour)
                    .multilineTextAlignment(.center)
                    .lineLimit(BooksPromoLayout.blurbLines)
                    .frame(maxWidth: .infinity)
                    .id(current.id)
                    .transition(.blurReplace)
            }
        }
        .frame(height: BooksPromoLayout.blurbHeight, alignment: .top)
        .animation(BooksPromoLayout.blurbFade, value: current?.id)
    }

    private var carousel: some View {
        let count = books.count
        // Числа эффекта — из констант, не из размеров вью; замыкание `visualEffect` не
        // привязано к главному актору, поэтому читаем их заранее.
        let step = BooksPromoLayout.step
        let shrink = BooksPromoLayout.sideShrink
        let tilt = BooksPromoLayout.sideTilt
        let drop = BooksPromoLayout.sideDrop
        return ScrollView(.horizontal) {
            LazyHStack(spacing: BooksPromoLayout.gap) {
                ForEach(0..<(count * Self.copies), id: \.self) { index in
                    let book = books[index % count]
                    bookView(book, slot: index, isCurrent: index == page)
                        .frame(width: BooksPromoLayout.slot)
                        .visualEffect { content, proxy in
                            // Доля пути до соседнего места: 0 по центру ленты, ±1 у соседей.
                            // Центр — от рамки скролла (как `ShowcasePromoLayout.position`), не
                            // константа 201: на широком экране якорь и константа расходились
                            // на 19 pt, и свайп не листал (задача 43).
                            let center = proxy.bounds(of: .scrollView)?.midX ?? proxy.size.width / 2
                            let t = max(-1, min(1, (proxy.size.width / 2 - center) / step))
                            return content
                                .scaleEffect(1 - shrink * abs(t))
                                .rotationEffect(.degrees(tilt * Double(t)))
                                .offset(y: drop * abs(t))
                        }
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned(limitBehavior: .alwaysByOne))
        .contentMargins(.horizontal, BooksPromoLayout.fit.margin, for: .scrollContent)
        // `.leading`, не `.center`: при симметричных полях сетка снэпа `viewAligned` и якорь
        // совпадают точно (`.center` промахивался — «Грабли» в CLAUDE.md).
        .scrollPosition(id: $page, anchor: .leading)
        .onScrollPhaseChange { _, phase in
            if phase == .idle { settle() }
        }
        .scrollIndicators(.hidden)
        .scrollDisabled(count < 2)
        .scrollClipDisabled()
        .frame(height: BooksPromoLayout.carouselHeight)
        #if DEBUG
        // `-debugBooksPromoStep <back|next|n|cycle>` — то же, что `-debugPromoStep`
        // у промо Кинопоиска: через 3с пролистать, `cycle` — вперёд по книге раз
        // в 1.6 с, 14 шагов, с перескоком копий, для записи на видео.
        .task {
            let value = UserDefaults.standard.string(forKey: "debugBooksPromoStep") ?? ""
            let cycleSteps = 14
            let cycleInterval: Duration = .seconds(1.6)
            let step = value == "back" ? -1 : (value == "next" || value == "cycle" ? 1 : Int(value) ?? 0)
            guard step != 0 else { return }
            try? await Task.sleep(for: .seconds(3))
            for _ in 0..<(value == "cycle" ? cycleSteps : 1) {
                guard !Task.isCancelled else { return }
                // Стартовая — из стейта: `books` в замыкании `.task` — с первого монтирования.
                withAnimation(.smooth) { page = (page ?? 0) + step }
                try? await Task.sleep(for: cycleInterval)
            }
        }
        #endif
    }

    @ViewBuilder
    private func bookView(_ book: BooksHomeCatalog.Book, slot: Int, isCurrent: Bool) -> some View {
        let geometry = BooksPromoLayout.geometry
        let coverWidth = geometry.coverWidth(aspect: min(book.aspect ?? BookFigureGeometry.defaultAspect, BooksPromoLayout.maxAspect))
        let figure = BookFigure(geometry: geometry, coverWidth: coverWidth) {
            SkeletonArtwork(source: book.cover)
        }
        Button { navigation.open(book.route) } label: {
            // Источник зума — у каждой копии, адрес экрана книги — только у текущей. Без
            // ветки по `isCurrent`: её смена пересоздавала книгу посреди свайпа, и обложка
            // моргала (урок промо «Главной» и Кинопоиска).
            Group {
                if let zoom {
                    figure.matchedTransitionSource(
                        id: isCurrent ? AnyHashable(book.route) : AnyHashable("books-promo-copy-\(slot)"),
                        in: zoom
                    )
                } else {
                    figure
                }
            }
            .shadow(color: .black.opacity(0.35), radius: 16, y: 8)
        }
        .buttonStyle(PressScaleButtonStyle(pressedScale: PressMotion.cardScale))
        .frame(height: BooksPromoLayout.carouselHeight)
        .accessibilityLabel(book.title)
    }

    private var readButton: some View {
        PlusButton("Читать книгу", type: .accent, size: BooksPromoLayout.buttonSize, haptic: .inAction, action: read)
    }

    private func read() {
        guard let book = current else { return }
        UIImpactFeedbackGenerator(style: .medium)
            .impactOccurred(intensity: ShowcaseMotion.tapHapticIntensity)
        actionBar.open(.book(book.reading))
    }

    /// Размытая копия обложки текущей книги — общий фон промо витрин
    /// (`ShowcasePromoBackdrop`): от верха экрана до низа промо, смена — кроссфейдом.
    private var backdrop: some View {
        ShowcasePromoBackdrop(
            source: current?.cover,
            id: current?.id,
            height: ServiceTopNavLayout.topSafeArea + CinemaLayout.contentTop
                + BooksPromoLayout.carouselHeight + BooksPromoLayout.blurbHeight + BooksPromoLayout.blurbToButton
                + BooksPromoLayout.buttonHeight + BooksPromoLayout.buttonBottom,
            pull: pull,
            opacity: BooksPromoLayout.backdropOpacity
        )
    }
}

/// Скелетон промо — книга по центру и края соседей, кнопка.
private struct BooksPromoSkeleton: View {
    var body: some View {
        let geometry = BooksPromoLayout.geometry
        let width = geometry.coverWidth(aspect: nil)
        VStack(spacing: 0) {
            Color.clear
                .frame(height: BooksPromoLayout.carouselHeight)
                .overlay {
                    HStack(spacing: BooksPromoLayout.gap) {
                        ForEach(0..<3, id: \.self) { index in
                            BookFigure(geometry: geometry, coverWidth: width) { EmptyView() }
                                .frame(width: BooksPromoLayout.slot)
                                .scaleEffect(index == 1 ? 1 : 1 - BooksPromoLayout.sideShrink)
                                .rotationEffect(.degrees(index == 1 ? 0 : (index == 0 ? -1 : 1) * BooksPromoLayout.sideTilt))
                                .offset(y: index == 1 ? 0 : BooksPromoLayout.sideDrop)
                        }
                    }
                }
                .clipped()
            VStack(spacing: 8) {
                SkeletonBar(width: BooksPromoLayout.blurbWidth * 280 / BooksPromoLayout.designBlurbWidth)
                SkeletonBar(width: BooksPromoLayout.blurbWidth * 220 / BooksPromoLayout.designBlurbWidth)
            }
            .frame(height: BooksPromoLayout.blurbHeight, alignment: .top)
            .padding(.top, 4)
            .padding(.bottom, BooksPromoLayout.blurbToButton)
            Capsule()
                .fill(PlusSkeleton.fill)
                .frame(width: BooksPromoLayout.buttonSize.width(title: "Читать книгу"), height: BooksPromoLayout.buttonHeight)
                .padding(.bottom, BooksPromoLayout.buttonBottom)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Карусели тем

/// Карусель книг — общая у главной Книг и «Главной». С `isRanked` — «Топ-10»: первые
/// десять, перед книгой цифра места (как `card / poster / top-10` у Кино, той же геометрией
/// от обложки).
struct BooksCarousel: View {
    let title: String
    let books: [BooksHomeCatalog.Book]
    var isRanked = false
    /// Тап по шапке — на «Главной» ведёт в таб Книг.
    var headerAction: (() -> Void)? = nil

    var body: some View {
        let items = isRanked ? Array(books.prefix(ServiceCarouselRank.limit)) : books
        ServiceCarousel(
            title: title,
            cardHeight: BooksCardLayout.cardHeight,
            isRanked: isRanked,
            headerAction: headerAction
        ) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, book in
                BooksCard(book: book, place: isRanked ? index + 1 : nil)
                    .zIndex(isRanked ? ServiceCarouselRank.zIndex(place: index + 1) : 0)
            }
        }
    }
}

/// Книга в проекции, под ней название (до двух строк) и автор; с местом — цифра слева.
private struct BooksCard: View {
    let book: BooksHomeCatalog.Book
    var place: Int? = nil

    @Environment(AppNavigationState.self) private var navigation
    @Environment(\.stackZoomNamespace) private var zoom

    var body: some View {
        let geometry = BooksCardLayout.geometry
        let scale = BooksCardLayout.fit.scale
        let coverWidth = geometry.coverWidth(aspect: book.aspect)
        let width = geometry.frameSize(coverWidth: coverWidth).width
        let figure = BookFigure(geometry: geometry, coverWidth: coverWidth) {
            SkeletonArtwork(source: book.cover)
        }
        Button { navigation.open(book.route) } label: {
            VStack(alignment: .leading, spacing: BooksCardLayout.captionGap) {
                Group {
                    if let zoom {
                        figure.matchedTransitionSource(id: book.route, in: zoom)
                    } else {
                        figure
                    }
                }
                // Обложка — под выступом страниц: её центр ниже середины кадра книги.
                .overlay(alignment: .topLeading) {
                    if let place {
                        ServiceCarouselRankNumber(
                            place: place,
                            coverCenter: geometry.pagesTop + geometry.coverHeight / 2,
                            scale: scale
                        )
                    }
                }

                VStack(alignment: .leading, spacing: 0) {
                    Text(book.title)
                        .plusText(.textS, .medium)
                        .foregroundStyle(Color.fillOne)
                        .lineLimit(BooksCardLayout.titleLines)
                    Text(book.author)
                        .plusText(.textS, .medium)
                        .foregroundStyle(Color.fillSubtitle)
                        .lineLimit(1)
                }
                .padding(.trailing, CinemaLayout.captionTrailing)
            }
            .frame(width: width, alignment: .leading)
            .padding(.leading, place == nil ? 0 : ServiceCarouselRank.lead * scale)
            .contentShape(.rect)
        }
        .buttonStyle(PressScaleButtonStyle(pressedScale: PressMotion.cardScale))
    }
}

/// Скелетон карусели темы — шапка-полоса и книги с полосами названия и автора.
/// Ряд — оверлеем на распорке: своей ширины ленте он не предлагает.
private struct BooksRowSkeleton: View {
    var body: some View {
        let geometry = BooksCardLayout.geometry
        let width = geometry.coverWidth(aspect: nil)
        VStack(spacing: 0) {
            EntitySectionHeaderSkeleton(lineHeight: ServiceCarouselLayout.headerLine)
            Color.clear
                .frame(height: BooksCardLayout.cardHeight)
                .overlay(alignment: .topLeading) {
                    HStack(alignment: .top, spacing: ServiceCarouselLayout.cardGap) {
                        ForEach(0..<BooksCardLayout.skeletonBooks, id: \.self) { _ in
                            VStack(alignment: .leading, spacing: BooksCardLayout.captionGap) {
                                BookFigure(geometry: geometry, coverWidth: width) { EmptyView() }
                                VStack(alignment: .leading, spacing: 4) {
                                    SkeletonBar(width: width * 0.8)
                                    SkeletonBar(width: width * 0.5)
                                }
                                .padding(.top, 2)
                            }
                        }
                    }
                    .padding(.leading, ServiceCarouselLayout.side)
                }
                .clipped()
        }
        .padding(.vertical, ServiceCarouselLayout.sectionPad)
        .accessibilityHidden(true)
    }
}
