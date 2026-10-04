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
    /// Главная Кинопоиска — по той же причине, что каталог витрины: экран таба
    /// размонтируется на переключении, а лента собирается раз за процесс.
    @State private var cinema = CinemaCatalog()
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
        // Связка поиска с навигацией — возврат выдачи из карточки, переезд поиска
        // по стеку, привязка к экрану фокуса. Висит и на экранах слоя фильма (у них
        // свой хром, 2026-10-04), решает верхний — см. `SearchNavigationSync`.
        .modifier(SearchNavigationSync(layer: nil))
        // Выдача без фокуса принадлежит своему табу: на другом табе её слой встал бы
        // на корне чужого стека.
        .onChange(of: navigation.activeTab) {
            search.isBrowsing = false
            // Ушли из карточки выдачи на другой таб — отметка ухода больше не наша:
            // иначе выдача «Плюса» вставала бы на корне чужого таба.
            search.dropSuspension()
            // И раскрытый раздел: новый поиск на другом табе начинается с обзора.
            search.collapse()
        }
        .environment(navigation)
        .environment(actionBar)
        .environment(keyboard)
        .environment(search)
        .environment(catalog)
        .environment(cinema)
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
            tabStack(.kinopoisk) { CinemaHomeScreen() }
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
            // Экраны сущностей и слой фильма — у каждого таба: карточки выдачи поиска
            // открываются откуда угодно (см. `EntityDestinations`).
            .modifier(EntityDestinations(zoom: stackZoom))
            // Корень стека — свой хостинг-контроллер, и корневое
            // `ignoresSafeArea(.keyboard)` до него не доходит (как и до пушей).
            // Поднятая клавиатура поджимала корень, витрина не ужималась, и стопка
            // вылезала за кадр поровну вверх и вниз: выдача уезжала на 38pt вверх,
            // а снизу инсет клавиатуры складывался с её собственным отступом.
            // Отступ от клавиатуры выдача считает сама.
            .ignoresSafeArea(.keyboard)
            // Системный бар у корня выключен — у всех табов разом. Витрина его не
            // прятала: до первого пуша он себя не проявлял, а после попа с экрана
            // со спрятанным баром корень получал его инсет, и выдача на возврате
            // съезжала на 54pt вниз (замер 2026-10-03).
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}
