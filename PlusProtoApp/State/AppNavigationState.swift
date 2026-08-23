import SwiftUI

/// Навигация супераппа: активный таб и независимый путь у каждого таба.
///
/// Пути живут здесь, а не в `@State` контейнера контента: при переключении таба его
/// `NavigationStack` размонтируется, и путь должен переживать это снаружи. Таб держим
/// тут же, чтобы переключать его мог не только таббар (тап по чипу action bar,
/// кросс-сервисные переходы из Алисы) — в MusicPlayer это было заперто в `@State`
/// семисотстрочного вью и оттуда недостижимо.
@Observable
final class AppNavigationState {
    var activeTab: AppTab = .plus

    /// Экран сущности, показанный **слоем поверх хрома** вместо пуша (см.
    /// `EntityRoute.coversChrome`). Живёт отдельно от путей: он не элемент стека,
    /// а отдельная презентация, и переживать переключение таба ему не нужно.
    var coveredRoute: EntityRoute?

    private var paths: [AppTab: NavigationPath] = [:]

    init() {
        #if DEBUG
        // Стартовый таб можно задать аргументом запуска — тапать симулятор из шелла нельзя,
        // а верификация в проекте скриншотная:
        //   xcrun simctl launch booted com.dima.PlusProtoApp -debugTab kinopoisk
        if let key = UserDefaults.standard.string(forKey: "debugTab"),
           let tab = AppTab(debugKey: key) {
            activeTab = tab
        }
        #endif
    }

    /// Тап по уже активному табу возвращает его стек на корень — привычное поведение
    /// системных таббаров, заодно единственный выход из пуша без свайпа.
    func select(_ tab: AppTab) {
        guard tab != activeTab else {
            if !(paths[tab]?.isEmpty ?? true) { paths[tab] = NavigationPath() }
            return
        }
        activeTab = tab
    }

    /// Программный пуш. Нужен и отладке (тапнуть по симулятору из шелла нечем),
    /// и будущим кросс-сервисным переходам из Алисы.
    func push(_ value: some Hashable, in tab: AppTab? = nil) {
        let tab = tab ?? activeTab
        var path = paths[tab] ?? NavigationPath()
        path.append(value)
        paths[tab] = path
    }

    /// Открыть экран сущности: пушем или слоем поверх хрома — решает сам маршрут.
    /// Одна точка входа, чтобы витрина и отладочный тап не расходились в способе.
    func open(_ route: EntityRoute, in tab: AppTab? = nil) {
        if route.coversChrome {
            coveredRoute = route
        } else {
            push(route, in: tab)
        }
    }

    /// Закрыть то, что открыто последним.
    func close(in tab: AppTab? = nil) {
        if coveredRoute != nil {
            coveredRoute = nil
        } else {
            pop(in: tab)
        }
    }

    /// Программный поп. Именно `removeLast`, а не подмена пути целиком: замена всего
    /// `NavigationPath` читается SwiftUI как смена контента, и экран снимается срезом,
    /// без зум-перехода.
    func pop(in tab: AppTab? = nil) {
        let tab = tab ?? activeTab
        guard var path = paths[tab], !path.isEmpty else { return }
        path.removeLast()
        paths[tab] = path
    }

    func path(for tab: AppTab) -> Binding<NavigationPath> {
        Binding(
            get: { self.paths[tab] ?? NavigationPath() },
            set: { self.paths[tab] = $0 }
        )
    }
}
