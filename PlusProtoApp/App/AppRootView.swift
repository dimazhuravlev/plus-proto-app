import SwiftUI

/// Композиционный корень: владеет глобальными состояниями, раздаёт их вниз
/// и держит фиксированный хром поверх контента.
struct AppRootView: View {
    @State private var navigation = AppNavigationState()
    @State private var actionBar = ActionBarState()
    @State private var keyboard = KeyboardObserver()
    @State private var search = SearchState()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            tabContent
                // Поджимаем контент скролла, а не фрейм: лента едет под хромом, но в покое
                // из-под него выходит. `contentMargins` едет по environment, поэтому доходит
                // и до запушенных экранов — `safeAreaInset` снаружи через NavigationStack
                // не пробивается (проверено на симуляторе).
                .contentMargins(.bottom, PlusChromeMetrics.contentBottomInset, for: .scrollContent)

            // Подложка нижнего хрома — своим слоем на всю высоту экрана, чтобы уйти
            // под home indicator: изнутри `overlay` ниже safe area она не пробивается.
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                TabBarUnderlay()
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
        .overlay(alignment: .top) {
            TopScrim()
        }
        // Между контентом и хромом: расфокусить надо экран, но не бар с клавиатурой.
        .overlay {
            SearchOverlay(isActive: keyboard.isUp) {
                actionBar.isSearchFocused = false
            }
        }
        // Выдача поиска — поверх затемнения, но под баром: поле ввода должно
        // остаться видимым и нажимаемым.
        .overlay {
            SearchResultsView()
        }
        .overlay(alignment: .bottom) {
            BottomChrome()
        }
        // Поверх хрома: полноэкранный плеер вырастает из мини-плеера и обязан
        // накрыть и бар, и таббар.
        .overlay {
            GeometryReader { proxy in
                FullScreenPlayer(screen: proxy.size)
            }
            .ignoresSafeArea()
        }
        // Системное поднятие над клавиатурой отключаем на корне: иначе SwiftUI поднимает
        // весь overlay с хромом целиком (включая таббар), и это складывается с ручным
        // сдвигом бара — он улетал вдвое выше клавиатуры. Отступ считает `BottomChrome`.
        .ignoresSafeArea(.keyboard)
        // Возврат из открытой сущности возвращает и поиск: сам запрос с выдачей
        // никуда не девались, поэтому достаточно вернуть фокус полю. Слушаем здесь,
        // а не в баре: глубина навигации — свойство корня, а не хрома.
        .onChange(of: navigation.depth) { _, depth in
            if search.consumeResume(tab: navigation.activeTab, depth: depth) {
                actionBar.isSearchFocused = true
            }
        }
        .environment(navigation)
        .environment(actionBar)
        .environment(keyboard)
        .environment(search)
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
