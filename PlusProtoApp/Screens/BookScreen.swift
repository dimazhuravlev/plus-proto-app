import SwiftUI

// MARK: - Версии

/// Версии книги на экране: текст и аудио. Порядок — как в ленте обложек: книга слева,
/// аудиокнига справа (макеты `893:54932` и `893:54891` файла Petr Batur).
enum BookVersion: Int, CaseIterable, Hashable {
    case text
    case audio
}

// MARK: - Геометрия

/// Числа макетов `893:54932` (книга) и `893:54891` (аудиокнига), холст 375. Поля 16
/// постоянные, обложки — макетного размера; где обложка соседней версии торчит у края
/// экрана, расстояние до края держится как в макете на любой ширине.
private enum BookScreenLayout {
    static let sideInset: CGFloat = 16

    // Лента обложек.
    /// Высота обложки в центре: книга 168×252, аудиокнига 252×252.
    static let coverHeight: CGFloat = 252
    static let coverRowPad: CGFloat = 8
    /// Соседняя версия: книга 128×192, аудиокнига 168×168, наклон ±7° к центру.
    static let bookSideScale: CGFloat = 192 / 252
    static let audioSideScale: CGFloat = 168 / 252
    static let sideTilt: Double = 7
    /// Центр соседки ниже центра главной обложки: книга слева — на 6, аудио справа — на 13.6.
    static let bookSideDrop: CGFloat = 6
    static let audioSideDrop: CGFloat = 13.6
    /// Центр аудиокниги справа — в 24.4 от правого края экрана; книги слева — в 2.5
    /// за левым краем. Шаг ленты — от первого, книга слева доезжает на разницу.
    static let audioSideEdge: CGFloat = 24.4
    static let bookSideEdge: CGFloat = -2.5
    @MainActor static var step: CGFloat { PlusMetrics.screenWidth / 2 - audioSideEdge }
    @MainActor static var bookSideShift: CGFloat {
        -(PlusMetrics.screenWidth / 2 - bookSideEdge - step)
    }
    /// Тень обложки: Figma `0 4 12.5 #000 50 %`; радиус SwiftUI — половина блюра Фигмы.
    static let shadowRadius: CGFloat = 6.25
    static let shadowY: CGFloat = 4
    static let shadowOpacity: Double = 0.5

    // Название.
    static let textPad: CGFloat = 8
    static let titleGap: CGFloat = 8

    // Счётчики: колонки по 88, поля 40, сверху 8.
    static let statsTop: CGFloat = 8
    static let statsSide: CGFloat = 40
    static let statWidth: CGFloat = 88

    // Кнопки: блок 8 сверху и снизу, ряд — ещё 12, между кнопками 8.
    static let buttonsPad: CGFloat = 8
    static let buttonsRowPad: CGFloat = 12
    static let buttonsGap: CGFloat = 8

    // Описание.
    static let descriptionTop: CGFloat = 16
    static let paragraphGap: CGFloat = 16

    // Детали: блок 16 сверху и снизу, шапка и строки через 8, строки через 14.
    static let detailsPad: CGFloat = 16
    static let detailsGap: CGFloat = 8
    static let detailsRowGap: CGFloat = 14
    static let detailsLabelWidth: CGFloat = 128

    // Теги: через 4 по горизонтали и 6 по вертикали, 8 сверху и снизу.
    static let tagsPad: CGFloat = 8
    static let tagsHGap: CGFloat = 4
    static let tagsVGap: CGFloat = 6

    // Карусели `carousel / Books`: шапка 16 сверху, 12 снизу; блок 8 сверху и снизу;
    // обложки высотой 159 через 8.
    static let sectionPad: CGFloat = 8
    static let sectionHeaderTop: CGFloat = 16
    static let sectionHeaderBottom: CGFloat = 12
    static let sectionTitleGap: CGFloat = 2
    static let sectionChevronBox: CGFloat = 20
    static var sectionHeaderLine: CGFloat { EntitySectionLayout.headerLine }
    static let shelfHeight: CGFloat = 159
    static let shelfGap: CGFloat = 8

    // Скелетон описания — полосы 12 по центрам строк Text M.
    static let skeletonBar: CGFloat = 12
    static var skeletonBarInset: CGFloat { (PlusTextSize.textM.lineHeight - skeletonBar) / 2 }
    static let skeletonParagraphs: [[CGFloat]] = [
        [1, 0.96, 0.93, 0.98, 0.62],
        [1, 0.94, 0.97, 0.45],
    ]

    static var bottomClearance: CGFloat { AlbumLayout.bottomClearance }

    /// Навбар: подложка — как только лента ушла под него, название — когда ушло своё.
    @MainActor
    static var navBarThresholds: EntityNavBarThresholds {
        let titleTop = coverRowPad * 2 + coverHeight + textPad
        return EntityNavBarThresholds(
            backgroundStart: 0,
            backgroundRamp: EntityNavBarMotion.backgroundRamp,
            titleStart: titleTop,
            titleRamp: EntityNavBarMotion.titleRamp
        )
    }
}

enum BookScreenMotion {
    /// Скелетоны сменяются контентом за 300 мс (задача пользователя 2026-10-04).
    static let reveal: Animation = EntityMotion.reveal
    /// Смена версии — блюром, 300 мс: старое уходит, новое проявляется на его месте.
    static let swap: Animation = .easeInOut(duration: 0.3)
    /// Тап по соседней обложке — лента доезжает сама.
    static let step: Animation = .smooth(duration: 0.4)
}

// MARK: - Экран

/// Экран книги — макеты `893:54932` (книга) и `893:54891` (аудиокнига) файла Petr Batur,
/// задача 2026-11-20. Сверху лента из двух обложек — книги и её аудиоверсии: свайп
/// переключает версию тем же движением, что промо «Главной» (соседка меньше, наклонена
/// на 7° и опущена, всё — функцией сдвига ленты кадр в кадр). Ниже — название, счётчики,
/// «Читать» и «Слушать», описание, детали, теги и две карусели; всё, что зависит от
/// версии, сменяется блюром.
///
/// Данные — живые, а чего не знают Google Books и Deezer (читатели, прослушивания,
/// возраст, переводчик, издательство, теги до 5–10), то выдумано стабильно по id книги
/// (`BookMockFacts`, просьба пользователя 2026-11-20: «главное, чтобы были»).
struct BookScreen: View {
    let entity: EntityRef
    private let facts: BookMockFacts
    @Environment(ActionBarState.self) private var actionBar
    @Environment(AppNavigationState.self) private var navigation
    @Environment(CollectionStore.self) private var collection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var text = BookTextStore()
    @State private var shelf = AuthorBooksStore()
    @State private var editions = BookEditionsStore()
    @State private var audio = BookAudioStore()
    /// Пропорции обложки: `nil` — картинка ещё едет, стоит скелетон книги.
    @State private var coverAspect: CGFloat??
    @State private var scrollOffset: CGFloat = 0
    /// Обложка в центре ленты — её пишет сама лента (`scrollPosition`).
    @State private var page: BookVersion? = .text
    /// Версия, чьё содержимое показано. Меняется, когда центр ленты перешёл середину
    /// шага, — не на каждом кадре.
    @State private var version: BookVersion = .text
    #if DEBUG
    @State private var didDebugTapPlay = false
    #endif

    private typealias Layout = BookScreenLayout

    init(entity: EntityRef) {
        self.entity = entity
        self.facts = BookMockFacts(bookID: entity.id)
        _coverAspect = State(initialValue: BookCoverAspect.cached(of: entity.artwork))
    }

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: 0) {
                    coverRow
                    titleBlock
                    swapping { stats(for: $0) }
                    buttons
                    swapping { versionContent(for: $0) }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, EntityNavBarGeometry.barHeight)
                .animation(BookScreenMotion.reveal, value: text.isReady)
                .animation(BookScreenMotion.reveal, value: shelf.isLoaded)
                .animation(BookScreenMotion.reveal, value: editions.isLoaded)
                .animation(BookScreenMotion.reveal, value: audio.state)
                .animation(BookScreenMotion.reveal, value: audio.isRelatedLoaded)
            }
            .scrollIndicators(.hidden)
            .contentMargins(
                .bottom,
                PlusChromeMetrics.contentBottomInset + Layout.bottomClearance,
                for: .scrollContent
            )
            .trackNavBarScroll(into: $scrollOffset)

            EntityNavBar(
                title: entity.title,
                artwork: entity.artwork,
                scrollOffset: scrollOffset,
                thresholds: Layout.navBarThresholds
            ) {
                navActions
            }
        }
        .background(Color.surfaceOne.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task { await text.load(bookID: entity.id) }
        .task(id: entity.artwork) {
            guard coverAspect == nil else { return }
            let aspect = await BookCoverAspect.load(of: entity.artwork)
            withAnimation(BookScreenMotion.reveal) { coverAspect = .some(aspect) }
        }
        // Автор из выдачи приходит сразу, с витрины — из тома: тогда ждём описание.
        .task(id: authorKey) { await loadByAuthor() }
        #if DEBUG
        .task {
            guard UserDefaults.standard.bool(forKey: "debugTapPlay"), !didDebugTapPlay else { return }
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            didDebugTapPlay = true
            startReading()
        }
        #endif
    }

    // MARK: Навбар

    /// Справа — «добавить», «поделиться», «ещё» (макет); кнопки — круги навбара 40,
    /// как «назад» (сквозное правило `EntityNavBar`).
    private var navActions: some View {
        HStack(spacing: EntityNavBarGeometry.backToEntityGap) {
            // «В коллекцию» — общий глиф: «+», добавленное — галочка (правило 2026-11-10).
            PlusButton(type: .chrome, size: .m, accessibilityTitle: "Добавить в Моё") {
                collection.toggleFavorite(collectionItem)
            } icon: {
                LikeGlyph(isLiked: collection.isFavorite(collectionItem.id), box: PlusButtonSize.m.iconBox)
            }
            PlusButton(icon: "iconShare", type: .chrome, size: .m, accessibilityTitle: "Поделиться", action: share)
            PlusButton(icon: "iconMore", type: .chrome, size: .m, accessibilityTitle: "Ещё") {
                ActionSheetState.shared.present(CollectionItemSheet.content(
                    for: collectionItem, shelf: nil, collection: collection,
                    navigation: navigation, actionBar: actionBar
                ))
            }
        }
    }

    // MARK: Лента обложек

    private var coverRow: some View {
        let step = Layout.step
        return ScrollView(.horizontal) {
            HStack(spacing: 0) {
                ForEach(BookVersion.allCases, id: \.self) { item in
                    Button {
                        guard item != page else { return }
                        withAnimation(BookScreenMotion.step) { page = item }
                    } label: {
                        cover(for: item)
                            .compositingGroup()
                            .shadow(
                                color: .black.opacity(Layout.shadowOpacity),
                                radius: Layout.shadowRadius,
                                y: Layout.shadowY
                            )
                            .frame(width: step, height: Layout.coverHeight)
                            .contentShape(.rect)
                    }
                    .buttonStyle(PressScaleButtonStyle(pressedScale: PressMotion.cardScale))
                    .modifier(BookVersionMotion(version: item, step: step, reduceMotion: reduceMotion))
                    // Главная — над соседкой: обложки в ленте заходят друг на друга.
                    .zIndex(item == version ? 1 : 0)
                    .id(item)
                    .accessibilityLabel(item == .text ? "Книга" : "Аудиокнига")
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned(limitBehavior: .alwaysByOne))
        .contentMargins(.horizontal, (PlusMetrics.screenWidth - step) / 2, for: .scrollContent)
        // `.leading` при симметричных полях центрирует точно (грабли в CLAUDE.md).
        .scrollPosition(id: $page, anchor: .leading)
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .frame(height: Layout.coverHeight)
        .padding(.vertical, Layout.coverRowPad)
        // Версия меняется на середине шага: номер ближайшей обложки, а не дробный сдвиг, —
        // действие срабатывает раз за переход, а не на каждом кадре.
        .onScrollGeometryChange(for: Int.self) { geometry in
            let position = (geometry.contentOffset.x + geometry.contentInsets.leading) / step
            return min(max(Int(position.rounded()), 0), BookVersion.allCases.count - 1)
        } action: { old, new in
            guard old != new, let next = BookVersion(rawValue: new) else { return }
            HomeInteractionHaptics.carouselStep()
            withAnimation(BookScreenMotion.swap) { version = next }
        }
    }

    @ViewBuilder
    private func cover(for item: BookVersion) -> some View {
        let geometry = BookFigureGeometry(coverHeight: Layout.coverHeight)
        switch item {
        case .text:
            ZStack {
                if let aspect = coverAspect {
                    BookFigure(geometry: geometry, coverWidth: geometry.coverWidth(aspect: aspect)) {
                        SkeletonArtwork(source: entity.artwork)
                    }
                    .transition(.opacity)
                } else {
                    BookFigure(geometry: geometry, coverWidth: geometry.coverWidth(aspect: nil)) { EmptyView() }
                        .coverArtworkMissing(true)
                        .transition(.opacity)
                }
            }
        case .audio:
            AudiobookFigure(geometry: geometry) {
                ZStack {
                    switch audio.state {
                    case .loading:
                        Color.clear
                    case .found(let found):
                        SkeletonArtwork(source: found.cover).transition(.opacity)
                    case .mock:
                        SkeletonArtwork(source: entity.artwork).transition(.opacity)
                    }
                }
            }
        }
    }

    // MARK: Название

    private var titleBlock: some View {
        VStack(spacing: Layout.titleGap) {
            Text(entity.title)
                .plusHeadline(.s)
                .foregroundStyle(Color.fillOne)
                .multilineTextAlignment(.center)
            if let author {
                Text(author)
                    .plusText(.textM, .medium)
                    .foregroundStyle(Color.fillSix)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Layout.textPad)
        .padding(.horizontal, Layout.sideInset)
    }

    // MARK: Смена версии

    /// Содержимое версии — на месте прежнего, блюром (`.blurReplace`): поддерево
    /// пересоздаётся по версии, высота доезжает той же кривой.
    private func swapping<Content: View>(@ViewBuilder _ content: @escaping (BookVersion) -> Content) -> some View {
        ZStack(alignment: .top) {
            content(version)
                .id(version)
                .transition(reduceMotion ? AnyTransition.opacity : AnyTransition(.blurReplace))
        }
        .frame(maxWidth: .infinity)
        .animation(BookScreenMotion.swap, value: version)
    }

    // MARK: Счётчики

    private struct Stat: Hashable {
        let value: String
        let label: String
    }

    private func statsList(for item: BookVersion) -> [Stat] {
        switch item {
        case .text:
            return [
                Stat(value: "\(text.pageCount ?? facts.pages)", label: "Страницы"),
                Stat(value: Self.count(facts.readers), label: "Читатели"),
            ]
        case .audio:
            var hours = facts.hours
            if case .found(let found) = audio.state, let real = found.hours { hours = real }
            return [
                Stat(value: Self.hoursFormat.string(from: NSNumber(value: hours)) ?? "", label: "Часов"),
                Stat(value: Self.count(facts.listens), label: "Прослушивания"),
            ]
        }
    }

    private static let hoursFormat: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        return formatter
    }()

    private func statsReady(for item: BookVersion) -> Bool {
        item == .text ? text.isReady : audio.state != .loading
    }

    /// «12,4 тыс.» — тысячи с одной цифрой после запятой, «,0» не пишем.
    private static func count(_ value: Int) -> String {
        guard value >= 1000 else { return "\(value)" }
        let thousands = (Double(value) / 100).rounded() / 10
        return (hoursFormat.string(from: NSNumber(value: thousands)) ?? "") + "\u{00A0}тыс."
    }

    @ViewBuilder
    private func stats(for item: BookVersion) -> some View {
        let list = statsList(for: item)
        if !list.isEmpty {
            HStack(alignment: .top, spacing: 0) {
                ForEach(list, id: \.self) { stat in
                    VStack(spacing: 0) {
                        Text(stat.value)
                            .plusText(.textL, .medium)
                            .foregroundStyle(Color.fillOne)
                        Text(stat.label)
                            .plusText(.textXS, .medium)
                            .foregroundStyle(Color.fillSix)
                    }
                    .frame(width: Layout.statWidth)
                }
            }
            .frame(maxWidth: .infinity)
            // Место держится сразу, числа проявляются, когда живые уже пришли: выдуманные
            // страницы и часы не сменяются настоящими на глазах.
            .opacity(statsReady(for: item) ? 1 : 0)
            .padding(.top, Layout.statsTop)
            .padding(.horizontal, Layout.statsSide)
        }
    }

    // MARK: Кнопки

    /// «Читать» — L, «Слушать» — XL (макет). Акцентная — кнопка выбранной версии, вторая —
    /// secondary (правка пользователя 2026-11-20); смена — той же кривой, что содержимое.
    private var buttons: some View {
        HStack(spacing: Layout.buttonsGap) {
            PlusButton("Читать", icon: "iconRead", type: version == .text ? .accent : .secondary,
                       size: .l, haptic: .inAction, action: startReading)
            PlusButton("Слушать", icon: "iconHeadphones", type: version == .audio ? .accent : .secondary,
                       size: .xl, haptic: .inAction, action: startListening)
        }
        .animation(BookScreenMotion.swap, value: version)
        .frame(maxWidth: .infinity)
        .padding(.vertical, Layout.buttonsRowPad)
        .padding(.vertical, Layout.buttonsPad)
        .padding(.horizontal, Layout.sideInset)
    }

    // MARK: Содержимое версии

    private func versionContent(for item: BookVersion) -> some View {
        VStack(spacing: 0) {
            description
            details(for: item)
            tags(for: item)
            if !editions.books.isEmpty {
                shelfSection("Другие версии книги", items: editions.books)
            }
            let together = item == .text ? readTogether : audio.related
            if !together.isEmpty {
                shelfSection(item == .text ? "С этой книгой читают" : "С этой книгой слушают", items: together)
            }
        }
    }

    // MARK: Описание

    /// Аннотация тома — у обеих версий: своей у аудиокниги Deezer не отдаёт.
    private var description: some View {
        ZStack(alignment: .topLeading) {
            if !text.isReady {
                descriptionSkeleton.transition(.opacity)
            } else if !text.annotation.isEmpty {
                VStack(alignment: .leading, spacing: Layout.paragraphGap) {
                    ForEach(Array(text.annotation.enumerated()), id: \.offset) { _, paragraph in
                        Text(paragraph)
                            .plusText(.textM, .medium)
                            .foregroundStyle(Color.fillFour)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Layout.descriptionTop)
        .padding(.horizontal, Layout.sideInset)
    }

    private var descriptionSkeleton: some View {
        GeometryReader { proxy in
            VStack(alignment: .leading, spacing: Layout.paragraphGap) {
                ForEach(Layout.skeletonParagraphs.indices, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 2 * Layout.skeletonBarInset) {
                        ForEach(Layout.skeletonParagraphs[index].indices, id: \.self) { line in
                            RoundedRectangle(cornerRadius: PlusSkeleton.textRadius, style: .continuous)
                                .fill(PlusSkeleton.fill)
                                .frame(
                                    width: proxy.size.width * Layout.skeletonParagraphs[index][line],
                                    height: Layout.skeletonBar
                                )
                        }
                    }
                    .padding(.vertical, Layout.skeletonBarInset)
                }
            }
        }
        .frame(height: descriptionSkeletonHeight)
        .accessibilityLabel("Загрузка")
    }

    private var descriptionSkeletonHeight: CGFloat {
        let lines = Layout.skeletonParagraphs.reduce(0) { $0 + $1.count }
        let gaps = Layout.skeletonParagraphs.count - 1
        return CGFloat(lines) * PlusTextSize.textM.lineHeight + CGFloat(gaps) * Layout.paragraphGap
    }

    // MARK: Детали

    private func detailRows(for item: BookVersion) -> [(label: String, value: String)] {
        switch item {
        case .text:
            return [
                ("Возраст", facts.age),
                ("Переводчик", facts.translator),
                ("Издательство", text.publisher ?? facts.publisher),
            ]
        case .audio:
            var narrator = facts.narrator
            var publisher = facts.audioPublisher
            if case .found(let found) = audio.state {
                if found.narrator != author { narrator = found.narrator }
                if let label = found.label { publisher = label }
            }
            return [
                ("Возраст", facts.age),
                ("Чтец", narrator),
                ("Переводчик", facts.translator),
                ("Издательство", publisher),
            ]
        }
    }

    @ViewBuilder
    private func details(for item: BookVersion) -> some View {
        let rows = detailRows(for: item)
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: Layout.detailsGap) {
                sectionHeader("Детали")
                VStack(alignment: .leading, spacing: Layout.detailsRowGap) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                        if index > 0 {
                            Rectangle().fill(Color.fillNine).frame(height: 1)
                        }
                        HStack(alignment: .top, spacing: 0) {
                            Text(row.label)
                                .plusText(.textM, .medium)
                                .foregroundStyle(Color.fillOne)
                                .frame(width: Layout.detailsLabelWidth, alignment: .leading)
                            Text(row.value)
                                .plusText(.textM, .medium)
                                .foregroundStyle(Color.fillOne)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(.horizontal, Layout.sideInset)
            }
            .padding(.vertical, Layout.detailsPad)
        }
    }

    // MARK: Теги

    private func tagList(for item: BookVersion) -> [String] {
        facts.tags(real: BookCategoryCopy.tags(from: text.categories), extra: item == .audio ? ["Аудио"] : [])
    }

    @ViewBuilder
    private func tags(for item: BookVersion) -> some View {
        let list = tagList(for: item)
        if !list.isEmpty {
            BookTagsLayout(horizontal: Layout.tagsHGap, vertical: Layout.tagsVGap) {
                ForEach(list, id: \.self) { tag in
                    PlusButtonLabel(type: .secondary, size: .s, title: Text(tag), icon: EmptyView())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, Layout.tagsPad)
            .padding(.horizontal, Layout.sideInset)
        }
    }

    // MARK: Карусели

    /// «С этой книгой читают» — другие книги автора (`AuthorBooksStore`).
    private var readTogether: [BookShelfItem] {
        shelf.books.map { book in
            BookShelfItem(
                id: "gb-\(book.id)",
                title: book.title,
                subtitle: author ?? "",
                cover: book.cover,
                aspect: book.aspect,
                isAudiobook: false
            )
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack(spacing: Layout.sectionTitleGap) {
            Text(title)
                .plusHeadline(.s)
                .foregroundStyle(Color.fillOne)
                .lineLimit(1)
            Image("iconDropleft")
                .renderingMode(.template)
                .resizable()
                .frame(width: Layout.sectionChevronBox, height: Layout.sectionChevronBox)
                .scaleEffect(x: -1)
                .foregroundStyle(Color.fillSubtitle)
                .offset(y: PlusMetrics.headerChevronDrop)
        }
        .frame(height: Layout.sectionHeaderLine)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityAddTraits(.isHeader)
        .padding(.top, Layout.sectionHeaderTop)
        .padding(.bottom, Layout.sectionHeaderBottom)
        .padding(.horizontal, Layout.sideInset)
    }

    private func shelfSection(_ title: String, items: [BookShelfItem]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(title)
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: Layout.shelfGap) {
                    ForEach(items) { item in
                        Button { navigation.open(item.route) } label: {
                            shelfCover(item)
                        }
                        .buttonStyle(PressScaleButtonStyle(pressedScale: PressMotion.cardScale))
                        .accessibilityLabel(item.title)
                    }
                }
            }
            .scrollIndicators(.hidden)
            .contentMargins(.horizontal, Layout.sideInset, for: .scrollContent)
            .frame(height: Layout.shelfHeight)
        }
        .padding(.vertical, Layout.sectionPad)
        .transition(.opacity)
    }

    @ViewBuilder
    private func shelfCover(_ item: BookShelfItem) -> some View {
        let geometry = BookFigureGeometry(coverHeight: Layout.shelfHeight)
        if item.isAudiobook {
            AudiobookFigure(geometry: geometry) { SkeletonArtwork(source: .remote(item.cover)) }
        } else {
            BookFigure(geometry: geometry, coverWidth: geometry.coverWidth(aspect: item.aspect)) {
                SkeletonArtwork(source: .remote(item.cover))
            }
        }
    }

    // MARK: Автор и загрузки

    /// Из поиска книга приходит с автором, с витрины — без: тогда он из API.
    private var author: String? {
        entity.subtitle.isEmpty ? text.author : entity.subtitle
    }

    /// Когда грузить то, что ищется по автору: автор известен — его имя; описание
    /// пришло, а автора нет — пустая строка; иначе ждём (`nil`).
    private var authorKey: String? {
        if let author, !author.isEmpty { return author }
        return text.isReady ? "" : nil
    }

    private func loadByAuthor() async {
        guard let key = authorKey else { return }
        let volumeID = BookTextStore.volumeID(for: entity.id)
        await withTaskGroup(of: Void.self) { group in
            group.addTask { @MainActor in
                await audio.load(title: entity.title, author: key.isEmpty ? nil : key)
            }
            group.addTask { @MainActor in
                guard let volumeID, !key.isEmpty else { return shelf.markEmpty() }
                await shelf.load(author: key, excludingVolume: volumeID, title: entity.title)
            }
            group.addTask { @MainActor in
                guard let volumeID, !key.isEmpty else { return editions.markEmpty() }
                await editions.load(title: entity.title, author: key, excludingVolume: volumeID)
            }
        }
    }

    // MARK: Действия

    private var collectionItem: CollectionItem {
        .book(
            EntityRef(id: entity.id, title: entity.title, subtitle: author ?? entity.subtitle, artwork: entity.artwork),
            aspect: coverAspect ?? nil
        )
    }

    private func share() {
        ShareState.shared.present(.book(
            title: entity.title,
            author: author ?? "",
            cover: entity.artwork,
            aspect: coverAspect ?? nil
        ))
    }

    /// «Читать» открывает читалку и кладёт книгу в бар (правка пользователя 2026-08-28).
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

    /// «Слушать» включает аудиоверсию в музыкальном плеере: главы — очередью, с первой.
    /// Пока главы едут — альбом одной записью; у моковой версии — превью, найденное
    /// по названию и автору книги.
    private func startListening() {
        UIImpactFeedbackGenerator(style: .medium)
            .impactOccurred(intensity: ShowcaseMotion.tapHapticIntensity)
        if page != .audio {
            withAnimation(BookScreenMotion.step) { page = .audio }
        }
        switch audio.state {
        case .found(let found):
            if let first = audio.chapters.first {
                actionBar.open(.music(first), queue: audio.chapters)
            } else {
                actionBar.open(.music(MusicNowPlaying(
                    id: "dz-\(found.albumID)",
                    cover: found.cover,
                    title: found.title,
                    artist: found.narrator,
                    containerID: "album:dz-\(found.albumID)"
                )))
            }
        case .loading, .mock:
            actionBar.open(.music(MusicNowPlaying(
                id: "book-audio-\(entity.id)",
                cover: entity.artwork,
                title: entity.title,
                artist: author ?? ""
            )))
        }
    }
}

// MARK: - Движение ленты

/// Масштаб, наклон и опускание обложки — от её места в ленте, кадр в кадр, как
/// у промо «Главной» (`PromoCardMotion`): smoothstep от доли шага, наклон к центру
/// со знаком стороны, без стейта. Объём — тот же, что у промо (`PromoDepthMotion`,
/// включён по умолчанию с #37): соседка повёрнута к центру вокруг вертикали и откинута
/// назад, центральная плоская. Переключатель — общий с промо (девменю «Главной»);
/// с «уменьшением движения» объёма нет.
private struct BookVersionMotion: ViewModifier {
    let version: BookVersion
    let step: CGFloat
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        let sideScale = version == .text ? BookScreenLayout.bookSideScale : BookScreenLayout.audioSideScale
        let drop = version == .text ? BookScreenLayout.bookSideDrop : BookScreenLayout.audioSideDrop
        let leftShift = BookScreenLayout.bookSideShift
        let tilt = reduceMotion ? 0 : BookScreenLayout.sideTilt
        let depth = HomePresentationSettings.shared.promoDepthEnabled && !reduceMotion
        return content.visualEffect { content, proxy in
            let position = ShowcasePromoLayout.position(of: proxy, step: step)
            let distance = ShowcasePromoLayout.ease(abs(position))
            let side: CGFloat = position < 0 ? -1 : 1
            return content
                .scaleEffect(1 + (sideScale - 1) * distance)
                .rotationEffect(.degrees(tilt * Double(distance * side)))
                .rotation3DEffect(
                    .degrees(depth ? -PromoDepthMotion.yaw * Double(PromoDepthMotion.swing(position)) : 0),
                    axis: (x: 0, y: 1, z: 0), perspective: PromoDepthMotion.perspective
                )
                .rotation3DEffect(
                    .degrees(depth ? PromoDepthMotion.pitch * Double(distance) : 0),
                    axis: (x: 1, y: 0, z: 0), perspective: PromoDepthMotion.perspective
                )
                .offset(x: position < 0 ? leftShift * distance : 0, y: drop * distance)
        }
    }
}

// MARK: - Теги

/// Теги в строку с переносом: зазоры по горизонтали и вертикали свои (макет: 4 и 6).
private struct BookTagsLayout: Layout {
    let horizontal: CGFloat
    let vertical: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrangement(width: proposal.width ?? .infinity, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let frames = arrangement(width: bounds.width, subviews: subviews).frames
        for (subview, frame) in zip(subviews, frames) {
            subview.place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                          anchor: .topLeading, proposal: ProposedViewSize(frame.size))
        }
    }

    private func arrangement(width: CGFloat, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        var x: CGFloat = 0
        var y: CGFloat = 0
        var row: CGFloat = 0
        var used: CGFloat = 0
        var frames: [CGRect] = []
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += row + vertical
                row = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            used = max(used, x + size.width)
            x += size.width + horizontal
            row = max(row, size.height)
        }
        return (CGSize(width: width.isFinite ? width : used, height: y + row), frames)
    }
}

/// Рубрики Google Books — по-русски. Приходят по-английски через « / » («Fiction /
/// Classics»): каждая часть переводится словарём, непереведённую английскую не
/// показываем, кириллицу — как есть.
enum BookCategoryCopy {
    private static let dictionary: [String: String] = [
        "fiction": "Художественная литература",
        "classics": "Классика",
        "action & adventure": "Приключения",
        "adventure": "Приключения",
        "historical": "Историческая проза",
        "history": "История",
        "biography & autobiography": "Биографии",
        "science fiction": "Фантастика",
        "fantasy": "Фэнтези",
        "romance": "Любовный роман",
        "mystery & detective": "Детективы",
        "thrillers": "Триллеры",
        "poetry": "Поэзия",
        "drama": "Драматургия",
        "philosophy": "Философия",
        "psychology": "Психология",
        "juvenile fiction": "Детская литература",
        "literary criticism": "Литературоведение",
        "literary": "Современная проза",
        "science": "Наука",
        "business & economics": "Бизнес",
        "self-help": "Саморазвитие",
        "religion": "Религия",
        "humor": "Юмор",
        "russia": "Русская литература",
        "russian": "Русская литература",
        "french": "Французская литература",
    ]

    static func tags(from categories: [String]) -> [String] {
        var seen: Set<String> = []
        return categories
            .flatMap { $0.components(separatedBy: "/") }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .compactMap { part -> String? in
                guard !part.isEmpty else { return nil }
                if part.range(of: "\\p{Cyrillic}", options: .regularExpression) != nil { return part }
                return dictionary[part.lowercased()]
            }
            .filter { seen.insert($0).inserted }
    }
}
