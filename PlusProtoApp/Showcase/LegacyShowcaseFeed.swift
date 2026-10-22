import SwiftUI

/// Исходная витрина GitHub. Слоты и реакции отделены от Figma-полок.
struct LegacyShowcaseFeed: View {
    let feed: ShowcaseFeed
    let zoom: Namespace.ID
    let prepareReplacement: @MainActor (ShowcaseBlock) async -> (@MainActor () -> Void)?
    @Environment(ShowcaseCatalog.self) private var catalog
    @Environment(ActionBarState.self) private var actionBar
    @Environment(AppNavigationState.self) private var navigation

    var body: some View {
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
                width: PlusMetrics.screenWidth,
                height: isHidden ? 0 : block.slot.frameHeight,
                alignment: .topLeading
            )
            .allowsHitTesting(!isHidden)
            .environment(
                \.showcaseThumbnail,
                ShowcaseThumbnailContext(
                    route: block.entityRoute,
                    zoom: zoom,
                    title: block.title,
                    onTap: { ShowcaseFeedAction.open(block, actionBar: actionBar, navigation: navigation) },
                    present: { navigation.coveredRoute = $0 }
                )
            )
    }

    /// Зазор над блоком: для первого — от низа промо (без промо — от низа ряда
    /// «продолженного», как если бы промо было нулевой высоты), дальше — от низа предыдущего.
    private func gap(before index: Int) -> CGFloat {
        guard index > 0 else {
            return ShowcaseLayout.promoToFirstBlock
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
        // Исполнитель — только в промо «Главной», в ленте его нет.
        case .artist: EmptyView()
        }
    }
}

enum ShowcaseFeedAction {
    /// Хаптика тапа. **Плеер отсюда больше не запускается**: открыть карточку —
    /// не то же самое, что включить контент (правка пользователя 2026-08-28).
    /// Запуск живёт на кнопках самих экранов: «Слушать» в альбоме, «Смотреть»
    /// в фильме, «Читать» в книге.
    ///
    /// Исключение — блок без своего экрана: у «Моей Волны» нет сущности, это
    /// генератор потока, и кроме запуска музыки тапу нечего делать.
    @MainActor static func open(_ block: ShowcaseBlock, actionBar: ActionBarState, navigation: AppNavigationState) {
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

}
