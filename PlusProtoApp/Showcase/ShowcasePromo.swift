import SwiftUI
import UIKit

/// Числа промо-слайдера «Главной» — макет `2532:26618`. Холст макета 440, раскладка
/// перенесена на 402 от центра экрана: размеры карточек и отступы от центра — как есть.
enum ShowcasePromoLayout {
    /// Шаг между центрами карточек: соседи выглядывают из-за краёв экрана
    /// (в макете центры соседей на ±188 от центра).
    static let step: CGFloat = 188
    /// Соседи меньше центральной: книга сбоку 161.56 против постера в центре 210.16.
    static let sideScale: CGFloat = 0.769
    /// Центр центральной карточки — от верха блока (низа навигации). В макете 185;
    /// на 10 выше — «отступ до навбара немного меньше» (правка пользователя 2026-10-08).
    static let cardCenterY: CGFloat = 175
    static var carouselHeight: CGFloat { cardCenterY * 2 }

    /// Наклон у каждой карточки свой, случайный, знак — тоже (в макете −3° у центральной,
    /// +5.03° и +5.94° у соседей): по центру 2…4°, сбоку 4.5…6.5°.
    static let centerTilt: ClosedRange<Double> = 2...4
    static let sideTilt: ClosedRange<Double> = 4.5...6.5
    /// Соседи ниже центральной — на 6…16, у каждой карточки своё (в макете 16 и 6).
    static let sideDrop: ClosedRange<Double> = 6...16

    /// Карточки по центру — по виду. Сбоку они те же, уменьшенные на `sideScale`:
    /// альбом сбоку 169, скругление 18 — в центре 219.8 и 23.4.
    static let poster = CGSize(width: 210.155, height: 315.235)
    static let posterRadius: CGFloat = 16.358
    static let album: CGFloat = 219.8
    static let albumRadius: CGFloat = 23.4
    static let bookWidth: CGFloat = 210.155

    /// Пара ✕/✓ у фильма и книги — у нижней кромки карточки: левый край на 24.6 от её
    /// левой кромки, низ пары — на 27.6 ниже низа карточки (заходит на неё на 12).
    static let pairLeading: CGFloat = 24.6
    static let pairBelow: CGFloat = 27.6
    /// У альбома — у верхней кромки справа (макет `2537:27595`): правый край на 14.5
    /// от правой кромки обложки, верх — на 22.5 выше её верха. Замер — в системе
    /// координат повёрнутой обложки.
    static let albumPairTrailing: CGFloat = 14.5
    static let albumPairAbove: CGFloat = 22.5

    /// Описание фильма и книги — под карточкой: Text S в четыре строки шириной 244;
    /// левый край на 97 левее центра экрана, то есть центр строки на 25 правее.
    /// Сверху — на 39.4 ниже низа своей карточки (у постера макета: 382 − 342.6).
    static let descriptionGap: CGFloat = 39.4
    static let descriptionWidth: CGFloat = 244
    static let descriptionShift: CGFloat = 25
    static let descriptionLines = 4
    static var descriptionHeight: CGFloat { CGFloat(descriptionLines) * PlusTextSize.textS.lineHeight }

    /// Подпись альбома (макет `2537:27595`) — аватар исполнителя 40, справа название
    /// альбома и исполнитель Text M. Наклонена вместе с обложкой: левый край на 3.3
    /// правее её левой кромки, верх — на 7.2 ниже низа (замер в системе обложки).
    /// Ширина 227 с полем справа 8; строки заходят друг на друга на 2.
    static let albumCaptionLeading: CGFloat = 3.3
    static let albumCaptionGap: CGFloat = 7.2
    static let albumCaptionWidth: CGFloat = 227
    static let albumCaptionTrailing: CGFloat = 8
    static let albumCaptionSpacing: CGFloat = 8
    static let albumCaptionLineOverlap: CGFloat = 2
    static let albumAvatar: CGFloat = 40

    /// Высота блока — до низа описания под самой высокой карточкой, постером: место
    /// держится всегда, и лента ниже не прыгает от айтема к айтему.
    static var height: CGFloat { descriptionTop(cardHeight: poster.height) + descriptionHeight }

    static func descriptionTop(cardHeight: CGFloat) -> CGFloat {
        cardCenterY + cardHeight / 2 + descriptionGap
    }

    /// Высота карточки айтема по центру — по виду.
    static func cardHeight(_ item: ShowcaseBlock) -> CGFloat {
        switch item {
        case .movie, .vibe, .reading, .watching:
            return poster.height
        case .album:
            return album
        case .book:
            let figure = BookFigureGeometry.fitting(width: bookWidth, aspect: nil)
            return figure.geometry.frameSize(coverWidth: figure.coverWidth).height
        }
    }

    /// Фон — картинка центральной карточки вдвое шире экрана, размытая: от физического
    /// верха экрана до низа блока и ещё немного ниже, в чёрный.
    static let backdropWidth: CGFloat = PlusMetrics.designWidth * 2
    static let backdropTail: CGFloat = 64
    /// Сколько фон уходит выше блока — до физического верха экрана.
    static var backdropAbove: CGFloat { ServiceTopNavLayout.topSafeArea + ServiceTopNavLayout.rowHeight }
    static var backdropHeight: CGFloat { backdropAbove + height + backdropTail }
    /// Фон — на 70 %, на 10 % прозрачнее фона промо сервисов (правка пользователя
    /// 2026-10-08).
    static let backdropOpacity: Double = 0.7

    /// Где слот относительно центра видимой ленты: 0 — по центру, ±1 — на месте соседа.
    /// Считается от рамки скролла, а не экрана: ширина устройства не важна.
    static func position(of proxy: GeometryProxy) -> CGFloat {
        guard let viewport = proxy.bounds(of: .scrollView) else { return 0 }
        return (proxy.size.width / 2 - viewport.midX) / step
    }

    /// Smoothstep от доли сдвига: у линейной рампы излом в центре и на месте соседа —
    /// карточка начинала расти и наклоняться щелчком, а не плавно (правило проекта для
    /// скролл-эффектов).
    static func ease(_ u: CGFloat) -> CGFloat {
        let x = min(max(u, 0), 1)
        return x * x * (3 - 2 * x)
    }
}

enum ShowcasePromoMotion {
    /// Пара ✕/✓ и описание проявляются вместе (правка пользователя 2026-10-08) и не
    /// сразу, а когда карточка встала в центр: пауза, затем короткий сильный ease-out.
    /// Пауза 100 мс — «уменьши задержку» (правка пользователя 2026-10-08, было 250).
    static let revealDelay: Duration = .milliseconds(100)
    static let revealIn: Animation = .timingCurve(0.23, 1, 0.32, 1, duration: 0.3)
    /// Свайп начался — уходят быстро: они отвечают только за центральную карточку.
    static let revealOut: Animation = .easeOut(duration: 0.15)
    static let pairHiddenScale: CGFloat = 0.9
    /// Тап по соседу — он доезжает в центр
    static let step: Animation = .smooth(duration: 0.4)
    /// ✕: карточка гаснет, как при смене айтема в ленте (`ShowcaseFeedbackMotion.swapOut`,
    /// 400 мс), затем ряд схлопывается — правая карточка едет в центр, зазор закрывается
    /// тем же движением (задача пользователя 2026-10-08). Движение по экрану — ease-in-out.
    static let collapse: Animation = .timingCurve(0.4, 0, 0.2, 1, duration: 0.45)
    /// Сдвиг начинается на хвосте угасания, когда карточки почти не видно (ease-in-out
    /// к 300 мс из 400 прошёл ~93 %): после полного угасания стояла мёртвая пауза
    /// с пустым центром (кадр 2026-10-08).
    static let collapseDelay: Duration = .milliseconds(300)
}

/// Промо-слайдер «Главной» (макет `2532:26618`, задача пользователя 2026-10-08):
/// фильмы, альбомы и книги по кругу, в обе стороны, по одной карточке за свайп.
///
/// Центральная крупнее соседей, у каждой карточки свой случайный наклон; масштаб, наклон
/// и опускание соседей идут за сдвигом ленты кадр в кадр (`visualEffect`, без стейта).
/// Описание и пара ✕/✓ — только у центральной и вместе: с паузой, когда карточка
/// встала. Фон — размытая картинка центральной, меняется вслед за сдвигом.
///
/// ✕ не подменяет айтем, а убирает его из круга: карточка гаснет, ряд схлопывается,
/// правая соседка встаёт в центр. Чтобы набор не кончился, в круг сразу за ней встаёт
/// новый айтем того же вида (`ShowcaseCatalog.preparePromoAddition`).
///
/// Круг — три копии набора, как у промо Книг и Кинопоиска: работает средняя, а когда
/// свайп остановился в крайней, лента перескакивает на ту же карточку средней.
struct ShowcasePromo: View {
    let items: [ShowcaseBlock]
    let zoom: Namespace.ID
    /// Айтем на месте — на сессию (`ShowcaseCatalog.promoIndex`): экран таба
    /// размонтируется на каждом переключении, а слайдер открывается там, где оставили.
    @Binding var savedIndex: Int

    @Environment(AppNavigationState.self) private var navigation
    @Environment(ShowcaseCatalog.self) private var catalog

    private typealias Layout = ShowcasePromoLayout

    private static let copies = 3
    /// Меньше трёх айтемов круг не держит: слева и справа от центральной стоял бы один
    /// и тот же. Пополнить ✕ нечем, а айтемов столько — айтем проявляется прежним.
    private static let minimumItems = 3

    /// Карточка ленты копий в центре.
    @State private var page: Int?
    /// Айтем, у которого показаны описание и пара ✕/✓, — центральный, вставший на место.
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

    init(items: [ShowcaseBlock], zoom: Namespace.ID, savedIndex: Binding<Int>) {
        self.items = items
        self.zoom = zoom
        _savedIndex = savedIndex
        let count = max(items.count, 1)
        let start = count + savedIndex.wrappedValue % count
        _page = State(initialValue: start)
        _scroll = State(initialValue: PromoScrollState(position: CGFloat(start)))
    }

    private var count: Int { items.count }

    /// Набор как он есть сейчас — в отложенных шагах ✕ и в замыканиях задач: `items`
    /// там с того прохода, на котором их создали.
    private var liveItems: [ShowcaseBlock] { catalog.feed.promo }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                // Ряд — не ленивый: в ленивом перескок на среднюю копию кадр рисовал позицию
                // на шаг левее, по оценке, — мелькала прежняя карточка (кадр 2026-10-08),
                // а ушедшие за экран слоты держали прежний айтем. Слотов не больше 18.
                HStack(spacing: 0) {
                    ForEach(0..<(count * Self.copies), id: \.self) { index in
                        slot(index)
                    }
                }
                .scrollTargetLayout()
            }
            // По одной карточке за свайп, как бы ни бросили.
            .scrollTargetBehavior(.viewAligned(limitBehavior: .alwaysByOne))
            .contentMargins(.horizontal, (PlusMetrics.designWidth - Layout.step) / 2, for: .scrollContent)
            .scrollPosition(id: $page, anchor: .center)
            .scrollIndicators(.hidden)
            // Карточки шире слота — за краями экрана их видно.
            .scrollClipDisabled()
            .scrollDisabled(count < 2 || removal != nil)
            .frame(height: Layout.height)
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                (geometry.contentOffset.x + geometry.contentInsets.leading) / Layout.step
            } action: { _, position in
                scroll.position = position
                placeIfNeeded(at: position, proxy: proxy)
            }
            // Фон — своим слоем под лентой, от физического верха экрана до ниже блока, как
            // у промо Кинопоиска и Книг: уходит в прозрачность, а не в чёрный — ниже фон
            // ленты, — и при оттяге тянется вверх. Слоями внутри ленты он внизу обрезался
            // о фон ленты, а при оттяге открывал чёрное (правки пользователя 2026-10-08).
            .background(alignment: .bottom) {
                PromoBackdropStack(items: items, scroll: scroll, collapse: removal == nil ? 0 : collapse)
                    .padding(.bottom, -Layout.backdropTail)
            }
            .onScrollPhaseChange { _, phase in
                guard removal == nil else { return }
                if phase == .idle {
                    settle()
                    scheduleReveal()
                } else {
                    hideReveal()
                }
            }
            .onAppear { scheduleReveal() }
            // Набор собрался заново (моки → живые, под заставкой) — центральный айтем
            // остаётся в центре, если он есть в новом наборе, иначе — с начала.
            .onChange(of: items.map(\.id)) { old, new in
                guard !isEditingSet else {
                    isEditingSet = false
                    return
                }
                recenter(old: old, new: new)
            }
            // Размытые фоны — заранее, на весь набор: фон берёт готовый растр с первого кадра.
            .task(id: items.map(\.promoArtwork)) {
                for item in items {
                    _ = await PromoBackdropRaster.render(item.promoArtwork)
                    scroll.rasters += 1
                }
            }
            #if DEBUG
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
            #endif
        }
    }

    // MARK: Слот

    private func slot(_ index: Int) -> some View {
        let item = items[index % max(count, 1)]
        let look = PromoCardLook(id: item.id)
        let isShown = index == page && revealed == item.id
        let shift = removal.map { index > $0 ? collapse : 0 } ?? 0
        return ZStack(alignment: .top) {
            card(item, slotIndex: index, isShown: isShown)
                .frame(height: Layout.carouselHeight)
                .modifier(PromoCardMotion(look: look, shift: shift))

            // У альбома подпись своя — на обложке, наклонена вместе с ней (`card`).
            if !item.isAlbum {
                description(item)
                    .offset(x: Layout.descriptionShift, y: Layout.descriptionTop(cardHeight: Layout.cardHeight(item)))
                    .modifier(PromoReveal(isShown: isShown))
                    .offset(x: -shift * Layout.step)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: Layout.step, height: Layout.height, alignment: .top)
        // Центральная — поверх соседей, как в макете: в ряду правый сосед ложился
        // на её кромку. Смена — на середине свайпа, когда карточки равны и почти
        // не касаются.
        .zIndex(index == page ? 1 : 0)
        .environment(feedback.state(for: item.id))
        .environment(\.showcaseRefresh, ShowcaseRefresh(prepare: { nil }, custom: { remove(slot: index) }))
    }

    /// Карточка и пара ✕/✓ на её кромке — пара оверлеем на карточке, а не внутри кнопки:
    /// так у неё свои нажатия, а наклон и масштаб — общие с карточкой. У альбома там же
    /// его подпись.
    private func card(_ item: ShowcaseBlock, slotIndex: Int, isShown: Bool) -> some View {
        let isCurrent = slotIndex == page
        let isAlbum = item.isAlbum
        return Button { tap(item, slotIndex: slotIndex, isCurrent: isCurrent) } label: {
            // `id` — по айтему: слот, чей айтем сменился (догрузка набора, ✕), встаёт
            // новым вью и берёт картинку из кэша с первого кадра, а не кадр-другой
            // показывает прежнюю.
            PromoCardFace(item: item)
                .id(item.id)
                .showcaseSwappable()
        }
        .buttonStyle(PressScaleButtonStyle(pressedScale: PressMotion.cardScale))
        // Источник зума — у каждой копии, но адрес экрана — только у центральной:
        // повторы того же айтема источником не становятся. Без `if`: смена ветки
        // пересоздавала карточку посреди свайпа, и она моргала.
        .matchedTransitionSource(id: zoomID(item, slotIndex: slotIndex, isCurrent: isCurrent), in: zoom)
        .accessibilityLabel(item.title)
        .overlay(alignment: isAlbum ? .topTrailing : .bottomLeading) {
            // Пара — у центральной и соседей: стеклянных кнопок у всех 18 слотов не
            // держим. Сосед в окне — чтобы пара ушедшей с центра догасла, а не пропала.
            if abs(slotIndex - (page ?? slotIndex)) <= 1 {
                ShowcaseFeedbackPair()
                    .modifier(PromoReveal(
                        isShown: isShown,
                        hiddenScale: ShowcasePromoMotion.pairHiddenScale,
                        anchor: isAlbum ? .trailing : .leading
                    ))
                    .offset(
                        x: isAlbum ? -Layout.albumPairTrailing : Layout.pairLeading,
                        y: isAlbum ? -Layout.albumPairAbove : Layout.pairBelow
                    )
            }
        }
        .overlay(alignment: .bottomLeading) {
            if case .album(let album) = item {
                // Высота подписи — ровно аватар: от низа обложки она сдвинута на зазор
                // и свою высоту. `alignmentGuide` в оверлее не сработал (кадр 2026-10-08:
                // подпись легла на обложку).
                PromoAlbumCaption(album: album)
                    .id(album.id)
                    .showcaseSwappable()
                    .modifier(PromoReveal(isShown: isShown))
                    .offset(x: Layout.albumCaptionLeading, y: Layout.albumCaptionGap + Layout.albumAvatar)
                    .allowsHitTesting(false)
            }
        }
    }

    private func zoomID(_ item: ShowcaseBlock, slotIndex: Int, isCurrent: Bool) -> AnyHashable {
        if isCurrent, let route = item.entityRoute { return AnyHashable(route) }
        return AnyHashable("showcase-promo-copy-\(slotIndex)")
    }

    /// Тап по центральной — её экран; по соседу — сосед доезжает в центр.
    private func tap(_ item: ShowcaseBlock, slotIndex: Int, isCurrent: Bool) {
        guard removal == nil else { return }
        UIImpactFeedbackGenerator(style: .medium)
            .impactOccurred(intensity: ShowcaseMotion.tapHapticIntensity)
        guard isCurrent else {
            withAnimation(ShowcasePromoMotion.step) { page = slotIndex }
            return
        }
        if let route = item.entityRoute { navigation.open(route) }
    }

    private func description(_ item: ShowcaseBlock) -> some View {
        Text(item.promoDescription)
            .plusText(.textS, .medium)
            .foregroundStyle(Color.fillFour)
            .lineLimit(Layout.descriptionLines)
            .frame(width: Layout.descriptionWidth, height: Layout.descriptionHeight, alignment: .topLeading)
            .showcaseSwappable()
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
                    catalog.insertPromo(addition, after: next.id)
                    center(on: removed.id)
                    removal = page
                }
            }
            withAnimation(ShowcasePromoMotion.collapse) {
                collapse = 1
            } completion: {
                editSet {
                    catalog.removePromo(id: removed.id)
                    feedback.remove(removed.id)
                    removal = nil
                    collapse = 0
                    center(on: next.id)
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
    private func recenter(old: [String], new: [String]) {
        guard !new.isEmpty else { return }
        let centered = old.isEmpty ? nil : old[Self.wrap(page ?? 0, old.count)]
        let index = centered.flatMap { new.firstIndex(of: $0) } ?? 0
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) {
            page = new.count + index
            scroll.position = CGFloat(new.count + index)
            savedIndex = index
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
        guard !isPlaced, let target = page else { return }
        isPlaced = true
        guard abs(position - CGFloat(target)) > 0.01 else { return }
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
}

/// Масштаб, наклон и опускание карточки — от её места в ленте, кадр в кадр. `shift` —
/// схлопывание ряда по ✕: карточка правее убранной уже сдвинута на эту долю шага, и её
/// вид считается от места, куда она едет. Модификатор анимируемый: `shift` идёт
/// кадрами анимации, а не скачком между концами.
private struct PromoCardMotion: ViewModifier, Animatable {
    let look: PromoCardLook
    var shift: CGFloat

    var animatableData: CGFloat {
        get { shift }
        set { shift = newValue }
    }

    func body(content: Content) -> some View {
        content.visualEffect { [look, shift] content, proxy in
            let distance = ShowcasePromoLayout.ease(abs(ShowcasePromoLayout.position(of: proxy) - shift))
            return content
                .scaleEffect(1 - (1 - ShowcasePromoLayout.sideScale) * distance)
                .rotationEffect(.degrees(look.centerTilt + (look.sideTilt - look.centerTilt) * Double(distance)))
                .offset(x: -shift * ShowcasePromoLayout.step, y: look.drop * distance)
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
    var position: CGFloat
    var rasters = 0

    init(position: CGFloat) {
        self.position = position
    }
}

// MARK: - Карточка

/// Случайный вид карточки — наклон и опускание, свои у каждого айтема и одни у всех его
/// копий (иначе перескок на среднюю копию был бы виден). Случайность — от id и соли
/// процесса: на холодном запуске наклоны другие.
private struct PromoCardLook {
    let centerTilt: Double
    let sideTilt: Double
    let drop: CGFloat

    init(id: String) {
        var hasher = Hasher()
        hasher.combine(id)
        var generator = SeededGenerator(seed: UInt64(bitPattern: Int64(hasher.finalize())))
        let centerSign: Double = Bool.random(using: &generator) ? 1 : -1
        let sideSign: Double = Bool.random(using: &generator) ? 1 : -1
        centerTilt = centerSign * Double.random(in: ShowcasePromoLayout.centerTilt, using: &generator)
        sideTilt = sideSign * Double.random(in: ShowcasePromoLayout.sideTilt, using: &generator)
        drop = CGFloat(Double.random(in: ShowcasePromoLayout.sideDrop, using: &generator))
    }
}

/// Обложка айтема в своих пропорциях: постер фильма 2:3, квадрат альбома, книга
/// в проекции (`BookFigure`, как в сетке выдачи).
private struct PromoCardFace: View {
    let item: ShowcaseBlock

    private typealias Layout = ShowcasePromoLayout

    var body: some View {
        switch item {
        case .movie(let movie):
            cover(movie.poster, size: Layout.poster, radius: Layout.posterRadius)
        case .album(let album):
            cover(album.cover, size: CGSize(width: Layout.album, height: Layout.album), radius: Layout.albumRadius)
        case .book(let book):
            let figure = BookFigureGeometry.fitting(width: Layout.bookWidth, aspect: nil)
            BookFigure(geometry: figure.geometry, coverWidth: figure.coverWidth) {
                SkeletonArtwork(source: book.cover)
            }
        case .vibe, .reading, .watching:
            EmptyView()
        }
    }

    private func cover(_ source: ArtworkSource, size: CGSize, radius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return PlusSkeleton.fill
            .overlay { SkeletonArtwork(source: source) }
            .frame(width: size.width, height: size.height)
            .clipShape(shape)
            .coverBorder(shape)
    }
}

/// Подпись альбома (макет `2537:27595`): аватар исполнителя, название альбома
/// и исполнитель. Без фото исполнителя — без аватара: выдумывать его нельзя.
private struct PromoAlbumCaption: View {
    let album: AlbumBlock

    private typealias Layout = ShowcasePromoLayout

    var body: some View {
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
        .frame(width: Layout.albumCaptionWidth, height: Layout.albumAvatar, alignment: .leading)
    }
}

/// Описание и пара появляются прозрачностью; пара — ещё и масштабом от своего края.
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

// MARK: - Фон

/// Фон под слайдером — размытая картинка центральной карточки, затемнённая, сверху
/// в полную силу (70 %), к низу уходит в прозрачность, в фон ленты. Два слоя: айтем
/// слева от центра ленты и айтем справа, правый проявляется по мере сдвига — кроссфейд
/// за пальцем. Оба слоя непрозрачные, затемнение и прозрачность — на их сумме,
/// сведённой в один растр: по отдельности слои просвечивали бы друг через друга.
///
/// Сводит `drawingGroup`, а не `compositingGroup`: тот в движении и в покое собирал слой
/// по-разному, и в кадр остановки ленты фон темнел на 8–29 уровней — смена фона
/// заканчивалась скачком (замер 2026-10-09).
///
/// `collapse` — схлопывание ряда по ✕: правая соседка уже на эту долю шага ближе
/// к центру. Вью анимируемое: доля идёт кадрами анимации.
///
/// При оттяге ленты вниз фон тянется вверх ровно на оттяг — сверху не открывается
/// чёрное, как у промо Кинопоиска и Книг (`ShowcasePromoBackdrop`).
private struct PromoBackdropStack: View, Animatable {
    let items: [ShowcaseBlock]
    let scroll: PromoScrollState
    var collapse: CGFloat

    var animatableData: CGFloat {
        get { collapse }
        set { collapse = newValue }
    }

    private typealias Layout = ShowcasePromoLayout

    var body: some View {
        // Растр досчитался — перерисовать.
        let _ = scroll.rasters
        let position = scroll.position + collapse
        let base = Int(floor(position))
        let fraction = position - CGFloat(base)
        ZStack {
            Color.black
            if !items.isEmpty {
                raster(items[wrap(base)])
                raster(items[wrap(base + 1)])
                    .opacity(Double(Layout.ease(fraction)))
            }
        }
        .frame(width: Layout.backdropWidth, height: Layout.backdropHeight)
        .overlay { Color.black.opacity(ShowcasePromoBackdropStyle.dim) }
        .drawingGroup()
        .mask {
            LinearGradient(
                stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black, location: ShowcasePromoBackdropStyle.solidShare),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .opacity(Layout.backdropOpacity)
        .visualEffect { content, proxy in
            // Верх фона в покое — физический верх экрана; ниже него — это оттяг.
            let pull = max(0, proxy.frame(in: .global).minY)
            return content.scaleEffect(
                (Layout.backdropHeight + pull) / Layout.backdropHeight,
                anchor: .bottom
            )
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func raster(_ item: ShowcaseBlock) -> some View {
        if let image = PromoBackdropRaster.cached(item.promoArtwork) {
            Image(uiImage: image)
                .resizable()
        } else {
            Color.black
        }
    }

    private func wrap(_ index: Int) -> Int {
        ((index % items.count) + items.count) % items.count
    }
}

/// Размытые фоны слайдера — маленький растр на айтем, посчитанный один раз. Блюр 60
/// стирает детали мельче ~20 pt, и растр в четверть размера, растянутый на слой,
/// неотличим от полного. Живой блюр на слое считался заново на каждом монтировании —
/// на перескоке копий и у каждого подъехавшего соседа, — а растр берётся с первого
/// кадра и в покое не стоит ничего.
@MainActor
private enum PromoBackdropRaster {
    static let scale: CGFloat = 0.25

    private static var cache: [ArtworkSource: UIImage] = [:]
    private static var inFlight: [ArtworkSource: Task<UIImage?, Never>] = [:]

    static func cached(_ source: ArtworkSource) -> UIImage? {
        cache[source]
    }

    static func render(_ source: ArtworkSource) async -> UIImage? {
        if let hit = cache[source] { return hit }
        if let task = inFlight[source] { return await task.value }
        let task = Task { @MainActor in await make(source) }
        inFlight[source] = task
        let raster = await task.value
        inFlight[source] = nil
        if let raster { cache[source] = raster }
        return raster
    }

    /// Та же картинка тем же блюром SwiftUI, что был на слое, только в масштабе:
    /// рамка и радиус уменьшены вместе — вид совпадает.
    private static func make(_ source: ArtworkSource) async -> UIImage? {
        guard let image = await sourceImage(source) else { return nil }
        let width = ShowcasePromoLayout.backdropWidth * scale
        let height = ShowcasePromoLayout.backdropHeight * scale
        let renderer = ImageRenderer(content:
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: width, height: height)
                .clipped()
                .blur(radius: ShowcasePromoBackdropStyle.blur * scale, opaque: true)
        )
        renderer.scale = 1
        renderer.isOpaque = true
        return renderer.uiImage
    }

    /// Живая картинка — без бандленного фолбэка: моковая обложка под фоном — чужой
    /// айтем. Моковый айтем (лента без сети) — его ассет.
    private static func sourceImage(_ source: ArtworkSource) async -> UIImage? {
        if let url = source.remoteURL { return await ArtworkLoader.shared.image(for: url) }
        guard let name = source.fallbackAsset, !name.isEmpty else { return nil }
        return UIImage(named: name)
    }
}

// MARK: - Тексты и картинки айтема

extension ShowcaseBlock {
    var isAlbum: Bool {
        if case .album = self { true } else { false }
    }

    /// Описание под слайдером — у фильма и книги их подпись. У альбома подпись своя
    /// (`PromoAlbumCaption`): описаний альбомов Deezer не отдаёт, а выдумывать их нельзя.
    var promoDescription: String {
        switch self {
        case .movie(let movie): movie.caption
        case .book(let book): book.caption
        case .album, .vibe, .reading, .watching: ""
        }
    }

    /// Картинка фона под слайдером — обложка айтема.
    var promoArtwork: ArtworkSource {
        switch self {
        case .movie(let movie): movie.poster
        case .album(let album): album.cover
        case .book(let book): book.cover
        case .vibe(let vibe): vibe.cover
        case .reading(let reading): reading.cover
        case .watching(let watching): watching.still
        }
    }
}
