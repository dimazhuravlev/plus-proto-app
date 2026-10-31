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
    /// Главная Книг — так же (2026-10-04).
    @State private var books = BooksHomeCatalog()
    /// «Для вас» таба Музыки — так же (2026-10-17).
    @State private var music = MusicHomeCatalog()
    /// Заставка на запуске. `@State` корня, поэтому показывается ровно один раз
    /// за процесс: возврат из фона её не воскрешает.
    @State private var isSplashShown = !SplashTiming.isDisabled

    var body: some View {
        ZStack {
            Color.surfaceOne.ignoresSafeArea()

            tabContent
                // Вступление промо — когда заставка ушла и профиль не на экране: профиль теперь
                // пуш стека и прячет хром (`isChromeHidden`), а не презентация поверх всего.
                .environment(\.promoIntroReady, !isSplashShown && !navigation.isChromeHidden)
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
            .modifier(BottomChromeHiding(isHidden: navigation.isChromeHidden))
        }
        // Между контентом и хромом: расфокусить надо экран, но не бар с клавиатурой.
        .overlay(alignment: .bottom) {
            BottomChrome()
                .modifier(BottomChromeHiding(isHidden: navigation.isChromeHidden))
        }
        #if DEBUG
        // `-debugProfile 1` — открыть профиль через 1.5 с после запуска: тапнуть аватарку
        // из шелла нечем. Тот же пуш, что у аватарки.
        .task {
            guard UserDefaults.standard.bool(forKey: "debugProfile") else { return }
            try? await Task.sleep(for: .seconds(1.5))
            navigation.openProfile()
        }
        // `-debugSeedAudiobook 1` — положить в «Буду читать» две аудиокниги тем же путём, что
        // «+» аудиокниги в выдаче: проверить квадрат аудиокниги среди книг (`AudiobookFigure`)
        // без поиска. Пишет в коллекцию на диске — перед прогоном сохранить ключ `collection`.
        .task {
            guard UserDefaults.standard.bool(forKey: "debugSeedAudiobook") else { return }
            for (index, title) in ["Мастер и Маргарита", "Преступление и наказание"].enumerated() {
                let hit = SearchHit(
                    id: SearchHit.audiobookPrefix + "debug-\(index)",
                    kind: .book,
                    title: title,
                    subtitle: "Аудиокнига",
                    artwork: .asset("mockAudiobook\(index + 1)"),
                    route: nil,
                    artworkAspect: 1,
                    isAudiobook: true
                )
                CollectionStore.shared.setFavorite(.audiobook(hit), true)
            }
        }
        #endif
        // Киноплеер, читалка и плеер музыки живут не здесь, а отдельной презентацией
        // поверх всего, включая слой карточки тайтла, — см. `ContentPlayerPresenter`.
        // В дереве корня от них только невидимый мост из состояния в UIKit.
        .background { ContentPlayerHost() }
        // Слой «поверх всего» (тост, дальше шеринг) — отдельное окно: экран фильма и плееры
        // лежат выше корня, оверлей в этом `ZStack` под ними не виден. См. `OverlayWindow`.
        .background { OverlayWindowHost() }
        // Тап по тосту «добавлено в Моё» открывает «Моё» откуда угодно. Окно тоста окружения
        // корня не видит, поэтому корень отдаёт центру замыкание (идемпотентно: перезапись того же).
        .onAppear {
            // Конец превью — в очередь живого бара, а не лишнего экземпляра `@State`.
            actionBar.attachAudio()
            // Поиск живёт в табе, где его открыли (решение пользователя 2026-10-31): уходя
            // с таба, он паркуется со своим запросом и местом в стеке, а на другом табе его
            // нет; вернулись — он снова там, без клавиатуры. В том же апдейте, что смена
            // таба: выдача не гаснет поверх чужого контента. Ставится отсюда, а не из `init`
            // состояния — лишний экземпляр корня перезаписал бы обработчик собой.
            navigation.onTabChange = { [search, actionBar] old, new in
                search.park(leaving: old, isFocused: actionBar.isSearchFocused)
                if actionBar.isSearchFocused { actionBar.isSearchFocused = false }
                search.unpark(entering: new)
            }
            navigation.onShowRoot = { [search] tab in
                search.forgetParked(tab)
            }
            ToastCenter.shared.openCollection = { [navigation, actionBar, keyboard, search] in
                // 1. Клавиатура уходит мягко. Поиск «Моего» закрывается, как тапом по затемнению
                // (`dropSuspension` обязателен, иначе `SearchNavigationSync` вернёт выдачу); поиск
                // другого таба паркуется вместе с его слоем (`onTabChange`) — не стирается.
                if keyboard.isUp { keyboard.dismissSmoothly() }
                if navigation.activeTab == .collection {
                    actionBar.isSearchFocused = false
                    search.isBrowsing = false
                    search.dropSuspension()
                    search.collapse()
                }
                // 2. Экран шеринга лежит в окне тоста, сам себя не закроет.
                if ShareState.shared.presented != nil { ShareState.shared.dismissImmediately() }
                // 3. Плееры презентует UIKit поверх верхнего контроллера. Если под ними слой фильма —
                // его снимет `showRoot`, и вместе с ним вся стопка: второй `dismiss` разом дал бы
                // «dismiss is in progress». Иначе плееры закрываем сами (профиль — пуш стека,
                // не презентация).
                if navigation.coveredRoute == nil {
                    actionBar.closeAllPlayers()
                }
                // 4. Таб — мгновенно, без анимации; слой фильма — тоже без зума: его источник
                // уходит вместе с табом (`AppNavigationState.withoutLayerZoom`). «Моё» — с корня,
                // и его припаркованный поиск не возвращается (`onShowRoot`).
                navigation.showRoot(of: .collection)
                TabBarMotion.tapHaptic()
            }
        }
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
            // Главная Кинопоиска собирается следом, в фоне, пока на экране витрина:
            // к первому переходу в таб лента и её первые картинки уже готовы, и экран
            // открывается сразу собой, без скелетона (жалоба 2026-10-04 на рывки).
            // После витрины, а не вместе с ней: промо берётся из запаса, который та
            // как раз пополняет, — и заставку это не держит.
            await cinema.loadIfNeeded()
            await books.loadIfNeeded()
            await music.loadIfNeeded()
        }
        // Системное поднятие над клавиатурой отключаем на корне: иначе SwiftUI поднимает
        // весь overlay с хромом целиком (включая таббар), и это складывается с ручным
        // сдвигом бара — он улетал вдвое выше клавиатуры. Отступ считает `BottomChrome`.
        .ignoresSafeArea(.keyboard)
        // Связка поиска с навигацией — возврат выдачи из карточки, переезд поиска
        // по стеку, привязка к экрану фокуса. Висит и на экранах слоя фильма (у них
        // свой хром, 2026-10-04), решает верхний — см. `SearchNavigationSync`.
        .modifier(SearchNavigationSync(layer: nil))
        // Слой фильма активного таба — с корня, который смену таба переживает
        // (`CoveredLayerPresenter`). Поиск на смене таба паркуется (`onTabChange` выше).
        .modifier(CoveredLayerPresenter(zoom: stackZoom))
        .environment(navigation)
        .environment(actionBar)
        .environment(keyboard)
        .environment(search)
        .environment(catalog)
        .environment(cinema)
        .environment(books)
        .environment(music)
        // Коллекция «Моё» — одна на приложение (`CollectionStore.shared`): сердце
        // мини-плеера отмечает трек из `ActionBarState`, у которого окружения нет.
        .environment(CollectionStore.shared)
        .environment(\.stackZoomNamespace, stackZoom)
    }

    /// Собирает витрину целиком: данные трёх сервисов и картинки первого экрана.
    ///
    /// Картинки ждём наравне с данными — в этом весь смысл заставки. Без прогрева
    /// лента открывается с готовой раскладкой, но пустыми обложками, и они въезжают
    /// на глазах: с точки зрения пользователя это то же самое мигание.
    private func prepareShowcase() async {
        let started = ContinuousClock.now
        // Шейдер голографии обложки альбома — под заставкой, параллельно с данными: первый
        // блик не должен собирать пайплайн на экране альбома (`CoverHoloShader`).
        async let holoShader: Void = CoverHoloShader.prewarm()

        // Постер начатого фильма для карточки «Продолжить» — до её первого кадра.
        await actionBar.watchHistory.backfillContinuingPoster()
        if shouldLoadLiveFeed {
            await catalog.loadIfNeeded()
            // История прогревается отдельно от рекомендательного промоблока.
            await ArtworkLoader.shared.prewarm(
                catalog.feed.artworks + actionBar.recently.artworks
            )
        }
        let promo = ShowcasePromo.composed(catalog.homePromo(catalog.feed.promo))
        PromoCardGlowRaster.retain(promo)
        // Prepare glows before a swipe, not while the next card becomes active.
        for item in promo { await PromoCardGlowRaster.render(item) }
        // Капля станции промо — растр на цвет: считается под заставкой, а не на первом
        // кадре показа. И на моках: станция в круге есть всегда.
        PromoStationPetal.prewarm(promo)
        await holoShader

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
            tabStack(.music) { MusicHomeScreen() }
        case .kinopoisk:
            tabStack(.kinopoisk) { CinemaHomeScreen() }
        case .books:
            tabStack(.books) { BooksHomeScreen() }
        case .collection:
            tabStack(.collection) { CollectionScreen() }
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
            .background(Color.surfaceOne)
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

// MARK: - Скрытие нижнего хрома

enum BottomChromeHidingMotion {
    /// Хром уезжает за нижнюю кромку целиком — с подложкой и home indicator
    static let distance: CGFloat = 240
    /// Вместе с пушем экрана: ease-in-out, длительность перехода стека
    static let slide: Animation = .easeInOut(duration: 0.35)
    static let fade: Animation = .easeInOut(duration: 0.2)
}

/// Нижний хром прячется на экранах, где его нет (профиль): уезжает за нижнюю кромку,
/// а не гаснет; с Reduce Motion — только прозрачность.
struct BottomChromeHiding: ViewModifier {
    let isHidden: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .offset(y: isHidden && !reduceMotion ? BottomChromeHidingMotion.distance : 0)
            .opacity(isHidden && reduceMotion ? 0 : 1)
            .allowsHitTesting(!isHidden)
            .animation(reduceMotion ? BottomChromeHidingMotion.fade : BottomChromeHidingMotion.slide, value: isHidden)
    }
}

/// Экран без нижнего хрома — пока он на экране, таббар и action bar спрятаны.
struct HidesBottomChrome: ViewModifier {
    @Environment(AppNavigationState.self) private var navigation

    func body(content: Content) -> some View {
        content
            .onAppear { navigation.hideChrome() }
            .onDisappear { navigation.showChrome() }
    }
}
