import SwiftUI

/// Витрина «Плюс» — главный экран супераппа.
struct ShowcaseScreen: View {
    /// Каталог живёт в корне приложения, а не здесь: витрина размонтируется
    /// на каждом переключении таба, и вместе с её `@State` пропадала бы вся лента —
    /// на возврате собирался бы другой фильм, другой альбом и другие книги, да ещё
    /// и новыми запросами (задача 2026-08-27: контент не должен перезагружаться).
    @Environment(ShowcaseCatalog.self) private var catalog
    @Environment(AppNavigationState.self) private var navigation
    /// Namespace зум-перехода живёт здесь: и источник (карточка ленты), и назначение
    /// (`navigationDestination`) — потомки этого вью, поэтому пробрасывать его
    /// через environment не нужно.
    @Namespace private var zoom

    var body: some View {
        @Bindable var navigation = navigation
        return ZStack {
            Color.black.ignoresSafeArea()
            ShowcaseFeedView(feed: catalog.feed, zoom: zoom)
        }
        // Карточка тайтла — слоем поверх всего, а не пушем: `fullScreenCover` кроется
        // на уровне окна, то есть выше хрома по определению. Пушем это недостижимо —
        // хром лежит слоем над контентом табов. Зум при этом сохраняется: `.zoom`
        // работает и для презентаций, не только для пуша.
        .fullScreenCover(item: $navigation.coveredRoute) { route in
            // Следующие фильмы («Похожее») экран показывает сам, вложенными
            // слоями — см. `CoveredEntityScreen`: свайп от края возвращает
            // на один фильм назад, а не на витрину.
            CoveredEntityScreen(route: route, depth: 0)
                // Свежая идентичность на случай подмены корня слоя, пока он
                // показан (повторный отладочный тап витрины): без неё новому
                // экрану достаётся @State старого (стор деталей, скролл, ролик).
                .id(route)
                .navigationTransition(.zoom(sourceID: route, in: zoom))
                #if DEBUG
                .task {
                    guard UserDefaults.standard.bool(forKey: "debugCloseEntity") else { return }
                    try? await Task.sleep(for: .seconds(2))
                    guard !Task.isCancelled else { return }
                    navigation.close()
                }
                #endif
        }
        .navigationDestination(for: EntityRoute.self) { route in
            // Слои поиска — и на пуше: поиск, открытый **с** альбома или книги,
            // обязан лечь поверх них. В корне стека они его не накрывали бы —
            // пуш рисуется выше корня (жалоба пользователя 2026-08-27).
            SearchLayers(host: .pushed) {
                EntityScreen(route: route)
            }
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
        // Загрузку витрины держит корень (`AppRootView`): пока она идёт, на экране
        // стоит заставка, а этот экран за своё время жизни не отвечает — его
        // размонтирует переключение таба.
    }
}
