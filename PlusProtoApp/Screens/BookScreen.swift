import SwiftUI

// MARK: - Геометрия

/// Числа макета `2427:26464` и правок пользователя 2026-10-04. Холст макета — 375,
/// у проекта 402: поля 16 остаются, колонка становится шире.
private enum BookScreenLayout {
    static let sideInset: CGFloat = 16

    // Шапка — как у альбома (правка 2026-10-04): фон — размытая копия обложки
    // от физического верха экрана, обложка — книга в проекции, как в выдаче поиска.
    /// Верх книги — там же, где кавер альбома: сразу под навбаром.
    static var coverTop: CGFloat { AlbumLayout.coverTop }
    /// Высота обложки — прежняя макетная 324; ширина — по пропорциям самой обложки.
    static let book = BookFigureGeometry(coverHeight: 324)
    /// Книга с блоком страниц над обложкой.
    static var bookHeight: CGFloat { book.frameSize(coverWidth: 0).height }
    /// Зазор от книги до названия — 16, как у альбома (прежде 8 + 8 макета).
    static let coverToTitle: CGFloat = 16
    static var coverZoneHeight: CGFloat { coverTop + bookHeight + coverToTitle }
    /// Фон уходит ниже книги на столько же, на сколько у альбома ниже кавера (48.5):
    /// там градиент уже довёл его до чёрного.
    static var backdropTail: CGFloat { AlbumLayout.coverArea - AlbumLayout.coverTop - AlbumLayout.coverSize }
    static var backdropHeight: CGFloat { coverTop + bookHeight + backdropTail }

    /// Название и автор: под ними 8, между ними 8.
    static let textBottom: CGFloat = 8
    static let titleToAuthor: CGFloat = 8
    /// Кнопка «Читать» — компонент `12:8770` (Size=xl, Type=accent, Icon=leading):
    /// глиф 24 и по 14 сверху и снизу, поля 22/26. Вокруг — 8 + 12 сверху и снизу
    /// и ряд с полями 10.
    static let buttonHeight: CGFloat = 52
    static let buttonIcon: CGFloat = 24
    static let buttonIconGap: CGFloat = 8
    static let buttonLeading: CGFloat = 22
    static let buttonTrailing: CGFloat = 26
    static let buttonRowInset: CGFloat = 10
    static let buttonsInnerPadding: CGFloat = 12
    static let buttonsOuterPadding: CGFloat = 8
    /// Описание: 8 сверху, 16 снизу, абзацы через 16.
    static let descriptionTop: CGFloat = 8
    static let descriptionBottom: CGFloat = 16
    static let paragraphGap: CGFloat = 16

    // «Книги писателя» — заголовок и поля секции как у «Других альбомов».
    static let sectionPad: CGFloat = 8
    static let sectionHeaderTop: CGFloat = 16
    static let sectionHeaderBottom: CGFloat = 12
    static let sectionTitleGap: CGFloat = 2
    static let sectionChevronBox: CGFloat = 20
    /// Строка заголовка секции — 28, как у заголовков выдачи (Headline M при 100 %).
    static let sectionHeaderLine: CGFloat = 28
    /// Книга карусели — тот же рисунок, высота обложки 186: в экран входит две
    /// книги с половиной, как у карточек «Других альбомов» (159).
    static let shelfBook = BookFigureGeometry(coverHeight: 186)
    static let shelfGap: CGFloat = 8
    static let shelfTextGap: CGFloat = 6
    static let shelfTextTrailing: CGFloat = 8
    static let shelfTitleLines = 2
    static let shelfSkeletonBooks = 3

    // Скелетоны — `PlusSkeleton`: полосы 12 по центрам строк Text M (20).
    static let skeletonBar: CGFloat = 12
    static var skeletonBarInset: CGFloat { (PlusTextSize.textM.lineHeight - skeletonBar) / 2 }
    static let skeletonAuthorWidth: CGFloat = 140
    /// Абзацы описания в скелетоне — доли ширины колонки по строкам.
    static let skeletonParagraphs: [[CGFloat]] = [
        [1, 0.96, 0.93, 0.98, 0.62],
        [1, 0.94, 0.97, 0.45],
    ]
    static let skeletonHeaderWidth: CGFloat = 140
    static let skeletonHeaderBar: CGFloat = 16

    /// Дополнительный воздух под низом ленты, сверх клиренса хрома — как у альбома.
    static var bottomClearance: CGFloat { AlbumLayout.bottomClearance }

    /// Пороги навбара — в той же связке с блоком названия, что у альбома: подложка —
    /// когда шапка почти ушла под бар, обложка с названием — когда под ним название.
    static var navBarThresholds: EntityNavBarThresholds {
        EntityNavBarThresholds(
            backgroundStart: coverZoneHeight - 122,
            backgroundRamp: 80,
            titleStart: coverZoneHeight - 22,
            titleRamp: 90
        )
    }
}

enum BookScreenMotion {
    /// Скелетоны сменяются контентом за 300 мс (задача пользователя 2026-10-04):
    /// кроссфейд на месте, и раскладка под ним доезжает той же кривой.
    static let reveal: Animation = .easeInOut(duration: 0.3)
}

// MARK: - Экран

/// Экран книги — макет `2427:26464` с правками 2026-10-04: шапка как у альбома (фон —
/// размытая копия обложки с той же резиной оттяга), обложка — книга в проекции
/// своих пропорций, как карточка выдачи поиска, название и автор, акцентная «Читать»,
/// описание и карусель «Книги писателя». Всё, что едет из сети, стоит скелетоном
/// и проявляется на его месте. Сверху — общий навбар с «назад» и «поделиться».
struct BookScreen: View {
    let entity: EntityRef
    @Environment(ActionBarState.self) private var actionBar
    /// Автор и описание — из того же захода в Google Books, что и текст читалки.
    @State private var text = BookTextStore()
    @State private var shelf = AuthorBooksStore()
    /// Пропорции обложки: `nil` — картинка ещё едет, стоит скелетон книги.
    /// `.some(nil)` — картинки нет вовсе, книга встаёт с пропорциями по умолчанию.
    @State private var coverAspect: CGFloat??
    @State private var scrollOffset: CGFloat = 0
    #if DEBUG
    /// `-debugTapPlay` уже нажал «Читать» на этом экране: читалка открывается
    /// поверх, и на её закрытии экран возвращается в окно — `.task` стартует заново.
    @State private var didDebugTapPlay = false
    #endif

    init(entity: EntityRef) {
        self.entity = entity
        // Обложка уже в кэше (книгу открыли из выдачи или с витрины) — книга встаёт
        // сразу своих пропорций, без скелетона на первом кадре.
        _coverAspect = State(initialValue: Self.cachedAspect(of: entity.artwork))
    }

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: 0) {
                    coverZone
                    titles
                    readButton
                    description
                    shelfSection
                }
                .frame(maxWidth: .infinity)
                // Смена скелетонов на контент — одной кривой: кроссфейд на месте,
                // а то, что ниже, доезжает до новой высоты вместе с ним.
                .animation(BookScreenMotion.reveal, value: text.isReady)
                .animation(BookScreenMotion.reveal, value: shelf.isLoaded)
                .animation(BookScreenMotion.reveal, value: author)
            }
            .scrollIndicators(.hidden)
            // Хром (таббар + action bar) на этом экране виден — лента едет под ним.
            .contentMargins(
                .bottom,
                PlusChromeMetrics.contentBottomInset + BookScreenLayout.bottomClearance,
                for: .scrollContent
            )
            // Шапка начинается от физического верха экрана, как у альбома.
            .ignoresSafeArea(edges: .top)
            .trackNavBarScroll(into: $scrollOffset)

            // Общий навбар как есть: кнопки 40, поля 16 с обеих сторон — правка
            // пользователя 2026-10-03 поверх макета, где кнопки 32 (`Size=sm`).
            EntityNavBar(
                title: entity.title,
                artwork: entity.artwork,
                scrollOffset: scrollOffset,
                thresholds: BookScreenLayout.navBarThresholds
            ) {
                // Поделиться пока нечем — кнопка из макета, с пресс-стейтом.
                GlassIconButton(icon: "iconShare", accessibilityTitle: "Поделиться")
            }
        }
        .background(Color.black.ignoresSafeArea())
        // Системный бар выключен: на пуше он рисовал бы свой back поверх нашего.
        .toolbar(.hidden, for: .navigationBar)
        .task { await text.load(bookID: entity.id) }
        .task(id: entity.artwork) {
            guard coverAspect == nil else { return }
            let aspect = await Self.loadAspect(of: entity.artwork)
            withAnimation(BookScreenMotion.reveal) { coverAspect = .some(aspect) }
        }
        // «Книги писателя» — когда известен автор: из выдачи он приходит сразу,
        // с витрины — из того же захода, что описание.
        .task(id: shelfKey) { await loadShelf() }
        #if DEBUG
        // `-debugTapPlay` — нажать «Читать»: из шелла тапнуть нечем.
        .task {
            guard UserDefaults.standard.bool(forKey: "debugTapPlay"), !didDebugTapPlay else { return }
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            didDebugTapPlay = true
            startReading()
        }
        #endif
    }

    // MARK: Шапка

    /// Оттяг вниз. Скролл вверх шапку не трогает — она обычным образом уезжает.
    private var pull: CGFloat { max(0, -scrollOffset) }

    /// Зона шапки: фон и книга. Фон — как у альбома, с той же резиной: компенсирует
    /// оттяг (`offset(y: -pull)`) и тянется ровно на его величину от верхней кромки —
    /// низ остаётся приклеен к блоку названия. Книга едет с контентом.
    private var coverZone: some View {
        let backdropScale = (BookScreenLayout.backdropHeight + pull) / BookScreenLayout.backdropHeight

        return ZStack(alignment: .top) {
            backdrop
                .scaleEffect(backdropScale, anchor: .top)
                .offset(y: -pull)
                // Фон проявляется вместе с книгой: до обложки размывать нечего.
                .opacity(coverAspect == nil ? 0 : 1)

            bookCover
                .padding(.top, BookScreenLayout.coverTop)
        }
        .frame(maxWidth: .infinity)
        // По верху: содержимое зоны выше её кадра (фон рисуется на всю свою высоту),
        // а `frame(height:)` по умолчанию центрирует переполнение — см. альбом.
        .frame(height: BookScreenLayout.coverZoneHeight, alignment: .top)
    }

    /// Фон — сама обложка: blur 30, чёрный 30 % и 16-стоповый градиент к чёрному
    /// снизу — ровно тот же, что у альбома.
    private var backdrop: some View {
        ArtworkImage(source: entity.artwork)
            .scaledToFill()
            .frame(width: PlusMetrics.designWidth, height: BookScreenLayout.backdropHeight)
            .clipped()
            .blur(radius: AlbumLayout.backdropBlur, opaque: true)
            .overlay(Color.black.opacity(AlbumLayout.backdropDim))
            .overlay(MovieScrim.gradient(peak: 1, from: .top, to: .bottom))
            .allowsHitTesting(false)
    }

    /// Книга — тот же рисунок, что карточка выдачи поиска, только крупно. Пока
    /// обложка едет — скелетон книги пропорций по умолчанию; приехала — книга своих
    /// пропорций проявляется на его месте.
    private var bookCover: some View {
        let geometry = BookScreenLayout.book
        return ZStack {
            if let aspect = coverAspect {
                BookFigure(geometry: geometry, coverWidth: geometry.coverWidth(aspect: aspect)) {
                    ArtworkImage(source: entity.artwork).scaledToFill()
                }
                .transition(.opacity)
            } else {
                BookFigure(geometry: geometry, coverWidth: geometry.coverWidth(aspect: nil)) {
                    EmptyView()
                }
                .transition(.opacity)
                .accessibilityLabel("Загрузка")
            }
        }
        .frame(height: BookScreenLayout.bookHeight)
    }

    // MARK: Название и автор

    /// Кегль названия — ступенью от длины, тем же правилом, что у альбома
    /// (`EntityTitleType`).
    private var titles: some View {
        VStack(spacing: BookScreenLayout.titleToAuthor) {
            Text(entity.title)
                .plusHeadline(EntityTitleType.style(for: entity.title))
                .foregroundStyle(Color.fillOne)
            authorLine
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, BookScreenLayout.sideInset)
        .padding(.bottom, BookScreenLayout.textBottom)
    }

    /// Строка автора держит место всегда: и до ответа API (там скелетон), и у книги
    /// без автора — иначе кнопка и описание съезжали бы на её высоту.
    private var authorLine: some View {
        ZStack {
            Text(author ?? " ")
                .plusText(.textM, .medium)
                .foregroundStyle(Color.fillSubtitle)
                .opacity(author == nil ? 0 : 1)

            if author == nil, !text.isReady {
                Capsule(style: .continuous)
                    .fill(PlusSkeleton.fill)
                    .frame(width: BookScreenLayout.skeletonAuthorWidth, height: BookScreenLayout.skeletonBar)
                    .transition(.opacity)
                    .accessibilityHidden(true)
            }
        }
    }

    /// Из поиска книга приходит с автором, с витрины — без: тогда он из API.
    private var author: String? {
        entity.subtitle.isEmpty ? text.author : entity.subtitle
    }

    // MARK: Кнопка

    private var readButton: some View {
        Button(action: startReading) {
            HStack(spacing: BookScreenLayout.buttonIconGap) {
                MovieIcon(name: "iconRead", box: BookScreenLayout.buttonIcon)
                Text("Читать")
                    .plusText(.textM, .semibold)
                    .foregroundStyle(Color.fillOne)
                    .fixedSize()
            }
            .padding(.leading, BookScreenLayout.buttonLeading)
            .padding(.trailing, BookScreenLayout.buttonTrailing)
            .frame(maxWidth: .infinity)
            .frame(height: BookScreenLayout.buttonHeight)
            // Общий акцентный стиль ДС — тот же, что у «Смотреть» и «Слушать»:
            // это одна и та же кнопка «включить контент».
            .accentButtonSurface()
        }
        .buttonStyle(PressScaleButtonStyle())
        .padding(.horizontal, BookScreenLayout.buttonRowInset)
        .padding(.vertical, BookScreenLayout.buttonsInnerPadding)
        .padding(.horizontal, BookScreenLayout.sideInset)
        .padding(.vertical, BookScreenLayout.buttonsOuterPadding)
    }

    // MARK: Описание

    /// Описание — на месте своего скелетона: кроссфейд в одной стопке, а не смена
    /// строк в колонке, иначе на время перехода обе стояли бы друг под другом.
    private var description: some View {
        ZStack(alignment: .topLeading) {
            if !text.isReady {
                descriptionSkeleton
                    .transition(.opacity)
            } else if !text.annotation.isEmpty {
                VStack(alignment: .leading, spacing: BookScreenLayout.paragraphGap) {
                    ForEach(Array(text.annotation.enumerated()), id: \.offset) { _, paragraph in
                        Text(paragraph)
                            .plusText(.textM, .medium)
                            .foregroundStyle(Color.fillFour)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.top, BookScreenLayout.descriptionTop)
                .padding(.bottom, BookScreenLayout.descriptionBottom)
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, BookScreenLayout.sideInset)
    }

    private var descriptionSkeleton: some View {
        GeometryReader { proxy in
            VStack(alignment: .leading, spacing: BookScreenLayout.paragraphGap) {
                ForEach(BookScreenLayout.skeletonParagraphs.indices, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 2 * BookScreenLayout.skeletonBarInset) {
                        ForEach(BookScreenLayout.skeletonParagraphs[index].indices, id: \.self) { line in
                            Rectangle()
                                .fill(PlusSkeleton.fill)
                                .frame(
                                    width: proxy.size.width * BookScreenLayout.skeletonParagraphs[index][line],
                                    height: BookScreenLayout.skeletonBar
                                )
                        }
                    }
                    .padding(.vertical, BookScreenLayout.skeletonBarInset)
                }
            }
        }
        .frame(height: descriptionSkeletonHeight)
        .padding(.top, BookScreenLayout.descriptionTop)
        .padding(.bottom, BookScreenLayout.descriptionBottom)
        .accessibilityLabel("Загрузка")
    }

    /// Высота скелетона — ровно его строки Text M и зазоры абзацев: `GeometryReader`
    /// своей высоты не знает.
    private var descriptionSkeletonHeight: CGFloat {
        let lines = BookScreenLayout.skeletonParagraphs.reduce(0) { $0 + $1.count }
        let gaps = BookScreenLayout.skeletonParagraphs.count - 1
        return CGFloat(lines) * PlusTextSize.textM.lineHeight + CGFloat(gaps) * BookScreenLayout.paragraphGap
    }

    // MARK: Книги писателя

    /// Карусель других книг автора (задача пользователя 2026-10-04). Пока ответ едет —
    /// скелетон секции; книг нет — секции нет вовсе.
    @ViewBuilder
    private var shelfSection: some View {
        ZStack(alignment: .topLeading) {
            if !shelf.isLoaded {
                shelfSkeleton
                    .transition(.opacity)
            } else if !shelf.books.isEmpty {
                shelfContent
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var shelfContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Шеврон — как у «Других альбомов»: полного списка книг автора нет,
            // заголовок не нажимается.
            HStack(spacing: BookScreenLayout.sectionTitleGap) {
                Text("Книги писателя")
                    .plusHeadline(.m)
                    .foregroundStyle(Color.fillOne)

                Image("iconDropleft")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: BookScreenLayout.sectionChevronBox, height: BookScreenLayout.sectionChevronBox)
                    .scaleEffect(x: -1)
                    .foregroundStyle(Color.fillSubtitle)
                    .offset(y: PlusMetrics.headerChevronDrop)
            }
            .frame(height: BookScreenLayout.sectionHeaderLine)
            .accessibilityAddTraits(.isHeader)
            .padding(.top, BookScreenLayout.sectionHeaderTop)
            .padding(.bottom, BookScreenLayout.sectionHeaderBottom)
            .padding(.horizontal, BookScreenLayout.sideInset)

            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: BookScreenLayout.shelfGap) {
                    ForEach(shelf.books) { book in
                        shelfCard(book)
                    }
                }
            }
            .scrollIndicators(.hidden)
            .contentMargins(.horizontal, BookScreenLayout.sideInset, for: .scrollContent)
        }
        .padding(.vertical, BookScreenLayout.sectionPad)
    }

    /// Книга карусели открывает свой экран — пушем, как «Другие альбомы».
    private func shelfCard(_ book: AuthorBooksStore.Book) -> some View {
        let geometry = BookScreenLayout.shelfBook
        let coverWidth = geometry.coverWidth(aspect: book.aspect)
        return NavigationLink(value: EntityRoute.book(EntityRef(
            id: "gb-\(book.id)",
            title: book.title,
            subtitle: author ?? "",
            artwork: .remote(book.cover)
        ))) {
            VStack(alignment: .leading, spacing: BookScreenLayout.shelfTextGap) {
                BookFigure(geometry: geometry, coverWidth: coverWidth) {
                    ArtworkImage(source: .remote(book.cover)).scaledToFill()
                }

                VStack(alignment: .leading, spacing: 0) {
                    Text(book.title)
                        .plusText(.textM, .medium)
                        .foregroundStyle(Color.fillOne)
                        .lineLimit(BookScreenLayout.shelfTitleLines)
                    if let year = book.year {
                        Text(year)
                            .plusText(.textM, .medium)
                            .foregroundStyle(Color.fillSubtitle)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(.trailing, BookScreenLayout.shelfTextTrailing)
            }
            .frame(width: geometry.frameSize(coverWidth: coverWidth).width, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(PressScaleButtonStyle(pressedScale: 0.97))
    }

    /// Скелетон секции — того же габарита: полоса заголовка в строке 28 и книги
    /// пропорций по умолчанию с полосами названия и года.
    private var shelfSkeleton: some View {
        let geometry = BookScreenLayout.shelfBook
        let coverWidth = geometry.coverWidth(aspect: nil)
        return VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(PlusSkeleton.fill)
                .frame(width: BookScreenLayout.skeletonHeaderWidth, height: BookScreenLayout.skeletonHeaderBar)
                .frame(height: BookScreenLayout.sectionHeaderLine)
                .padding(.top, BookScreenLayout.sectionHeaderTop)
                .padding(.bottom, BookScreenLayout.sectionHeaderBottom)
                .padding(.horizontal, BookScreenLayout.sideInset)

            // В ленте, как настоящая карусель: третья книга уходит за край экрана,
            // а не распирает колонку.
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: BookScreenLayout.shelfGap) {
                    ForEach(0..<BookScreenLayout.shelfSkeletonBooks, id: \.self) { _ in
                        VStack(alignment: .leading, spacing: BookScreenLayout.shelfTextGap) {
                            BookFigure(geometry: geometry, coverWidth: coverWidth) { EmptyView() }
                            VStack(alignment: .leading, spacing: 2 * BookScreenLayout.skeletonBarInset) {
                                Rectangle().fill(PlusSkeleton.fill)
                                    .frame(width: coverWidth * 0.8, height: BookScreenLayout.skeletonBar)
                                Rectangle().fill(PlusSkeleton.fill)
                                    .frame(width: coverWidth * 0.35, height: BookScreenLayout.skeletonBar)
                            }
                            .padding(.top, BookScreenLayout.skeletonBarInset)
                        }
                    }
                }
            }
            .scrollDisabled(true)
            .scrollIndicators(.hidden)
            .contentMargins(.horizontal, BookScreenLayout.sideInset, for: .scrollContent)
        }
        .padding(.vertical, BookScreenLayout.sectionPad)
        .accessibilityLabel("Загрузка")
    }

    /// Когда грузить «Книги писателя»: автор известен — его имя; описание пришло,
    /// а автора так и нет — пустая строка (карусели не будет); иначе ждём (`nil`).
    /// Ключ меняется ровно на этих переходах — заход не перезапускается и не дублирует
    /// запрос из-за прихода описания.
    private var shelfKey: String? {
        if let author, !author.isEmpty { return author }
        return text.isReady ? "" : nil
    }

    /// Книги автора — только у настоящего тома Google: моковой книге искать нечего.
    private func loadShelf() async {
        guard let key = shelfKey else { return }
        guard let volumeID = BookTextStore.volumeID(for: entity.id), !key.isEmpty else {
            shelf.markEmpty()
            return
        }
        await shelf.load(author: key, excludingVolume: volumeID, title: entity.title)
    }

    // MARK: Обложка

    /// Пропорции обложки из кэша — синхронно, на первом кадре.
    private static func cachedAspect(of source: ArtworkSource) -> CGFloat?? {
        if let url = source.remoteURL {
            return ArtworkLoader.shared.cached(url).map { .some(aspect(of: $0)) }
        }
        return .some(source.fallbackAsset.flatMap { UIImage(named: $0) }.map(aspect(of:)))
    }

    /// Пропорции обложки — по самой картинке. Не загрузилась — `nil`: книга встанет
    /// с пропорциями по умолчанию, а на обложке будет заглушка `ArtworkImage`.
    private static func loadAspect(of source: ArtworkSource) async -> CGFloat? {
        if let url = source.remoteURL, let image = await ArtworkLoader.shared.image(for: url) {
            return aspect(of: image)
        }
        return source.fallbackAsset.flatMap { UIImage(named: $0) }.map(aspect(of:))
    }

    private static func aspect(of image: UIImage) -> CGFloat {
        image.size.width / max(image.size.height, 1)
    }

    // MARK: Действия

    /// «Читать» открывает читалку и кладёт книгу в бар: переход на экран
    /// ни того, ни другого не делает (правка пользователя 2026-08-28).
    private func startReading() {
        UIImpactFeedbackGenerator(style: .medium)
            .impactOccurred(intensity: ShowcaseMotion.tapHapticIntensity)
        actionBar.open(.book(BookInProgress(
            id: entity.id,
            cover: entity.artwork,
            title: entity.title,
            author: author
        )))
    }
}
