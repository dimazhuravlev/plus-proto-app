import SwiftUI

/// Витрина «Плюс» — главный экран супераппа.
///
/// Каталог живёт здесь, а не в `AppRootView`: витрина — единственный его потребитель,
/// а её сборка не должна инвалидировать хром.
struct ShowcaseScreen: View {
    @State private var catalog = ShowcaseCatalog()
    @Environment(AppNavigationState.self) private var navigation
    /// Namespace зум-перехода живёт здесь: и источник (карточка ленты), и назначение
    /// (`navigationDestination`) — потомки этого вью, поэтому пробрасывать его
    /// через environment не нужно.
    @Namespace private var zoom

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ShowcaseFeedView(feed: catalog.feed, zoom: zoom)
        }
        .navigationDestination(for: EntityRoute.self) { route in
            EntityScreen(route: route)
                // Нативный зум: миниатюра карточки разворачивается в экран и сворачивается
                // обратно. `sourceID` — сам маршрут, тот же объект, что и в
                // `matchedTransitionSource`, поэтому стороны перехода не могут разъехаться.
                .navigationTransition(.zoom(sourceID: route, in: zoom))
                #if DEBUG
                // `-debugCloseEntity` — снять экран через 2с: свернуть зум из шелла нечем,
                // а обратный ход надо смотреть покадрово так же, как прямой. Задача висит
                // на самом экране, а не на витрине: витрину под пушем размонтирует,
                // и её `task` отменяется вместе с ожиданием.
                .task {
                    guard UserDefaults.standard.bool(forKey: "debugCloseEntity") else { return }
                    try? await Task.sleep(for: .seconds(2))
                    guard !Task.isCancelled else { return }
                    navigation.pop()
                }
                #endif
        }
        .task {
            #if DEBUG
            // `-debugMockFeed` — прогон на моках без сети: сверка вёрстки с макетом
            // не должна зависеть от того, что сегодня отдали API.
            guard !UserDefaults.standard.bool(forKey: "debugMockFeed") else { return }
            #endif
            await catalog.loadIfNeeded()
        }
    }
}
