import SwiftUI

/// Числа промо-слайдера «Главной» — макет `2532:26618`. Холст макета 440, раскладка
/// перенесена на 402 от центра экрана: размеры карточек и отступы от центра — как есть.
enum ShowcasePromoLayout {
    /// Шаг между центрами карточек: соседи выглядывают из-за краёв экрана
    /// (в макете центры соседей на ±188 от центра).
    static let step: CGFloat = 188
    /// Соседи меньше центральной: книга сбоку 161.56 против постера в центре 210.16.
    static let sideScale: CGFloat = 0.769
    /// Центр центральной карточки — от верха блока (низа навигации)
    static let cardCenterY: CGFloat = 185
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

    /// Пара ✕/✓ — у нижней кромки центральной карточки: левый край на 24.6 от её
    /// левой кромки, низ пары — на 27.6 ниже низа карточки (заходит на неё на 12).
    static let pairLeading: CGFloat = 24.6
    static let pairBelow: CGFloat = 27.6

    /// Описание под карточкой — Text S в четыре строки шириной 244; левый край на 97
    /// левее центра экрана, то есть центр строки на 25 правее. Сверху — на 39.4 ниже
    /// низа своей карточки (у постера макета: 382 − 342.6): под квадратом альбома
    /// оно не висит на высоте постера.
    static let descriptionGap: CGFloat = 39.4
    static let descriptionWidth: CGFloat = 244
    static let descriptionShift: CGFloat = 25
    static let descriptionLines = 4
    static var descriptionHeight: CGFloat { CGFloat(descriptionLines) * PlusTextSize.textS.lineHeight }
    /// Описание гаснет вдвое быстрее, чем карточка уходит с центра: к середине свайпа
    /// его уже нет, и два описания не лежат друг на друге.
    static let descriptionFade: CGFloat = 2

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

    /// Где слот относительно центра видимой ленты: 0 — по центру, ±1 — на месте соседа.
    /// Считается от рамки скролла, а не экрана: ширина устройства не важна.
    static func position(of proxy: GeometryProxy) -> CGFloat {
        guard let viewport = proxy.bounds(of: .scrollView) else { return 0 }
        return (proxy.size.width / 2 - viewport.midX) / step
    }

    /// Прозрачность фона слота: соседи по центру лежат слоями — правый над левым.
    /// Левый (уходящий или приходящий) стоит в полную силу, правый проявляется над ним
    /// по мере сдвига: смена идёт без провала в чёрный посередине свайпа.
    static func backdropOpacity(_ t: CGFloat) -> Double {
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
    /// Пара ✕/✓ проявляется не сразу, а когда карточка встала в центр (задача
    /// пользователя): пауза, затем короткий сильный ease-out.
    static let pairDelay: Duration = .milliseconds(250)
    static let pairIn: Animation = .timingCurve(0.23, 1, 0.32, 1, duration: 0.3)
    /// Свайп начался — пара уходит быстро: она отвечает только за центральную карточку.
    static let pairOut: Animation = .easeOut(duration: 0.15)
    static let pairHiddenScale: CGFloat = 0.9
    /// Тап по соседу — он доезжает в центр
    static let step: Animation = .smooth(duration: 0.4)
}

/// Промо-слайдер «Главной» (макет `2532:26618`, задача пользователя 2026-10-08):
/// фильмы, альбомы и книги по кругу, в обе стороны, по одной карточке за свайп.
///
/// Центральная крупнее соседей, у каждой карточки свой случайный наклон; масштаб, наклон
/// и опускание соседей идут за сдвигом ленты кадр в кадр (`visualEffect`, без стейта).
/// Под центральной — её описание и пара ✕/✓: описание проявляется вслед за сдвигом,
/// пара — с паузой, когда карточка встала. Фон — размытая картинка центральной,
/// меняется тоже вслед за сдвигом.
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
    /// Айтем, у которого показана пара ✕/✓, — центральный, вставший на место.
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
                LazyHStack(spacing: 0) {
                    ForEach(0..<(count * Self.copies), id: \.self) { index in
                        backdrop(index)
                    }
                }
                LazyHStack(spacing: 0) {
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
                hidePair()
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
        #if DEBUG
        // `-debugHomePromoStep <back|next|n>` — через 3с пролистать слайдер: свайпнуть
        // из шелла нечем. Словами, а не «-1»: минус аргументы запуска читают как ключ.
        .task {
            let value = UserDefaults.standard.string(forKey: "debugHomePromoStep") ?? ""
            let step = value == "back" ? -1 : (value == "next" ? 1 : Int(value) ?? 0)
            guard step != 0 else { return }
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            withAnimation(ShowcasePromoMotion.step) { page = (page ?? count) + step }
        }
        #endif
    }

    // MARK: Слот

    private func slot(_ index: Int) -> some View {
        let itemIndex = index % max(count, 1)
        let item = items[itemIndex]
        let look = PromoCardLook(id: item.id)
        return ZStack(alignment: .top) {
            card(item, itemIndex: itemIndex, slotIndex: index)
                .frame(height: Layout.carouselHeight)
                .visualEffect { content, proxy in
                    let distance = Layout.ease(abs(Layout.position(of: proxy)))
                    return content
                        .scaleEffect(1 - (1 - Layout.sideScale) * distance)
                        .rotationEffect(.degrees(look.centerTilt + (look.sideTilt - look.centerTilt) * Double(distance)))
                        .offset(y: look.drop * distance)
                }

            description(item)
                .offset(x: Layout.descriptionShift, y: Layout.descriptionTop(cardHeight: Layout.cardHeight(item)))
                .visualEffect { content, proxy in
                    let distance = abs(Layout.position(of: proxy))
                    return content.opacity(Double(1 - Layout.ease(distance * Layout.descriptionFade)))
                }
                .allowsHitTesting(false)
        }
        .frame(width: Layout.step, height: Layout.height, alignment: .top)
        .environment(feedbackState(itemIndex))
        .environment(\.showcaseRefresh, ShowcaseRefresh { await prepareReplacement(itemIndex) })
    }

    private func feedbackState(_ itemIndex: Int) -> ShowcaseFeedbackState {
        feedback.indices.contains(itemIndex) ? feedback[itemIndex] : ShowcaseFeedbackState()
    }

    /// Карточка и пара ✕/✓ у её нижней кромки — пара оверлеем на карточке, а не внутри
    /// кнопки: так у неё свои нажатия, а наклон и масштаб — общие с карточкой.
    private func card(_ item: ShowcaseBlock, itemIndex: Int, slotIndex: Int) -> some View {
        let isCurrent = slotIndex == page
        return Button { tap(item, slotIndex: slotIndex, isCurrent: isCurrent) } label: {
            PromoCardFace(item: item)
                .showcaseSwappable()
        }
        .buttonStyle(PressScaleButtonStyle(pressedScale: PressMotion.cardScale))
        .modifier(PromoZoomSource(route: isCurrent ? item.entityRoute : nil, zoom: zoom))
        .accessibilityLabel(item.title)
        .overlay(alignment: .bottomLeading) {
            ShowcaseFeedbackPair()
                .modifier(PromoPairReveal(isShown: isCurrent && revealed == itemIndex))
                .offset(x: Layout.pairLeading, y: Layout.pairBelow)
        }
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
                PromoBackdrop(source: item.promoArtwork, height: Layout.backdropHeight)
            }
            .visualEffect { content, proxy in
                let t = Layout.position(of: proxy)
                // Слой стоит под экраном, а не едет со слотом: виден он целиком, меняется
                // только прозрачность.
                return content
                    .offset(x: -t * Layout.step)
                    .opacity(Layout.backdropOpacity(t))
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    // MARK: Круг и пара

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
            try? await Task.sleep(for: ShowcasePromoMotion.pairDelay)
            guard !Task.isCancelled else { return }
            withAnimation(ShowcasePromoMotion.pairIn) { revealed = index }
        }
    }

    private func hidePair() {
        revealTask?.cancel()
        guard revealed != nil else { return }
        withAnimation(ShowcasePromoMotion.pairOut) { revealed = nil }
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

/// Источник зума экрана сущности — только у центральной копии: повторы того же айтема
/// в ленте копий источником не становятся.
private struct PromoZoomSource: ViewModifier {
    let route: EntityRoute?
    let zoom: Namespace.ID

    func body(content: Content) -> some View {
        if let route {
            content.matchedTransitionSource(id: route, in: zoom)
        } else {
            content
        }
    }
}

/// Пара появляется прозрачностью и масштабом от левого края; с «уменьшением движения» —
/// одной прозрачностью.
private struct PromoPairReveal: ViewModifier {
    let isShown: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(isShown || reduceMotion ? 1 : ShowcasePromoMotion.pairHiddenScale, anchor: .leading)
            .opacity(isShown ? 1 : 0)
            .allowsHitTesting(isShown)
            .accessibilityHidden(!isShown)
    }
}

/// Размытая копия картинки центральной карточки — фон под слайдером, уходит в чёрный
/// к низу. Растр вместо живого блюра: пересчитывать его нужно только на смене айтема,
/// а не на каждом кадре свайпа.
private struct PromoBackdrop: View {
    let source: ArtworkSource
    let height: CGFloat

    var body: some View {
        ArtworkImage(source: source)
            .scaledToFill()
            .frame(width: ShowcasePromoLayout.backdropWidth, height: height)
            .clipped()
            .blur(radius: ShowcasePromoBackdropStyle.blur, opaque: true)
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
            .opacity(ShowcasePromoBackdropStyle.opacity)
    }
}

// MARK: - Тексты и картинки айтема

extension ShowcaseBlock {
    /// Описание под слайдером: у фильма и книги — их подпись, у альбома — исполнитель
    /// и название: описаний альбомов Deezer не отдаёт, а выдумывать их нельзя.
    var promoDescription: String {
        switch self {
        case .movie(let movie): movie.caption
        case .book(let book): book.caption
        case .album(let album): "\(album.title) · альбом «\(album.subtitle)»"
        case .vibe, .reading, .watching: ""
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
