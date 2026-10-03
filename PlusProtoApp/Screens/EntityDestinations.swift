import SwiftUI

/// Куда ведут маршруты сущностей — на корне стека **каждого** таба.
///
/// Жили на витрине, и с других табов карточки выдачи поиска не открывали ничего:
/// глубина навигации росла, а экрана не было — выдача залипала под несуществующей
/// карточкой, а фильм потом сам всплывал на «Плюсе» (проверка навигации поиска
/// 2026-10-03). Поиск открывается на любом табе, значит и назначения нужны везде.
struct EntityDestinations: ViewModifier {
    /// Namespace зума — общий с витриной и выдачей (`stackZoomNamespace` из корня).
    let zoom: Namespace.ID

    @Environment(AppNavigationState.self) private var navigation

    func body(content: Content) -> some View {
        @Bindable var navigation = navigation
        return content
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
                    // Клавиатуры на экране сущности нет, а открыть его могут прямо из
                    // выдачи, пока она поднята: без этого скролл получал её инсет
                    // на время перехода.
                    .ignoresSafeArea(.keyboard)
                    .navigationTransition(.zoom(sourceID: route, in: zoom))
                    #if DEBUG
                    .task {
                        guard UserDefaults.standard.bool(forKey: "debugCloseEntity") else { return }
                        try? await Task.sleep(for: .seconds(2))
                        guard !Task.isCancelled else { return }
                        navigation.close()
                        LayerProbe.dumpAfterClose()
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
                // Пуш живёт в своём хостинг-контроллере, и корневое `ignoresSafeArea(.keyboard)`
                // до него не доходит: открытый из выдачи экран получал инсет клавиатуры,
                // пока она уезжала, а на возврате — пока поднималась, и перекладывался
                // посреди перехода. Выдача на пуше считает отступ клавиатуры сама, как в корне.
                .ignoresSafeArea(.keyboard)
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
                    LayerProbe.dumpAfterClose()
                }
                #endif
            }
    }
}
