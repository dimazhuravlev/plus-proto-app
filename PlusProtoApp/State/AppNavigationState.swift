import SwiftUI

/// Навигация супераппа: активный таб и независимый путь у каждого таба.
///
/// Пути живут здесь, а не в `@State` контейнера контента: при переключении таба его
/// `NavigationStack` размонтируется, и путь должен переживать это снаружи. Таб держим
/// тут же, чтобы переключать его мог не только таббар (тап по чипу action bar,
/// кросс-сервисные переходы) — в MusicPlayer это было заперто в `@State`
/// семисотстрочного вью и оттуда недостижимо.
@Observable
final class AppNavigationState {
    var activeTab: AppTab = .plus {
        didSet {
            guard activeTab != oldValue else { return }
            #if DEBUG
            NavTrace.log("tab \(oldValue) → \(activeTab) layers=\(layerRoutes.mapValues(\.id)) paths=\(layerPaths.mapValues { $0.map(\.id) })")
            #endif
            onTabChange?(oldValue, activeTab)
        }
    }

    /// Что сделать на смене таба в том же апдейте — ставит корень (`AppRootView`, `onAppear`):
    /// поиск уходящего таба паркуется, поиск пришедшего возвращается. Синхронно, а не
    /// `onChange` корня: из слоя фильма таб меняют, пока корень снят с окна, и его
    /// `onChange` в это время не приходят.
    @ObservationIgnored var onTabChange: ((AppTab, AppTab) -> Void)?

    /// Таб открывают с корня (`showRoot`) — ставит корень: поиск этого таба забывается.
    @ObservationIgnored var onShowRoot: ((AppTab) -> Void)?

    /// Слой поверх хрома — **у каждого таба свой**, как и стек (решение пользователя
    /// 2026-10-31: «внутри каждого таба свой независимый навигационный стек»). Ушли на другой
    /// таб — слой остаётся за своим табом и встаёт на место, когда таб выбирают снова.
    /// Прежде слой был один на приложение и снимался сменой таба, а показывал его корень
    /// стека таба: тот размонтировался посреди показа, и фильм оставался висеть поверх
    /// чужого таба (поиск → фильм → режиссёр → другой таб).
    private var layerRoutes: [AppTab: EntityRoute] = [:]
    private var layerPaths: [AppTab: [EntityRoute]] = [:]

    /// Экран сущности, показанный **слоем поверх хрома** вместо пуша (см.
    /// `EntityRoute.coversChrome`), — у активного таба. Живёт отдельно от путей: он не
    /// элемент стека, а отдельная презентация (её показывает корень, `AppRootView`).
    var coveredRoute: EntityRoute? {
        get { layerRoutes[activeTab] }
        set {
            let old = layerRoutes[activeTab]
            #if DEBUG
            NavTrace.log("layer[\(activeTab)] \(old?.id ?? "nil") → \(newValue?.id ?? "nil")")
            #endif
            layerRoutes[activeTab] = newValue
            // Новый слой — чистый стек: путь прошлого слоя не должен доставаться
            // следующему, в том числе при подмене корня.
            //
            // На закрытии путь не трогаем: слой со всей стопкой снимает одна
            // презентация корня. Срезанный путь заставлял каждый экран стопки снимать
            // свой экран сам — два `dismiss` разом, и второму UIKit отказывал
            // («dismiss is in progress», таб из слоя, 2026-10-04). Остаток пути без слоя
            // ничего не значит: все, кто его читает, сперва смотрят на `coveredRoute`.
            if newValue != old, newValue != nil { layerPaths[activeTab] = [] }
        }
    }

    /// Стопка **внутри** слоя активного таба: «Похожее» открывает следующий фильм поверх
    /// текущего, не закрывая его (решение пользователя 2026-08-25). Элемент глубины `i` —
    /// вложенный `fullScreenCover` экрана глубины `i` (см. `CoveredEntityScreen`);
    /// сам массив живёт здесь, чтобы `open`/`close` оставались одной точкой входа.
    var coveredPath: [EntityRoute] {
        get { layerPaths[activeTab] ?? [] }
        set { layerPaths[activeTab] = newValue }
    }

    /// Стопка слоя конкретного таба — для экранов слоя: на смене таба их стопка не должна
    /// подменяться стопкой нового таба, иначе вложенные экраны снимали бы себя сами
    /// вдобавок к снятию всего слоя («dismiss is in progress»).
    func layerPath(of tab: AppTab) -> [EntityRoute] {
        layerPaths[tab] ?? []
    }

    func setLayerPath(_ path: [EntityRoute], of tab: AppTab) {
        layerPaths[tab] = path
    }

    /// Сколько вложенных экранов слоя таба уже вернулось на экран после возврата на таб.
    /// Стопку UIKit показывает по одной презентации: вложенный экран встаёт, когда показан
    /// тот, что под ним. Без счётчика он вставал своим зумом из карточки — на возврате
    /// режиссёр «открывался» заново (запись 2026-10-31). Со счётчиком каждый следующий
    /// встаёт мгновенно, в той же транзакции без анимаций. `nil` — стопка не восстанавливается.
    private var revealedLayerDepth: [AppTab: Int] = [:]

    /// Глубина, до которой стопку слоя таба уже можно показывать.
    func layerRevealLimit(of tab: AppTab) -> Int {
        revealedLayerDepth[tab] ?? .max
    }

    /// Экран слоя глубины `depth` встал на возврате — следующий может вставать следом.
    func layerScreenAppeared(depth: Int, of tab: AppTab) {
        guard let revealed = revealedLayerDepth[tab], revealed == depth else { return }
        Self.withoutLayerZoom {
            revealedLayerDepth[tab] = depth + 1 >= layerPath(of: tab).count ? nil : depth + 1
        }
    }

    private var paths: [AppTab: NavigationPath] = [:]

    /// Просьбы «к началу экрана» по табам: повторный тап по табу, стек которого уже
    /// на корне (правка пользователя 2026-10-03). Счётчик, а не флаг: корневой экран
    /// слушает смену своего значения, и каждый тап — новая просьба.
    private(set) var scrollToTopRequests: [AppTab: Int] = [:]

    /// Насколько глубоко мы сейчас от корня активного таба: пуши стека таба плюс
    /// слой поверх хрома со своей стопкой. По этому числу поиск понимает, что
    /// пользователь вернулся из открытой сущности, и восстанавливает выдачу
    /// (см. `SearchState.suspend(at:)`).
    ///
    /// Считается внутри класса, потому что снаружи `paths` приватны, а `@Observable`
    /// отслеживает чтение — вью, читающая `depth`, обновится на каждый пуш и поп.
    var depth: Int {
        level.stack + level.layer
    }

    /// Та же глубина по частям: пуши стека активного таба и экраны слоя поверх хрома
    /// (0 — слоя нет, 1 — корень слоя, дальше — его стопка). Нужна связке поиска
    /// с навигацией (`SearchNavigationSync`): возврат из слоя и поп в стеке таба —
    /// разные случаи, хотя глубина в обоих падает.
    struct Level: Equatable {
        var stack: Int
        var layer: Int
    }

    var level: Level {
        Level(stack: stackDepth, layer: coveredRoute == nil ? 0 : 1 + coveredPath.count)
    }

    /// Верхний ли экран — тот, чей нижний хром сейчас живой. `layer` — глубина экрана
    /// в стопке слоя (`CoveredEntityScreen.depth`), `nil` — корень приложения: его
    /// хром общий для всех стеков табов и живой, пока слоя нет. У экранов, открытых
    /// из фильма дальше, хром свой (2026-10-04), а все, что под верхним, накрыты им.
    func isTop(layer: Int?) -> Bool {
        guard let layer else { return coveredRoute == nil }
        return coveredRoute != nil && coveredPath.count == layer
    }

    /// Пуши в стеке активного таба — без слоя поверх хрома. По нему корень понимает,
    /// на экране ли витрина или запушенный экран со своим навбаром.
    var stackDepth: Int {
        paths[activeTab]?.count ?? 0
    }

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
    /// системных таббаров, заодно единственный выход из пуша без свайпа. Стек уже
    /// на корне — корневой экран уезжает к началу (`scrollToTopRequests`). Тап по своему
    /// табу из слоя фильма (таббар его экранов) снимает слой.
    ///
    /// Другой таб — просто другой таб: у каждого свой стек и свой слой (решение пользователя
    /// 2026-10-31). Слой уходящего таба остаётся за ним, слой пришедшего встаёт на место.
    func select(_ tab: AppTab) {
        guard tab != activeTab else {
            if coveredRoute != nil {
                // Таббар слоя — у экранов, открытых из фильма дальше (2026-10-04): свой таб —
                // домой, к его контенту: слой снимается целиком, стек на корень.
                Self.withoutLayerZoom {
                    coveredRoute = nil
                    paths[tab] = NavigationPath()
                }
            } else if !(paths[tab]?.isEmpty ?? true) {
                paths[tab] = NavigationPath()
            } else {
                scrollToTopRequests[tab, default: 0] += 1
            }
            return
        }
        // Слой уходит или приходит вместе с табом — мгновенно, без зума: его миниатюра-
        // источник живёт в ленте таба, которая в этом же апдейте размонтируется или только
        // монтируется (`withoutLayerZoom`).
        if coveredRoute != nil || layerRoutes[tab] != nil {
            Self.withoutLayerZoom {
                // Стопка слоя пришедшего таба встаёт по экрану, без зумов (`revealedLayerDepth`).
                if layerRoutes[tab] != nil, !layerPath(of: tab).isEmpty {
                    revealedLayerDepth[tab] = 0
                }
                activeTab = tab
            }
        } else {
            activeTab = tab
        }
    }

    /// Показать корень таба откуда угодно: профиль и слой фильма этого таба сняты, стек
    /// на корне, таб активен. Для тапа по тосту — он живёт в окне поверх всего, и «закрыть
    /// всё и открыть таб» делается одним синхронным вызовом, без анимаций. Слой таба, с
    /// которого ушли, остаётся за ним — как при обычной смене таба; со своими вложенными
    /// экранами его UIKit снимает целой стопкой — по одной презентации (см. `coveredRoute`).
    func showRoot(of tab: AppTab) {
        // «С корня» — и без припаркованного поиска этого таба: иначе он встал бы поверх
        // сброшенного стека («Мне нравится» в «Для вас» → «Моё», ревью 2026-10-31).
        onShowRoot?(tab)
        Self.withoutLayerZoom {
            layerRoutes[tab] = nil
            paths[tab] = NavigationPath()
            activeTab = tab
        }
    }

    /// Слой фильма снимается вместе со сменой таба или стека — без анимации. Слой показан
    /// зумом (`.navigationTransition(.zoom)`) и на закрытии сжимается в миниатюру-источник,
    /// а та живёт в ленте таба: смена таба или сброс стека в том же апдейте её размонтирует.
    /// На iOS 27 UIKit на сжатии в источник вне окна падает по assert
    /// (`_UIZoomTransitionController` → `_morphPreviewFromCurrentState`, SIGABRT — крэш-лог
    /// TestFlight 2026-10-10: «Позже» на экране фильма → тап по тосту → «Моё»).
    private static func withoutLayerZoom(_ change: () -> Void) {
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant, change)
    }

    /// Сколько экранов, прячущих нижний хром (таббар и action bar), сейчас на экране —
    /// профиль и его дебаг-меню (правка пользователя 2026-10-21). Счётчик, а не флаг:
    /// дебаг-меню пушится поверх профиля, и его появление приходит раньше ухода профиля.
    private(set) var chromeHiders = 0

    var isChromeHidden: Bool { chromeHiders > 0 }

    func hideChrome() { chromeHiders += 1 }
    func showChrome() { chromeHiders = max(0, chromeHiders - 1) }

    /// Профиль — с аватарки навигации витрин: обычным пушем в стек активного таба,
    /// справа налево, с навбаром «назад» (правка пользователя 2026-10-21; прежде
    /// выезжал снизу поверх всего, включая хром).
    func openProfile() {
        push(ProfileRoute())
    }

    /// Программный пуш. Нужен и отладке (тапнуть по симулятору из шелла нечем),
    /// и переходам, у которых нет `NavigationLink`: полные списки коллекции «Моё».
    func push(_ value: some Hashable, in tab: AppTab? = nil) {
        let tab = tab ?? activeTab
        var path = paths[tab] ?? NavigationPath()
        path.append(value)
        paths[tab] = path
    }

    /// Открыть экран сущности: пушем или слоем поверх хрома — решает сам маршрут.
    /// Одна точка входа, чтобы витрина и отладочный тап не расходились в способе.
    func open(_ route: EntityRoute, in tab: AppTab? = nil) {
        if coveredRoute != nil {
            // Слой уже показан — всё, что открыто из него, встаёт в его стопку, поверх
            // текущего экрана: «Похожее» на экране фильма, режиссёр из съёмочной
            // группы. Пуш ушёл бы в стек таба — под слой, его бы не было видно.
            coveredPath.append(route)
        } else if route.coversChrome {
            coveredRoute = route
        } else {
            push(route, in: tab)
        }
    }

    /// Закрыть то, что открыто последним: верхний экран стека слоя, затем сам слой.
    func close(in tab: AppTab? = nil) {
        if coveredRoute != nil {
            if coveredPath.isEmpty {
                coveredRoute = nil
            } else {
                coveredPath.removeLast()
            }
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
