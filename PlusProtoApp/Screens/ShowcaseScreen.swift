import SwiftUI

/// Витрина «Плюс» — главный экран супераппа.
///
/// Каталог живёт здесь, а не в `AppRootView`: витрина — единственный его потребитель,
/// а её сборка не должна инвалидировать хром.
struct ShowcaseScreen: View {
    @State private var catalog = ShowcaseCatalog()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ShowcaseFeedView(feed: catalog.feed)
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
