import SwiftUI

// MARK: - Движение

/// Тайминги витрины. Значения стартовые — подтверждаются на симуляторе.
enum ShowcaseMotion {
    /// Каскадное появление карточки при въезде в экран.
    static let appear: Animation = .smooth(duration: 0.5)
    /// Насколько карточка приподнимается, пока проявляется.
    static let appearOffset: CGFloat = 24
    /// Доля карточки в кадре, с которой она считается показанной.
    static let appearThreshold: Double = 0.05

    /// Нажатие на миниатюру: подсаживаем её слабее, чем кнопки хрома —
    /// у обложки большая площадь, и скейл 0.92 читался бы как прыжок.
    static let pressedScale: CGFloat = 0.97
    static let pressDuration: Double = 0.15
    /// Хаптика тапа — та же карта, что у табов (nav-chrome §11).
    static let tapHapticIntensity: CGFloat = 0.7

    /// Глубина параллакса по слоям, pt смещения на весь проход через экран.
    /// Эффект намеренно едва заметный: «лёгкий параллакс» из решения 2026-08-22.
    enum Depth {
        /// Обложка — самый дальний слой, отстаёт сильнее всех.
        static let artwork: CGFloat = 10
        /// Подпись идёт почти вровень с лентой.
        static let caption: CGFloat = 4
        /// Кнопки — ближний слой, слегка обгоняют.
        static let controls: CGFloat = -4
    }
}

// MARK: - Экран

/// Витрина «Плюс» — кросс-сервисная лента (`2004:10701`).
///
/// Раскладка абсолютная, а не стек с отступами: в макете карточки наезжают друг на друга
/// (орб «Моей Волны» начинается раньше, чем кончается книжный блок) и выходят за оба края
/// экрана. Каждый блок знает свой слот — см. `ShowcaseLayout`.
struct ShowcaseFeedView: View {
    let feed: ShowcaseFeed
    /// Namespace зум-перехода — объявлен в `ShowcaseScreen`, см. комментарий там.
    let zoom: Namespace.ID
    @Environment(ActionBarState.self) private var actionBar
    @Environment(AppNavigationState.self) private var navigation
    @State private var scrollPosition = ScrollPosition()

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ShowcaseHeader(headline: feed.headline)
                    .frame(height: ShowcaseLayout.Slot.header.height)
                    .padding(.top, ShowcaseLayout.Slot.header.top)
                    .showcaseAppear()

                ForEach(Array(feed.blocks.enumerated()), id: \.element.id) { index, block in
                    card(block)
                        .padding(.top, gap(before: index))
                        // Наезжающая карточка должна лечь поверх предыдущей, как в макете.
                        .zIndex(Double(index))
                        .showcaseAppear()
                }
            }
            .frame(width: ShowcaseLayout.designWidth)
        }
        .scrollIndicators(.hidden)
        .scrollPosition($scrollPosition)
        // Координаты макета отсчитываются от физического верха экрана, а не от safe area:
        // заголовок на 70.79 должен лечь сразу под статус-бар. Иначе лента съезжает вниз
        // на всю высоту выреза.
        .ignoresSafeArea(edges: .top)
        .background(alignment: .top) {
            ShowcaseBackdrop(source: feed.backdrop)
        }
        #if DEBUG
        // Скролл переставляется и после подмены блоков живыми: лента пересобирается,
        // и заданная на старте позиция сбрасывается в ноль. Пауза обязательна —
        // до перераскладки `scrollTo` уезжает в ещё не существующую высоту.
        .task(id: feed.blocks.map(\.id)) {
            let offset = UserDefaults.standard.double(forKey: "debugScrollTo")
            guard offset > 0 else { return }
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            scrollPosition.scrollTo(y: offset)
        }
        // `-debugTapBlock <n>` — повторяет тап по n-й карточке: тапнуть по симулятору
        // из шелла нечем, а связь «карточка → плеер» иначе не проверить.
        //
        // Именно `task(id:)`, а не `onAppear`: замыкание `onAppear` вызывается один раз
        // и держит ту ленту, что была на первом кадре, то есть моковую. Здесь задача
        // перезапускается на каждой подмене блока и всегда видит текущую.
        .task(id: feed.blocks.map(\.id)) {
            let tapIndex = UserDefaults.standard.integer(forKey: "debugTapBlock")
            guard tapIndex > 0, tapIndex <= feed.blocks.count else { return }
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            let block = feed.blocks[tapIndex - 1]
            actionBar.open(block.player)
            // Настоящий тап делает и то, и другое — отладочный обязан повторять его целиком.
            if UserDefaults.standard.bool(forKey: "debugOpenEntity"), let route = block.entityRoute {
                try? await Task.sleep(for: .seconds(1))
                // Через `open`, а не `push`: карточка тайтла показывается слоем поверх
                // хрома, и отладочный тап обязан повторять настоящий целиком.
                navigation.open(route)
            }
        }
        #endif
    }

    /// Карточка целиком не интерактивна: нажатие и зум-переход берёт на себя только её
    /// миниатюра — обложка, кадр, стеклянный блок (см. `showcaseThumbnail()`). Куда вести
    /// и в каком namespace зумить, карточка узнаёт из контекста: маршрут известен здесь,
    /// а миниатюра лежит на несколько слоёв глубже.
    private func card(_ block: ShowcaseBlock) -> some View {
        blockView(block)
            .frame(
                width: ShowcaseLayout.designWidth,
                height: block.slot.height,
                alignment: .topLeading
            )
            .environment(
                \.showcaseThumbnail,
                ShowcaseThumbnailContext(
                    route: block.entityRoute,
                    zoom: zoom,
                    title: block.title,
                    onTap: { open(block) },
                    present: { navigation.coveredRoute = $0 }
                )
            )
    }

    /// Хаптика и перевод action bar в режим сущности. Бар отражает последний
    /// потреблённый контент, а открытие экрана сущности — это ровно оно.
    private func open(_ block: ShowcaseBlock) {
        UIImpactFeedbackGenerator(style: .medium)
            .impactOccurred(intensity: ShowcaseMotion.tapHapticIntensity)
        actionBar.open(block.player)
    }

    /// Зазор над блоком: для первого — от заголовка, дальше — от низа предыдущего.
    private func gap(before index: Int) -> CGFloat {
        let previous = index == 0 ? ShowcaseLayout.Slot.header : feed.blocks[index - 1].slot
        return ShowcaseLayout.gap(above: feed.blocks[index].slot, after: previous)
    }

    @ViewBuilder
    private func blockView(_ block: ShowcaseBlock) -> some View {
        switch block {
        case .movie(let item): MovieCard(block: item)
        case .album(let item): AlbumCard(block: item)
        case .book(let item): BookCard(block: item)
        case .vibe(let item): MyVibeCard(block: item)
        case .reading(let item): ContinueReadingCard(block: item)
        case .watching(let item): ContinueWatchingCard(block: item)
        }
    }
}

// MARK: - Появление и параллакс

/// Каскадное появление: карточка проявляется и подтягивается вверх, когда въезжает
/// в экран. Срабатывает один раз — обратно при уходе не гаснет, иначе лента мерцала бы
/// при быстром скролле туда-обратно.
private struct ShowcaseAppear: ViewModifier {
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : ShowcaseMotion.appearOffset)
            .onScrollVisibilityChange(threshold: ShowcaseMotion.appearThreshold) { visible in
                guard visible, !shown else { return }
                withAnimation(ShowcaseMotion.appear) { shown = true }
            }
    }
}

extension View {
    func showcaseAppear() -> some View {
        modifier(ShowcaseAppear())
    }

    /// Параллакс слоя внутри карточки: слой смещается тем сильнее, чем дальше карточка
    /// от центра экрана. Считается в `visualEffect` — это GPU-этап без перерасчёта
    /// раскладки, поэтому на скролле бесплатно (требование 120 fps).
    func showcaseParallax(_ depth: CGFloat) -> some View {
        visualEffect { content, proxy in
            let screen = proxy.bounds(of: .scrollView)?.height ?? proxy.size.height
            guard screen > 0 else { return content.offset(y: 0) }
            // −0.5…0.5 — путь карточки от нижней кромки экрана к верхней.
            let progress = (proxy.frame(in: .scrollView).midY - screen / 2) / screen
            return content.offset(y: progress * depth)
        }
    }
}
