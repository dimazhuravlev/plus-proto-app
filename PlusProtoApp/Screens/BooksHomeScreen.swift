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
    static let blurbFade: Animation = .easeInOut(duration: 0.25)
    static let buttonHeight: CGFloat = 48
    static let buttonPadding: CGFloat = 32
    static let buttonBottom: CGFloat = 24
    /// Фон — размытая копия обложки текущей книги, затемнённая и уходящая в чёрный
    static let backdropBlur: CGFloat = 40
    static let backdropDim: Double = 0.35
    static let backdropFade: Animation = .easeInOut(duration: 0.4)
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

    static let filters = ["Книги", "Аудиокниги"]

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
            // Скелетон и лента — слоями, на месте (урок главной Кинопоиска).
            ZStack(alignment: .top) {
                if catalog.isLoaded {
                    VStack(spacing: 0) {
                        if !catalog.promos.isEmpty {
                            BooksPromoCarousel(books: catalog.promos)
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

    @Environment(ActionBarState.self) private var actionBar
    @Environment(AppNavigationState.self) private var navigation
    @Environment(\.stackZoomNamespace) private var zoom

    /// Повторов набора — тот же круг, что у промо Кинопоиска.
    private static let laps = 200

    @State private var page: Int?

    init(books: [BooksHomeCatalog.Book]) {
        self.books = books
        _page = State(initialValue: books.count * (Self.laps / 2))
    }

    private var current: BooksHomeCatalog.Book? {
        guard !books.isEmpty else { return nil }
        let index = page ?? books.count * (Self.laps / 2)
        return books[((index % books.count) + books.count) % books.count]
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

    /// Коротко о текущей книге — сменяется кроссфейдом вместе с фоном.
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
                    .transition(.opacity)
            }
        }
        .frame(height: BooksPromoLayout.blurbHeight, alignment: .top)
        .animation(BooksPromoLayout.blurbFade, value: current?.id)
    }

    private var carousel: some View {
        let count = books.count
        return ScrollView(.horizontal) {
            LazyHStack(spacing: BooksPromoLayout.gap) {
                ForEach(0..<(count * Self.laps), id: \.self) { index in
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
                        }
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned(limitBehavior: .alwaysByOne))
        .contentMargins(.horizontal, (PlusMetrics.designWidth - BooksPromoLayout.slot) / 2, for: .scrollContent)
        .scrollPosition(id: $page, anchor: .center)
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

    /// Размытая копия обложки текущей книги — от физического верха экрана до низа
    /// промо, затемнённая и уходящая в чёрный. Смена книги — кроссфейдом.
    private var backdrop: some View {
        let height = ServiceTopNavLayout.topSafeArea + CinemaLayout.contentTop
            + BooksPromoLayout.carouselHeight + BooksPromoLayout.blurbHeight + BooksPromoLayout.blurbToButton
            + BooksPromoLayout.buttonHeight + BooksPromoLayout.buttonBottom
        return ZStack {
            if let current {
                SkeletonArtwork(source: current.cover)
                    .frame(width: PlusMetrics.designWidth, height: height)
                    .blur(radius: BooksPromoLayout.backdropBlur, opaque: true)
                    .overlay { Color.black.opacity(BooksPromoLayout.backdropDim) }
                    .id(current.id)
                    .transition(.opacity)
            }
        }
        .frame(width: PlusMetrics.designWidth, height: height)
        .clipped()
        .mask {
            LinearGradient(
                stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.55), .init(color: .clear, location: 1)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .animation(BooksPromoLayout.backdropFade, value: current?.id)
        .allowsHitTesting(false)
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
