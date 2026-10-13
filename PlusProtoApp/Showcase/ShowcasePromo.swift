import SwiftUI
import UIKit

/// Числа промо-слайдера «Главной» — макет `2532:26618`. Холст макета 440, раскладка
/// перенесена на 402 от центра экрана: размеры карточек и отступы от центра — как есть.
///
/// Числа ниже — макет на 402 (`scale` = 1). Слайдер — центрированная карусель с постоянными
/// краями соседей: на любой ширине из-за края экрана выглядывает ровно столько же сосед,
/// сколько на 402, а растёт вся геометрия карточек (шаг, размеры, высоты, отступы, подпись
/// альбома) на `scale`. Кнопки ✕/✓ 40, шрифты и интерлиньяж подписи — не масштабируются,
/// их позиции — да.
enum ShowcasePromoLayout {
    /// Видимый край соседней карточки на 402: от кромки экрана до внутреннего края соседа
    /// (центр экрана 201 − половина шага до его кромки 107.2 = 93.8). Инвариант на любой ширине.
    static let neighbourEdge: CGFloat = 93.8

    /// Множитель промо: `(screenWidth/2 − край) / (402/2 − край)` — видимый край соседа
    /// не меняется с шириной. 390 → ≈0.944, 402 → 1, 440 → ≈1.177.
    @MainActor
    static var scale: CGFloat {
        (PlusMetrics.screenWidth / 2 - neighbourEdge) / (PlusMetrics.designWidth / 2 - neighbourEdge)
    }

    /// Шаг между центрами карточек: соседи выглядывают из-за краёв экрана
    /// (в макете центры соседей на ±188 от центра).
    @MainActor
    static var step: CGFloat { 188 * scale }
    /// Соседи меньше центральной: книга сбоку 161.56 против постера в центре 210.16.
    static let sideScale: CGFloat = 0.769
    /// Центр центральной карточки — от верха блока (низа навигации). В макете 185;
    /// на 10 выше — «отступ до навбара немного меньше» (правка пользователя 2026-10-08).
    @MainActor
    static var cardCenterY: CGFloat { 175 * scale }
    @MainActor
    static var carouselHeight: CGFloat { cardCenterY * 2 }

    /// Величина наклона у каждой карточки своя, случайная: по центру 2…4°, сбоку 4.5…6.5°.
    /// Знак — от места в ряду, а не от карточки: по центру минус, у соседей плюс, через одну
    /// снова минус, как в макете (−3° у центральной, +5.03° и +5.94° у соседей). Ряд
    /// всегда «+ − + −» (правка пользователя 2026-10-09: со случайным знаком соседи
    /// клонились в одну сторону).
    static let centerTilt: ClosedRange<Double> = 2...4
    static let sideTilt: ClosedRange<Double> = 4.5...6.5
    /// Соседи ниже центральной — на 6…16, у каждой карточки своё (в макете 16 и 6).
    static let sideDrop: ClosedRange<Double> = 6...16   // на 402, умножается на `scale`

    /// Карточки по центру — по виду. Сбоку они те же, уменьшенные на `sideScale`:
    /// альбом сбоку 169, скругление 18 — в центре 219.8 и 23.4.
    @MainActor
    static var poster: CGSize { CGSize(width: 210.155 * scale, height: 315.235 * scale) }
    @MainActor
    static var posterRadius: CGFloat { 16.358 * scale }
    @MainActor
    static var album: CGFloat { 219.8 * scale }
    /// Скругление альбома — как у постера, а не макетные 23.4: «немного уменьшить»
    /// (правка пользователя 2026-10-09), и углы карточек в ряду одинаковые.
    @MainActor
    static var albumRadius: CGFloat { posterRadius }
    @MainActor
    static var bookWidth: CGFloat { 210.155 * scale }
    /// Книга ряда. Скругления меньше общих (правка пользователя 2026-10-09): обложка —
    /// как постер и альбом ряда, серая подложка — на ту же величину (19.2 → 16.4, 24.1 → 21.2).
    @MainActor
    static var book: (geometry: BookFigureGeometry, coverWidth: CGFloat) {
        var figure = BookFigureGeometry.fitting(width: bookWidth, aspect: nil)
        figure.geometry.radiusTrim = figure.geometry.coverRadius - posterRadius
        return figure
    }

    /// Пара ✕/✓ у фильма и книги — у нижней кромки карточки: левый край на 24.6 от её
    /// левой кромки, низ пары — на 27.6 ниже низа карточки (заходит на неё на 12).
    @MainActor
    static var pairLeading: CGFloat { 24.6 * scale }
    @MainActor
    static var pairBelow: CGFloat { 27.6 * scale }
    /// У альбома — у верхней кромки справа (макет `2537:27595`): правый край на 14.5
    /// от правой кромки обложки, верх — на 22.5 выше её верха. Замер — в системе
    /// координат повёрнутой обложки.
    @MainActor
    static var albumPairTrailing: CGFloat { 14.5 * scale }
    @MainActor
    static var albumPairAbove: CGFloat { 22.5 * scale }

    /// У исполнителя пара — по касательной к кругу (правка пользователя 2026-10-13): центры
    /// обеих кнопок на окружности, середина пары — на φ по часовой от 12 часов, пара
    /// вместе с иконками повёрнута на φ.
    static let artistPairAngle: Angle = .degrees(26)
    /// Сдвиг середины пары от центра круга: `(d·sin φ, −d·cos φ)`, ось y вниз. `d` — до
    /// середины хорды между центрами кнопок, `sqrt(r² − 23²)`: 23 — половина расстояния
    /// между ними (40 + 6), и оба центра ровно на окружности. Кнопки не масштабируются.
    @MainActor
    static var artistPairOffset: CGSize {
        let radius = album / 2
        let halfSpan = (PlusMetrics.circleButton + PlusMetrics.circleButtonGap) / 2
        let distance = (radius * radius - halfSpan * halfSpan).squareRoot()
        let angle = artistPairAngle.radians
        return CGSize(width: distance * CGFloat(sin(angle)), height: -distance * CGFloat(cos(angle)))
    }

    /// Подпись альбома (макет `2537:27595`) — аватар исполнителя 40, справа название
    /// альбома и исполнитель Text M. Наклонена вместе с обложкой: левый край на 3.3
    /// правее её левой кромки, верх — на 7.2 ниже низа (замер в системе обложки).
    /// Ширина 227 с полем справа 8; строки заходят друг на друга на 2.
    @MainActor
    static var albumCaptionLeading: CGFloat { 3.3 * scale }
    @MainActor
    static var albumCaptionGap: CGFloat { 7.2 * scale }
    @MainActor
    static var albumCaptionWidth: CGFloat { 227 * scale }
    @MainActor
    static var albumCaptionTrailing: CGFloat { 8 * scale }
    @MainActor
    static var albumCaptionSpacing: CGFloat { 8 * scale }
    /// Строки подписи заходят друг на друга на 2 — это интерлиньяж шрифта, не геометрия.
    static let albumCaptionLineOverlap: CGFloat = 2
    @MainActor
    static var albumAvatar: CGFloat { 40 * scale }

    /// Подпись исполнителя (задача 64) — одна строка Text M по центру колонки
    /// шириной с квадрат альбома, на месте верхней строки подписи альбома: полоса подписи
    /// начинается на `albumCaptionGap` под квадратом, а две строки альбома стоят в ней
    /// по центру высоты аватара. Отсчёт — от низа квадрата до верха строки.
    @MainActor
    static var centeredCaptionTop: CGFloat {
        let albumLines = 2 * PlusTextSize.textM.lineHeight - albumCaptionLineOverlap
        return albumCaptionGap + (albumAvatar - albumLines) / 2
    }

    /// Пустое место под самой высокой карточкой, постером. Было 39.4 + 64 под описание;
    /// описание убрано, пустое место ужато на 56 — правка пользователя 2026-10-10.
    @MainActor
    static var belowCards: CGFloat { 47.4 * scale }

    /// Высота блока — до низа постера плюс `belowCards`: место держится всегда, и лента
    /// ниже не прыгает от айтема к айтему.
    @MainActor
    static var height: CGFloat { cardCenterY + poster.height / 2 + belowCards }

    /// Фон — картинка центральной карточки вдвое шире экрана, размытая: от физического
    /// верха экрана до низа блока и ещё немного ниже, в чёрный.
    @MainActor
    static var backdropWidth: CGFloat { PlusMetrics.screenWidth * 2 }
    /// +56 к прежним 64, чтобы фон не укоротился вместе с блоком (правка 2026-10-10).
    @MainActor
    static var backdropTail: CGFloat { 120 * scale }
    /// Сколько фон уходит выше блока — до физического верха экрана.
    static var backdropAbove: CGFloat { ServiceTopNavLayout.topSafeArea + ServiceTopNavLayout.rowHeight }
    @MainActor
    static var backdropHeight: CGFloat { backdropAbove + height + backdropTail }
    /// Фон — на 60 %: на 10 % прозрачнее фона промо сервисов (правка пользователя
    /// 2026-10-08) и ещё на 10 % (правка 2026-10-09).
    static let backdropOpacity: Double = 0.6

    /// Где слот относительно центра видимой ленты: 0 — по центру, ±1 — на месте соседа.
    /// Считается от рамки скролла, а не экрана: ширина устройства не важна. Шаг приходит
    /// параметром — вызывается из `visualEffect`, где `step` (ширина-зависимый) недоступен.
    static func position(of proxy: GeometryProxy, step: CGFloat) -> CGFloat {
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
    /// Пара ✕/✓ (и подпись альбома) проявляются вместе (правка пользователя 2026-10-08) и не
    /// сразу, а когда карточка встала в центр: пауза, затем короткий сильный ease-out.
    /// Без паузы — сразу как лента встала (правка пользователя 2026-10-13; было 50, до этого
    /// 100 и 250): задержку и так даёт доводка ленты до места.
    static let revealDelay: Duration = .zero
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
    /// Перестановка набора перед ✕-схлопыванием должна лечь в свой проход, и только потом
    /// стартует `collapse`: в одном проходе подмена вью получала неявный переход.
    static let editSettle: Duration = .milliseconds(40)
}

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
/// Пара ✕/✓ (у альбома — и подпись) — только у центральной и вместе: с паузой, когда карточка
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

    init(items: [ShowcaseBlock], zoom: Namespace.ID, savedIndex: Binding<Int>) {
        self.items = items
        self.zoom = zoom
        _savedIndex = savedIndex
        let count = max(items.count, 1)
        let start = count + savedIndex.wrappedValue % count
        _pageID = State(initialValue: items.isEmpty ? nil : PromoSlotID(copy: 1, item: items[start % count].id))
        _scroll = State(initialValue: PromoScrollState(position: CGFloat(start)))
    }

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
    /// там с того прохода, на котором их создали.
    private var liveItems: [ShowcaseBlock] { catalog.feed.promo }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                // Ряд — не ленивый: в ленивом перескок на среднюю копию кадр рисовал позицию
                // на шаг левее, по оценке, — мелькала прежняя карточка (кадр 2026-10-08),
                // а ушедшие за экран слоты держали прежний айтем. Слотов не больше 18.
                HStack(spacing: 0) {
                    ForEach(Array(slotIDs.enumerated()), id: \.element) { index, _ in
                        slot(index)
                    }
                }
                .scrollTargetLayout()
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
            .onScrollGeometryChange(for: CGFloat.self) { [step = Layout.step] geometry in
                (geometry.contentOffset.x + geometry.contentInsets.leading) / step
            } action: { _, position in
                scroll.position = position
                placeIfNeeded(at: position, proxy: proxy)
            }
            // Фон — своим слоем под лентой, от физического верха экрана до ниже блока, как
            // у промо Кинопоиска и Книг: уходит в прозрачность, в чёрный фон экрана, и при
            // оттяге тянется вверх. Слоями внутри ленты он внизу обрезался о карточки ленты,
            // а при оттяге открывал чёрное (правки пользователя 2026-10-08).
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
            .onAppear {
                scrollProxy = proxy
                trace("appear")
                scheduleReveal()
            }
            #if DEBUG
            .onChange(of: pageID) { _, _ in trace("pageID") }
            #endif
            // Набор собрался заново (моки → живые, под заставкой) — центральный айтем
            // остаётся в центре, если он есть в новом наборе, иначе — с начала.
            .onChange(of: items.map(\.id)) { _, new in
                guard !isEditingSet else {
                    isEditingSet = false
                    pinToEditAnchor()
                    return
                }
                recenter(new: new)
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
            // `-debugHomePromoKind <artist|vibe|artistWave>` — через 3 с поставить в центр первый
            // айтем вида: исполнителя, станцию «Моей волны» или волну «в стиле артиста» (задача 68).
            // Тем же путём, что `-debugHomePromoStep`.
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
                    case .movie, .album, .book, .reading, .watching: false
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
    /// его подпись, у исполнителя — имя под кругом.
    private func card(_ item: ShowcaseBlock, slotIndex: Int, isShown: Bool) -> some View {
        let isCurrent = slotIndex == page
        let pair = PromoPairPlacement(item)
        return Button { tap(item, slotIndex: slotIndex, isCurrent: isCurrent) } label: {
            // Смена по ✕ (`showcaseSwappable`) — внутри лица: у станции она на слоях
            // по отдельности (`PromoStationCard`).
            PromoCardFace(item: item)
        }
        .buttonStyle(PressScaleButtonStyle(pressedScale: PressMotion.cardScale))
        // Источник зума — у каждой копии, но адрес экрана — только у центральной:
        // повторы того же айтема источником не становятся. Без `if`: смена ветки
        // пересоздавала карточку посреди свайпа, и она моргала.
        .matchedTransitionSource(id: zoomID(item, slotIndex: slotIndex, isCurrent: isCurrent), in: zoom)
        .accessibilityLabel(item.title)
        .overlay(alignment: pair.alignment) {
            // Пара — у центральной и соседей: стеклянных кнопок у всех 18 слотов не
            // держим. Сосед в окне — чтобы пара ушедшей с центра догасла, а не пропала.
            if abs(slotIndex - (page ?? slotIndex)) <= 1 {
                ShowcaseFeedbackPair()
                    .modifier(PromoReveal(
                        isShown: isShown,
                        hiddenScale: ShowcasePromoMotion.pairHiddenScale,
                        anchor: pair.anchor
                    ))
                    .rotationEffect(pair.rotation)
                    .offset(pair.offset)
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
                    .showcaseSwappable()
                    .modifier(PromoReveal(isShown: isShown, hiddenScale: ShowcasePromoMotion.pairHiddenScale, anchor: .leading))
                    .offset(x: Layout.albumCaptionLeading, y: Layout.albumCaptionGap + Layout.albumAvatar)
            }
        }
        .overlay(alignment: .top) {
            if let caption = item.promoCaption {
                // Имя исполнителя — показывается, как подпись альбома: только у центральной,
                // когда встала. Не нажимается.
                PromoCenteredCaption(title: caption)
                    .showcaseSwappable()
                    .modifier(PromoReveal(isShown: isShown, hiddenScale: ShowcasePromoMotion.pairHiddenScale, anchor: .top))
                    .offset(y: Layout.album + Layout.centeredCaptionTop)
            }
        }
    }

    private func zoomID(_ item: ShowcaseBlock, slotIndex: Int, isCurrent: Bool) -> AnyHashable {
        if isCurrent, let route = item.entityRoute { return AnyHashable(route) }
        return AnyHashable("showcase-promo-copy-\(slotIndex)")
    }

    /// Тап по центральной — её экран; по соседу — сосед доезжает в центр. Станция «Моей
    /// волны» своего экрана не имеет: центральная включает волну, как карточка ленты.
    private func tap(_ item: ShowcaseBlock, slotIndex: Int, isCurrent: Bool) {
        guard removal == nil else { return }
        tapHaptic()
        guard isCurrent else {
            withAnimation(ShowcasePromoMotion.step) { page = slotIndex }
            return
        }
        if case .vibe = item {
            actionBar.openMyVibe()
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
                // Перестановка ложится в свой проход до старта схлопывания.
                try? await Task.sleep(for: ShowcasePromoMotion.editSettle)
                // Страховка: если прикалывание в `onChange` уже отработало — no-op.
                pinToEditAnchor()
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
        let index = centered.flatMap { new.firstIndex(of: $0) } ?? 0
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
    var shift: CGFloat

    var animatableData: CGFloat {
        get { shift }
        set { shift = newValue }
    }

    func body(content: Content) -> some View {
        // Всё, что зависит от ширины экрана, берётся здесь, на главном потоке: замыкание
        // `visualEffect` не изолировано.
        let step = ShowcasePromoLayout.step
        let drop = look.drop * ShowcasePromoLayout.scale
        return content.visualEffect { [look, shift] content, proxy in
            let position = ShowcasePromoLayout.position(of: proxy, step: step) - shift
            let distance = ShowcasePromoLayout.ease(abs(position))
            let magnitude = look.centerTilt + (look.sideTilt - look.centerTilt) * Double(distance)
            // Знак чередуется по местам ряда: −1 по центру, +1 у соседей, −1 через одну.
            // Косинус меняет его плавно по ходу свайпа — карточка проходит через ноль,
            // без щелчка, — и не зависит от копии круга и от состава набора.
            let tilt = -magnitude * cos(Double.pi * Double(position))
            return content
                .scaleEffect(1 - (1 - ShowcasePromoLayout.sideScale) * distance)
                .rotationEffect(.degrees(tilt))
                .offset(x: -shift * step, y: drop * distance)
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

/// Случайный вид карточки — величина наклона и опускание, свои у каждого айтема и одни у всех его
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
        // Только величины: знак задаёт место в ряду (`PromoCardMotion`).
        centerTilt = Double.random(in: ShowcasePromoLayout.centerTilt, using: &generator)
        sideTilt = Double.random(in: ShowcasePromoLayout.sideTilt, using: &generator)
        drop = CGFloat(Double.random(in: ShowcasePromoLayout.sideDrop, using: &generator))
    }
}

/// Обложка айтема в своих пропорциях: постер фильма 2:3, квадрат альбома, книга
/// в проекции (`BookFigure`, как в сетке выдачи), круг исполнителя размером с альбом,
/// лепесток станции (`PromoStationCard`, кадр 208×249).
private struct PromoCardFace: View {
    let item: ShowcaseBlock

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
            cover(artist.picture, size: square, shape: Circle())
                .showcaseSwappable()
        case .vibe(let vibe):
            // Смена по ✕ — на слоях лепестка по отдельности, внутри него.
            PromoStationCard(title: vibe.title, station: vibe.promoStation)
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
            .frame(width: ShowcasePromoLayout.album)
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
/// проявляется (`PromoReveal`), и поворот. Фильм и книга — у нижней кромки слева, альбом —
/// у верхней справа, исполнитель — по касательной к кругу, станция — внутри лепестка.
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
                offset: CGSize(width: origin.x * Layout.scale, height: origin.y * Layout.scale),
                anchor: .center
            )
        case .movie, .book, .reading, .watching:
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

/// Фон под слайдером — размытая картинка центральной карточки, затемнённая, сверху
/// в полную силу (60 %), к низу уходит в прозрачность, в чёрный фон экрана. Два слоя: айтем
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
        .visualEffect { [height = Layout.backdropHeight] content, proxy in
            // Верх фона в покое — физический верх экрана; ниже него — это оттяг.
            let pull = max(0, proxy.frame(in: .global).minY)
            return content.scaleEffect(
                (height + pull) / height,
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
    /// Строка под кругом исполнителя. У остальных видов её нет: «Моя волна» и название
    /// станции — внутри лепестка (`PromoStationCard`).
    var promoCaption: String? {
        switch self {
        case .artist(let artist): artist.name
        case .movie, .album, .book, .vibe, .reading, .watching: nil
        }
    }

    /// Картинка фона под слайдером — обложка айтема. У исполнителя — его фото, у станции —
    /// её иллюстрация в цветах станции, а не кавер плеера; у волны «в стиле артиста» —
    /// фото артиста.
    var promoArtwork: ArtworkSource {
        switch self {
        case .movie(let movie): movie.poster
        case .album(let album): album.cover
        case .book(let book): book.cover
        case .vibe(let vibe): vibe.promoStation.artwork
        case .reading(let reading): reading.cover
        case .watching(let watching): watching.still
        case .artist(let artist): artist.picture
        }
    }
}
