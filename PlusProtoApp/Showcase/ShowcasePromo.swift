import SwiftUI
import UIKit

/// Ключ слота ряда: копия круга и айтем, а не номер места. По номеру места каждая
/// вставка и удаление (✕) сдвигала отображение `items[index % count]` почти у всех слотов,
/// вью получали новый айтем и пересоздавались — пять видимых обложек мигали дважды
/// (жалоба 2026-10-10). По `(копия, id)` существующие вью живут, ряд лишь перекладывается.
private struct PromoSlotID: Hashable {
    let copy: Int
    let item: String
}

/// Промо-слайдер «Главной» (макет `2532:26618`, задача пользователя 2026-10-08):
/// фильмы, альбомы и книги по кругу, в обе стороны, по одной карточке за свайп. С задачи 64
/// в круге и исполнители (круг с фото, имя под ним) и станция «Моей волны» (с задачи 65 —
/// лепесток, `PromoStationCard`): тап по исполнителю — его экран, по станции — включает волну.
///
/// Центральная крупнее соседей, у каждой карточки свой случайный наклон; масштаб, наклон
/// и опускание соседей идут за сдвигом ленты кадр в кадр (`visualEffect`, без стейта).
/// Пара ✕/✓ (у альбома — и подпись) — только у центральной и вместе, когда карточка
/// встала. Фон — размытая картинка центральной, меняется вслед за сдвигом.
///
/// ✕ не подменяет айтем, а убирает его из круга: карточка гаснет, ряд схлопывается,
/// правая соседка встаёт в центр. Чтобы набор не кончился, в круг сразу за ней встаёт
/// новый айтем того же вида (`ShowcaseCatalog.preparePromoAddition`).
///
/// Круг — три копии набора, как у промо Книг и Кинопоиска: работает средняя, а когда
/// свайп остановился в крайней, лента перескакивает на ту же карточку средней.
///
/// `composed` исключает начатые фильмы и книги: продолжение потребления остаётся
/// в Recently и исходных витринах.
struct ShowcasePromo: View {
    let items: [ShowcaseBlock]
    private let fixedPreview: Bool
    let zoom: Namespace.ID
    /// Айтем на месте — на сессию (`ShowcaseCatalog.promoIndex`): экран таба
    /// размонтируется на каждом переключении, а слайдер открывается там, где оставили.
    @Binding var savedIndex: Int

    @Environment(AppNavigationState.self) private var navigation
    @Environment(ShowcaseCatalog.self) private var catalog
    @Environment(ActionBarState.self) private var actionBar

    private typealias Layout = ShowcasePromoLayout

    private static let copies = 3
    /// Меньше трёх айтемов круг не держит: слева и справа от центральной стоял бы один
    /// и тот же. Пополнить ✕ нечем, а айтемов столько — айтем проявляется прежним.
    private static let minimumItems = 3

    /// Карточка ленты копий в центре.
    @State private var pageID: PromoSlotID?
    /// Слот в центре на момент перестановки набора (`editSet`). Ленту прикалываем к нему
    /// уже после того, как раскладка легла (`pinToEditAnchor`): `scrollTo` внутри самого
    /// `editSet` разрешается по старой раскладке и становится no-op, а биндинг `pageID` при
    /// вставке ленту не двигает — ключ слота не меняется, команды от него нет.
    @State private var editAnchor: PromoSlotID?
    /// Прокси ленты — для явного `scrollTo` после перестановки набора (`remove(slot:)`).
    @State private var scrollProxy: ScrollViewProxy?
    /// Айтем, у которого показана пара ✕/✓ (у альбома — и подпись), — центральный, вставший на место.
    @State private var revealed: String?
    @State private var revealTask: Task<Void, Never>?
    /// Состояние пары — на айтем, а не на копию и не на место в наборе: ✕ убирает айтемы,
    /// и места сдвигаются; после перескока на среднюю копию ✓ остаётся при айтеме.
    @State private var feedback = PromoFeedbackStore()
    /// Дробный слот в центре — для фона. Пишется на кадрах скролла, читает только фон.
    @State private var scroll: PromoScrollState
    /// ✕: слот убираемой карточки. Всё правее него едет влево на `collapse` шага.
    @State private var removal: Int?
    @State private var collapse: CGFloat = 0
    /// Набор меняет сам слайдер (✕) — центр он уже выставил, пересчитывать не нужно.
    @State private var isEditingSet = false
    /// Лента встала на стартовую карточку (`placeIfNeeded`).
    @State private var isPlaced = false
    @State private var petalWave = PromoPetalWave<PromoSlotID>(duration: LiftWaveConfig.duration)
    @State private var playingPetalID: String?
    @State private var hasInteracted = false
    @State private var swipeHaptics = PromoSwipeHapticPolicy()

    init(items: [ShowcaseBlock], zoom: Namespace.ID, savedIndex: Binding<Int>, fixedPreview: Bool = false) {
        self.fixedPreview = fixedPreview
        self.items = items
        self.zoom = zoom
        _savedIndex = savedIndex
        let count = max(items.count, 1)
        let startIndex = HomePromoStartPolicy.index(in: items, preferred: savedIndex.wrappedValue) {
            $0.homePromoKind == .artist
        } ?? 0
        let start = count + startIndex
        _pageID = State(initialValue: items.isEmpty ? nil : PromoSlotID(copy: 1, item: items[start % count].id))
        _scroll = State(initialValue: PromoScrollState(position: CGFloat(start)))

    }

    #if DEBUG
    private func captureLocate(_ kind: String) -> Bool {
        guard !liveItems.isEmpty, let current = page else { return false }
        let item = liveItems[Self.wrap(current, liveItems.count)]
        let target: HomePromoKind = kind == "petal" ? .station : (kind == "album" ? .album : .movie)
        let matches = item.homePromoKind == target
        if matches { scheduleReveal() }
        if !matches { page = current + 1 }
        return matches
    }

    private func capturePerform(_ action: String) async {
        guard !liveItems.isEmpty, let current = page else { return }
        let item = liveItems[Self.wrap(current, liveItems.count)]
        let target: String?
        switch action {
        case "like", "save", "intro-collapse": target = item.id + ":like"
        case "dislike": target = item.id + ":dislike"
        case "play", "pause", "open": target = item.id + ":card:\(current)"
        case "tap-neighbor":
            let index = Self.wrap(current + 1, liveItems.count)
            target = liveItems[index].id + ":card:\(current + 1)"
        default: target = nil
        }
        if let target { await MixCaptureTouches.shared.press(target: target) }
        switch action {
        case "intro-replay": PromoIntroSession.shared.replay()
        case "prepare-save":
            // Только в сценарии съёмки; исходная коллекция восстановится из снимка.
            if let saved = item.recommendationCollectionItem { CollectionStore.shared.setFavorite(saved, false) }
        case "intro-collapse":
            PromoIntroSession.shared.interact()
        case "open":
            tap(item, slotIndex: current, isCurrent: true)
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2))
                MixCaptureTouches.shared.tap(at: CGPoint(x: 24, y: 84))
                navigation.close()
            }
        case "back": navigation.pop()
        case "reset-playback":
            if actionBar.isMusicPlaying { actionBar.toggleMusicPlayback() }
        case "next":
            MixCaptureTouches.shared.swipe(target: item.id + ":card:\(current)")
            PromoIntroSession.shared.interact()
            withAnimation(ShowcasePromoMotion.step) { page = current + 1 }
        case "tap-neighbor":
            let index = Self.wrap(current + 1, liveItems.count)
            tap(liveItems[index], slotIndex: current + 1, isCurrent: false)
        case "play":
            tap(item, slotIndex: current, isCurrent: true)
        case "like", "save":
            feedback.state(for: item.id).debugDones += 1
        case "dislike":
            feedback.state(for: item.id).debugDismisses += 1
        case "pause":
            tap(item, slotIndex: current, isCurrent: true)
        case "undo": ToastCenter.shared.activate()
        default: break
        }
    }
    #endif

    private var count: Int { items.count }

    /// Номер места центральной карточки в ряду копий. Хранится ключом слота (`pageID`),
    /// номер — производный: остальной код читает и пишет его как раньше.
    private var page: Int? {
        get {
            guard let id = pageID else { return nil }
            let promo = liveItems
            guard let index = promo.firstIndex(where: { $0.id == id.item }) else { return nil }
            return id.copy * promo.count + index
        }
        nonmutating set {
            let promo = liveItems
            guard let value = newValue, !promo.isEmpty else {
                pageID = nil
                return
            }
            let copy = Int((Double(value) / Double(promo.count)).rounded(.down))
            pageID = PromoSlotID(copy: copy, item: promo[Self.wrap(value, promo.count)].id)
        }
    }

    /// Ключи слотов ряда: копии круга по порядку, в каждой — айтемы набора.
    private var slotIDs: [PromoSlotID] {
        (0..<Self.copies).flatMap { copy in items.map { PromoSlotID(copy: copy, item: $0.id) } }
    }

    /// Набор как он есть сейчас — в отложенных шагах ✕ и в замыканиях задач: `items`
    /// там с того прохода, на котором их создали. Тот же состав, что у `items`
    /// (`composed`): обложки рекомендаций без карточек «Продолжить».
    private var liveItems: [ShowcaseBlock] { fixedPreview ? items : Self.composed(catalog.homePromo(catalog.feed.promo)) }

    /// Промо содержит рекомендации с обложками и описаниями.
    /// Продолженное потребление остаётся в Recently и исходной витрине.
    /// Порядок сохраняется: старт без артиста выбирает HomePromoStartPolicy,
    /// а перестановка первой карточки здесь меняла левого соседа после ✕.
    static func composed(_ promo: [ShowcaseBlock]) -> [ShowcaseBlock] {
        promo.compactMap { block in
            switch block {
            case .watching, .reading: return nil
            case .movie(let movie):
                guard movie.resume == nil else { return nil }
                return block
            case .book(let book): return book.resume == nil ? block : nil
            default: return block
            }
        }
    }

    private var spacingGeometry: PromoCarouselSpacing? {
        guard PlusMetrics.screenWidth > 402 else { return nil }
        let settings = HomePresentationSettings.shared
        func cards(at width: CGFloat) -> [PromoCarouselSpacing.Card] {
            let geometry = Layout.geometry(viewportWidth: width)
            let cards = items.map { item in
                let card = geometry.card(for: item.homePromoKind)
                let look = PromoCardLook(id: item.id)
                return PromoCarouselSpacing.Card(
                    mainWidth: PromoCarouselSpacing.projectedWidth(width: card.main.width, height: card.main.height,
                        degrees: settings.uprightEnabled ? 0 : look.centerTilt),
                    sideWidth: PromoCarouselSpacing.projectedWidth(width: card.neighbour.width, height: card.neighbour.height,
                        degrees: settings.uprightEnabled ? settings.sideAngle : look.sideTilt))
            }
            return Array(repeating: cards, count: Self.copies).flatMap { $0 }
        }
        return PromoCarouselSpacing(cards: cards(at: PlusMetrics.screenWidth),
            viewportWidth: PlusMetrics.screenWidth, baselineCards: cards(at: 402))
    }

    /// Только окрестность экрана закрепляется в кэше: семь карточек и запас по одной с краёв.
    private func glowItems(around current: Int?) -> [ShowcaseBlock] {
        guard !items.isEmpty else { return [] }
        var seen = Set<String>()
        return [0, -1, 1, -2, 2, -3, 3, -4, 4].compactMap { delta in
            let item = items[Self.wrap((current ?? count) + delta, count)]
            return seen.insert(item.id).inserted ? item : nil
        }
    }

    var body: some View {
        let spacing = spacingGeometry
        let collapsedSpacing = removal.flatMap { removed in spacing.map { $0.removing(at: removed) } }
        let visibleCount = spacing.map { PlusMetrics.screenWidth > $0.sevenCardMinimumWidth ? 7 : 5 } ?? 5
        let slots = slotIDs
        // Снимок этого прохода. Асинхронные действия по-прежнему читают liveItems.
        let currentPage = pageID.flatMap { id in items.firstIndex { $0.id == id.item }.map { id.copy * count + $0 } }
        let glowItems = glowItems(around: currentPage)
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                // Ряд — не ленивый: в ленивом перескок на среднюю копию кадр рисовал позицию
                // на шаг левее, по оценке, — мелькала прежняя карточка (кадр 2026-10-08),
                // а ушедшие за экран слоты держали прежний айтем. Слотов не больше 18.
                ZStack(alignment: .topLeading) {
                    // Persistent layers share the card row's scroll geometry.
                    // Opacity is evaluated by visualEffect DURING the drag, with no
                    // page-ID switch or observation round-trip on each frame.
                    HStack(spacing: 0) {
                        ForEach(Array(slots.enumerated()), id: \.element) { index, _ in
                            let shift = removal.map { index > $0 ? collapse : 0 } ?? 0
                            PromoSwipeGlow(item: items[index % max(count, 1)], shift: shift, rasters: scroll.rasters)
                        }
                    }
                    .compositingGroup()
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                    HStack(spacing: 0) {
                        ForEach(Array(slots.enumerated()), id: \.element) { index, _ in
                            slot(index, currentPage: currentPage, visibleCount: visibleCount,
                                 spacing: spacing, collapsedSpacing: collapsedSpacing)
                        }
                    }
                    .scrollTargetLayout()
                    .opacity(HomePresentationSettings.shared.promoGlowInspectionEnabled ? MixMotionCapture.glowForegroundOpacity : 1)
                }
            }
            // По одной карточке за свайп, как бы ни бросили.
            .scrollTargetBehavior(.viewAligned(limitBehavior: .alwaysByOne))
            .contentMargins(.horizontal, (PlusMetrics.screenWidth - Layout.step) / 2, for: .scrollContent)
            // `.leading` при симметричных полях центрирует точно, `.center` промахивался
            // на ~3 pt (грабли в CLAUDE.md).
            .scrollPosition(id: $pageID, anchor: .leading)
            .scrollIndicators(.hidden)
            // Карточки шире слота — за краями экрана их видно.
            .scrollClipDisabled()
            .scrollDisabled(count < 2 || removal != nil)
            .frame(height: Layout.height)
            .overlay(alignment: .top) {
                // Полоса привязана к экрану, не к наклоняемому/масштабируемому слоту.
                ZStack(alignment: .top) {
                    ForEach(items, id: \.id) { item in
                        if let text = item.promoSynopsis {
                            let coverHeight = item.homePromoKind == .book
                                ? Layout.book.geometry.frameSize(coverWidth: Layout.book.coverWidth).height
                                : Layout.poster.height
                            let textWidth = min(300, PlusMetrics.screenWidth - 48)
                            PromoSynopsis(text: text, availableWidth: textWidth)
                                .showcaseSwappable()
                                .modifier(PromoReveal(isShown: revealed == item.id,
                                                      hiddenScale: ShowcasePromoMotion.pairHiddenScale, anchor: .top))
                                .zoomSourceCaption(item.entityRoute)
                                .offset(y: Layout.cardCenterY + coverHeight / 2 + 16)
                                .environment(feedback.state(for: item.id))
                        }
                    }
                }
                .frame(width: PlusMetrics.screenWidth - 48, height: 48, alignment: .top)
                .opacity(HomePresentationSettings.shared.promoGlowInspectionEnabled ? MixMotionCapture.glowForegroundOpacity : 1)
                .allowsHitTesting(false)
            }
            .onScrollGeometryChange(for: CGFloat.self) { [step = Layout.step] geometry in
                (geometry.contentOffset.x + geometry.contentInsets.leading) / step
            } action: { _, position in
                scroll.position = position
                if removal == nil, swipeHaptics.moved(to: position) {
                    HomeInteractionHaptics.carouselStep()
                }
                placeIfNeeded(at: position, proxy: proxy)
            }
            .onScrollPhaseChange { _, phase, context in
                guard removal == nil else { return }
                let position = (context.geometry.contentOffset.x + context.geometry.contentInsets.leading) / Layout.step
                if phase == .tracking {
                    swipeHaptics.begin(at: position)
                    HomeInteractionHaptics.prepareCarousel()
                }
                if phase == .interacting {
                    hasInteracted = true
                    if swipeHaptics.interact(at: position) {
                        HomeInteractionHaptics.carouselStep()
                    }
                    PromoIntroSession.shared.interact()
                }
                if phase == .idle {
                    if swipeHaptics.moved(to: position) {
                        HomeInteractionHaptics.carouselStep()
                    }
                    swipeHaptics.reset()
                    settle()
                    scheduleReveal()
                } else {
                    hideReveal()
                }
            }
            .onChange(of: HomePresentationSettings.shared.promoLiftWaveEnabled) { _, enabled in
                if !enabled { petalWave.reset() }
            }
            .onDisappear {
                revealTask?.cancel()
            }
            .onAppear {
                scrollProxy = proxy
                trace("appear")
                scheduleReveal()
            }
            #if DEBUG
            .onChange(of: pageID) { _, _ in trace("pageID") }
            #endif
            // Набор собрался заново (моки → живые, под заставкой) — центральный айтем
            // остаётся в центре, если он есть в новом наборе, иначе — на сохранённом месте.
            .onChange(of: items.map(\.id)) { _, new in
                petalWave.retain(Set(slotIDs))
                guard !isEditingSet else {
                    isEditingSet = false
                    pinToEditAnchor()
                    return
                }
                recenter(new: new)
            }
            .task(id: glowItems.map { PromoCardGlowRaster.key(for: $0) }) {
                PromoCardGlowRaster.retain(glowItems)
                for item in glowItems {
                    guard !Task.isCancelled else { return }
                    await PromoCardGlowRaster.render(item)
                    guard !Task.isCancelled else { return }
                    scroll.rasters += 1
                }
            }
            #if DEBUG
            .task { await MixMotionCapture.run(locate: captureLocate, perform: capturePerform) }
            // `-debugHomePromoStep <back|next|n|cycle>` — через 3с пролистать слайдер:
            // свайпнуть из шелла нечем. `cycle` — вперёд по карточке раз в 1.6 с, 14 шагов:
            // круг проходит перескок копий, его снимают на видео. Словами, а не «-1»: минус
            // аргументы запуска читают как ключ.
            .task {
                let value = UserDefaults.standard.string(forKey: "debugHomePromoStep") ?? ""
                let cycleSteps = 14
                let cycleInterval: Duration = .seconds(1.6)
                let step = value == "back" ? -1 : (value == "next" || value == "cycle" ? 1 : Int(value) ?? 0)
                guard step != 0 else { return }
                try? await Task.sleep(for: .seconds(3))
                for _ in 0..<(value == "cycle" ? cycleSteps : 1) {
                    guard !Task.isCancelled else { return }
                    withAnimation(ShowcasePromoMotion.step) { page = (page ?? count) + step }
                    try? await Task.sleep(for: cycleInterval)
                }
            }
            // `-debugHomePromoKind <artist|vibe|artistWave|continueMovie|continueBook>` — через 3 с
            // поставить в центр первый айтем вида: исполнителя, станцию «Моей волны», волну
            // «в стиле артиста» (задача 68) или «Продолжить» фильма и книги (задача 69).
            // Тем же путём, что `-debugHomePromoStep`.
            .task {
                let arguments = ProcessInfo.processInfo.arguments
                let movie = arguments.contains("-debugPromoEditorialMovie")
                let book = arguments.contains("-debugPromoEditorialBook")
                let petal = arguments.contains("-debugPromoPetalLayout")
                let album = arguments.contains("-debugPromoAlbumBadge")
                let artistWave = arguments.contains("-debugPromoArtistWaveLayout")
                let artistName = arguments.firstIndex(of: "-debugPromoArtistName").flatMap { index in
                    index + 1 < arguments.count ? arguments[index + 1] : nil
                }
                guard movie || book || petal || album || artistWave || artistName != nil else { return }
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { return }
                // alwaysByOne ограничивает и программный переход: идём по одному
                // слоту, а не прыгаем сразу на далёкую карточку.
                for _ in 0...liveItems.count {
                    let promo = liveItems
                    guard !Task.isCancelled, !promo.isEmpty else { return }
                    let current = page ?? promo.count
                    let item = promo[Self.wrap(current, promo.count)]
                    let matches: Bool = switch item {
                    case .movie: movie
                    case .book: book
                    case .vibe(let vibe): petal || (artistWave && vibe.promoStation.artist != nil)
                    case .album: album
                    case .artist(let artist): artist.name == artistName
                    default: false
                    }
                    if matches { scheduleReveal(); return }
                    withAnimation(ShowcasePromoMotion.step) { page = current + 1 }
                    try? await Task.sleep(for: .milliseconds(700))
                }
            }
            .task {
                let kind = UserDefaults.standard.string(forKey: "debugHomePromoKind") ?? ""
                guard !kind.isEmpty else { return }
                try? await Task.sleep(for: .seconds(3))
                let promo = liveItems
                guard !Task.isCancelled else { return }
                let index = promo.firstIndex { item in
                    switch item {
                    case .artist: kind == "artist"
                    case .vibe(let vibe): kind == (vibe.promoStation.artist == nil ? "vibe" : "artistWave")
                    case .movie(let movie): kind == "continueMovie" && movie.resume != nil
                    case .book(let book): kind == "continueBook" && book.resume != nil
                    case .album, .reading, .watching: false
                    }
                }
                guard let index else { return }
                withAnimation(ShowcasePromoMotion.step) { page = promo.count + index }
            }
            // `-debugHomePromoArtist 1` — через 6 с тап по подписи центрального альбома:
            // тот же `openArtist`, что у кнопки; у карточки исполнителя — тот же `tap`, что
            // у неё самой. Центральный другого вида (или альбом без id исполнителя) — ничего.
            .task {
                guard UserDefaults.standard.bool(forKey: "debugHomePromoArtist") else { return }
                try? await Task.sleep(for: .seconds(6))
                let promo = liveItems
                guard !Task.isCancelled, !promo.isEmpty, let current = page else { return }
                let item = promo[Self.wrap(current, promo.count)]
                switch item {
                case .album(let album) where album.artistRoute != nil:
                    openArtist(item)
                case .artist:
                    tap(item, slotIndex: current, isCurrent: true)
                default:
                    return
                }
            }
            // `-debugHomePromoDismiss <n>` — ✕ у центральной карточки n раз подряд: первый
            // через 6 с, дальше раз в 2.5 с. Тот же `dismiss()` пары, что у тапа.
            .task {
                let times = UserDefaults.standard.integer(forKey: "debugHomePromoDismiss")
                guard times > 0 else { return }
                try? await Task.sleep(for: .seconds(6))
                for _ in 0..<times {
                    let promo = liveItems
                    guard !Task.isCancelled, !promo.isEmpty, let current = page else { return }
                    feedback.state(for: promo[Self.wrap(current, promo.count)].id).debugDismisses += 1
                    try? await Task.sleep(for: .seconds(2.5))
                }
            }
            .task {
                guard ProcessInfo.processInfo.arguments.contains("-debugPromoRecommendationToast") else { return }
                try? await Task.sleep(for: .seconds(6))
                for _ in 0..<30 {
                    guard !Task.isCancelled else { return }
                    let promo = liveItems
                    if !promo.isEmpty, let current = page {
                        let item = promo[Self.wrap(current, promo.count)]
                        if revealed == item.id {
                            feedback.state(for: item.id).debugDones += 1
                            return
                        }
                    }
                    try? await Task.sleep(for: .milliseconds(200))
                }
            }
            #endif
        }
    }

    // MARK: Слот

    private func slot(_ index: Int, currentPage: Int?, visibleCount: Int, spacing: PromoCarouselSpacing?,
                      collapsedSpacing: PromoCarouselSpacing?) -> some View {
        let item = items[index % max(count, 1)]
        let look = PromoCardLook(id: item.id)
        let isShown = index == currentPage && revealed == item.id
        let shift = removal.map { index > $0 ? collapse : 0 } ?? 0
        // Доступность зависит от дискретного окна, а не от каждого дробного кадра скролла.
        let isVisible = abs(CGFloat(index - scroll.nearestSlot) - shift) <= CGFloat(visibleCount / 2)
        return ZStack(alignment: .top) {
            card(item, slotIndex: index, currentPage: currentPage, visibleCount: visibleCount, isShown: isShown)
                .frame(height: Layout.carouselHeight)
                .modifier(PromoCardMotion(look: look, kind: item.homePromoKind, slotIndex: index, spacing: spacing,
                                          collapsedSpacing: collapsedSpacing, removal: removal, collapse: collapse,
                                          visibleCount: visibleCount))
                .offset(y: item.homePromoKind == .station ? 24 : 0)
        }
        .frame(width: Layout.step, height: Layout.height, alignment: .top)
        // Центральная — поверх соседей, как в макете: в ряду правый сосед ложился
        // на её кромку. Смена — на середине свайпа, когда карточки равны и почти
        // не касаются.
        .zIndex(index == currentPage ? 1 : 0)
        .allowsHitTesting(isVisible)
        .accessibilityHidden(!isVisible)
        .environment(\.promoDepthShift, shift)
        .environment(feedback.state(for: item.id))
        .environment(\.showcaseRefresh, ShowcaseRefresh(prepare: { nil }, custom: { remove(slot: index) }))
    }

    /// Карточка и пара ✕/✓ на её кромке — пара оверлеем на карточке, а не внутри кнопки:
    /// так у неё свои нажатия, а наклон и масштаб — общие с карточкой. У альбома там же
    /// его подпись, у исполнителя — имя под кругом.
    private func card(_ item: ShowcaseBlock, slotIndex: Int, currentPage: Int?, visibleCount: Int, isShown: Bool) -> some View {
        let isCurrent = slotIndex == currentPage
        let captionRoute = isCurrent ? item.entityRoute : nil
        let pair = PromoPairPlacement(item)
        let petalLayout = item.homePromoKind == .station
        let settings = HomePresentationSettings.shared
        let depthEnabled = settings.promoDepthEnabled
        let waveEnabled = settings.promoLiftWaveEnabled
        let slotID = PromoSlotID(copy: slotIndex / max(count, 1), item: item.id)
        let pulse = petalWave.pulses[slotID]
        let waveOrigin = pulse?.origin ?? .zero
        return Button { tap(item, slotIndex: slotIndex, isCurrent: isCurrent) } label: {
            // Смена по ✕ (`showcaseSwappable`) — внутри лица: у станции она на слоях
            // по отдельности (`PromoStationCard`).
            PromoCardFace(item: item, breathing: playingPetalID == item.id
                          && abs(slotIndex - (currentPage ?? slotIndex)) <= visibleCount / 2
                          && actionBar.isMusicPlaying && MyVibeTracks.isVibe(actionBar.music?.id),
                          depthEnabled: depthEnabled, waveEnabled: waveEnabled,
                          waveTrigger: pulse?.trigger ?? 0, waveOrigin: waveOrigin)
        }
        .buttonStyle(PressScaleButtonStyle(pressedScale: PressMotion.cardScale))
        .modifier(MixCaptureTarget(name: item.id + ":card:\(slotIndex)"))
        .simultaneousGesture(
            SpatialTapGesture().onEnded { tap in
                petalWave.recordTouch(tap.location, at: slotID, time: ProcessInfo.processInfo.systemUptime)
            },
            including: waveEnabled && petalLayout && isCurrent && !fixedPreview ? .all : .subviews
        )
        // Источник зума — у каждой копии, но адрес экрана — только у центральной:
        // повторы того же айтема источником не становятся. Без `if`: смена ветки
        // пересоздавала карточку посреди свайпа, и она моргала.
        .matchedTransitionSource(id: zoomID(item, slotIndex: slotIndex, isCurrent: isCurrent), in: zoom)
        .accessibilityLabel(item.promoAccessibilityLabel)
        .overlay(alignment: .topLeading) {
            if case .album = item {
                PromoAlbumBadge(feedback: feedback.state(for: item.id))
                    .zoomSourceCaption(captionRoute)
                    .showcaseSwappable()
                    .modifier(PromoReveal(isShown: isShown, hiddenScale: ShowcasePromoMotion.pairHiddenScale, anchor: .leading))
                    .padding(.leading, 8)
                    .padding(.top, 8)
                    .allowsHitTesting(false)
                    .promoLayer(enabled: depthEnabled, depth: PromoDepthMotion.pairDepth, alignment: .topLeading)
            }
        }
        .overlay(alignment: pair.alignment) {
            // Пара — у центральной и соседей: стеклянных кнопок у всех 18 слотов не
            // держим. Сосед в окне — чтобы пара ушедшей с центра догасла, а не пропала.
            // У карточки «Продолжить» пары нет — на её месте кнопка (ниже).
            if !petalLayout, item.promoResume == nil, abs(slotIndex - (currentPage ?? slotIndex)) <= 1 {
                ShowcaseFeedbackPair(introEligible: isShown, usesIntroDesign: true, usesPromoReactions: true,
                                     usesSaveReaction: settings.promoSaveV2Enabled, recommendation: item)
                    .zoomSourceCaption(captionRoute)
                    .allowsHitTesting(!fixedPreview)
                    .modifier(PromoReveal(
                        isShown: isShown,
                        hiddenScale: ShowcasePromoMotion.pairHiddenScale,
                        anchor: pair.anchor
                    ))
                    .rotationEffect(pair.rotation)
                    .offset(pair.offset)
                    .promoLayer(enabled: depthEnabled, depth: PromoDepthMotion.pairDepth, alignment: pair.alignment)
            }
        }
        .overlay(alignment: .topLeading) {
            if petalLayout, case .vibe(let vibe) = item {
                VStack(spacing: 24) {
                    PromoStationCaption(title: vibe.title, station: vibe.promoStation)
                        .zoomSourceCaption(captionRoute)
                        .showcaseSwappable()
                        .allowsHitTesting(false)
                        .modifier(LiftWave(
                            trigger: pulse?.trigger ?? 0,
                            origin: CGPoint(x: waveOrigin.x - Layout.stationCaptionOrigin.x,
                                            y: waveOrigin.y - Layout.stationCaptionOrigin.y),
                            enabled: waveEnabled,
                            overflow: PromoStationLayout.captionWaveOverflow(scale: Layout.stationScale),
                            scale: Layout.stationScale
                        ))
                    if abs(slotIndex - (currentPage ?? slotIndex)) <= 1 {
                        ShowcaseFeedbackPair(introEligible: isShown, usesIntroDesign: true, usesPromoReactions: true,
                                             usesSaveReaction: settings.promoSaveV2Enabled, recommendation: item)
                            .zoomSourceCaption(captionRoute)
                            .allowsHitTesting(!fixedPreview)
                            .modifier(PromoReveal(isShown: isShown,
                                                  hiddenScale: ShowcasePromoMotion.pairHiddenScale,
                                                  anchor: .center))
                    }
                }
                .frame(width: Layout.stationCaptionWidth)
                .offset(x: Layout.stationCaptionOrigin.x, y: Layout.stationCaptionOrigin.y)
                .promoLayer(enabled: depthEnabled, depth: PromoDepthMotion.captionDepth, alignment: .topLeading)
            }
        }

        .overlay(alignment: .bottomLeading) {
            if case .album(let album) = item {
                // Высота подписи — ровно аватар: от низа обложки она сдвинута на зазор
                // и свою высоту. `alignmentGuide` в оверлее не сработал (кадр 2026-10-08:
                // подпись легла на обложку).
                // Подпись — отдельная кнопка в оверлее, не внутри кнопки карточки: тап
                // по ней открывает исполнителя, по обложке — альбом. Нажимаема только
                // пока видна (`PromoReveal`).
                PromoAlbumCaption(album: album, onArtist: album.artistRoute == nil ? nil : { openArtist(item) })
                    .zoomSourceCaption(captionRoute)
                    .showcaseSwappable()
                    .modifier(PromoReveal(isShown: isShown, hiddenScale: ShowcasePromoMotion.pairHiddenScale, anchor: .leading))
                    .offset(x: Layout.albumCaptionLeading, y: Layout.albumCaptionGap + Layout.albumAvatar)
                    .promoLayer(enabled: depthEnabled, depth: PromoDepthMotion.captionDepth, alignment: .bottomLeading)
            }
        }

        .overlay(alignment: .top) {
            if let caption = item.promoCaption {
                // Имя исполнителя — показывается, как подпись альбома: только у центральной,
                // когда встала. Не нажимается.
                PromoCenteredCaption(title: caption)
                    .zoomSourceCaption(captionRoute)
                    .showcaseSwappable()
                    .modifier(PromoReveal(isShown: isShown, hiddenScale: ShowcasePromoMotion.pairHiddenScale, anchor: .top))
                    .offset(y: Layout.artist + Layout.centeredCaptionTop)
                    .promoLayer(enabled: depthEnabled, depth: PromoDepthMotion.captionDepth, alignment: .top)
            }
        }
    }

    private func zoomID(_ item: ShowcaseBlock, slotIndex: Int, isCurrent: Bool) -> AnyHashable {
        // «Продолжить» книги экрана не открывает — источником зума не становится; фильм
        // открывает экран тайтла, как обычная карточка.
        if isCurrent, item.opensPlayerOnTap == false, let route = item.entityRoute { return AnyHashable(route) }
        return AnyHashable("showcase-promo-copy-\(slotIndex)")
    }

    /// Тап по центральной — её экран; по соседу — сосед доезжает в центр. Станция «Моей
    /// волны» своего экрана не имеет: центральная включает волну, как карточка ленты.
    /// «Продолжить» фильма — экран тайтла, плеер только по кнопке (правка пользователя
    /// 2026-10-14); «Продолжить» книги — сразу читалка, как его кнопка.
    private func tap(_ item: ShowcaseBlock, slotIndex: Int, isCurrent: Bool) {
        guard removal == nil, !(fixedPreview && isCurrent) else { return }
        tapHaptic()
        guard isCurrent else {
            PromoIntroSession.shared.interact()
            withAnimation(ShowcasePromoMotion.step) { page = slotIndex }
            return
        }
        if item.opensPlayerOnTap, let resume = item.promoResume {
            actionBar.open(resume)
            return
        }
        if case .vibe(let vibe) = item {
            playingPetalID = item.id
            actionBar.openMyVibe()
            if let station = VibeStation.all.first(where: { $0.title == vibe.promoStation.name }) {
                actionBar.recently.record(.station(station.id))
            }
            if HomePresentationSettings.shared.promoLiftWaveEnabled, actionBar.isMusicPlaying {
                let slot = PromoSlotID(copy: slotIndex / max(count, 1), item: item.id)
                // Кнопка и SpatialTapGesture могут завершиться в любом порядке.
                // Следующий проход MainActor читает уже записанную точку этого тапа.
                Task { @MainActor in
                    await Task.yield()
                    guard HomePresentationSettings.shared.promoLiftWaveEnabled,
                          actionBar.isMusicPlaying, pageID == slot else { return }
                    let size = Layout.stationSize
                    petalWave.launch(at: slot, fallbackOrigin: CGPoint(x: size.width / 2, y: size.height / 2),
                                     time: ProcessInfo.processInfo.systemUptime)
                }
            }
            return
        }
        if let route = item.entityRoute { navigation.open(route) }
    }

    /// Тап по подписи альбома — экран исполнителя. Пока карточку убирают по ✕ или она
    /// меняется — не открывается. Источника зума нет, как в `AlbumScreen.openArtist`.
    private func openArtist(_ item: ShowcaseBlock) {
        guard removal == nil,
              !feedback.state(for: item.id).isSwapping,
              case .album(let album) = item,
              let route = album.artistRoute
        else { return }
        tapHaptic()
        navigation.open(route)
    }

    private func tapHaptic() {
        hasInteracted = true
        UIImpactFeedbackGenerator(style: .medium)
            .impactOccurred(intensity: ShowcaseMotion.tapHapticIntensity)
    }

    // MARK: ✕ — айтем уходит из круга

    /// Карточка гаснет; ряд схлопывается — правая соседка едет в центр, зазор закрывается
    /// тем же движением; айтем уходит из набора. Пока карточка гаснет, каталог готовит
    /// новый айтем, и он встаёт в круг сразу за соседкой — за краем экрана, в схлопывании
    /// подъезжает справа. Все перестановки набора — без анимации и с пересчётом центра
    /// в той же транзакции: на экране ничего не дёргается.
    private func remove(slot: Int) {
        let promo = liveItems
        guard !promo.isEmpty else { return }
        let removed = promo[Self.wrap(slot, promo.count)]
        let state = feedback.state(for: removed.id)
        guard removal == nil, slot == page, promo.count > 1 else {
            state.isSwapping = false
            return
        }
        hasInteracted = true
        swipeHaptics.reset()
        removal = slot
        revealTask?.cancel()
        withAnimation(ShowcaseFeedbackMotion.swapOut) { state.isContentHidden = true }

        Task { @MainActor in
            async let prepared = catalog.preparePromoAddition(for: removed)
            try? await Task.sleep(for: ShowcasePromoMotion.collapseDelay)
            let addition = await prepared
            let current = liveItems
            guard addition != nil || current.count > Self.minimumItems,
                  let removedIndex = current.firstIndex(where: { $0.id == removed.id })
            else {
                // Пополнить нечем, а убирать дальше некуда — айтем проявляется прежним.
                withAnimation(ShowcaseFeedbackMotion.swapIn) { state.isContentHidden = false }
                try? await Task.sleep(for: ShowcaseFeedbackMotion.swap)
                state.isSwapping = false
                removal = nil
                scheduleReveal()
                return
            }
            let next = current[(removedIndex + 1) % current.count]
            if let addition {
                editSet {
                    // Соседка — карточка «Продолжить» (✕ у последнего айтема каталога):
                    // в наборе каталога её нет, новый айтем — в его начало, сразу за ними.
                    // Иначе каталог дописал бы его в конец — между убранным и соседкой.
                    catalog.insertPromo(addition, after: next.promoResume == nil ? next.id : nil)
                    center(on: removed.id)
                    removal = page
                }
                // Перестановка ложится в свой проход до старта схлопывания.
                try? await Task.sleep(for: ShowcasePromoMotion.editSettle)
                // Страховка: если прикалывание в `onChange` уже отработало — no-op.
                pinToEditAnchor()
            }
            withAnimation(ShowcasePromoMotion.collapse) {
                collapse = 1
            } completion: {
                var undoRemoval: (@MainActor () -> Void)?
                editSet {
                    undoRemoval = catalog.removePromo(id: removed.id)
                    feedback.remove(removed.id)
                    removal = nil
                    collapse = 0
                    center(on: next.id)
                }
                if let undoRemoval {
                    ToastCenter.shared.showDislikedRecommendation(title: PromoFeedbackCopy.disliked()) {
                        editSet {
                            undoRemoval()
                            if removal == nil { center(on: removed.id) }
                        }
                        scheduleReveal()
                    }
                }
                scheduleReveal()
            }
        }
    }

    /// Перестановка набора самим слайдером — без анимации, одной транзакцией с центром.
    private func editSet(_ change: () -> Void) {
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) {
            isEditingSet = true
            change()
            editAnchor = pageID
        }
        trace("edit")
    }

    /// После перестановки набора раскладка сдвигается на шаг (вставка перед центром), а
    /// ключ центрального слота прежний — лента сама не едет. Явно ставим её на сохранённый
    /// якорь, когда `items` и раскладка уже новые; мгновенной транзакцией.
    private func pinToEditAnchor() {
        guard let anchor = editAnchor else { return }
        trace("pin anchor=\(anchor.copy)/\(anchor.item)")
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) {
            pageID = anchor
            scrollProxy?.scrollTo(anchor, anchor: .center)
        }
    }

    /// Айтем `id` — в центр, в средней копии.
    private func center(on id: String) {
        let promo = liveItems
        guard let index = promo.firstIndex(where: { $0.id == id }) else { return }
        page = promo.count + index
        scroll.position = CGFloat(promo.count + index)
        savedIndex = index
    }

    /// Набор сменил каталог — центральный айтем остаётся в центре, если он в наборе.
    private func recenter(new: [String]) {
        guard !new.isEmpty else { return }
        // Центральный айтем — по ключу слота: каталог уже сменил набор, и номер места
        // в новом наборе указывал бы на чужой айтем.
        let centered = pageID?.item
        // Центрального айтема в новом наборе нет (мок сменился живым, порция каталога) —
        // то же место ряда, а не начало: иначе случайный старт (2026-10-14) всякий раз
        // съезжал на первую карточку.
        let preferred = centered.flatMap { new.firstIndex(of: $0) } ?? (savedIndex % new.count)
        let index = hasInteracted ? preferred : (HomePromoStartPolicy.index(in: liveItems, preferred: preferred) {
            $0.homePromoKind == .artist
        } ?? 0)
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) {
            page = new.count + index
            scroll.position = CGFloat(new.count + index)
            savedIndex = index
            editAnchor = pageID
        }
        trace("recenter new=\(new.count) index=\(index)")
        // Диагноз (2026-10-10, задача 16). Витрина публикует промо порциями (кино, музыка,
        // книги — `publishPromo`), и набор меняется уже после монтирования слайдера: число
        // айтемов в копии растёт, и центральный айтем во второй копии уезжает на другое
        // место ряда. До f519c7e место было числом, `page` менялся, и биндинг двигал ленту.
        // С ключом слота `(копия, id)` ключ центрального айтема тот же — команды скролла нет,
        // лента остаётся на старом offset и показывает в центре соседа, а `pageID` указывает
        // на сдвинутого. Первое ✕ и `pinToEditAnchor` выравнивали их скачком. Ставим ленту
        // на ключ явно, когда раскладка новая, — как после перестановки набора.
        pinToEditAnchor()
        Task { @MainActor in
            try? await Task.sleep(for: ShowcasePromoMotion.editSettle)
            guard removal == nil, !isEditingSet else { return }
            pinToEditAnchor()
        }
        scheduleReveal()
    }

    // MARK: Круг и проявление

    /// Стартовая позиция по id приходит раньше раскладки, и лента вставала на нулевой
    /// слот — у левого края круга, без соседа слева (кадр 2026-10-09). Первая геометрия
    /// после раскладки ставит ленту на стартовую карточку — без анимации. Тот же приём,
    /// что у стартового чипса `FilterChipsRow`, только без паузы: геометрия приходит
    /// уже после раскладки.
    private func placeIfNeeded(at position: CGFloat, proxy: ScrollViewProxy) {
        guard !isPlaced, let target = pageID, let place = page else { return }
        isPlaced = true
        trace("place position=\(position) place=\(place)")
        guard abs(position - CGFloat(place)) > 0.01 else { return }
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) { proxy.scrollTo(target, anchor: .center) }
    }

    /// Свайп остановился: запомнить айтем и, если это крайняя копия, перескочить на ту же
    /// карточку средней — без анимации, картинка та же.
    private func settle() {
        let count = liveItems.count
        guard count > 0, let current = page else { return }
        let index = Self.wrap(current, count)
        savedIndex = index
        let middle = count + index
        trace("scroll idle current=\(current) middle=\(middle)")
        guard current != middle else { return }
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) {
            page = middle
            scroll.position += CGFloat(middle - current)
        }
    }

    private func scheduleReveal() {
        revealTask?.cancel()
        let promo = liveItems
        guard !promo.isEmpty, let current = page else { return }
        let id = promo[Self.wrap(current, promo.count)].id
        revealTask = Task { @MainActor in
            try? await Task.sleep(for: ShowcasePromoMotion.revealDelay)
            guard !Task.isCancelled else { return }
            withAnimation(ShowcasePromoMotion.revealIn) { revealed = id }
        }
    }

    private func hideReveal() {
        revealTask?.cancel()
        guard revealed != nil else { return }
        withAnimation(ShowcasePromoMotion.revealOut) { revealed = nil }
    }

    private static func wrap(_ index: Int, _ count: Int) -> Int {
        ((index % count) + count) % count
    }

    /// `-debugPromoTrace 1` — события ленты и состояние в консоль: кто и когда двигает
    /// `pageID`, чтобы сверить его с видимым центром (`scroll.position`).
    private func trace(_ event: String) {
        #if DEBUG
        guard UserDefaults.standard.bool(forKey: "debugPromoTrace") else { return }
        let slot = pageID.map { "\($0.copy)/\($0.item)" } ?? "nil"
        print("[promo] \(event) pageID=\(slot) page=\(page.map(String.init) ?? "nil") position=\(scroll.position) count=\(liveItems.count)")
        #endif
    }
}

/// Масштаб, наклон и опускание карточки — от её места в ленте, кадр в кадр. `shift` —
/// схлопывание ряда по ✕: карточка правее убранной уже сдвинута на эту долю шага, и её
/// вид считается от места, куда она едет. Модификатор анимируемый: `shift` идёт
/// кадрами анимации, а не скачком между концами.
private struct PromoCardMotion: ViewModifier, Animatable {
    let look: PromoCardLook
    let kind: HomePromoKind
    let slotIndex: Int
    let spacing: PromoCarouselSpacing?
    let collapsedSpacing: PromoCarouselSpacing?
    let removal: Int?
    var collapse: CGFloat
    private var shift: CGFloat { removal.map { slotIndex > $0 ? collapse : 0 } ?? 0 }
    var visibleCount: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var animatableData: CGFloat {
        get { collapse }
        set { collapse = newValue }
    }

    func body(content: Content) -> some View {
        // Всё, что зависит от ширины экрана, берётся здесь, на главном потоке: замыкание
        // `visualEffect` не изолировано.
        let step = ShowcasePromoLayout.step
        let viewportWidth = PlusMetrics.screenWidth
        let settings = HomePresentationSettings.shared
        let geometry = ShowcasePromoLayout.geometry
        let additionalDrop = settings.legacySideOffsetEnabled ? CGFloat(settings.legacySideOffset) : 0
        let drop = geometry.neighbourDrop(additionalOffset: additionalDrop)
        let upright = settings.uprightEnabled
        let sideAngle = settings.sideAngle
        let depth = settings.promoDepthEnabled && !reduceMotion
        let card = geometry.card(for: kind)
        let sideScale = CGSize(width: card.neighbour.width / card.main.width,
                               height: card.neighbour.height / card.main.height)
        return content.visualEffect { [look, shift, collapse, upright, sideAngle, sideScale, depth] content, proxy in
            let rawPosition = ShowcasePromoLayout.position(of: proxy, step: step)
            let position = rawPosition - shift
            let horizontalOffset = spacing.map {
                let start = $0.center(of: CGFloat(slotIndex), scrollPosition: CGFloat(slotIndex) - rawPosition)
                let center: CGFloat
                if let removal, let collapsedSpacing {
                    let endIndex = slotIndex > removal ? slotIndex - 1 : slotIndex
                    let end = collapsedSpacing.center(of: CGFloat(endIndex), scrollPosition: CGFloat(removal))
                    center = start + (end - start) * collapse
                } else {
                    center = start
                }
                return center - viewportWidth / 2 - rawPosition * step
            } ?? (-shift * step)
            let distance = ShowcasePromoLayout.ease(abs(position))
            let magnitude = look.centerTilt + (look.sideTilt - look.centerTilt) * Double(distance)
            // Знак чередуется по местам ряда: −1 по центру, +1 у соседей, −1 через одну.
            // Косинус меняет его плавно по ходу свайпа — карточка проходит через ноль,
            // без щелчка, — и не зависит от копии круга и от состава набора.
            let tilt = upright
                ? sideAngle * Double(distance) * (position < 0 ? -1 : 1)
                : -magnitude * cos(Double.pi * Double(position))
            return content
                .scaleEffect(x: 1 + (sideScale.width - 1) * distance,
                             y: 1 + (sideScale.height - 1) * distance)
                .opacity(PromoViewportSizing.visibility(at: position, count: visibleCount))
                .rotationEffect(.degrees(tilt))
                .rotation3DEffect(
                    .degrees(depth ? -PromoDepthMotion.yaw * Double(PromoDepthMotion.swing(position)) : 0),
                    axis: (x: 0, y: 1, z: 0), perspective: PromoDepthMotion.perspective
                )
                .rotation3DEffect(
                    .degrees(depth ? PromoDepthMotion.pitch * Double(distance) : 0),
                    axis: (x: 1, y: 0, z: 0), perspective: PromoDepthMotion.perspective
                )
                .offset(x: horizontalOffset, y: drop * distance)
        }
    }
}

/// Состояния пар ✕/✓ по id айтема. Не наблюдаемый: словарь достраивается прямо в `body`,
/// наблюдаются сами состояния.
@MainActor
private final class PromoFeedbackStore {
    private var states: [String: ShowcaseFeedbackState] = [:]

    func state(for id: String) -> ShowcaseFeedbackState {
        if let state = states[id] { return state }
        let state = ShowcaseFeedbackState()
        states[id] = state
        return state
    }

    func remove(_ id: String) {
        states[id] = nil
    }
}

/// Где лента — для фона: дробный слот в центре и счётчик досчитанных растров. Пишется
/// на кадрах скролла, но читает его только фон — перерисовывается он один.
@MainActor
@Observable
private final class PromoScrollState {
    var position: CGFloat {
        didSet {
            let next = Int(position.rounded())
            if nearestSlot != next { nearestSlot = next }
        }
    }
    private(set) var nearestSlot: Int
    var rasters = 0

    init(position: CGFloat) {
        self.position = position
        self.nearestSlot = Int(position.rounded())
    }
}

// MARK: - Карточка

/// Случайный вид карточки — величина наклона и опускание, свои у каждого айтема и одни у всех его
/// копий (иначе перескок на среднюю копию был бы виден). Случайность — от id и соли
/// процесса: на холодном запуске наклоны другие.
private struct PromoCardLook {
    let centerTilt: Double
    let sideTilt: Double

    init(id: String) {
        var hasher = Hasher()
        hasher.combine(id)
        var generator = SeededGenerator(seed: UInt64(bitPattern: Int64(hasher.finalize())))
        // Только величины: знак задаёт место в ряду (`PromoCardMotion`).
        centerTilt = Double.random(in: ShowcasePromoLayout.centerTilt, using: &generator)
        sideTilt = Double.random(in: ShowcasePromoLayout.sideTilt, using: &generator)
    }
}

/// Обложка айтема в своих пропорциях: постер фильма 2:3, квадрат альбома, книга
/// в проекции (`BookFigure`, как в сетке выдачи), круг исполнителя размером с альбом,
/// лепесток станции (`PromoStationCard`, кадр 208×249).
private struct PromoCardFace: View {
    let item: ShowcaseBlock
    var breathing = false
    var depthEnabled = false
    var waveEnabled = false
    var waveTrigger = 0
    var waveOrigin = CGPoint.zero

    private typealias Layout = ShowcasePromoLayout

    var body: some View {
        let square = CGSize(width: Layout.album, height: Layout.album)
        switch item {
        case .movie(let movie):
            cover(movie.poster, size: Layout.poster, radius: Layout.posterRadius)
                .showcaseSwappable()
        case .album(let album):
            cover(album.cover, size: square, radius: Layout.albumRadius)
                .showcaseSwappable()
        case .book(let book):
            let figure = Layout.book
            BookFigure(geometry: figure.geometry, coverWidth: figure.coverWidth) {
                SkeletonArtwork(source: book.cover)
            }
            .showcaseSwappable()
        case .artist(let artist):
            cover(artist.picture, size: CGSize(width: Layout.artist, height: Layout.artist), shape: Circle())
                .showcaseSwappable()
        case .vibe(let vibe):
            // Смена по ✕ — на слоях лепестка по отдельности, внутри него.
            PromoStationCard(title: vibe.title, station: vibe.promoStation,
                             showsCaption: false, breathing: breathing,
                             artDepth: depthEnabled ? PromoDepthMotion.artDepth : 0)
                .modifier(LiftWave(trigger: waveTrigger, origin: waveOrigin, enabled: waveEnabled,
                                   overflow: PromoStationLayout.waveOverflow(scale: Layout.stationScale),
                                   scale: Layout.stationScale))
        case .reading, .watching:
            EmptyView()
        }
    }

    private func cover(_ source: ArtworkSource, size: CGSize, radius: CGFloat) -> some View {
        cover(source, size: size, shape: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    private func cover<S: InsettableShape>(_ source: ArtworkSource, size: CGSize, shape: S) -> some View {
        PlusSkeleton.fill
            .overlay { SkeletonArtwork(source: source) }
            .frame(width: size.width, height: size.height)
            .clipShape(shape)
            .coverBorder(shape)
    }
}

/// Подпись исполнителя (задача 64): одна строка Text M по центру колонки шириной
/// с квадрат альбома. Без кнопок — касание проходит к карточке.
private struct PromoCenteredCaption: View {
    let title: String

    var body: some View {
        Text(title)
            .plusText(.textM, .medium)
            .foregroundStyle(Color.fillOne)
            .lineLimit(1)
            .multilineTextAlignment(.center)
            .frame(width: ShowcasePromoLayout.artist)
            .allowsHitTesting(false)
    }
}

/// Подпись альбома (макет `2537:27595`): аватар исполнителя, название альбома
/// и исполнитель. Без фото исполнителя — без аватара: выдумывать его нельзя.
private struct PromoAlbumCaption: View {
    let album: AlbumBlock
    /// Тап по подписи — экран исполнителя. `nil` — id исполнителя нет: подпись не
    /// нажимается и пропускает касание, как была.
    var onArtist: (() -> Void)?

    private typealias Layout = ShowcasePromoLayout

    var body: some View {
        tappable
            .frame(width: Layout.albumCaptionWidth, height: Layout.albumAvatar, alignment: .leading)
    }

    /// Кнопка — по размеру содержимого: просадка идёт от его центра, а внешний кадр
    /// подписи остаётся прежним.
    @ViewBuilder
    private var tappable: some View {
        if let onArtist {
            Button(action: onArtist) {
                content.contentShape(.rect)
            }
            .buttonStyle(PressScaleButtonStyle(pressedScale: PressMotion.cardScale))
            .accessibilityLabel(album.title)
        } else {
            content.allowsHitTesting(false)
        }
    }

    private var content: some View {
        HStack(spacing: Layout.albumCaptionSpacing) {
            if let picture = album.artistPicture {
                PlusSkeleton.fill
                    .overlay { SkeletonArtwork(source: picture) }
                    .frame(width: Layout.albumAvatar, height: Layout.albumAvatar)
                    .clipShape(Circle())
                    .coverBorder(Circle())
            }
            // У альбома витрины `title` — исполнитель, `subtitle` — название.
            VStack(alignment: .leading, spacing: -Layout.albumCaptionLineOverlap) {
                Text(album.subtitle)
                    .plusText(.textM, .medium)
                    .foregroundStyle(Color.fillOne)
                Text(album.title)
                    .plusText(.textM, .medium)
                    .foregroundStyle(Color.fillSubtitle)
            }
            .lineLimit(1)
        }
        .padding(.trailing, Layout.albumCaptionTrailing)
    }
}

/// Пара и подпись альбома появляются прозрачностью и лёгким масштабом от своего края
/// (правка пользователя 2026-10-10: подпись — как пара).
/// С «уменьшением движения» — одной прозрачностью.
private struct PromoReveal: ViewModifier {
    let isShown: Bool
    var hiddenScale: CGFloat = 1
    var anchor: UnitPoint = .center
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(isShown || reduceMotion ? 1 : hiddenScale, anchor: anchor)
            .opacity(isShown ? 1 : 0)
            .allowsHitTesting(isShown)
            .accessibilityHidden(!isShown)
    }
}

/// Где пара ✕/✓ у карточки вида: угол кадра лица, сдвиг от него, край, от которого она
/// проявляется (`PromoReveal`), и поворот. Фильм, книга и альбом — у верхней кромки справа,
/// исполнитель — по касательной к кругу, станция — внутри лепестка.
private struct PromoPairPlacement {
    let alignment: Alignment
    let offset: CGSize
    let anchor: UnitPoint
    let rotation: Angle

    private typealias Layout = ShowcasePromoLayout

    @MainActor
    init(_ item: ShowcaseBlock) {
        switch item {
        case .album:
            self.init(
                alignment: .topTrailing,
                offset: CGSize(width: -Layout.albumPairTrailing, height: -Layout.albumPairAbove),
                anchor: .trailing
            )
        case .artist:
            // От центра круга; проявляется от своей середины.
            self.init(alignment: .center, offset: Layout.artistPairOffset, anchor: .center, rotation: Layout.artistPairAngle)
        case .vibe:
            let origin = PromoStationLayout.pairOrigin
            self.init(
                alignment: .topLeading,
                offset: CGSize(width: origin.x * Layout.stationScale, height: origin.y * Layout.stationScale),
                anchor: .center
            )
        case .movie:
            self.init(alignment: .topTrailing, offset: CGSize(width: -8, height: -PlusMetrics.circleButton / 2), anchor: .topTrailing)
        case .book:
            let inset: CGFloat = 0
            self.init(alignment: .topTrailing, offset: CGSize(width: -8 - inset, height: inset - PlusMetrics.circleButton / 2), anchor: .topTrailing)
        case .reading, .watching:
            self.init(
                alignment: .bottomLeading,
                offset: CGSize(width: Layout.pairLeading, height: Layout.pairBelow),
                anchor: .leading
            )
        }
    }

    private init(alignment: Alignment, offset: CGSize, anchor: UnitPoint, rotation: Angle = .zero) {
        self.alignment = alignment
        self.offset = offset
        self.anchor = anchor
        self.rotation = rotation
    }
}

// MARK: - Фон

/// Each layer stays mounted, including while crossing the middle-copy boundary.
private struct PromoSwipeGlow: View {
    let item: ShowcaseBlock
    let shift: CGFloat
    let rasters: Int

    var body: some View {
        let step = ShowcasePromoLayout.step
        let canvas = PromoCardGlowRaster.canvas(item)
        let drop: CGFloat = item.homePromoKind == .station
            ? 24 : 0
        ZStack {
            if let image = PromoCardGlowRaster.cached(item) {
                Image(uiImage: image).resizable()
                    .frame(width: canvas.width, height: canvas.height)
            }
        }
        .frame(width: step, height: ShowcasePromoLayout.height, alignment: .top)
        .offset(y: ShowcasePromoLayout.cardCenterY - canvas.height / 2 + drop)
        .visualEffect { content, proxy in
            let position = ShowcasePromoLayout.position(of: proxy, step: step)
            let weight = max(0, 1 - abs(position - shift))
            return content
                .offset(x: -position * step)
                .opacity(Double(weight) * PromoCardGlowConfig.opacity)
        }
        .blendMode(.plusLighter)
    }
}
