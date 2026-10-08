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

    /// Прозрачность слоя фона: слои непрозрачные и лежат правый над левым. Левый
    /// (уходящий или приходящий) стоит в полную силу, правый проявляется над ним
    /// по мере сдвига — кроссфейд без провала и без просвета третьего слоя.
    static func backdropReveal(_ t: CGFloat) -> Double {
        if t <= 0 { return t >= -1 ? 1 : 0 }
        return Double(1 - ease(t))
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
    /// Смена картинки фона в слое (✕) — как у фона промо сервисов, вместе с проявлением
    /// нового айтема (`ShowcaseFeedbackMotion.swapIn`, те же 400 мс).
    static let backdropSwap: Animation = ShowcasePromoBackdropStyle.fade
}

/// Промо-слайдер «Главной» (макет `2532:26618`, задача пользователя 2026-10-08):
/// фильмы, альбомы и книги по кругу, в обе стороны, по одной карточке за свайп.
///
/// Центральная крупнее соседей, у каждой карточки свой случайный наклон; масштаб, наклон
/// и опускание соседей идут за сдвигом ленты кадр в кадр (`visualEffect`, без стейта).
/// Описание и пара ✕/✓ — только у центральной и вместе: с паузой, когда карточка
/// встала. Фон — размытая картинка центральной, меняется вслед за сдвигом.
///
/// Круг — три копии набора, как у промо Книг и Кинопоиска: работает средняя, а когда
/// свайп остановился в крайней, лента перескакивает на ту же карточку средней.
struct ShowcasePromo: View {
    let items: [ShowcaseBlock]
    let zoom: Namespace.ID
    /// Новый айтем на место по ✕ (`ShowcaseCatalog.preparePromoReplacement`).
    var prepareReplacement: @MainActor (Int) async -> (@MainActor () -> Void)? = { _ in nil }
    /// Айтем на месте — на сессию (`ShowcaseCatalog.promoIndex`): экран таба
    /// размонтируется на каждом переключении, а слайдер открывается там, где оставили.
    @Binding var savedIndex: Int

    @Environment(AppNavigationState.self) private var navigation

    private typealias Layout = ShowcasePromoLayout

    private static let copies = 3

    /// Карточка ленты копий в центре.
    @State private var page: Int?
    /// Айтем, у которого показаны описание и пара ✕/✓, — центральный, вставший на место.
    @State private var revealed: Int?
    @State private var revealTask: Task<Void, Never>?
    /// Состояние пары — на айтем, а не на копию: после перескока на среднюю копию
    /// отметка ✓ и смена по ✕ остаются при айтеме.
    @State private var feedback: [ShowcaseFeedbackState]

    init(
        items: [ShowcaseBlock],
        zoom: Namespace.ID,
        prepareReplacement: @escaping @MainActor (Int) async -> (@MainActor () -> Void)? = { _ in nil },
        savedIndex: Binding<Int>
    ) {
        self.items = items
        self.zoom = zoom
        self.prepareReplacement = prepareReplacement
        _savedIndex = savedIndex
        let count = max(items.count, 1)
        _page = State(initialValue: count + savedIndex.wrappedValue % count)
        _feedback = State(initialValue: items.map { _ in ShowcaseFeedbackState() })
    }

    private var count: Int { items.count }

    private var currentItem: Int {
        guard count > 0 else { return 0 }
        let index = page ?? count
        return ((index % count) + count) % count
    }

    var body: some View {
        ScrollView(.horizontal) {
            ZStack(alignment: .topLeading) {
                // Фон — своим слоем под всеми карточками: в общем ряду фон правого
                // соседа лёг бы поверх левой карточки.
                //
                // Ряды — не ленивые: в ленивом перескок на среднюю копию кадр рисовал
                // позицию на шаг левее, по оценке, — мелькала прежняя карточка (кадр
                // 2026-10-08), а ушедшие за экран слоты держали прежний айтем. Слотов
                // не больше 18, фон — готовый маленький растр, держать их все дёшево.
                HStack(spacing: 0) {
                    ForEach(0..<(count * Self.copies), id: \.self) { index in
                        backdrop(index)
                    }
                }
                HStack(spacing: 0) {
                    ForEach(0..<(count * Self.copies), id: \.self) { index in
                        slot(index)
                    }
                }
                .scrollTargetLayout()
                .padding(.top, Layout.backdropAbove)
            }
        }
        // По одной карточке за свайп, как бы ни бросили.
        .scrollTargetBehavior(.viewAligned(limitBehavior: .alwaysByOne))
        .contentMargins(.horizontal, (PlusMetrics.designWidth - Layout.step) / 2, for: .scrollContent)
        .scrollPosition(id: $page, anchor: .center)
        .scrollIndicators(.hidden)
        // Карточки шире слота — за краями экрана их видно.
        .scrollClipDisabled()
        .scrollDisabled(count < 2)
        // Рамка ленты — от верха экрана до низа фона: выше и ниже своей рамки лента
        // режет содержимое и с `scrollClipDisabled` (замер кадром 2026-10-08 — фон
        // обрывался по кромкам блока). Место в ленте витрины — прежнее: отрицательные
        // отступы возвращают блоку его высоту.
        .frame(height: Layout.backdropHeight)
        .padding(.top, -Layout.backdropAbove)
        .padding(.bottom, -Layout.backdropTail)
        .onScrollPhaseChange { _, phase in
            if phase == .idle {
                settle()
                scheduleReveal()
            } else {
                hideReveal()
            }
        }
        .onAppear { scheduleReveal() }
        // Набор собрался заново (моки → живые, под заставкой) — с начала средней копии.
        // Смена айтема по ✕ число не меняет и сюда не попадает.
        .onChange(of: count) {
            feedback = items.map { _ in ShowcaseFeedbackState() }
            savedIndex = 0
            page = count
            scheduleReveal()
        }
        // Размытые фоны — заранее, на весь набор: слой, смонтированный на перескоке
        // копий или подъехавший соседом, берёт готовый растр с первого кадра.
        .task(id: items.map(\.promoArtwork)) {
            for item in items {
                _ = await PromoBackdropRaster.render(item.promoArtwork)
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
        // `-debugHomePromoDismiss 1` — ✕ у центральной карточки через 6 с: смена айтема
        // и кроссфейд фона на видео. Тот же `dismiss()` пары, что у тапа.
        .task {
            guard UserDefaults.standard.bool(forKey: "debugHomePromoDismiss") else { return }
            try? await Task.sleep(for: .seconds(6))
            guard !Task.isCancelled else { return }
            // Число айтемов — из стейта: `items` в замыкании `.task` — с первого монтирования.
            let total = max(feedback.count, 1)
            let index = ((page ?? total) % total + total) % total
            feedbackState(index).debugDismisses += 1
        }
        #endif
    }

    // MARK: Слот

    private func slot(_ index: Int) -> some View {
        let itemIndex = index % max(count, 1)
        let item = items[itemIndex]
        let look = PromoCardLook(id: item.id)
        let isShown = index == page && revealed == itemIndex
        return ZStack(alignment: .top) {
            card(item, itemIndex: itemIndex, slotIndex: index, isShown: isShown)
                .frame(height: Layout.carouselHeight)
                .visualEffect { content, proxy in
                    let distance = Layout.ease(abs(Layout.position(of: proxy)))
                    return content
                        .scaleEffect(1 - (1 - Layout.sideScale) * distance)
                        .rotationEffect(.degrees(look.centerTilt + (look.sideTilt - look.centerTilt) * Double(distance)))
                        .offset(y: look.drop * distance)
                }

            // У альбома подпись своя — на обложке, наклонена вместе с ней (`card`).
            if !item.isAlbum {
                description(item)
                    .offset(x: Layout.descriptionShift, y: Layout.descriptionTop(cardHeight: Layout.cardHeight(item)))
                    .modifier(PromoReveal(isShown: isShown))
                    .allowsHitTesting(false)
            }
        }
        .frame(width: Layout.step, height: Layout.height, alignment: .top)
        // Центральная — поверх соседей, как в макете: в ряду правый сосед ложился
        // на её кромку. Смена — на середине свайпа, когда карточки равны и почти
        // не касаются.
        .zIndex(index == page ? 1 : 0)
        .environment(feedbackState(itemIndex))
        .environment(\.showcaseRefresh, ShowcaseRefresh { await prepareReplacement(itemIndex) })
    }

    private func feedbackState(_ itemIndex: Int) -> ShowcaseFeedbackState {
        feedback.indices.contains(itemIndex) ? feedback[itemIndex] : ShowcaseFeedbackState()
    }

    /// Карточка и пара ✕/✓ на её кромке — пара оверлеем на карточке, а не внутри кнопки:
    /// так у неё свои нажатия, а наклон и масштаб — общие с карточкой. У альбома там же
    /// его подпись.
    private func card(_ item: ShowcaseBlock, itemIndex: Int, slotIndex: Int, isShown: Bool) -> some View {
        let isCurrent = slotIndex == page
        let isAlbum = item.isAlbum
        return Button { tap(item, slotIndex: slotIndex, isCurrent: isCurrent) } label: {
            // `id` — по айтему: ленивая лента держит слоты, ушедшие за экран, и если их
            // айтем сменился там (догрузка набора, ✕ у другой копии), на возврате обложка
            // кадр-другой показывала прежний — «чужая карточка мелькнула». Новое вью
            // берёт картинку из кэша с первого кадра.
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

    // MARK: Фон

    private func backdrop(_ index: Int) -> some View {
        let item = items[index % max(count, 1)]
        return Color.clear
            .frame(width: Layout.step, height: Layout.backdropHeight)
            .overlay(alignment: .top) {
                PromoBackdrop(source: item.promoArtwork)
            }
            .visualEffect { content, proxy in
                let t = Layout.position(of: proxy)
                // Слой стоит под экраном, а не едет со слотом: виден он целиком, меняется
                // только прозрачность.
                return content
                    .offset(x: -t * Layout.step)
                    .opacity(Layout.backdropReveal(t))
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    // MARK: Круг и проявление

    /// Свайп остановился: запомнить айтем и, если это крайняя копия, перескочить на ту же
    /// карточку средней — без анимации, картинка та же.
    private func settle() {
        guard count > 0, let current = page else { return }
        let index = ((current % count) + count) % count
        savedIndex = index
        let middle = count + index
        guard current != middle else { return }
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) { page = middle }
    }

    private func scheduleReveal() {
        revealTask?.cancel()
        let index = currentItem
        revealTask = Task { @MainActor in
            try? await Task.sleep(for: ShowcasePromoMotion.revealDelay)
            guard !Task.isCancelled else { return }
            withAnimation(ShowcasePromoMotion.revealIn) { revealed = index }
        }
    }

    private func hideReveal() {
        revealTask?.cancel()
        guard revealed != nil else { return }
        withAnimation(ShowcasePromoMotion.revealOut) { revealed = nil }
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

/// Слой фона под слайдером — размытая картинка айтема, затемнённая и уходящая в чёрный
/// к низу. Слой непрозрачный: затемнение и уход в чёрный запечены в него, а не
/// наложены прозрачностью — иначе под центральным просвечивал соседний, и когда тот
/// гас за краем, фон моргал (жалоба пользователя 2026-10-08).
///
/// Картинка сменилась на экране (✕) — новая проявляется поверх старой, старая стоит
/// под ней в полную силу до конца смены. Сменилась, пока слой был за экраном (ленивая
/// лента держит ушедшие слоты), — на возврате сразу новая: иначе фон вспыхивал прежней
/// картинкой и перетекал обратно (кадр 2026-10-08, перескок копий).
private struct PromoBackdrop: View {
    let source: ArtworkSource

    @State private var shown: UIImage?
    /// Чей растр в `shown` — понять, что айтем сменился, пока слоя не было на экране.
    @State private var shownSource: ArtworkSource?
    @State private var previous: UIImage?
    @State private var swaps = 0
    @State private var isOnScreen = false

    private typealias Layout = ShowcasePromoLayout

    init(source: ArtworkSource) {
        self.source = source
        let cached = PromoBackdropRaster.cached(source)
        _shown = State(initialValue: cached)
        _shownSource = State(initialValue: cached == nil ? nil : source)
    }

    /// Что рисовать сверху. Пока слой не на экране, а растр в `shown` чужой — сразу
    /// растр текущего айтема: первый кадр возврата уже верный.
    private var current: UIImage? {
        if isOnScreen || shownSource == source { return shown }
        return PromoBackdropRaster.cached(source) ?? shown
    }

    var body: some View {
        ZStack {
            Color.black
            if let previous {
                raster(previous)
                    .transition(.identity)
            }
            if let current {
                raster(current)
                    .id(swaps)
                    .transition(.asymmetric(insertion: .opacity, removal: .identity))
            }
        }
        .frame(width: Layout.backdropWidth, height: Layout.backdropHeight)
        .overlay { Color.black.opacity(ShowcasePromoBackdropStyle.dim) }
        .overlay {
            // Прежняя маска «сверху в полную силу, к низу в прозрачность» поверх чёрного
            // экрана — то же, что чёрный поверх картинки: 1 − 0.7 · маска.
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(1 - Layout.backdropOpacity), location: 0),
                    .init(color: .black.opacity(1 - Layout.backdropOpacity), location: ShowcasePromoBackdropStyle.solidShare),
                    .init(color: .black, location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .onAppear {
            isOnScreen = true
            guard shownSource != source, let cached = PromoBackdropRaster.cached(source) else { return }
            var instant = Transaction()
            instant.disablesAnimations = true
            withTransaction(instant) {
                shown = cached
                shownSource = source
                previous = nil
            }
        }
        .onDisappear { isOnScreen = false }
        .task(id: source) {
            guard let raster = await PromoBackdropRaster.render(source), shownSource != source else { return }
            let swap = swaps + 1
            withAnimation(ShowcasePromoMotion.backdropSwap) {
                previous = shown
                shown = raster
                shownSource = source
                swaps = swap
            } completion: {
                if swaps == swap { previous = nil }
            }
        }
    }

    private func raster(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .frame(width: Layout.backdropWidth, height: Layout.backdropHeight)
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
