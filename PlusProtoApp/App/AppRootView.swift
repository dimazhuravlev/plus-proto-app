import SwiftUI

/// Композиционный корень: владеет глобальными состояниями, раздаёт их вниз
/// и держит фиксированный хром поверх контента.
struct AppRootView: View {
    @State private var navigation = AppNavigationState()
    @State private var actionBar = ActionBarState()
    @State private var keyboard = KeyboardObserver()
    @State private var search = SearchState()
    /// Namespace зума экранов стека — см. `EnvironmentValues.stackZoomNamespace`.
    @Namespace private var stackZoom
    /// Каталог витрины — здесь, а не в самой витрине: `ShowcaseScreen`
    /// размонтируется на каждом переключении таба, и лента собиралась бы заново
    /// (другой фильм, другой альбом, новые запросы). Хром от этого не страдает:
    /// `@Observable` перерисовывает только тех, кто читает `feed`, а корень
    /// его не читает.
    @State private var catalog = ShowcaseCatalog()
    /// Заставка на запуске. `@State` корня, поэтому показывается ровно один раз
    /// за процесс: возврат из фона её не воскрешает.
    @State private var isSplashShown = !SplashTiming.isDisabled

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
        // Верхний скрим — только у витрины: она одна уезжает под статус-бар без своего
        // навбара. У экранов с `EntityNavBar` (альбом, книга, заглушки сервисов) блюр
        // один — подложка навбара под его кнопками. Скрим лежит оверлеем поверх всего
        // и мылил бы сами элементы бара: верх обложки в нём (жалоба пользователя
        // 2026-10-03). Прячется прозрачностью, а не ветвлением: размонтированный
        // `VariableBlurView` пересоздавался бы на каждом пуше.
        .overlay(alignment: .top) {
            TopScrim()
                .opacity(showsTopScrim ? 1 : 0)
                .animation(TopScrimMotion.fade, value: showsTopScrim)
        }
        // Между контентом и хромом: расфокусить надо экран, но не бар с клавиатурой.
        .overlay(alignment: .bottom) {
            BottomChrome()
        }
        // Киноплеер, читалка и плеер музыки живут не здесь, а отдельной презентацией
        // поверх всего, включая слой карточки тайтла, — см. `ContentPlayerPresenter`.
        // В дереве корня от них только невидимый мост из состояния в UIKit.
        .background { ContentPlayerHost() }
        // Выше всего, включая плеер: пока витрина собирается, показывать нечего
        // и трогать нечего. Уходит одной прозрачностью — см. `SplashTiming.fade`.
        .overlay {
            if isSplashShown {
                SplashScreen()
                    .transition(.opacity)
                    // Заставка ловит касания на себя: под ней лента уже стоит,
                    // и случайный тап по невидимой карточке открыл бы экран,
                    // которого пользователь не выбирал.
                    .contentShape(.rect)
                    .onTapGesture {}
            }
        }
        // Сборка витрины идёт **под заставкой** и живёт в корне, а не в самой
        // витрине: экран таба размонтируется при переключении, а лента должна
        // собраться один раз за процесс.
        .task {
            // Потолок ожидания отдельной задачей: сеть может отвечать минуту
            // (у `URLSession` свои 20с на запрос), и держать заставку до последнего
            // нельзя — витрина умеет жить на моках и достраиваться по мере ответов.
            let deadline = Task {
                try? await Task.sleep(for: SplashTiming.timeout)
                guard !Task.isCancelled else { return }
                hideSplash()
            }
            await prepareShowcase()
            deadline.cancel()
            hideSplash()
        }
        // Системное поднятие над клавиатурой отключаем на корне: иначе SwiftUI поднимает
        // весь overlay с хромом целиком (включая таббар), и это складывается с ручным
        // сдвигом бара — он улетал вдвое выше клавиатуры. Отступ считает `BottomChrome`.
        .ignoresSafeArea(.keyboard)
        // Возврат из открытой сущности возвращает и поиск: сам запрос с выдачей
        // никуда не девались, поэтому достаточно вернуть фокус полю. Слушаем здесь,
        // а не в баре: глубина навигации — свойство корня, а не хрома.
        .onChange(of: navigation.depth) { _, depth in
            // Поиск, открытый на пуше, переезжает вместе с пользователем: свайп-назад
            // с альбома клавиатуру не опускает, и слои обязаны оказаться на экране,
            // куда он вернулся. Только пока из выдачи никуда не уходили — там глубина
            // меняется как раз потому, что поиск остался позади.
            if actionBar.isSearchFocused, !search.isSuspended {
                search.host(at: depth)
            }
            if search.consumeResume(tab: navigation.activeTab, depth: depth) {
                // Клавиатура — после перехода, не посреди него: см. `SearchState.resumeDelay`.
                let tab = navigation.activeTab
                Task { @MainActor in
                    try? await Task.sleep(for: SearchState.resumeDelay)
                    // Пока ждали, пользователь мог уйти снова — в другую карточку
                    // выдачи или в другой таб: тогда клавиатура ему не нужна.
                    let stillHere = search.isResuming
                        && navigation.activeTab == tab
                        && navigation.depth == depth
                    search.finishResume()
                    if stillHere { actionBar.isSearchFocused = true }
                }
            }
        }
        // Поиск прикрепляется к экрану, с которого его открыли, — и к нему же
        // возвращается: `consumeResume` выше выставляет фокус, и глубина берётся
        // заново, уже после того как экран вернулся.
        .onChange(of: actionBar.isSearchFocused) { _, focused in
            guard focused else { return }
            search.host(at: navigation.depth)
        }
        .environment(navigation)
        .environment(actionBar)
        .environment(keyboard)
        .environment(search)
        .environment(catalog)
        .environment(\.stackZoomNamespace, stackZoom)
    }

    /// Витрина на экране: таб «Плюс» без пушей. Слой карточки фильма не в счёт —
    /// он накрывает скрим собой, и прятать его под ним незачем.
    private var showsTopScrim: Bool {
        navigation.activeTab == .plus && navigation.stackDepth == 0
    }

    /// Собирает витрину целиком: данные трёх сервисов и картинки первого экрана.
    ///
    /// Картинки ждём наравне с данными — в этом весь смысл заставки. Без прогрева
    /// лента открывается с готовой раскладкой, но пустыми обложками, и они въезжают
    /// на глазах: с точки зрения пользователя это то же самое мигание.
    private func prepareShowcase() async {
        let started = ContinuousClock.now

        if shouldLoadLiveFeed {
            await catalog.loadIfNeeded()
            await ArtworkLoader.shared.prewarm(catalog.feed.artworks)
        }

        // Минимальная выдержка: когда всё пришло из кэша за сотню миллисекунд,
        // заставка не должна мигнуть и пропасть — это читается сбоем, а не запуском.
        let elapsed = ContinuousClock.now - started
        if elapsed < SplashTiming.minimum {
            try? await Task.sleep(for: SplashTiming.minimum - elapsed)
        }
    }

    /// Идти ли в сеть за витриной. Ходим, только если есть чем: без ключа Кинопоиска
    /// каждый запрос вернул бы 401, а лента всё равно осталась бы моковой — так что
    /// у свежего клона без ключей поведение ровно то же, что под `-debugMockFeed`.
    private var shouldLoadLiveFeed: Bool {
        #if DEBUG
        // `-debugMockFeed` — прогон на моках без сети: ждать нечего.
        if UserDefaults.standard.bool(forKey: "debugMockFeed") { return false }
        #endif
        return APIKeysCheck.isKinopoiskConfigured
    }

    private func hideSplash() {
        guard isSplashShown else { return }
        withAnimation(SplashTiming.fade) { isSplashShown = false }
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
            // Затемнение и выдача живут **внутри стека**, а не слоем над всем
            // приложением: так пуш, открытый из выдачи, накрывает их собой, а поп
            // открывает обратно — на возврате витрина не мелькает. Здесь корень
            // стека, второй носитель слоёв — запушенный экран (`SearchLayers`
            // в `navigationDestination`): поиск, открытый **с** альбома, обязан
            // лечь поверх альбома. Кто из них показывает слои, решает глубина
            // открытия поиска.
            //
            // Хром (`BottomChrome`) остаётся выше всех и виден и на выдаче,
            // и на запушенном экране — как просил пользователь (2026-08-25):
            // из поиска всё, кроме карточки фильма, открывается с таббаром и баром.
            SearchLayers(host: .stackRoot) {
                content()
            }
            .background(Color.black)
        }
    }
}
