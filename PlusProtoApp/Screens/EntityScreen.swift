import SwiftUI

/// Роутер экранов сущностей. Один вход на все три типа: путь навигации хранит
/// `EntityRoute`, и он же служит `sourceID` зум-перехода.
struct EntityScreen: View {
    let route: EntityRoute

    var body: some View {
        screen
            // Пока экран на месте, подпись карточки, из которой он развернулся, спрятана
            // вместе с её обложкой (`ZoomPresence`).
            .background {
                ZoomPresenceTracker(route: route)
                    .frame(width: 0, height: 0)
            }
            #if DEBUG
            .onAppear { LayerProbe.dumpGesturesIfRequested() }
            #endif
    }

    @ViewBuilder
    private var screen: some View {
        switch route {
        case .movie(let ref): MovieScreen(entity: ref)
        case .book(let ref): BookScreen(entity: ref)
        case .album(let ref): AlbumScreen(entity: ref)
        case .playlist(let ref): PlaylistScreen(entity: ref)
        case .artist(let ref): PersonScreen(role: .artist, entity: ref)
        case .director(let ref): PersonScreen(role: .director, entity: ref)
        case .writer(let ref): PersonScreen(role: .writer, entity: ref)
        case .episodes(let ref): SeriesEpisodesScreen(entity: ref)
        }
    }
}

// MARK: - Стопка слоя

/// Экран сущности в слое поверх хрома **плюс презентация следующего экрана слоя**.
///
/// «Похожее» кладёт следующий фильм в `coveredPath`, и каждый экран слоя показывает
/// свой «следующий» собственным вложенным `fullScreenCover` — стопка презентаций
/// вместо `NavigationStack` внутри одной. Не прихоть: у зум-перехода есть свой
/// интерактивный дисмисс от левого края, и в стеке он перехватывал свайп у жеста
/// попа — свайп-назад закрывал весь слой на витрину. Со стопкой жест по построению
/// снимает ровно один экран: возврат — к предыдущему фильму (правка пользователя
/// 2026-08-25, заменила NavigationStack из первой версии).
///
/// Вложенный переход — тоже зум: источник помечает карточка «Похожего» через
/// `entityZoomNamespace`, и экран разворачивается из неё, а свайп сворачивает обратно.
///
/// **Экраны, открытые из фильма дальше** (режиссёр, а с его экрана — альбомы, книги,
/// персоны), — с таббаром и action bar (правка пользователя 2026-10-04): фильм хром
/// накрывает, остальные экраны живут с ним, как в стеке таба. Корневой хром под
/// полноэкранным слоем не виден, поэтому у такого экрана хром свой — тот же
/// `BottomChrome` с подложкой и слоями поиска. Фокус поиска берёт только верхний бар
/// (`AppNavigationState.isTop`). Тап по своему табу снимает слой, по другому — уводит
/// на тот таб, а слой со стопкой остаётся за своим и встаёт на место, когда таб выбирают
/// снова (`AppNavigationState.select`, 2026-10-31).
struct CoveredEntityScreen: View {
    let route: EntityRoute
    /// Сколько экранов слоя лежит под этим: корень — 0, его «похожее» — 1…
    let depth: Int
    /// Таб, которому принадлежит слой (`CoveredLayer`): стопку экран читает у него, а не
    /// у активного таба — на смене таба она не должна подменяться чужой.
    let tab: AppTab
    @Environment(AppNavigationState.self) private var navigation
    @Namespace private var zoom

    var body: some View {
        screen
            .environment(\.entityZoomNamespace, zoom)
            // Связка поиска с навигацией — на каждом экране слоя, и на фильме тоже:
            // решает верхний, а корень под слоем снят с окна (`SearchNavigationSync`).
            .modifier(SearchNavigationSync(layer: depth))
            .fullScreenCover(item: next) { pushed in
                CoveredEntityScreen(route: pushed, depth: depth + 1, tab: tab)
                    .navigationTransition(.zoom(sourceID: pushed, in: zoom))
            }
            // Возврат на таб: стопка слоя встаёт по экрану — следующий за этим (`AppNavigationState.revealedLayerDepth`).
            .onAppear { navigation.layerScreenAppeared(depth: depth, of: tab) }
            #if DEBUG
            .onAppear { NavTrace.log("layer screen + d\(depth) \(tab) \(route.id)") }
            .onDisappear { NavTrace.log("layer screen − d\(depth) \(tab) \(route.id)") }
            #endif
    }

    @ViewBuilder
    private var screen: some View {
        if route.coversChrome {
            EntityScreen(route: route)
        } else {
            // Тот же состав, что у корня (`AppRootView`): контент со слоями поиска,
            // подложка хрома во всю высоту и хром оверлеем.
            ZStack {
                SearchLayers(host: .pushed) {
                    EntityScreen(route: route)
                }
                // Карточки выдачи — источник зума в namespace слоя: следующий экран
                // стопки разворачивается из них, как из выдачи в стеке таба.
                .environment(\.stackZoomNamespace, zoom)

                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    TabBarUnderlay()
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }
            .overlay(alignment: .bottom) {
                BottomChrome()
            }
            .environment(\.chromeLayer, depth)
            // Подъём над клавиатурой хром считает сам — как в корне.
            .ignoresSafeArea(.keyboard)
        }
    }

    /// Следующий экран слоя — элемент `coveredPath` своей глубины. Сброс в nil
    /// (свайп или крестик) срезает путь **начиная с себя**: вместе с экраном
    /// уходит и всё, что он успел открыть поверх.
    private var next: Binding<EntityRoute?> {
        Binding(
            get: {
                let path = navigation.layerPath(of: tab)
                guard depth < navigation.layerRevealLimit(of: tab) else { return nil }
                return path.indices.contains(depth) ? path[depth] : nil
            },
            set: { value in
                // Слой ушёл вместе с табом — SwiftUI снимает и вложенные экраны и пишет сюда
                // `nil`, но стопка остаётся за табом: вернутся — она встанет целиком.
                // Срезает её только закрытие внутри слоя активного таба (свайп, крестик).
                guard navigation.activeTab == tab, navigation.coveredRoute != nil else { return }
                var path = navigation.layerPath(of: tab)
                if value == nil, path.count > depth {
                    path.removeSubrange(depth...)
                    navigation.setLayerPath(path, of: tab)
                }
            }
        )
    }
}

/// Namespace зум-перехода вложенного экрана слоя. Кладёт `CoveredEntityScreen`,
/// читает карточка «Похожего», помечая себя источником. Через environment, а не
/// параметрами: между экраном и секцией несколько слоёв вью, которым он не нужен, —
/// тот же приём, что у `showcaseThumbnail` витрины.
extension EnvironmentValues {
    @Entry var entityZoomNamespace: Namespace.ID?

    /// Namespace зума экранов стека: источник — миниатюры витрины и карточки выдачи
    /// поиска, назначение — `navigationDestination` и слой карточки фильма на витрине.
    /// Живёт в корне (`AppRootView`): выдача — сосед экрана в `SearchLayers`, а не его
    /// потомок, и namespace витрины до неё не дотягивался — экран, открытый из выдачи,
    /// зумился из центра экрана и на возврате сворачивался в никуда (жалоба
    /// пользователя 2026-10-03: моргал на возврате в поиск).
    @Entry var stackZoomNamespace: Namespace.ID?
}
