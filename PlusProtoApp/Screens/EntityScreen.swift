import SwiftUI

/// Роутер экранов сущностей. Один вход на все три типа: путь навигации хранит
/// `EntityRoute`, и он же служит `sourceID` зум-перехода.
struct EntityScreen: View {
    let route: EntityRoute

    var body: some View {
        switch route {
        case .movie(let ref): MovieScreen(entity: ref)
        case .book(let ref): BookScreen(entity: ref)
        case .album(let ref): AlbumScreen(entity: ref)
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
struct CoveredEntityScreen: View {
    let route: EntityRoute
    /// Сколько экранов слоя лежит под этим: корень — 0, его «похожее» — 1…
    let depth: Int
    @Environment(AppNavigationState.self) private var navigation
    @Namespace private var zoom

    var body: some View {
        EntityScreen(route: route)
            .environment(\.entityZoomNamespace, zoom)
            .fullScreenCover(item: next) { pushed in
                CoveredEntityScreen(route: pushed, depth: depth + 1)
                    .navigationTransition(.zoom(sourceID: pushed, in: zoom))
            }
    }

    /// Следующий экран слоя — элемент `coveredPath` своей глубины. Сброс в nil
    /// (свайп или крестик) срезает путь **начиная с себя**: вместе с экраном
    /// уходит и всё, что он успел открыть поверх.
    private var next: Binding<EntityRoute?> {
        Binding(
            get: {
                navigation.coveredPath.indices.contains(depth) ? navigation.coveredPath[depth] : nil
            },
            set: { value in
                if value == nil, navigation.coveredPath.count > depth {
                    navigation.coveredPath.removeSubrange(depth...)
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
}
