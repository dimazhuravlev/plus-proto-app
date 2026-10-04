import SwiftUI

// MARK: - Геометрия

/// Числа макета `2427:26464` и правок пользователя 2026-10-04. Холст макета — 375,
/// у проекта 402: поля 16 остаются, колонка становится шире.
private enum BookScreenLayout {
    static let sideInset: CGFloat = EntityCoverLayout.side

    /// Шапка — общая с альбомом (`EntityCoverHeader`, правки 2026-10-04): фон — размытая
    /// копия обложки, обложка тянется за оттягом. Обложка — книга в проекции, как
    /// в выдаче поиска: высота обложки — прежняя макетная 324, ширина — по пропорциям.
    static let book = BookFigureGeometry(coverHeight: 324)
    /// Книга с блоком страниц над обложкой.
    static var bookHeight: CGFloat { book.frameSize(coverWidth: 0).height }

    /// Описание: сразу под блоком названия (его 24 снизу — как у альбома до треклиста),
    /// 16 снизу, абзацы через 16.
    static let descriptionTop: CGFloat = 0
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
    /// Абзацы описания в скелетоне — доли ширины колонки по строкам.
    static let skeletonParagraphs: [[CGFloat]] = [
        [1, 0.96, 0.93, 0.98, 0.62],
        [1, 0.94, 0.97, 0.45],
    ]
    static let skeletonHeaderWidth: CGFloat = 140
    static let skeletonHeaderBar: CGFloat = 16

    /// Дополнительный воздух под низом ленты, сверх клиренса хрома — как у альбома.
    static var bottomClearance: CGFloat { AlbumLayout.bottomClearance }

    /// Пороги навбара — общие с альбомом, от верха названия.
    static var navBarThresholds: EntityNavBarThresholds {
        EntityCoverLayout.navBarThresholds(coverHeight: bookHeight)
    }
}

enum BookScreenMotion {
    /// Скелетоны сменяются контентом за 300 мс (задача пользователя 2026-10-04):
    /// кроссфейд на месте, и раскладка под ним доезжает той же кривой.
    static let reveal: Animation = EntityMotion.reveal
}

// MARK: - Экран

/// Экран книги — макет `2427:26464` с правками 2026-10-04: та же конструкция, что
/// у альбома — общая резиновая шапка (фон — размытая копия обложки, обложка тянется
/// за оттягом) и общий блок названия (название, строка автора с фото и годом, «Читать»
/// и круглые «нравится», «скачать», «поделиться»). Обложка — книга в проекции своих
/// пропорций, как карточка выдачи поиска. Ниже — описание и «Книги писателя». Всё,
/// что едет из сети, стоит скелетоном и проявляется на его месте.
struct BookScreen: View {
    let entity: EntityRef
    @Environment(ActionBarState.self) private var actionBar
    @Environment(AppNavigationState.self) private var navigation
    /// Автор и описание — из того же захода в Google Books, что и текст читалки.
    @State private var text = BookTextStore()
    @State private var shelf = AuthorBooksStore()
    /// Пропорции обложки: `nil` — картинка ещё едет, стоит скелетон книги.
    /// `.some(nil)` — картинки нет вовсе, книга встаёт с пропорциями по умолчанию.
    @State private var coverAspect: CGFloat??
    /// Фото автора — из Википедии; пока ищется — скелетон круга.
    @State private var portrait: EntityPersonRow.Picture = .loading
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
                    header
                    description
                    shelfSection
                }
                .frame(maxWidth: .infinity)
                // Смена скелетонов на контент — одной кривой: кроссфейд на месте,
                // а то, что ниже, доезжает до новой высоты вместе с ним.
                .animation(BookScreenMotion.reveal, value: text.isReady)
                .animation(BookScreenMotion.reveal, value: shelf.isLoaded)
                .animation(BookScreenMotion.reveal, value: author)
                .animation(BookScreenMotion.reveal, value: portrait)
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

            // Общий навбар, как у альбома, — без правого слота: «поделиться» теперь
            // в ряду действий под названием.
            EntityNavBar(
                title: entity.title,
                artwork: entity.artwork,
                scrollOffset: scrollOffset,
                thresholds: BookScreenLayout.navBarThresholds
            )
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
        .task(id: author) { await loadPortrait() }
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

    /// Ширина обложки сейчас: своих пропорций, а пока они едут — по умолчанию.
    private var coverWidth: CGFloat {
        BookScreenLayout.book.coverWidth(aspect: coverAspect ?? nil)
    }

    /// Шапка — общая с альбомом (`EntityHeader`): резиновая зона обложки и блок
    /// названия — название кеглем по длине, строка автора (фото, имя, год), «Читать»
    /// и три круглые. Фон проявляется вместе с книгой: до обложки размывать нечего.
    private var header: some View {
        EntityHeader(
            artwork: entity.artwork,
            coverSize: CGSize(
                width: BookScreenLayout.book.frameSize(coverWidth: coverWidth).width,
                height: BookScreenLayout.bookHeight
            ),
            scrollOffset: scrollOffset,
            backdropOpacity: coverAspect == nil ? 0 : 1,
            title: entity.title
        ) {
            bookCover
        } person: {
            // Автора так и не узнали — строки нет; пока узнаём — скелетон.
            if author != nil || !text.isReady {
                // Строка автора — переход на экран писателя (2026-10-04).
                Button(action: openWriter) {
                    EntityPersonRow(
                        picture: portrait,
                        name: author,
                        detail: text.year,
                        isDetailLoading: !text.isReady
                    )
                    .contentShape(.rect)
                }
                .buttonStyle(PressScaleButtonStyle(pressedScale: 0.97))
                .disabled(author == nil)
            }
        } primary: {
            EntityPrimaryButton(icon: "iconRead", title: "Читать", action: startReading)
        }
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

    // MARK: Автор

    /// Из поиска книга приходит с автором, с витрины — без: тогда он из API.
    private var author: String? {
        entity.subtitle.isEmpty ? text.author : entity.subtitle
    }

    /// Экран писателя: фото — то, что нашлось для строки (иначе экран поищет сам).
    private func openWriter() {
        guard let author, !author.isEmpty else { return }
        let photo: ArtworkSource
        if case .artwork(let source) = portrait { photo = source } else { photo = .asset("") }
        navigation.open(.writer(EntityRef(id: "name-\(author)", title: author, subtitle: "", artwork: photo)))
    }

    /// Фото автора — из Википедии, по имени из метаданных тома. Картинка грузится
    /// до показа: круг меняет скелетон на фото, а не на пустоту. Фото нет — аватарки
    /// нет, строка начинается с имени (правка пользователя 2026-10-04).
    private func loadPortrait() async {
        guard let author, !author.isEmpty else { return }
        let picture: EntityPersonRow.Picture
        if let url = await WikipediaPeople.shared.portrait(of: author),
           await ArtworkLoader.shared.image(for: url) != nil {
            picture = .artwork(.remote(url))
        } else {
            picture = .none
        }
        guard !Task.isCancelled else { return }
        portrait = picture
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

    /// Книга карусели открывает свой экран, как «Другие альбомы», — через навигацию,
    /// а не `NavigationLink`: в слое фильма стека нет (`AppNavigationState.open`).
    /// Обложка — на скелетоне подложки, пока едет.
    private func shelfCard(_ book: AuthorBooksStore.Book) -> some View {
        let geometry = BookScreenLayout.shelfBook
        let coverWidth = geometry.coverWidth(aspect: book.aspect)
        let route = EntityRoute.book(EntityRef(
            id: "gb-\(book.id)",
            title: book.title,
            subtitle: author ?? "",
            artwork: .remote(book.cover)
        ))
        return Button { navigation.open(route) } label: {
            VStack(alignment: .leading, spacing: BookScreenLayout.shelfTextGap) {
                BookFigure(geometry: geometry, coverWidth: coverWidth) {
                    SkeletonArtwork(source: .remote(book.cover))
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
