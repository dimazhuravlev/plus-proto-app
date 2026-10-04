import SwiftUI
import UIKit

/// Числа промо книжной витрины. Макета нет — раскладка по скриншоту Книг (задача
/// пользователя 2026-10-04), книга — наша, в проекции (`BookFigure`).
enum BooksPromoLayout {
    /// Книга по центру: обложка 290 по высоте (было 260 — «немного увеличить», правка
    /// пользователя), пропорции не шире 0.72 — иначе альбомный скан распёр бы слот
    static let geometry = BookFigureGeometry(coverHeight: 290)
    static let maxAspect: CGFloat = 0.72
    /// Слот книги в ленте и зазор: соседи выглядывают из-за краёв на ~50
    static let slot: CGFloat = 222
    static let gap: CGFloat = 24
    static var step: CGFloat { slot + gap }
    /// Соседи меньше и наклонены на 3° наружу — как обложки соседей в большом плеере
    /// музыки (`MusicPlayerLayout.neighborTilt`), угол — от расстояния до центра
    static let sideTilt: Double = 3
    static let sideShrink: CGFloat = 0.14
    /// …и ниже центральной на 16 (правка пользователя 2026-10-04) — тоже за сдвигом
    static let sideDrop: CGFloat = 16
    /// Поля над и под книгой — под наклон и тень
    static let carouselTop: CGFloat = 20
    static let carouselBottom: CGFloat = 24
    static var carouselHeight: CGFloat {
        carouselTop + geometry.frameSize(coverWidth: 0).height + carouselBottom
    }
    /// Описание под книгой — Text M в три строки, по центру; место под три строки
    /// держится всегда, чтобы кнопка не прыгала от книги к книге
    static let blurbLines = 3
    static var blurbHeight: CGFloat { PlusTextSize.textM.lineHeight * CGFloat(blurbLines) }
    static let blurbSide: CGFloat = 32
    static let blurbToButton: CGFloat = 20
    static let blurbFade: Animation = .smooth(duration: 0.3)
    static let buttonHeight: CGFloat = 48
    static let buttonPadding: CGFloat = 32
    static let buttonBottom: CGFloat = 24
    /// Фон промо — в полную силу (правка пользователя 2026-10-04 — «опасити больше»;
    /// прежде 0.8, как просили тем же днём раньше)
    static let backdropOpacity: Double = 1
}

/// Карточка книги в карусели темы.
enum BooksCardLayout {
    static let geometry = BookFigureGeometry(coverHeight: 200)
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
                        ForEach(catalog.rows) { row in
                            BooksRow(row: row)
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
        return ScrollView(.horizontal) {
            LazyHStack(spacing: BooksPromoLayout.gap) {
                ForEach(0..<(count * Self.copies), id: \.self) { index in
                    let book = books[index % count]
                    bookView(book, isCurrent: index == page)
                        .frame(width: BooksPromoLayout.slot)
                        .visualEffect { content, proxy in
                            // Доля пути до соседнего места: 0 по центру экрана, ±1 у соседей.
                            // Кадр — в координатах экрана: в координатах скролла он отсчитан
                            // от поля ленты, и самая крупная книга стояла правее центра на
                            // это поле (жалоба пользователя 2026-10-04).
                            let mid = proxy.frame(in: .global).midX
                            let t = max(-1, min(1, (mid - PlusMetrics.designWidth / 2) / BooksPromoLayout.step))
                            return content
                                .scaleEffect(1 - BooksPromoLayout.sideShrink * abs(t))
                                .rotationEffect(.degrees(BooksPromoLayout.sideTilt * Double(t)))
                                .offset(y: BooksPromoLayout.sideDrop * abs(t))
                        }
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned(limitBehavior: .alwaysByOne))
        .contentMargins(.horizontal, (PlusMetrics.designWidth - BooksPromoLayout.slot) / 2, for: .scrollContent)
        .scrollPosition(id: $page, anchor: .center)
        .onScrollPhaseChange { _, phase in
            if phase == .idle { settle() }
        }
        .scrollIndicators(.hidden)
        .scrollDisabled(count < 2)
        .scrollClipDisabled()
        .frame(height: BooksPromoLayout.carouselHeight)
    }

    @ViewBuilder
    private func bookView(_ book: BooksHomeCatalog.Book, isCurrent: Bool) -> some View {
        let geometry = BooksPromoLayout.geometry
        let coverWidth = geometry.coverWidth(aspect: min(book.aspect ?? BookFigureGeometry.defaultAspect, BooksPromoLayout.maxAspect))
        let figure = BookFigure(geometry: geometry, coverWidth: coverWidth) {
            SkeletonArtwork(source: book.cover)
        }
        Button { navigation.open(book.route) } label: {
            Group {
                if isCurrent, let zoom {
                    figure.matchedTransitionSource(id: book.route, in: zoom)
                } else {
                    figure
                }
            }
            .shadow(color: .black.opacity(0.35), radius: 16, y: 8)
        }
        .buttonStyle(PressScaleButtonStyle(pressedScale: 0.97))
        .frame(height: BooksPromoLayout.carouselHeight)
        .accessibilityLabel(book.title)
    }

    private var readButton: some View {
        Button(action: read) {
            Text("Читать книгу")
                .plusText(.textM, .semibold)
                .foregroundStyle(Color.fillOne)
                .padding(.horizontal, BooksPromoLayout.buttonPadding)
                .frame(height: BooksPromoLayout.buttonHeight)
                .accentButtonSurface()
        }
        .buttonStyle(PressScaleButtonStyle())
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
                SkeletonBar(width: 280)
                SkeletonBar(width: 220)
            }
            .frame(height: BooksPromoLayout.blurbHeight, alignment: .top)
            .padding(.top, 4)
            .padding(.bottom, BooksPromoLayout.blurbToButton)
            Capsule()
                .fill(PlusSkeleton.fill)
                .frame(width: 180, height: BooksPromoLayout.buttonHeight)
                .padding(.bottom, BooksPromoLayout.buttonBottom)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Карусели тем

private struct BooksRow: View {
    let row: BooksHomeCatalog.Row

    var body: some View {
        ServiceCarousel(title: row.title, cardHeight: BooksCardLayout.cardHeight) {
            ForEach(row.books) { book in
                BooksCard(book: book)
            }
        }
    }
}

/// Книга в проекции, под ней название (до двух строк) и автор.
private struct BooksCard: View {
    let book: BooksHomeCatalog.Book

    @Environment(AppNavigationState.self) private var navigation
    @Environment(\.stackZoomNamespace) private var zoom

    var body: some View {
        let geometry = BooksCardLayout.geometry
        let coverWidth = geometry.coverWidth(aspect: book.aspect)
        let width = geometry.frameSize(coverWidth: coverWidth).width
        let figure = BookFigure(geometry: geometry, coverWidth: coverWidth) {
            SkeletonArtwork(source: book.cover)
        }
        Button { navigation.open(book.route) } label: {
            VStack(alignment: .leading, spacing: BooksCardLayout.captionGap) {
                if let zoom {
                    figure.matchedTransitionSource(id: book.route, in: zoom)
                } else {
                    figure
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
            .contentShape(.rect)
        }
        .buttonStyle(PressScaleButtonStyle(pressedScale: 0.97))
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
