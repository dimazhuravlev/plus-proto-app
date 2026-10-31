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
        content
            // Слоя фильма здесь нет: его показывает корень (`CoveredLayerPresenter`), который
            // смену таба переживает. Отсюда, с корня стека таба, слой оставался висеть поверх
            // чужого таба: стек размонтировался посреди показа (2026-10-31).
            //
            // Профиль — обычный экран стека (правка пользователя 2026-10-21): со слоями поиска,
            // как все пуши, — бар на нём живой.
            .navigationDestination(for: ProfileRoute.self) { _ in
                SearchLayers(host: .pushed) {
                    ProfileScreen()
                }
                .ignoresSafeArea(.keyboard)
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

/// Слой поверх хрома активного таба — карточка тайтла со своей стопкой. Висит на корне
/// приложения (`AppRootView`), а не на корне стека таба: у каждого таба слой свой
/// (`AppNavigationState.coveredRoute`), и на смене таба показ должен пережить размонтирование
/// стека — уходящий слой снимается, слой пришедшего таба встаёт, один показчик на всё.
///
/// Карточка тайтла — слоем поверх всего, а не пушем: `fullScreenCover` кроется на уровне
/// окна, то есть выше хрома по определению. Пушем это недостижимо — хром лежит слоем над
/// контентом табов. Зум при этом сохраняется: `.zoom` работает и для презентаций.
struct CoveredLayerPresenter: ViewModifier {
    /// Namespace зума — общий с витриной и выдачей (`stackZoomNamespace` из корня).
    let zoom: Namespace.ID

    @Environment(AppNavigationState.self) private var navigation
    /// Слой, который сейчас на экране, — по появлению его корня. Нужен записи `nil`:
    /// SwiftUI пишет её и тогда, когда сам снимает слой ушедшего таба, — уже после смены
    /// таба (трасса `-debugNavTrace` 2026-10-31), и без сверки она закрыла бы слой нового.
    @State private var presented: CoveredLayer?

    func body(content: Content) -> some View {
        content
            .fullScreenCover(item: layer) { layer in
                // Следующие фильмы («Похожее») экран показывает сам, вложенными
                // слоями — см. `CoveredEntityScreen`: свайп от края возвращает
                // на один фильм назад, а не на витрину.
                CoveredEntityScreen(route: layer.route, depth: 0, tab: layer.tab)
                    .onAppear { presented = layer }
                    .onDisappear { if presented == layer { presented = nil } }
                    // Нижний инсет под хром — как у контента табов (`AppRootView`): показ висел
                    // внутри таба и получал его через окружение, а экраны слоя со своим таббаром
                    // на него рассчитывают (ревью 2026-10-31: серии в слое уходили под бар).
                    // Фильм снимает его у себя сам.
                    .contentMargins(.bottom, PlusChromeMetrics.contentBottomInset, for: .scrollContent)
                    // Свежая идентичность на случай подмены корня слоя, пока он
                    // показан (повторный отладочный тап витрины): без неё новому
                    // экрану достаётся @State старого (стор деталей, скролл, ролик).
                    .id(layer)
                    // Клавиатуры на экране сущности нет, а открыть его могут прямо из
                    // выдачи, пока она поднята: без этого скролл получал её инсет
                    // на время перехода.
                    .ignoresSafeArea(.keyboard)
                    .navigationTransition(.zoom(sourceID: layer.route, in: zoom))
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
    }

    /// Слой активного таба. По `nil` снимается только тот слой, что сейчас и показан
    /// у активного таба, — закрытие свайпом зума. Слой ушедшего таба остаётся за ним.
    private var layer: Binding<CoveredLayer?> {
        Binding(
            get: { navigation.coveredRoute.map { CoveredLayer(tab: navigation.activeTab, route: $0) } },
            set: { value in
                guard value == nil, let presented, presented.tab == navigation.activeTab,
                      presented.route == navigation.coveredRoute else { return }
                navigation.coveredRoute = nil
            }
        )
    }
}

/// Слой и таб, которому он принадлежит: один и тот же фильм, открытый в двух табах, —
/// два разных слоя, и смена таба между ними обязана снять один и показать другой.
struct CoveredLayer: Hashable, Identifiable {
    let tab: AppTab
    let route: EntityRoute

    var id: Self { self }
}
