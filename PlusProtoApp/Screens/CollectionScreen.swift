import SwiftUI
import UIKit

/// Числа коллекции «Моё» — макет `2837:33529` (2026-10-19; прежде `2351:17327`). Кадр
/// макета 375: четыре целые карточки 76 и торчащий край пятой 24 (правка пользователя
/// 2026-10-19). На другой ширине целых по-прежнему четыре и край тот же (`CarouselFit`):
/// растёт карточка, а с ней — обложки и высоты лент (правило 4 CLAUDE.md).
enum CollectionLayout {
    /// Лента — сразу под навигацией: контент на y 101 при высоте `top` 100
    static let contentTop: CGFloat = ServiceTopNavLayout.rowHeight + 1
    /// Воздух под последней секцией сверх клиренса хрома
    static let feedBottom: CGFloat = 16
    /// Между секциями — вплотную: воздух даёт поле 16 над заголовком (правка
    /// пользователя 2026-10-04 — «минус 8 между всеми блоками»; в макете было 8)
    static let sectionGap: CGFloat = 0
    static let side: CGFloat = 16
    static let cardGap: CGFloat = 8
    /// Секция — поля 8 сверху и снизу (`carousel / Music / xsmall cards`), шапка
    /// 52 = 16 + 24 + 12: строка заголовка — Headline S при 100 %
    static let sectionPad: CGFloat = 8
    static var headerLine: CGFloat { PlusHeadline.s.lineHeight }
    /// Подпись — 6 под обложкой, Text S
    static let captionGap: CGFloat = 6
    static var captionLine: CGFloat { PlusTextSize.textS.lineHeight }
    /// Подпись под альбомом — с полем 8 справа (`card / text` макета); у исполнителя — без
    static let albumCaptionTrailing: CGFloat = 8

    /// Карточки на 375 — 76: постер 2:3 (76 × 114), квадрат альбома и плейлиста, круг
    /// исполнителя. Целых — 4, торчащий край пятой — 24 (инвариант на любой ширине).
    static let peek: CGFloat = 24
    static let carousel = CarouselFit(
        designCard: (PlusMetrics.designWidth - side - peek - 4 * cardGap) / 4,
        whole: 4,
        side: side,
        gap: cardGap
    )
    @MainActor static var cardWidth: CGFloat { carousel.cardWidth }
    @MainActor static var posterHeight: CGFloat { cardWidth * 3 / 2 }
    /// Радиус — токен карточки, от ширины не зависит
    static let cardRadius: CGFloat = 8
    /// Книга — карточка книги (`card / book`) высотой постера (114 на 375, ступень
    /// xsmall ДС); ширина — от пропорций обложки, поэтому у книг край пятой не постоянный.
    @MainActor static var book: BookFigureGeometry {
        BookFigureGeometry(coverHeight: posterHeight)
    }

    /// Название карточки — до двух строк, деталь (год, автор, исполнитель) — в одну
    /// (правка пользователя 2026-10-04)
    static let titleLines = 2
    /// Высоты лент — карточка с подписью на пределе строк: у альбомов и исполнителей —
    /// название до двух строк, у плейлистов, кино и книг подписей нет — лента ровно
    /// в обложку (макет `2837:33529`).
    @MainActor static var posterRowHeight: CGFloat { posterHeight }
    @MainActor static var bookRowHeight: CGFloat { book.frameSize(coverWidth: 0).height }
    @MainActor static var coverRowHeight: CGFloat { cardWidth }

    /// Лента вертикальных карточек — с местом под полосу прогресса, если в ней есть
    /// начатое (`CardProgressBar`); без начатого высота прежняя.
    static func rowHeight(_ base: CGFloat, progress: [Double?]) -> CGFloat {
        base + (progress.contains { $0 != nil } ? CardProgressBar.footprint : 0)
    }

    /// «Смотреть дальше» экрана «Кино» — горизонтальные карточки витрины Кинопоиска,
    /// две целые и край третьей 24 (правка пользователя 2026-10-20)
    static let historyFit = CarouselFit(
        designCard: (PlusMetrics.designWidth - side - peek - 2 * cardGap) / 2,
        whole: 2,
        side: side,
        gap: cardGap
    )
    /// Подпись — шрифт UI kit, от ширины не масштабируется: растёт только обложка.
    @MainActor static var titleOnlyRowHeight: CGFloat { cardWidth + captionGap + 2 * captionLine }

    /// Треки — колонки по три строки (`track stack`), строка — обложка 48 r6 и поля 8
    /// между строками. Колонка с собственными полями 16 по бокам: следующая начинается
    /// на `ширина + 16`, и её обложка выглядывает из-под правого края на
    /// `trackColumnPeek` (24; было 335 → выглядывало 51) — ширина = экран − peek − поле,
    /// от ширины экрана: следующая колонка выглядывает на 24 на любой ширине.
    @MainActor static var trackColumnWidth: CGFloat {
        PlusGrid.columnWidth(side: side, peek: EntitySectionLayout.trackColumnPeek)
    }
    static let tracksPerColumn = 3
    static let trackCover: CGFloat = 48
    static let trackCoverRadius: CGFloat = 6
    static let trackRowGap: CGFloat = 8
    static let trackTextGap: CGFloat = 12
    static let trackControlsGap: CGFloat = 8
    static let downloadIcon: CGFloat = 16
    static var tracksHeight: CGFloat {
        CGFloat(tracksPerColumn) * trackCover + CGFloat(tracksPerColumn - 1) * 2 * trackRowGap
    }
    /// Шапка треков (`carousel / Music / opened playlist`): кнопка 40, названия 24 + 20,
    /// поля 16 сверху и 12 снизу; блок — с полями секции 8 сверху и снизу
    static let tracksHeaderTop: CGFloat = 16
    static let tracksHeaderBottom: CGFloat = 12
    static let tracksHeaderGap: CGFloat = 12
    static let playButton = PlusButtonSize.m
    /// Микрошейдер под «play» шапки треков — 64, от кромки кнопки на −10 по горизонтали,
    /// по центру шапки по вертикали
    static let tracksShader: CGFloat = 64
    static let tracksShaderLeading: CGFloat = -10

    /// Разделитель строк треков — Fill/Eight, 0.5
    static let divider = Color.fillEight
    /// «Ещё» у строки трека — белый 60 %
    static let more = Color.fillFive
}

enum CollectionMotion {
    /// Отмеченное или снятое встаёт и уходит в карусели плавно
    static let itemsChange: Animation = .smooth(duration: 0.35)
}

/// Коллекция «Моё» — содержимое пятого таба (макет `2351:17327`, задача пользователя
/// 2026-10-04): общая для кино, книг и музыки. Сверху — общая навигация сервисов
/// с полками «Любимое» и «Скачанное», ниже — секции по видам: кино, книги, треки
/// колонками, исполнители, альбомы, плейлисты. Пустая секция не показывается, пустая
/// полка — подсказкой.
///
/// Данные — `CollectionStore`: отмечают их сердца, «Позже» и «Скачать» по всему
/// приложению, и коллекция меняется на лету. Шеврон секции открывает её полным списком.
struct CollectionScreen: View {
    @Environment(CollectionStore.self) private var collection
    @Environment(AppNavigationState.self) private var navigation
    @Environment(ActionBarState.self) private var actionBar
    @Environment(\.scenePhase) private var scenePhase
    /// Заставка ушла и хром на месте — тот же признак, что у вступления промо «Главной»:
    /// подсказка порядка под заставкой отыграла бы появление невидимой.
    @Environment(\.promoIntroReady) private var introReady

    /// Выбранная полка — ею подсвечена пилюля, сразу по тапу.
    @State private var shelfIndex = 0
    /// Показанная полка — догоняет выбранную, когда старая погасла: по ней контент,
    /// виды, кнопка порядка и режим порядка.
    @State private var shownShelf: CollectionStore.Shelf = .favorites
    @State private var feedOpacity: Double = 1
    @State private var shelfSwap: Task<Void, Never>?
    /// Где оставили каждую полку (вертикаль, 0 — верх ленты). Пишется в момент подмены,
    /// не покадрово; живёт, пока экран смонтирован.
    @State private var shelfOffsets: [CollectionStore.Shelf: CGFloat] = [:]
    @State private var scrollOffset: CGFloat = 0
    @State private var scrollPosition = ScrollPosition(edge: .top)
    /// Режим «изменить порядок»: рабочий порядок, захват и сдвиги блока — одним объектом,
    /// чтобы палец, двигающий блок, перерисовывал только этот блок, а не весь экран.
    @State private var reorder = CollectionReorderState()

    /// Виды полки, в которых есть записи, — в порядке пользователя. В режиме порядка —
    /// в рабочем (`draftOrder`): он меняется на глазах, а в хранилище уходит по «Готово».
    private func visibleKinds(_ shelf: CollectionStore.Shelf) -> [CollectionItem.Kind] {
        let order = reorder.isReordering && reorder.shelf == shelf
            ? reorder.draftOrder
            : collection.kindsOrder(on: shelf)
        return order.filter { count($0, on: shelf) > 0 }
    }

    /// «Кино» и «Книги» «Любимого» — лайкнутое вперемешку с начатым (`CollectionMix`);
    /// у остальных видов и в «Скачанном» — `nil`, там записи полки как есть.
    private func mix(_ kind: CollectionItem.Kind, on shelf: CollectionStore.Shelf) -> [CollectionMixEntry]? {
        guard shelf == .favorites else { return nil }
        switch kind {
        case .movie: return CollectionMix.movies(collection, history: actionBar.watchHistory)
        case .book: return CollectionMix.books(collection, reading: actionBar.readingHistory)
        default: return nil
        }
    }

    private func count(_ kind: CollectionItem.Kind, on shelf: CollectionStore.Shelf) -> Int {
        // Плейлисты «Любимого» — и свои: карточка «Мои плейлисты» есть, даже если
        // любимых нет.
        let own = kind == .playlist && shelf == .favorites ? MyPlaylists.all.count : 0
        return (mix(kind, on: shelf)?.count ?? collection.items(kind, on: shelf).count) + own
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.surfaceOne.ignoresSafeArea()

            // Лента одна на обе полки — меняется только её содержимое. Пока у каждой
            // полки была своя, на смене обе разом докладывали свой сдвиг, и подложка
            // навигации моргала (жалоба пользователя 2026-10-04).
            ScrollView {
                shelfContent(shownShelf)
                    .id(shownShelf)
                    .opacity(feedOpacity)
                    .padding(.bottom, CollectionLayout.feedBottom)
            }
            .scrollIndicators(.hidden)
            // Блок в руке — лента стоит: палец двигает блок, а не прокручивает её.
            .scrollDisabled(reorder.heldKind != nil)
            .contentMargins(.top, CollectionLayout.contentTop, for: .scrollContent)
            .scrollPosition($scrollPosition)
            .trackNavBarScroll(into: $scrollOffset)
        }
        .overlay(alignment: .top) {
            ServiceTopNav(
                filters: CollectionStore.Shelf.allCases.map(\.title),
                selection: $shelfIndex,
                scrollOffset: scrollOffset,
                // «Моё» — не витрина: затемнения сверху нет (затемнение — у витрин, 2026-10-10).
                showsTopShade: false,
                // Блок в руке поднимается под навбар — подложка держится, даже когда лента
                // стоит у верха (автопрокрутка докатывает её туда) и скролл подложки не даёт.
                holdsBackdrop: reorder.heldKind != nil,
                trailingAccessory: AnyView(
                    CollectionReorderButton(
                        isEnabled: reorder.isReordering || canReorder,
                        action: toggleReordering
                    )
                )
            )
        }
        .environment(reorder)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: CollectionListRoute.self) { route in
            // Слои поиска — и на пуше, как у экранов сущностей: поиск, открытый
            // со списка, обязан лечь поверх него.
            SearchLayers(host: .pushed) {
                CollectionListScreen(route: route)
            }
            .ignoresSafeArea(.keyboard)
        }
        .navigationDestination(for: CollectionServiceRoute.self) { route in
            SearchLayers(host: .pushed) {
                CollectionServiceScreen(route: route)
            }
            .ignoresSafeArea(.keyboard)
        }
        .navigationDestination(for: CollectionTracksRoute.self) { route in
            SearchLayers(host: .pushed) {
                CollectionTracksScreen(route: route)
            }
            .ignoresSafeArea(.keyboard)
        }
        .navigationDestination(for: SeriesDownloadsRoute.self) { route in
            SearchLayers(host: .pushed) {
                SeriesDownloadsScreen(route: route)
            }
            .ignoresSafeArea(.keyboard)
        }
        .onChange(of: shelfIndex) {
            // Полку сменили посреди редактирования — порядок прежней сохраняется, режим
            // выключается: у новой полки свой порядок и своё «изменить».
            finishReordering()
            swapShelf(to: CollectionStore.Shelf(rawValue: shelfIndex) ?? .favorites)
        }
        // Уход с экрана (другой таб, пуш) и фон приложения выключают режим и сохраняют
        // порядок: перестановка уже сделана на глазах, терять её молча — хуже.
        // Подсказка порядка уходит вместе с экраном: показ уже засчитан.
        .onDisappear {
            finishReordering()
            CollectionReorderHint.shared.dismissInstantly()
        }
        // Подсказка порядка — при первом входе, когда переставлять есть что и заставка
        // ушла (запуск сразу на «Моё»); блоков стало меньше двух — кнопка приглушена,
        // и подсказка уходит.
        .task(id: [canReorder, introReady]) {
            let hint = CollectionReorderHint.shared
            guard canReorder else {
                hint.dismiss()
                return
            }
            guard introReady, hint.isDue else { return }
            try? await Task.sleep(for: CollectionReorderHintMotion.delay)
            guard !Task.isCancelled, !reorder.isReordering else { return }
            hint.present()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { finishReordering() }
        }
        // Повторный тап по табу на корне — к началу ленты, как на витринах.
        .onChange(of: navigation.scrollToTopRequests[.collection]) {
            withAnimation(ShowcaseScrollMotion.toTop) { scrollPosition.scrollTo(edge: .top) }
        }
        #if DEBUG
        // `-debugCollectionList <movie|book|track|artist|album|playlist>` — через 1.5 с
        // открыть то, что открывает заголовок карусели этого вида (тем же путём): тапнуть
        // заголовок из шелла нечем. `myPlaylists` — то, что открывает карточка
        // «Мои плейлисты».
        // Один раз за процесс: на возврате корень появляется снова, и задача
        // открыла бы список опять.
        .task {
            guard !Self.didDebugOpenList,
                  let raw = UserDefaults.standard.string(forKey: "debugCollectionList") else { return }
            let kind = CollectionItem.Kind(rawValue: raw)
            guard kind != nil || raw == "myPlaylists" else { return }
            Self.didDebugOpenList = true
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            if let kind {
                CollectionSectionNavigation.open(kind, on: shownShelf, navigation: navigation)
            } else {
                CollectionSectionNavigation.openMyPlaylists(on: shownShelf, navigation: navigation)
            }
        }
        // `-debugCollectionSheet <вид>` — через 1.5 с шторка записи тем же кодом, что
        // долгое нажатие: первая запись вида в «Любимом» (`movie` — в «Скачанном»).
        // Тапнуть из шелла нечем. Один раз за процесс.
        .task {
            guard !Self.didDebugSheet,
                  let raw = UserDefaults.standard.string(forKey: "debugCollectionSheet"),
                  let kind = CollectionItem.Kind(rawValue: raw) else { return }
            Self.didDebugSheet = true
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            let shelf: CollectionStore.Shelf = kind == .movie ? .downloads : .favorites
            guard let item = collection.items(kind, on: shelf).first else { return }
            ActionSheetState.shared.present(CollectionItemSheet.content(
                for: item, shelf: shelf, collection: collection, navigation: navigation, actionBar: actionBar
            ))
        }
        // `-debugCollectionReorder 1` — через 2 с войти в режим порядка (как кнопка
        // в навбаре), через 4 с поставить первый блок на второе место (тот же свап, что
        // у драга), через 6 с — «Готово». Один раз за процесс.
        .task {
            guard !Self.didDebugReorder,
                  UserDefaults.standard.bool(forKey: "debugCollectionReorder") else { return }
            Self.didDebugReorder = true
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            toggleReordering()
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            reorder.swapBlocks(0, 1)
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            toggleReordering()
        }
        // `-debugCollectionOpen <вид>` — через 2 с после ухода заставки открыть экран первой
        // записи вида в «Любимом» тем же путём, что тап по карточке (`navigation.open`):
        // с её обложки идёт зум. Пара к `-debugCloseEntity` — проверка возврата подписи.
        // Один раз за процесс.
        .task(id: introReady) {
            guard introReady, !Self.didDebugOpen,
                  let raw = UserDefaults.standard.string(forKey: "debugCollectionOpen"),
                  let kind = CollectionItem.Kind(rawValue: raw) else { return }
            Self.didDebugOpen = true
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled,
                  let route = collection.items(kind, on: .favorites).first?.route else { return }
            navigation.open(route)
        }
        // `-debugReorderHintTap 1` — через 2 с после появления подсказки порядка тап по ней
        // тем же кодом, что настоящий (вход в режим порядка): проверка ухода. Показ —
        // вместе с `-collectionReorderHintEverySession YES`. Один раз за процесс.
        .task {
            guard !Self.didDebugHintTap,
                  UserDefaults.standard.bool(forKey: "debugReorderHintTap") else { return }
            Self.didDebugHintTap = true
            // Подсказка ждёт ухода заставки — ждём и мы, до 20 с.
            for _ in 0..<200 where CollectionReorderHint.shared.phase != .shown {
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else { return }
            }
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled, CollectionReorderHint.shared.phase == .shown else { return }
            toggleReordering()
        }
        // `-debugCollectionShelf <pt>` — через 1.5 с прокрутить «Любимое» на <pt>, через
        // 3.5 с выбрать «Скачанное», через 6 с — снова «Любимое» (выбор — тем же путём,
        // что тап). Строки `[shelf] save/restore/actual …` — в лог. Один раз за процесс.
        .task {
            guard !Self.didDebugShelf,
                  UserDefaults.standard.object(forKey: "debugCollectionShelf") != nil else { return }
            Self.didDebugShelf = true
            let target = CGFloat(UserDefaults.standard.double(forKey: "debugCollectionShelf"))
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            var instant = Transaction()
            instant.disablesAnimations = true
            withTransaction(instant) { scrollPosition.scrollTo(y: target) }
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            withAnimation(ServiceTopNavMotion.select) { shelfIndex = CollectionStore.Shelf.downloads.rawValue }
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            withAnimation(ServiceTopNavMotion.select) { shelfIndex = CollectionStore.Shelf.favorites.rawValue }
        }
        #endif
    }

    #if DEBUG
    private static var didDebugOpenList = false
    private static var didDebugReorder = false
    private static var didDebugSheet = false
    private static var didDebugShelf = false
    private static var didDebugHintTap = false
    private static var didDebugOpen = false
    /// `-debugCollectionShelf <pt>` включает и строки `[shelf] …` в лог.
    private static let tracesShelf = UserDefaults.standard.object(forKey: "debugCollectionShelf") != nil
    #endif

    // MARK: Смена полки

    /// У каждой полки своя позиция скролла, а смена — последовательная, как у полных
    /// списков (`CollectionListScreen.swapList`): старая гаснет, в паузе подменяется
    /// и встаёт туда, где её оставили, новая проявляется. Позиция уходящей пишется в момент
    /// подмены, не покадрово. Быстрые тапы подряд прерывают незаконченную смену: показана
    /// всегда последняя выбранная.
    private func swapShelf(to selected: CollectionStore.Shelf) {
        shelfSwap?.cancel()
        guard selected != shownShelf else {
            withAnimation(CollectionListMotion.fadeIn) { feedOpacity = 1 }
            return
        }
        shelfSwap = Task { @MainActor in
            withAnimation(CollectionListMotion.fadeOut) { feedOpacity = 0 }
            try? await Task.sleep(for: CollectionListMotion.fadeOutDuration)
            guard !Task.isCancelled else { return }
            let leaving = shownShelf
            shelfOffsets[leaving] = scrollOffset
            let saved = shelfOffsets[selected] ?? 0
            #if DEBUG
            if Self.tracesShelf {
                NSLog("[shelf] save %@=%.1f", String(describing: leaving), scrollOffset)
                NSLog("[shelf] restore %@ target=%.1f", String(describing: selected), saved)
            }
            #endif
            var instant = Transaction()
            instant.disablesAnimations = true
            withTransaction(instant) {
                shownShelf = selected
                if saved > 0.5 {
                    scrollPosition.scrollTo(y: saved)
                } else {
                    scrollPosition.scrollTo(edge: .top)
                }
            }
            withAnimation(CollectionListMotion.fadeIn) { feedOpacity = 1 }
            #if DEBUG
            if Self.tracesShelf {
                try? await Task.sleep(for: .milliseconds(400))
                NSLog("[shelf] actual %@=%.1f", String(describing: selected), scrollOffset)
            }
            #endif
        }
    }

    // MARK: Режим порядка

    /// Есть что переставлять — на полке два блока и больше.
    private var canReorder: Bool {
        visibleKinds(shownShelf).count > 1
    }

    /// Кнопка навбара (и подсказка под ней): вход в режим и «Готово» — один тап,
    /// одна хаптика. Подсказка после любого из них уходит.
    private func toggleReordering() {
        PlayerHaptics.tap()
        CollectionReorderHint.shared.dismiss()
        if reorder.isReordering {
            finishReordering()
        } else {
            reorder.start(shelf: shownShelf, order: visibleKinds(shownShelf))
        }
    }

    /// Сохранить рабочий порядок и выйти из режима. Виды, которых на полке сейчас нет
    /// (пустые), держат свои места в сохранённом порядке: видимые занимают места
    /// видимых в порядке рабочего списка.
    private func finishReordering() {
        guard reorder.isReordering, let editedShelf = reorder.shelf else { return }
        var draft = reorder.draftOrder[...]
        let merged = collection.kindsOrder(on: editedShelf).map { kind in
            reorder.draftOrder.contains(kind) ? draft.removeFirst() : kind
        }
        collection.setKindsOrder(merged, on: editedShelf)
        reorder.stop()
    }

    @ViewBuilder
    private func shelfContent(_ shelf: CollectionStore.Shelf) -> some View {
        let kinds = visibleKinds(shelf)
        if kinds.isEmpty {
            // Подсказка — по центру видимой части ленты под баннером: у пустого
            // «Скачанного» баннер тот же, что у полного (макет `18102:17240`).
            VStack(spacing: 0) {
                smartDownloadsBanner(on: shelf)
                CollectionEmptyState(shelf: shelf)
            }
            .containerRelativeFrame(.vertical) { length, _ in length - CollectionLayout.contentTop }
        } else {
            VStack(spacing: CollectionLayout.sectionGap) {
                smartDownloadsBanner(on: shelf)
                ForEach(kinds, id: \.self) { kind in
                    CollectionReorderBlock(kind: kind) {
                        section(kind, on: shelf)
                    }
                }
            }
            // Пространство жеста порядка стоит на самой ленте: оно не едет вместе
            // с блоком, и сдвиг пальца не искажается сдвигом блока под ним.
            .coordinateSpace(name: CollectionReorderState.feedSpace)
            // Анимируется состав видов; перестановку анимирует сам свап (`swapBlocks`),
            // поэтому значение — множество: порядок его не меняет.
            .animation(CollectionMotion.itemsChange, value: Set(kinds))
        }
    }

    /// Умная загрузка — первым блоком «Скачанного», и полного, и пустого (задача
    /// пользователя 2026-10-21, макеты `18292:52150`, `18102:17240`): 8 сверху, первая
    /// секция — сразу под ним, её шапка несёт своё поле 8. Закрыли — гаснет, место
    /// схлопывается, блоки поднимаются.
    @ViewBuilder
    private func smartDownloadsBanner(on shelf: CollectionStore.Shelf) -> some View {
        if shelf == .downloads, !SmartDownloads.shared.isBannerDismissed {
            SmartDownloadsBanner()
                .padding(.horizontal, CollectionLayout.side)
                .padding(.top, CollectionLayout.sectionPad)
                .transition(.opacity)
        }
    }

    @ViewBuilder
    private func section(_ kind: CollectionItem.Kind, on shelf: CollectionStore.Shelf) -> some View {
        let items = collection.items(kind, on: shelf)
        let openAll = { CollectionSectionNavigation.open(kind, on: shelf, navigation: navigation) }
        // «Кино» и «Книги» «Любимого» — лайкнутое вперемешку с начатым; в «Скачанном» —
        // записи полки, той же карточкой.
        let entries = mix(kind, on: shelf) ?? items.map { CollectionMixEntry(item: $0, date: $0.date(on: shelf) ?? .distantPast) }
        switch kind {
        case .track:
            CollectionTracksBlock(items: items, shelf: shelf, openAll: openAll)
        case .movie where shelf == .downloads:
            // «Скачанное» — горизонтальными карточками коллекции: фильм играет сразу,
            // сериал открывает свои скачанные серии (задача пользователя 2026-10-20).
            let lines = items.contains { CollectionDownloadMeta.text($0) != nil } ? 2 : 1
            CollectionCarousel(title: kind.title, height: PPMovieCard.rowHeight(.medium, lines: lines), items: items, openAll: openAll) { item in
                CollectionDownloadCard(item: item)
            }
            .task { await collection.backfillDownloadStills() }
        case .movie:
            let progress = entries.map { CollectionProgress.movie($0, history: actionBar.watchHistory) }
            CollectionCarousel(
                title: kind.title,
                height: CollectionLayout.rowHeight(CollectionLayout.posterRowHeight, progress: progress),
                items: entries,
                openAll: openAll
            ) { entry in
                CollectionPosterCard(item: entry.item, resume: entry.resume, progress: CollectionProgress.movie(entry, history: actionBar.watchHistory), shelf: shelf)
            }
        case .book:
            let progress = entries.map { CollectionProgress.book($0, reading: actionBar.readingHistory) }
            CollectionCarousel(
                title: kind.title,
                height: CollectionLayout.rowHeight(CollectionLayout.bookRowHeight, progress: progress),
                items: entries,
                openAll: openAll
            ) { entry in
                CollectionBookCard(item: entry.item, progress: CollectionProgress.book(entry, reading: actionBar.readingHistory), shelf: shelf)
            }
        case .artist:
            CollectionCarousel(title: kind.title, height: CollectionLayout.titleOnlyRowHeight, items: items, openAll: openAll) { item in
                CollectionArtistCard(item: item, shelf: shelf)
            }
        case .album:
            CollectionCarousel(title: kind.title, height: CollectionLayout.titleOnlyRowHeight, items: items, openAll: openAll) { item in
                CollectionSquareCard(item: item, showsTitle: true, shelf: shelf)
            }
        case .playlist:
            // Первой — «Мои плейлисты» (`card / playlist`, `2844:37412`): превью до четырёх
            // плейлистов полки, тап — их полный список.
            // В «Любимом» карточка показывает свои плейлисты (`MyPlaylists`), в «Скачанном» —
            // скачанные.
            let previews = shelf == .favorites ? MyPlaylists.items : items
            let cards = [CollectionPlaylistSlot.mine(Array(previews.prefix(CollectionMyPlaylistsCard.previews)))]
                + items.map(CollectionPlaylistSlot.playlist)
            CollectionCarousel(title: kind.title, height: CollectionLayout.coverRowHeight, items: cards, openAll: openAll) { card in
                switch card {
                case .mine(let previews):
                    CollectionMyPlaylistsCard(previews: previews) {
                        CollectionSectionNavigation.openMyPlaylists(on: shelf, navigation: navigation)
                    }
                case .playlist(let item):
                    CollectionSquareCard(item: item, showsTitle: false, shelf: shelf)
                }
            }
        }
    }
}

// MARK: - Секция-карусель

/// Секция карточками: заголовок 56 с шевроном — переход в полный список, ниже лента
/// с полями 16 и зазором 8 (`carousel / Movies` макета). Высота ленты — явная, из
/// размеров карточки: своей `LazyHStack` здесь не меряет (`ServiceCarousel`).
/// Общая у коллекции и её экранов «Кино» и «Книги»: там режима порядка нет, а у
/// карусели без полного списка (`openAll == nil`) нет и шеврона.
struct CollectionCarousel<Item: Identifiable, Card: View>: View {
    let title: String
    let height: CGFloat
    let items: [Item]
    var openAll: (() -> Void)?
    @ViewBuilder var card: (Item) -> Card

    @Environment(CollectionReorderState.self) private var reorder: CollectionReorderState?

    private var isReordering: Bool { reorder?.isReordering ?? false }

    /// Без полного списка шапка — не кнопка: выключенная кнопка приглушила бы заголовок.
    /// Есть ли список, у карусели не меняется — ветка не переключается.
    @ViewBuilder
    private var header: some View {
        if let openAll {
            Button(action: openAll) {
                EntitySectionHeader(title: title, isChevronCollapsed: isReordering, lineHeight: CollectionLayout.headerLine)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
        } else {
            EntitySectionHeader(title: title, showsChevron: false, lineHeight: CollectionLayout.headerLine)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            // Иконка-хват — на правом краю шапки (`2584:29425`: x 339 при поле 16, y 16),
            // шеврон на её время гаснет.
            .overlay(alignment: .topTrailing) {
                if reorder != nil {
                    // По центру строки заголовка
                    CollectionReorderGrip(isVisible: isReordering)
                        .padding(.top, EntitySectionLayout.headerTop + (CollectionLayout.headerLine - CollectionReorderGrip.size) / 2)
                        .padding(.trailing, CollectionLayout.side)
                }
            }

            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: CollectionLayout.cardGap) {
                    ForEach(items) { item in
                        card(item)
                    }
                }
                .scrollTargetLayout()
                .animation(CollectionMotion.itemsChange, value: items.map(\.id))
            }
            .scrollIndicators(.hidden)
            .scrollDisabled(isReordering)
            .scrollTargetBehavior(.viewAligned)
            .contentMargins(.horizontal, CollectionLayout.side, for: .scrollContent)
            .frame(height: height)
        }
        .padding(.vertical, CollectionLayout.sectionPad)
    }
}

// MARK: - Карточки

/// Фильм — постер 86 × 129 r8, без подписи (правка пользователя 2026-10-10): название
/// читает VoiceOver. Начатый фильм без своего экрана (моки витрины) — тап продолжает
/// просмотр, как «Смотреть дальше».
struct CollectionPosterCard: View {
    let item: CollectionItem
    var resume: MovieInProgress? = nil
    /// Начатый фильм — полоса прогресса под постером (`CardProgressBar`). Ленте —
    /// место под неё (`CollectionLayout.rowHeight`).
    var progress: Double? = nil
    /// Полка, где показан постер, — для действий записи (`nil` — «Покупки»).
    var shelf: CollectionStore.Shelf? = nil

    @Environment(AppNavigationState.self) private var navigation
    @Environment(ActionBarState.self) private var actionBar
    @Environment(\.stackZoomNamespace) private var zoom

    var body: some View {
        Button(action: open) {
            VStack(spacing: CardProgressBar.gap) {
                CollectionArtwork(
                    source: item.artwork,
                    width: CollectionLayout.cardWidth,
                    height: CollectionLayout.posterHeight,
                    shape: RoundedRectangle(cornerRadius: CollectionLayout.cardRadius, style: .continuous)
                )
                .collectionZoomSource(item.route, in: zoom)
                if let progress {
                    CardProgressBar(progress: progress)
                        .zoomSourceCaption(item.route)
                }
            }
            .frame(width: CollectionLayout.cardWidth, alignment: .top)
            .contentShape(.rect)
        }
        .buttonStyle(PressScaleButtonStyle(pressedScale: PressMotion.cardScale))
        .accessibilityLabel(item.title)
        .collectionItemActions(item, shelf: shelf)
    }

    private func open() {
        // Отпускание после долгого нажатия, открывшего шторку, — не тап.
        guard !ActionSheetState.shared.isPresented else { return }
        if let route = item.route {
            navigation.open(route)
        } else if let resume {
            UIImpactFeedbackGenerator(style: .medium)
                .impactOccurred(intensity: ShowcaseMotion.tapHapticIntensity)
            actionBar.open(.movie(resume))
        }
    }
}

/// Книга — наша проекция с обложкой 128 (`BookFigure`), без подписи (правка
/// пользователя 2026-10-10): название читает VoiceOver.
struct CollectionBookCard: View {
    let item: CollectionItem
    /// Начатая книга («Читаю»): тап — сразу читалка (правка пользователя 2026-10-20).
    var readBook: BookInProgress? = nil
    /// Прочитанная доля — полоса под книгой (`CardProgressBar`).
    var progress: Double? = nil
    /// Полка, где показана книга, — чьё «Удалить» в шторке (`nil` — «Читаю», «Прочитано»).
    var shelf: CollectionStore.Shelf? = nil

    @Environment(AppNavigationState.self) private var navigation
    @Environment(ActionBarState.self) private var actionBar
    @Environment(\.stackZoomNamespace) private var zoom

    var body: some View {
        let geometry = CollectionLayout.book
        let coverWidth = geometry.coverWidth(aspect: item.aspect)
        let width = geometry.frameSize(coverWidth: coverWidth).width
        Button(action: open) {
            VStack(spacing: CardProgressBar.gap) {
                BookFigure(geometry: geometry, coverWidth: coverWidth) {
                    if let artwork = item.artwork {
                        SkeletonArtwork(source: artwork)
                    }
                }
                .collectionZoomSource(item.route, in: zoom)
                if let progress {
                    CardProgressBar(progress: progress)
                        .zoomSourceCaption(item.route)
                }
            }
            .frame(width: width, alignment: .top)
            .contentShape(.rect)
        }
        .buttonStyle(PressScaleButtonStyle(pressedScale: PressMotion.cardScale))
        .accessibilityLabel(item.title)
        .collectionItemActions(item, shelf: shelf)
    }

    private func open() {
        // Отпускание после долгого нажатия, открывшего шторку, — не тап.
        guard !ActionSheetState.shared.isPresented else { return }
        if let readBook {
            UIImpactFeedbackGenerator(style: .medium)
                .impactOccurred(intensity: ShowcaseMotion.tapHapticIntensity)
            actionBar.open(.book(readBook))
            return
        }
        guard let route = item.route else { return }
        navigation.open(route)
    }
}

/// Альбом и плейлист — квадрат r8; у альбома под ним название до двух строк, у плейлиста
/// подписи нет (макет `2837:33529`). Открывают свои экраны; плейлист без экрана — играет.
private struct CollectionSquareCard: View {
    let item: CollectionItem
    let showsTitle: Bool
    var shelf: CollectionStore.Shelf? = nil

    @Environment(AppNavigationState.self) private var navigation
    @Environment(ActionBarState.self) private var actionBar
    @Environment(\.stackZoomNamespace) private var zoom

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: CollectionLayout.captionGap) {
                CollectionArtwork(
                    source: item.artwork,
                    width: CollectionLayout.cardWidth,
                    height: CollectionLayout.cardWidth,
                    shape: RoundedRectangle(cornerRadius: CollectionLayout.cardRadius, style: .continuous)
                )
                .collectionZoomSource(item.route, in: zoom)

                if showsTitle {
                    CollectionCaption(title: item.title)
                        .padding(.trailing, CollectionLayout.albumCaptionTrailing)
                        .zoomSourceCaption(item.route)
                }
            }
            .frame(width: CollectionLayout.cardWidth, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(PressScaleButtonStyle(pressedScale: PressMotion.cardScale))
        .collectionItemActions(item, shelf: shelf)
    }

    private func open() {
        // Отпускание после долгого нажатия, открывшего шторку, — не тап.
        guard !ActionSheetState.shared.isPresented else { return }
        if let route = item.route {
            navigation.open(route)
        } else if let playable = item.playable {
            PlayerHaptics.tap()
            actionBar.open(.music(playable))
        }
    }
}

/// Карточка ленты плейлистов: «Мои плейлисты» первой, дальше — сами плейлисты.
private enum CollectionPlaylistSlot: Identifiable {
    case mine([CollectionItem])
    case playlist(CollectionItem)

    var id: String {
        switch self {
        case .mine: "my-playlists"
        case .playlist(let item): item.id
        }
    }
}

/// «Мои плейлисты» — `card / playlist` (`2844:37412`): квадрат карточки на подложке
/// Fill/Nine, внутри сеткой 2 × 2 превью до четырёх плейлистов полки — 32 с полями
/// и зазором 4 на карточке 76, скругление 4; пустые места остаются подложкой. Подписи
/// нет, как у всей ленты плейлистов. Тап — полный список плейлистов «Мои плейлисты».
private struct CollectionMyPlaylistsCard: View {
    static let title = "Мои плейлисты"
    static let previews = 4

    let previews: [CollectionItem]
    let action: () -> Void

    private enum Layout {
        /// Числа макета на карточке 76 — дальше тем же масштабом, что карточка
        static let designCard: CGFloat = 76
        static let inset: CGFloat = 4
        static let cover: CGFloat = 32
        static let coverRadius: CGFloat = 4
        /// Бордер подложки — 0.467 в макете (у превью — обычный 0.67)
        static let containerBorder: CGFloat = 0.467
    }

    var body: some View {
        let width = CollectionLayout.cardWidth
        let scale = width / Layout.designCard
        let inset = Layout.inset * scale
        let cover = Layout.cover * scale
        let shape = RoundedRectangle(cornerRadius: CollectionLayout.cardRadius, style: .continuous)
        Button(action: action) {
            Color.fillNine
                .frame(width: width, height: width)
                .overlay(alignment: .topLeading) {
                    // Своя стопка с выравниванием по углу: у неявной стопки оверлея дети
                    // разной величины встают по центру, и сетка съезжала.
                    ZStack(alignment: .topLeading) {
                        ForEach(previews.indices, id: \.self) { index in
                            CollectionArtwork(
                                source: previews[index].artwork,
                                width: cover,
                                height: cover,
                                shape: RoundedRectangle(cornerRadius: Layout.coverRadius * scale, style: .continuous)
                            )
                            .padding(.leading, inset + CGFloat(index % 2) * (cover + inset))
                            .padding(.top, inset + CGFloat(index / 2) * (cover + inset))
                        }
                    }
                }
                .clipShape(shape)
                .overlay {
                    shape.strokeBorder(CoverBorder.color, lineWidth: Layout.containerBorder)
                }
                .contentShape(.rect)
        }
        .buttonStyle(PressScaleButtonStyle(pressedScale: PressMotion.cardScale))
        .accessibilityLabel(Self.title)
    }
}

/// Исполнитель — круг 86, под ним имя по центру.
private struct CollectionArtistCard: View {
    let item: CollectionItem
    var shelf: CollectionStore.Shelf? = nil

    @Environment(AppNavigationState.self) private var navigation
    @Environment(\.stackZoomNamespace) private var zoom

    var body: some View {
        Button(action: open) {
            VStack(spacing: CollectionLayout.captionGap) {
                CollectionArtwork(
                    source: item.artwork,
                    width: CollectionLayout.cardWidth,
                    height: CollectionLayout.cardWidth,
                    shape: Circle()
                )
                .collectionZoomSource(item.route, in: zoom)

                CollectionCaption(title: item.title, isCentered: true)
                    .zoomSourceCaption(item.route)
            }
            .frame(width: CollectionLayout.cardWidth)
            .contentShape(.rect)
        }
        .buttonStyle(PressScaleButtonStyle(pressedScale: PressMotion.cardScale))
        .collectionItemActions(item, shelf: shelf)
    }

    private func open() {
        // Отпускание после долгого нажатия, открывшего шторку, — не тап.
        guard !ActionSheetState.shared.isPresented else { return }
        guard let route = item.route else { return }
        navigation.open(route)
    }
}

/// Обложка карточки на скелетоне: картинка проявляется на месте серой заливки,
/// хайрлайн — как у всех карточек проекта.
struct CollectionArtwork<S: InsettableShape>: View {
    let source: ArtworkSource?
    let width: CGFloat
    let height: CGFloat
    let shape: S

    var body: some View {
        PlusSkeleton.fill
            .overlay {
                if let source {
                    SkeletonArtwork(source: source)
                }
            }
            .frame(width: width, height: height)
            .clipShape(shape)
            .coverArtworkMissing(source == nil)
            .coverBorder(shape)
    }
}

/// Подпись карточки — Text S: название белым до двух строк, деталь серым в строку.
private struct CollectionCaption: View {
    let title: String
    var subtitle: String? = nil
    var isCentered = false

    var body: some View {
        VStack(alignment: isCentered ? .center : .leading, spacing: 0) {
            Text(title)
                .plusText(.textS, .medium)
                .foregroundStyle(Color.fillOne)
                .lineLimit(CollectionLayout.titleLines)
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .plusText(.textS, .medium)
                    .foregroundStyle(Color.fillSubtitle)
                    .lineLimit(1)
            }
        }
        .multilineTextAlignment(isCentered ? .center : .leading)
        .frame(maxWidth: .infinity, alignment: isCentered ? .center : .leading)
    }
}

private extension View {
    /// Источник зума в экран сущности — как у карточек витрин.
    @ViewBuilder
    func collectionZoomSource(_ route: EntityRoute?, in zoom: Namespace.ID?) -> some View {
        if let route, let zoom {
            matchedTransitionSource(id: route, in: zoom)
        } else {
            self
        }
    }
}

// MARK: - Треки

/// Треки — блок `carousel / Music / opened playlist`: шапка с круглой «play», названием
/// и числом треков, под ней колонки по три строки, листаются вбок по колонке.
/// Тап по строке включает трек, «play» шапки — с первого трека полки.
private struct CollectionTracksBlock: View {
    let items: [CollectionItem]
    let shelf: CollectionStore.Shelf
    let openAll: () -> Void

    @Environment(ActionBarState.self) private var actionBar
    @Environment(CollectionReorderState.self) private var reorder

    /// Очередь полки: её треки по порядку — конец превью переключает на следующий.
    private var queue: [MusicNowPlaying] {
        items.compactMap(\.playable)
    }

    private var columns: [[CollectionItem]] {
        stride(from: 0, to: items.count, by: CollectionLayout.tracksPerColumn).map {
            Array(items[$0..<min($0 + CollectionLayout.tracksPerColumn, items.count)])
        }
    }

    /// Играет ли сейчас трек этой полки — тогда «play» шапки — пауза.
    private var isPlayingShelf: Bool {
        guard actionBar.isMiniPlayerVisible, actionBar.isMusicPlaying, let id = actionBar.music?.id else { return false }
        return items.contains { $0.playable?.id == id }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 0) {
                    ForEach(columns.indices, id: \.self) { index in
                        let column = columns[index]
                        VStack(spacing: 0) {
                            ForEach(column.indices, id: \.self) { row in
                                CollectionTrackRow(
                                    item: column[row],
                                    queue: queue,
                                    isFirst: row == 0,
                                    isLast: row == column.count - 1,
                                    shelf: shelf
                                )
                            }
                        }
                        .frame(width: CollectionLayout.trackColumnWidth, alignment: .top)
                    }
                }
                .scrollTargetLayout()
                .animation(CollectionMotion.itemsChange, value: items.map(\.id))
            }
            .scrollIndicators(.hidden)
            .scrollDisabled(reorder.isReordering)
            .scrollTargetBehavior(.viewAligned)
            .frame(height: CollectionLayout.tracksHeight, alignment: .top)
        }
        .padding(.vertical, CollectionLayout.sectionPad)
    }

    private var header: some View {
        HStack(spacing: CollectionLayout.tracksHeaderGap) {
            // В режиме порядка «play» остаётся на месте выключенной кнопкой ДС — как кнопка
            // навбара при одном блоке.
            // «Любимое» — `Size=M • 40px, Type=plain` макета на микрошейдере, как у «play»
            // блока «Похоже на» (оверлей шапки ниже); «Скачанное» — обычная круглая кнопка
            // secondary без шейдера (правка пользователя 2026-10-21).
            PlusButton(
                type: shelf == .favorites ? .plain : .secondary,
                size: CollectionLayout.playButton,
                state: reorder.isReordering ? .disabled : .normal,
                accessibilityTitle: isPlayingShelf ? "Пауза" : "Слушать",
                haptic: .inAction,
                action: togglePlayback
            ) {
                PlayPauseGlyph(isPlaying: isPlayingShelf, box: CollectionLayout.playButton.iconBox)
            }
            .animation(CollectionReorderMotion.disabledFade, value: reorder.isReordering)

            // Название — переход в полный список, как шеврон у карусельных секций.
            Button(action: openAll) {
                VStack(alignment: .leading, spacing: 0) {
                    // Шеврон — как у шапок каруселей (правка пользователя 2026-10-20).
                    HStack(spacing: EntitySectionLayout.titleGap) {
                        Text(CollectionItem.Kind.track.title)
                            .plusHeadline(.s)
                            .foregroundStyle(Color.fillOne)
                        EntitySectionChevron(isCollapsed: reorder.isReordering)
                    }
                    Text(subtitle)
                        .plusText(.textM, .medium)
                        .foregroundStyle(Color.fillSubtitle)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
        .overlay(alignment: .leading) {
            // Полка у блока не меняется — ветка постоянна, идентичность цела.
            if shelf == .favorites {
                SharedVideoLayer(video: .musicMicroShader, poster: "musicMicroShaderPoster")
                    .frame(width: CollectionLayout.tracksShader, height: CollectionLayout.tracksShader)
                    .offset(x: CollectionLayout.tracksShaderLeading)
                    .allowsHitTesting(false)
            }
        }
        .padding(.horizontal, CollectionLayout.side)
        .padding(.top, CollectionLayout.tracksHeaderTop)
        .padding(.bottom, CollectionLayout.tracksHeaderBottom)
        // Хват — на правом краю, по центру кнопки «play» (в макете у шапки треков
        // его нет: от каруселей — тот же край, а вертикаль — середина ряда 40).
        .overlay(alignment: .topTrailing) {
            CollectionReorderGrip(isVisible: reorder.isReordering)
                .padding(.top, CollectionLayout.tracksHeaderTop + (CollectionLayout.playButton.height - CollectionReorderGrip.size) / 2)
                .padding(.trailing, CollectionLayout.side)
        }
    }

    /// «Моя волна по любимому» — текст макета у «Любимого»; у «Скачанного» макета нет —
    /// число треков.
    private var subtitle: String {
        shelf == .favorites ? "Моя волна по любимому" : CollectionCopy.tracks(items.count)
    }

    private func togglePlayback() {
        PlayerHaptics.tap()
        if isPlayingShelf {
            actionBar.toggleMusicPlayback()
        } else if let first = items.first?.playable {
            actionBar.open(.music(first), queue: queue)
        }
    }
}

/// Строка трека — `list-item / music`: обложка 48 r6, название и исполнитель Text M
/// (бейдж 18+ у названия), справа отметка «скачано» и «ещё». Между строками колонки —
/// разделитель 0.5. Общая у колонок блока «Треки» и экрана треков полки.
struct CollectionTrackRow: View {
    let item: CollectionItem
    /// Очередь полки, в которой стоит строка.
    let queue: [MusicNowPlaying]
    let isFirst: Bool
    let isLast: Bool
    /// Полка, где стоит строка, — для действий записи.
    var shelf: CollectionStore.Shelf? = nil

    @Environment(CollectionStore.self) private var collection
    @Environment(ActionBarState.self) private var actionBar

    var body: some View {
        HStack(spacing: 0) {
            CollectionArtwork(
                source: item.artwork,
                width: CollectionLayout.trackCover,
                height: CollectionLayout.trackCover,
                shape: RoundedRectangle(cornerRadius: CollectionLayout.trackCoverRadius, style: .continuous)
            )

            HStack(spacing: CollectionLayout.trackTextGap) {
                VStack(alignment: .leading, spacing: EntitySectionLayout.textStackGap) {
                    HStack(spacing: 6) {
                        Text(item.title)
                            .plusText(.textM, .medium)
                            .foregroundStyle(Color.fillOne)
                            .lineLimit(1)
                        if item.isExplicit == true {
                            EntityExplicitBadge()
                        }
                    }
                    Text(item.subtitle)
                        .plusText(.textM, .medium)
                        .foregroundStyle(Color.fillSubtitle)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: CollectionLayout.trackControlsGap) {
                    if collection.isDownloaded(item.id) {
                        Image("iconDownload")
                            .renderingMode(.template)
                            .resizable()
                            .frame(width: CollectionLayout.downloadIcon, height: CollectionLayout.downloadIcon)
                            .foregroundStyle(Color.accentPrimary)
                            .accessibilityLabel("Скачано")
                    }
                    CollectionItemMoreButton(item: item, shelf: shelf)
                }
            }
            .padding(.leading, CollectionLayout.trackTextGap)
        }
        .padding(.horizontal, CollectionLayout.side)
        .padding(.top, isFirst ? 0 : CollectionLayout.trackRowGap)
        .padding(.bottom, isLast ? 0 : CollectionLayout.trackRowGap)
        .contentShape(.rect)
        // Проседает строка, а черта стоит: просевшая черта короче соседних и съезжает.
        .pressScale(PressMotion.rowScale)
        .overlay(alignment: .bottom) {
            if !isLast {
                ListDivider()
                    .padding(.horizontal, CollectionLayout.side)
            }
        }
        .onTapGesture(perform: play)
        .collectionItemActions(item, shelf: shelf)
    }

    private func play() {
        // Отпускание после долгого нажатия, открывшего шторку, — не тап.
        guard !ActionSheetState.shared.isPresented else { return }
        guard let playable = item.playable else { return }
        PlayerHaptics.tap()
        actionBar.open(.music(playable), queue: queue)
    }
}

// MARK: - Порядок блоков

/// Числа режима «изменить порядок». Иконки — макет «Моего»: кнопка навбара
/// `icon / change order` `2584:26578` (20 × 20, x 279, y 62 на кадре 375), хват в шапке
/// блока `icon` `2584:29425` (20 × 20, x 339, y 16). Остальное — решения спеки 35.
enum CollectionReorderMotion {
    /// Соседи уступают место — как сдвиг строк при перестановке на домашнем экране.
    static let swap: Animation = .smooth(duration: 0.3)
    /// Отпущенный блок встаёт в свою ячейку.
    static let settleDuration: Double = 0.3
    static let settle: Animation = .smooth(duration: settleDuration)
    /// Фон стекла проявляется на захвате и гаснет, когда блок уже встал на место.
    static let glassFadeDuration: Double = 0.2
    static let glassFade: Animation = .easeInOut(duration: glassFadeDuration)
    /// Подъём блока в руке — как просадка карточки, только вверх (`PressMotion`).
    static let liftScale: CGFloat = 1.02
    /// Выключение кнопки навбара при одном блоке и «play» «Треков» в режиме — одна кривая.
    static let disabledFade: Animation = .easeInOut(duration: 0.2)
    /// Захват — удержание 0.3 с без сдвига больше 10 pt: быстрый свайп раньше этого
    /// уходит в прокрутку ленты.
    static let pressDuration: TimeInterval = 0.3
    static let pressSlop: CGFloat = 10
    /// Автопрокрутка у края, пока блок в руке: зона 80 pt под навбаром и над хромом,
    /// скорость пропорциональна глубине захода, до максимума в pt/с. Reduce Motion её
    /// не отключает — это управление, а не украшение.
    static let autoScrollZone: CGFloat = 80
    static let autoScrollMaxSpeed: CGFloat = 600
    /// Тряска: угол в градусах, подскок в pt, период в секундах, сдвиг фазы между блоками
    /// (по виду) — соседи не качаются в унисон.
    static let shakeAngle: Double = 0.35
    static let shakeLift: Double = 0.6
    static let shakePeriod: Double = 0.26
    static let shakePhaseStep: Double = 2.1
    /// Тряска входит и выходит плавно: резкий останов читался бы как глюк.
    static let shakeFade: Animation = .easeInOut(duration: 0.2)
    /// Часы тряски идут ещё столько после «Готово», пока амплитуда не дойдёт до нуля.
    static let clockLinger: Duration = .milliseconds(400)
    /// Фон блока в руке — скругление.
    static let glassRadius: CGFloat = PlusRadius.readerBlock
    /// Правка пользователя 2026-10-10: поля вернули — фон и клип блока в руке с отступом 8
    /// от левого и правого края экрана (на время была версия «во всю ширину»).
    static let glassInset: CGFloat = CollectionLayout.cardGap
    /// Фон блока в руке выходит на 8 ниже его рамки: с нижним полем секции 8 — 16 под
    /// содержимым у всех видов (правка пользователя 2026-10-10: вплотную под карточками
    /// фон кончался резко). Раскладку это не меняет: фон и клип рисуются ниже рамки
    /// блока, соседи на месте.
    static let glassBottomExtra: CGFloat = 8
    /// Клип вне захвата: шире блока ровно на радиус — дуги углов за кромкой, срезов нет.
    static let restClipInset: CGFloat = -glassRadius
}

/// Состояние режима порядка — один объект на экран: переключение режима перерисовывает
/// блоки, а сдвиг пальца (`dragTranslation`) читает только сам блок в руке — модификатор
/// `CollectionReorderOffset`, поэтому лента не пересобирается на каждое событие жеста.
@MainActor
@Observable
final class CollectionReorderState {
    /// Имя пространства жеста — сама лента: оно не едет вместе с блоком.
    static let feedSpace = "collectionFeed"

    private(set) var isReordering = false
    /// Полка, чей порядок правят.
    private(set) var shelf: CollectionStore.Shelf?
    /// Рабочий порядок видимых видов: меняется на глазах, в хранилище уходит по «Готово».
    private(set) var draftOrder: [CollectionItem.Kind] = []
    /// Блок под пальцем — от долгого нажатия до отпускания.
    private(set) var heldKind: CollectionItem.Kind?
    /// Блок в руке и пока он доезжает на место: выше соседей, со стеклом, без тряски.
    private(set) var liftedKind: CollectionItem.Kind?
    /// Сдвиг пальца — прямо, без анимации: блок идёт 1:1.
    private(set) var dragTranslation: CGFloat = 0
    /// Поправка на свап: ячейка блока при перестановке переезжает на высоту соседа,
    /// поправка уносит ровно столько же обратно — и под пальцем блок не прыгает. Пишется
    /// в той же анимации, что и свап, поэтому сумма ячейки и поправки все 0.3 с постоянна.
    private(set) var dragCompensation: CGFloat = 0
    /// Идут ли часы тряски: `TimelineView` стоит на паузе, пока режим выключен.
    private(set) var isClockRunning = false

    /// Высоты блоков — замер для логики жеста (середины соседей), раскладку они не задают.
    @ObservationIgnored private var heights: [CollectionItem.Kind: CGFloat] = [:]
    @ObservationIgnored private var settleEnd = Date.distantPast
    @ObservationIgnored private var settleTask: Task<Void, Never>?
    @ObservationIgnored private var clockTask: Task<Void, Never>?
    /// Щелчок на перескок блока через соседа (правка пользователя 2026-10-10) — самый лёгкий
    /// отклик, как у колеса выбора. Греется на захвате; только у драга, не у отладочного свапа.
    @ObservationIgnored private let swapHaptic = UISelectionFeedbackGenerator()

    func setHeight(_ height: CGFloat, for kind: CollectionItem.Kind) {
        heights[kind] = height
    }

    // MARK: Режим

    func start(shelf: CollectionStore.Shelf, order: [CollectionItem.Kind]) {
        settleTask?.cancel()
        clockTask?.cancel()
        self.shelf = shelf
        draftOrder = order
        heldKind = nil
        liftedKind = nil
        dragTranslation = 0
        dragCompensation = 0
        isClockRunning = true
        isReordering = true
    }

    func stop() {
        if let heldKind { release(heldKind) }
        isReordering = false
        shelf = nil
        draftOrder = []
        // Часы доживают до нуля амплитуды и уходят на паузу.
        clockTask?.cancel()
        clockTask = Task {
            try? await Task.sleep(for: CollectionReorderMotion.clockLinger)
            guard !Task.isCancelled else { return }
            isClockRunning = false
        }
    }

    // MARK: Жест

    /// Блок оторвался от ленты (долгое нажатие дошло до конца): хаптик medium.
    func grab(_ kind: CollectionItem.Kind) {
        guard isReordering, heldKind == nil, Date.now >= settleEnd else { return }
        settleTask?.cancel()
        heldKind = kind
        liftedKind = kind
        dragTranslation = 0
        dragCompensation = 0
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        swapHaptic.prepare()
    }

    /// Палец сдвинулся на `translation` от точки захвата. Блок идёт за ним, а когда его
    /// центр пересекает середину соседа, они меняются местами (`swap`).
    func drag(translation: CGFloat) {
        guard let kind = heldKind else { return }
        dragTranslation = translation
        while let index = draftOrder.firstIndex(of: kind), let height = heights[kind] {
            let origin = draftOrder[..<index].reduce(0) { $0 + (heights[$1] ?? 0) }
            let center = origin + height / 2 + dragTranslation + dragCompensation
            if index + 1 < draftOrder.count,
               let below = heights[draftOrder[index + 1]],
               center > origin + height + below / 2 {
                swap(index, index + 1, compensating: -below)
                swapHaptic.selectionChanged()
            } else if index > 0,
                      let above = heights[draftOrder[index - 1]],
                      center < origin - above / 2 {
                swap(index, index - 1, compensating: above)
                swapHaptic.selectionChanged()
            } else {
                break
            }
        }
    }

    /// Палец поднят (или жест отменён системой): блок доезжает на место, хаптик light.
    func release(_ kind: CollectionItem.Kind) {
        guard heldKind == kind else { return }
        heldKind = nil
        withAnimation(CollectionReorderMotion.settle) {
            dragTranslation = 0
            dragCompensation = 0
        }
        PlayerHaptics.tap()
        settleEnd = Date.now.addingTimeInterval(CollectionReorderMotion.settleDuration)
        // Блок остаётся наверху, пока стекло под ним не погасло.
        settleTask?.cancel()
        settleTask = Task {
            try? await Task.sleep(for: .seconds(CollectionReorderMotion.settleDuration + CollectionReorderMotion.glassFadeDuration))
            guard !Task.isCancelled else { return }
            liftedKind = nil
        }
    }

    /// Свап соседних блоков — тот же код у драга и у отладочного флага.
    func swapBlocks(_ first: Int, _ second: Int) {
        swap(first, second)
    }

    private func swap(_ first: Int, _ second: Int, compensating delta: CGFloat = 0) {
        guard draftOrder.indices.contains(first), draftOrder.indices.contains(second), first != second else { return }
        withAnimation(CollectionReorderMotion.swap) {
            draftOrder.swapAt(first, second)
            dragCompensation += delta
        }
    }
}

/// Блок коллекции (секция одного вида) — в режиме порядка его можно зажать в любом
/// месте и перетащить. Вне режима — ничего не меняется: жест выключен, содержимое
/// кликабельно, тряски нет. Дерево одно в обоих режимах (без `if`): иначе вход в режим
/// пересоздавал бы карусели и сбрасывал их прокрутку.
private struct CollectionReorderBlock<Content: View>: View {
    let kind: CollectionItem.Kind
    private let content: Content

    @Environment(CollectionReorderState.self) private var reorder
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(kind: CollectionItem.Kind, @ViewBuilder content: () -> Content) {
        self.kind = kind
        self.content = content()
    }

    var body: some View {
        let isReordering = reorder.isReordering
        let isHeld = reorder.heldKind == kind
        content
            // Тапы карточек, прокрутка каруселей и кнопки блока — выключены в режиме.
            .allowsHitTesting(!isReordering)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                reorder.setHeight(height, for: kind)
            }
            // Блок в руке обрезается по своему фону: карточки, уходящие за кромку стекла,
            // не торчат из него. Клип проявляется той же кривой, что и фон; вне захвата
            // он шире блока и ничего не режет.
            .clipShape(CollectionReorderClip(
                inset: isHeld ? CollectionReorderMotion.glassInset : CollectionReorderMotion.restClipInset,
                bottomExtra: bottomExtra
            ))
            .animation(glassAnimation(isHeld: isHeld), value: isHeld)
            .background { glass(isHeld: isHeld) }
            // Распознаватель — на неподвижном слое блока, до сдвига и масштаба:
            // хит-тест и координаты не зависят от того, где блок нарисован сейчас.
            .contentShape(.rect)
            .gesture(CollectionReorderPress(kind: kind, reorder: reorder, isActive: isReordering))
            .scaleEffect(isHeld && !reduceMotion ? CollectionReorderMotion.liftScale : 1)
            .animation(isHeld ? PressMotion.pressIn : PressMotion.release, value: isHeld)
            .modifier(CollectionReorderShake(kind: kind))
            .modifier(CollectionReorderOffset(kind: kind))
            .zIndex(reorder.liftedKind == kind ? 1 : 0)
    }

    /// Сколько фон и клип выходят ниже рамки блока — одинаково у всех видов.
    private var bottomExtra: CGFloat { CollectionReorderMotion.glassBottomExtra }

    /// Появление — сразу, исчезновение — после посадки блока (задержка = время посадки).
    private func glassAnimation(isHeld: Bool) -> Animation {
        isHeld
            ? CollectionReorderMotion.glassFade
            : CollectionReorderMotion.glassFade.delay(CollectionReorderMotion.settleDuration)
    }

    /// Фон блока в руке — стекло хрома: блюр не пропускает соседей. Проявляется на захвате,
    /// гаснет после того, как блок встал на место (задержка = время посадки).
    private func glass(isHeld: Bool) -> some View {
        Color.clear
            .chromeGlass(RoundedRectangle(cornerRadius: CollectionReorderMotion.glassRadius, style: .continuous))
            .padding(.horizontal, CollectionReorderMotion.glassInset)
            // Ниже рамки блока на `bottomExtra`: отрицательный нижний отступ, раскладка та же.
            .padding(.bottom, -bottomExtra)
            .opacity(isHeld ? 1 : 0)
            .animation(glassAnimation(isHeld: isHeld), value: isHeld)
            .allowsHitTesting(false)
    }
}

/// Захват блока — UIKit-распознаватель долгого нажатия (0.3 с, сдвиг до 10 pt). SwiftUI-
/// жест с нулевой дистанцией на ленте забирал касания у `ScrollView`, и в режиме она
/// не прокручивалась. У `UILongPressGestureRecognizer` быстрый свайп раньше 0.3 с
/// не распознаётся и уходит в пан прокрутки; удержание — захват, и тот же
/// распознаватель дальше отдаёт `.changed` с позицией пальца: это и есть драг.
/// `.ended` и `.cancelled` — отпускание.
///
/// Позиция пальца — в координатах содержимого ленты (`location(in: UIScrollView)`):
/// когда лента прокручивается, а палец стоит, сдвиг блока растёт сам и блок остаётся
/// под пальцем. Пока блок в руке и палец у верха или низа экрана, ленту катит
/// `CADisplayLink` напрямую через `UIScrollView` — покадровое не идёт через `@State`.
private struct CollectionReorderPress: UIGestureRecognizerRepresentable {
    let kind: CollectionItem.Kind
    let reorder: CollectionReorderState
    /// Вне режима распознаватель выключен — блок ведёт себя как обычно.
    let isActive: Bool

    @MainActor
    final class Coordinator: NSObject {
        /// Вертикаль пальца в окне (глобальные координаты конвертера SwiftUI) на захвате и сейчас.
        /// Окно не едет вместе с блоком, сдвиг блока на них не влияет.
        private var startGlobalY: CGFloat = 0
        private var lastGlobalY: CGFloat = 0
        /// Прокрутка ленты на захвате: сдвиг блока — это сдвиг пальца в окне плюс то,
        /// на сколько уехала лента (автопрокрутка).
        private var startOffsetY: CGFloat = 0
        weak var recognizer: UILongPressGestureRecognizer?
        weak var scrollView: UIScrollView?
        var reorder: CollectionReorderState?
        private var link: CADisplayLink?
        private var windowHeight: CGFloat = 0

        #if DEBUG
        /// `-debugReorderTrace 1` — строки `[reorder] …` в лог на каждый шаг жеста.
        private static let isTracing = UserDefaults.standard.bool(forKey: "debugReorderTrace")
        #endif

        /// Сдвиг блока от точки захвата: палец в окне + путь, который проехала лента.
        var translation: CGFloat {
            (lastGlobalY - startGlobalY) + ((scrollView?.contentOffset.y ?? 0) - startOffsetY)
        }

        func begin(_ recognizer: UILongPressGestureRecognizer, globalY: CGFloat, reorder: CollectionReorderState) {
            self.recognizer = recognizer
            self.reorder = reorder
            scrollView = Self.feedScrollView(for: recognizer)
            windowHeight = recognizer.view?.window?.bounds.height ?? 0
            startGlobalY = globalY
            lastGlobalY = globalY
            startOffsetY = scrollView?.contentOffset.y ?? 0
            #if DEBUG
            if Self.isTracing {
                NSLog("[reorder] view=%@", recognizer.view.map { String(describing: type(of: $0)) } ?? "nil")
                if scrollView == nil { NSLog("[reorder] лента не найдена: драг без автопрокрутки") }
            }
            #endif
            trace("began", globalY: globalY)
            // Автопрокрутке нужна лента; без неё драг работает, а часы не заводим.
            guard scrollView != nil else { return }
            link?.invalidate()
            let newLink = CADisplayLink(target: self, selector: #selector(tick(_:)))
            newLink.add(to: .main, forMode: .common)
            link = newLink
        }

        func end(globalY: CGFloat? = nil) {
            trace("ended", globalY: globalY ?? lastGlobalY)
            link?.invalidate()
            link = nil
            recognizer = nil
            scrollView = nil
            reorder = nil
        }

        /// Палец сдвинулся: блок идёт за ним, свап — той же функцией, что и у любого сдвига.
        func update(globalY: CGFloat) {
            lastGlobalY = globalY
            trace("changed", globalY: globalY)
            reorder?.drag(translation: translation)
        }

        /// Лента — вертикальный `UIScrollView` под пальцем. Распознаватель SwiftUI стоит
        /// на служебном виде, который не обязан лежать внутри ленты, поэтому ищем не от него,
        /// а `hitTest` окна по точке касания и поднимаемся по `superview`. Горизонтальные
        /// карусели (содержимое шире рамки) и ленты без запаса прокрутки пропускаем.
        private static func feedScrollView(for recognizer: UILongPressGestureRecognizer) -> UIScrollView? {
            func isFeed(_ view: UIView) -> UIScrollView? {
                guard let scroll = view as? UIScrollView,
                      scroll.contentSize.height > scroll.bounds.height + 1,
                      scroll.contentSize.width <= scroll.bounds.width + 1 else { return nil }
                return scroll
            }
            if let window = recognizer.view?.window {
                var view = window.hitTest(recognizer.location(in: window), with: nil)
                while let current = view {
                    if let scroll = isFeed(current) { return scroll }
                    view = current.superview
                }
            }
            var view = recognizer.view
            while let current = view {
                if let scroll = isFeed(current) { return scroll }
                view = current.superview
            }
            return nil
        }

        private func trace(_ event: String, globalY: CGFloat) {
            #if DEBUG
            guard Self.isTracing else { return }
            NSLog("[reorder] %@ y=%.1f tr=%.1f scroll=%.1f found=%d", event, globalY, translation, scrollView?.contentOffset.y ?? -1, scrollView == nil ? 0 : 1)
            #endif
        }

        @objc private func tick(_ link: CADisplayLink) {
            guard let recognizer, let scrollView, let reorder, reorder.heldKind != nil else {
                // Часы гасим, сам захват не трогаем: его закрывает распознаватель.
                link.invalidate()
                self.link = nil
                return
            }
            let speed = Self.autoScrollSpeed(fingerY: recognizer.location(in: nil).y, windowHeight: windowHeight)
            guard speed != 0 else { return }
            let dt = link.targetTimestamp - link.timestamp
            // Пределы — с учётом полей содержимого (`contentMargins` сверху и под хромом).
            let inset = scrollView.adjustedContentInset
            let minY = -inset.top
            let maxY = max(minY, scrollView.contentSize.height + inset.bottom - scrollView.bounds.height)
            let target = min(maxY, max(minY, scrollView.contentOffset.y + speed * dt))
            guard target != scrollView.contentOffset.y else { return }
            scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: target), animated: false)
            trace("scroll", globalY: lastGlobalY)
            reorder.drag(translation: translation)
        }

        /// Скорость прокрутки, pt/с (плюс — вниз): зона 80 pt под навбаром и над хромом,
        /// скорость пропорциональна глубине захода, до максимума; вне зон — стоп.
        /// Края зон — от констант хрома, а не от замера вью.
        static func autoScrollSpeed(fingerY: CGFloat, windowHeight: CGFloat) -> CGFloat {
            let zone = CollectionReorderMotion.autoScrollZone
            let top = ServiceTopNavLayout.topSafeArea + CollectionLayout.contentTop
            let bottomInset = windowSafeBottom + PlusChromeMetrics.contentBottomInset
            let bottom = windowHeight - bottomInset
            let upDepth = (top + zone - fingerY) / zone
            let downDepth = (fingerY - (bottom - zone)) / zone
            if upDepth > 0 { return -min(1, upDepth) * CollectionReorderMotion.autoScrollMaxSpeed }
            if downDepth > 0 { return min(1, downDepth) * CollectionReorderMotion.autoScrollMaxSpeed }
            return 0
        }

        private static var windowSafeBottom: CGFloat {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first { $0.isKeyWindow }?
                .safeAreaInsets.bottom ?? 0
        }
    }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    func makeUIGestureRecognizer(context: Context) -> UILongPressGestureRecognizer {
        let recognizer = UILongPressGestureRecognizer()
        recognizer.minimumPressDuration = CollectionReorderMotion.pressDuration
        recognizer.allowableMovement = CollectionReorderMotion.pressSlop
        recognizer.isEnabled = isActive
        return recognizer
    }

    func updateUIGestureRecognizer(_ recognizer: UILongPressGestureRecognizer, context: Context) {
        recognizer.isEnabled = isActive
    }

    func handleUIGestureRecognizerAction(_ recognizer: UILongPressGestureRecognizer, context: Context) {
        let coordinator = context.coordinator
        // Позиция — в глобальных координатах конвертера SwiftUI, а не в координатах вида
        // распознавателя: те могут ехать вместе с блоком.
        let globalY = context.converter.location(in: .global).y
        switch recognizer.state {
        case .began:
            coordinator.begin(recognizer, globalY: globalY, reorder: reorder)
            reorder.grab(kind)
        case .changed:
            coordinator.update(globalY: globalY)
        case .ended, .cancelled, .failed:
            coordinator.end(globalY: globalY)
            reorder.release(kind)
        default:
            break
        }
    }
}

/// Клип блока в руке — скруглённый прямоугольник со стеклянным фоном. Отступ от краёв
/// блока анимируется: в покое он отрицательный (клип шире блока на радиус — углы дуги
/// лежат за кромкой и ничего не режут), в руке — поле стекла. Вертикаль — рамка блока
/// и `bottomExtra` ниже неё (то же поле, что у стекла; в покое под рамкой нечего резать).
private struct CollectionReorderClip: Shape {
    var inset: CGFloat
    let bottomExtra: CGFloat

    var animatableData: CGFloat {
        get { inset }
        set { inset = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var frame = rect.insetBy(dx: inset, dy: 0)
        frame.size.height += bottomExtra
        return Path(
            roundedRect: frame,
            cornerRadius: CollectionReorderMotion.glassRadius,
            style: .continuous
        )
    }
}

/// Сдвиг блока в руке: палец — прямо, поправка на свап — вместе с анимацией свапа.
/// Читает сдвиг только у блока в руке, и только этот модификатор перерисовывается на
/// каждое событие жеста — содержимое блока не пересобирается.
private struct CollectionReorderOffset: ViewModifier {
    let kind: CollectionItem.Kind
    @Environment(CollectionReorderState.self) private var reorder

    func body(content: Content) -> some View {
        let isLifted = reorder.liftedKind == kind
        // Два сдвига, а не сумма: у поправки своя анимация, у пальца её нет — одна
        // сумма обрывала бы анимацию поправки на каждом событии жеста.
        content
            .offset(y: isLifted ? reorder.dragCompensation : 0)
            .offset(y: isLifted ? reorder.dragTranslation : 0)
    }
}

/// Тряска блоков, как у иконок iOS в режиме правки: угол `A·sin(2π·t/T + φ)` и подскок
/// `0.6·sin(2π·t/T + φ + π/2)` — аналитическая функция времени, ничего не пишется
/// в `@State`. `TimelineView` стоит в дереве всегда (иначе вход в режим пересоздавал бы
/// содержимое блока), но на паузе, пока режим выключен и амплитуда дошла до нуля, —
/// в покое ни одного тика. Reduce Motion — без тряски.
private struct CollectionReorderShake: ViewModifier {
    let kind: CollectionItem.Kind
    @Environment(CollectionReorderState.self) private var reorder
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let amount: Double = reorder.isReordering && reorder.liftedKind != kind && !reduceMotion ? 1 : 0
        let phase = Double(CollectionItem.Kind.allCases.firstIndex(of: kind) ?? 0) * CollectionReorderMotion.shakePhaseStep
        TimelineView(.animation(paused: !reorder.isClockRunning || reduceMotion)) { timeline in
            content
                .modifier(CollectionShakeEffect(
                    amount: amount,
                    time: timeline.date.timeIntervalSinceReferenceDate,
                    phase: phase
                ))
                .animation(CollectionReorderMotion.shakeFade, value: amount)
        }
    }
}

/// Один кадр тряски. Анимируется только `amount` (вход и выход), время подаёт `TimelineView`.
private struct CollectionShakeEffect: GeometryEffect {
    var amount: Double
    let time: Double
    let phase: Double

    var animatableData: Double {
        get { amount }
        set { amount = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        guard amount > 0 else { return ProjectionTransform(.identity) }
        // Время по модулю периода: иначе у больших значений sin теряет точность.
        let period = CollectionReorderMotion.shakePeriod
        let angle = 2 * Double.pi * time.truncatingRemainder(dividingBy: period) / period + phase
        let rotation = amount * CollectionReorderMotion.shakeAngle * .pi / 180 * sin(angle)
        let lift = amount * CollectionReorderMotion.shakeLift * sin(angle + .pi / 2)
        let transform = CGAffineTransform(translationX: size.width / 2, y: size.height / 2 + lift)
            .rotated(by: rotation)
            .translatedBy(x: -size.width / 2, y: -size.height / 2)
        return ProjectionTransform(transform)
    }
}

/// Иконка-хват в шапке блока (`2584:29425`) — на месте шеврона, появляется кросс-попом.
private struct CollectionReorderGrip: View {
    static let size: CGFloat = 20

    let isVisible: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Image("iconDragHandle")
            .renderingMode(.template)
            .resizable()
            .frame(width: Self.size, height: Self.size)
            .foregroundStyle(Color.fillSubtitle)
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible || reduceMotion ? 1 : ActionBarMotion.iconSwapScale)
            .animation(reduceMotion ? .easeInOut(duration: 0.2) : ActionBarMotion.iconSwap, value: isVisible)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// Кнопка навбара «изменить порядок» ↔ «готово» (`2584:26578`) — `PlusButton` plain M:
/// иконка 20, круг 40 под отрицательным отступом — раскладка держит только иконку. Иконки
/// меняются кросс-попом, как у сердца и play/pause.
private struct CollectionReorderButton: View {
    let isEnabled: Bool
    let action: () -> Void

    @Environment(CollectionReorderState.self) private var reorder
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let size = PlusButtonSize.m

    var body: some View {
        let isReordering = reorder.isReordering
        let swapScale = reduceMotion ? 1 : ActionBarMotion.iconSwapScale
        PlusButton(
            type: .plain,
            size: Self.size,
            state: isEnabled ? .normal : .disabled,
            accessibilityTitle: isReordering ? "Готово" : "Изменить порядок",
            haptic: .inAction,
            action: action
        ) {
            ZStack {
                // Блоков меньше двух — переставлять нечего: иконка приглушена, как
                // у выключенной кнопки ДС, место за ней держится.
                glyph("iconChangeOrder", color: isEnabled ? .fillSubtitle : .fillSeven)
                    .opacity(isReordering ? 0 : 1)
                    .scaleEffect(isReordering ? swapScale : 1)
                glyph("iconDone", color: .accentPrimary)
                    .opacity(isReordering ? 1 : 0)
                    .scaleEffect(isReordering ? 1 : swapScale)
            }
            .animation(reduceMotion ? .easeInOut(duration: 0.2) : ActionBarMotion.iconSwap, value: isReordering)
            .animation(.easeInOut(duration: 0.2), value: isEnabled)
        }
        // Круг 40 — в раскладке целиком, как в макете навбара (`17778:34241`), а не
        // голой иконкой под отрицательным отступом.
        // Онбординг — под кнопкой, по её центру: едет вместе с навбаром, лента под ним
        // скроллится, а подсказка стоит. Тап по ней — то же действие, что у кнопки.
        .overlay(alignment: .top) {
            CollectionReorderHintBubble(phase: CollectionReorderHint.shared.phase, action: action)
                .fixedSize()
                .alignmentGuide(.top) { _ in -(Self.size.height + CollectionReorderHintLayout.gap) }
        }
    }

    /// «Изменить порядок» — приглушённый белый, «Готово» — фиолетовый акцент приложения;
    /// цвет меняется вместе с иконкой, кросс-попом.
    private func glyph(_ name: String, color: Color) -> some View {
        Image(name)
            .renderingMode(.template)
            .resizable()
            .foregroundStyle(color)
    }
}

// MARK: - Пустая полка

/// Полка пуста — подсказка, откуда в неё попадают.
private struct CollectionEmptyState: View {
    let shelf: CollectionStore.Shelf

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .plusHeadline(.s)
                .foregroundStyle(Color.fillOne)
            Text(hint)
                .plusText(.textM, .medium)
                .foregroundStyle(Color.fillSubtitle)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var title: String {
        switch shelf {
        case .favorites: "Здесь будет любимое"
        case .downloads: "Скачанного пока нет"
        }
    }

    private var hint: String {
        switch shelf {
        case .favorites: "Отмечайте «Нравится» у музыки и книг и «Позже» у фильмов — всё соберётся здесь"
        case .downloads: "Скачайте фильм, книгу, альбом или трек — они появятся здесь"
        }
    }
}

// MARK: - Прогресс карточек

/// Прогресс под вертикальными карточками коллекции: начатый и недосмотренный фильм —
/// из истории просмотра, читаемая книга — из истории чтения. Дочитанное и нетронутое —
/// без полосы.
@MainActor
enum CollectionProgress {
    static func movie(_ entry: CollectionMixEntry, history: WatchHistory) -> Double? {
        let id = entry.item.route?.ref.id ?? entry.resume?.id
        let watched = history.continuing.first { $0.id == id }?.progress
        return visible(entry.progress ?? watched)
    }

    static func movie(_ item: CollectionItem, history: WatchHistory) -> Double? {
        visible(history.continuing.first { $0.id == item.route?.ref.id }?.progress)
    }

    static func book(_ entry: CollectionMixEntry, reading: ReadingHistory) -> Double? {
        book(entry.item, reading: reading)
    }

    static func book(_ item: CollectionItem, reading: ReadingHistory) -> Double? {
        item.route.flatMap { reading.readingProgress(for: $0.ref.id) }
    }

    private static func visible(_ progress: Double?) -> Double? {
        guard let progress, ContentProgress.isStarted(progress), progress < 1 else { return nil }
        return progress
    }
}
