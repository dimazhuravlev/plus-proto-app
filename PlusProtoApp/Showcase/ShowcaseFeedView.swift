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

/// Уезд ленты к началу по повторному тапу таба — движение по экрану: ease-in-out,
/// длинная лента доезжает за ту же длительность, что и короткая.
/// Уезд к началу ленты по повторному тапу таба — общий у витрины и главной Кинопоиска.
enum ShowcaseScrollMotion {
    static let toTop: Animation = .timingCurve(0.65, 0, 0.35, 1, duration: 0.5)
}

/// Витрина «Плюс» — кросс-сервисная лента (`2004:10701`).
///
/// Раскладка абсолютная, а не стек с отступами: в макете карточки наезжают друг на друга
/// (орб «Моей Волны» начинается раньше, чем кончается книжный блок) и выходят за оба края
/// экрана. Каждый блок знает свой слот — см. `ShowcaseLayout`.
struct ShowcaseFeedView: View {
    let feed: ShowcaseFeed
    /// Namespace зум-перехода — объявлен в `ShowcaseScreen`, см. комментарий там.
    let zoom: Namespace.ID
    /// Новый контент для блока по ✕ (`ShowcaseCatalog.prepareReplacement`).
    var prepareReplacement: @MainActor (ShowcaseBlock) async -> (@MainActor () -> Void)? = { _ in nil }
    /// Айтем промо на месте — на сессию (`ShowcaseCatalog.promoIndex`).
    @Binding var promoIndex: Int
    /// Сколько ленты ушло под навигацию — от этого её подложка (`HomeTopNav`).
    @Binding var scrollOffset: CGFloat
    @Environment(ActionBarState.self) private var actionBar
    @Environment(AppNavigationState.self) private var navigation
    @Environment(ShowcaseCatalog.self) private var catalog
    @State private var scrollPosition = ScrollPosition()

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Промо-слайдер — над лентой, свой набор (задача пользователя 2026-10-08).
                if !feed.promo.isEmpty {
                    ShowcasePromo(
                        items: feed.promo,
                        zoom: zoom,
                        savedIndex: $promoIndex
                    )
                    .padding(.top, ShowcaseLayout.promoTop)
                    .showcaseAppear()
                }

                // Карточка — на слот, а не на контент: ✕ меняет блок в слоте, и карточка
                // обязана пережить смену — с ней живёт пара ✕/✓, которая стоит на месте
                // (`ShowcaseFeedbackHost`). Слоты фиксированы макетом и не повторяются.
                ForEach(Array(feed.blocks.enumerated()), id: \.element.slot.top) { index, block in
                    card(block, index: index)
                        .padding(.top, gap(before: index))
                        // Наезжающая карточка должна лечь поверх предыдущей, как в макете.
                        .zIndex(Double(index))
                        .showcaseAppear()
                }
            }
            .frame(width: ShowcaseLayout.designWidth)
            // Клиренс под хромом ленте уже даёт `contentMargins` в корне — это воздух
            // сверх него, чтобы последняя карточка не притиралась к панели действий.
            .padding(.bottom, ShowcaseLayout.feedBottomPadding)
        }
        .scrollIndicators(.hidden)
        .scrollPosition($scrollPosition)
        .trackNavBarScroll(into: $scrollOffset)
        // Повторный тап по табу «Плюс» на корне — к началу ленты, как в системных
        // таббарах (правка пользователя 2026-10-03).
        .onChange(of: navigation.scrollToTopRequests[.plus]) {
            withAnimation(ShowcaseScrollMotion.toTop) { scrollPosition.scrollTo(edge: .top) }
        }
        // Координаты макета отсчитываются от физического верха экрана, а не от safe area:
        // карточки ложатся в свои слоты, а лента уходит под статус-бар и навигацию.
        .ignoresSafeArea(edges: .top)
        // Первый показ отыграл — следующие появления витрины без проявления.
        .onDisappear { ShowcaseAppearMemory.hasShown = true }
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
        //
        // Срабатываний — не больше двух на процесс (мок-лента + живая): без потолка
        // каждая пересборка блоков тапала заново и переоткрывала карточку, которую
        // пользователь только что закрыл (жалоба 2026-08-25).
        .task(id: feed.blocks.map(\.id)) {
            let tapIndex = UserDefaults.standard.integer(forKey: "debugTapBlock")
            guard tapIndex > 0, tapIndex <= feed.blocks.count, ShowcaseTapDebug.fires < 2 else { return }
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            ShowcaseTapDebug.fires += 1
            let block = feed.blocks[tapIndex - 1]
            // Ровно то же, что делает настоящий тап (`open`), а не своя копия его
            // логики: копия разошлась с оригиналом, когда переход перестал запускать
            // плеер, и отладочный прогон продолжал показывать чип.
            open(block)
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
    private func card(_ block: ShowcaseBlock, index: Int) -> some View {
        // Убранная ✕ целиком карточка — нулевой высоты: зазор под ней считается от её
        // слота, и лента ниже подтягивается ровно на её высоту. Контент к этому моменту
        // уже погас (`ContinueReadingCard.dismiss`).
        let isHidden = catalog.hiddenBlockIDs.contains(block.id)
        return ShowcaseFeedbackHost(debugIndex: index + 1) { blockView(block) }
            .environment(\.showcaseRefresh, ShowcaseRefresh { await prepareReplacement(block) })
            .frame(
                width: ShowcaseLayout.designWidth,
                height: isHidden ? 0 : block.slot.height,
                alignment: .topLeading
            )
            .allowsHitTesting(!isHidden)
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

    /// Хаптика тапа. **Плеер отсюда больше не запускается**: открыть карточку —
    /// не то же самое, что включить контент (правка пользователя 2026-08-28).
    /// Запуск живёт на кнопках самих экранов: «Слушать» в альбоме, «Смотреть»
    /// в фильме, «Читать» в книге.
    ///
    /// Исключение — блок без своего экрана: у «Моей Волны» нет сущности, это
    /// генератор потока, и кроме запуска музыки тапу нечего делать.
    private func open(_ block: ShowcaseBlock) {
        UIImpactFeedbackGenerator(style: .medium)
            .impactOccurred(intensity: ShowcaseMotion.tapHapticIntensity)
        guard block.entityRoute == nil else { return }
        // «Моя Волна» — поток: включает настоящий трек волны, а не «трек» с её именем.
        if case .vibe = block {
            actionBar.openMyVibe()
            return
        }
        actionBar.open(block.player)
    }

    /// Зазор над блоком: для первого — от низа промо, дальше — от низа предыдущего.
    private func gap(before index: Int) -> CGFloat {
        guard index > 0 else {
            return feed.promo.isEmpty
                ? ShowcaseLayout.promoTop + ShowcaseLayout.promoToFirstBlock
                : ShowcaseLayout.promoToFirstBlock
        }
        return ShowcaseLayout.gap(above: feed.blocks[index].slot, after: feed.blocks[index - 1].slot)
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
    /// Проявление — только при первом показе витрины за процесс (правка пользователя
    /// 2026-10-04): экран таба пересоздаётся на каждом переключении, и прежде лента
    /// заново всплывала сдвигом при каждом возврате на «Плюс».
    @State private var shown = ShowcaseAppearMemory.hasShown

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

/// Витрина уже показывалась в этом процессе — дальше она встаёт сразу, без проявления.
/// Отметка ставится, когда витрина уходит с экрана (переключение таба, пуш).
@MainActor
enum ShowcaseAppearMemory {
    static var hasShown = false
}

#if DEBUG
/// Потолок срабатываний `-debugTapBlock` на процесс — см. задачу в `ShowcaseFeedView`.
private enum ShowcaseTapDebug {
    static var fires = 0
}
#endif

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
