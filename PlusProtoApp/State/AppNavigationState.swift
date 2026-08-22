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

    func path(for tab: AppTab) -> Binding<NavigationPath> {
        Binding(
            get: { self.paths[tab] ?? NavigationPath() },
            set: { self.paths[tab] = $0 }
        )
    }
}
