import SwiftUI

/// Композиционный корень: владеет глобальными состояниями, раздаёт их вниз
/// и держит фиксированный хром поверх контента.
struct AppRootView: View {
    @State private var navigation = AppNavigationState()
    @State private var actionBar = ActionBarState()
    @State private var keyboard = KeyboardObserver()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            tabContent
                // Поджимаем контент скролла, а не фрейм: лента едет под хромом, но в покое
                // из-под него выходит. `contentMargins` едет по environment, поэтому доходит
                // и до запушенных экранов — `safeAreaInset` снаружи через NavigationStack
                // не пробивается (проверено на симуляторе).
                .contentMargins(.bottom, PlusChromeMetrics.contentBottomInset, for: .scrollContent)
        }
        .overlay(alignment: .bottom) {
            BottomChrome()
        }
        .environment(navigation)
        .environment(actionBar)
        .environment(keyboard)
    }

    /// Свой `NavigationStack` на каждый таб: путь независимый, хром остаётся снаружи стеков.
    /// Переключение — жёсткий `switch` без transition (решение 2026-08-22): случаи расписаны
    /// по одному, чтобы у каждого таба была своя идентичность вью и переключение не читалось
    /// SwiftUI как смена пути внутри одного стека.
    @ViewBuilder
    private var tabContent: some View {
        switch navigation.activeTab {
        case .plus:
            tabStack(.plus) { ShowcaseScreen() }
        case .music:
            tabStack(.music) { ServiceStubScreen(tab: .music) }
        case .kinopoisk:
            tabStack(.kinopoisk) { ServiceStubScreen(tab: .kinopoisk) }
        case .books:
            tabStack(.books) { ServiceStubScreen(tab: .books) }
        case .alisa:
            tabStack(.alisa) { ServiceStubScreen(tab: .alisa) }
        }
    }

    private func tabStack<Content: View>(
        _ tab: AppTab,
        @ViewBuilder content: () -> Content
    ) -> some View {
        NavigationStack(path: navigation.path(for: tab)) {
            content()
                .background(Color.black)
        }
    }
}
