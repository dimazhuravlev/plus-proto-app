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
    var activeTab: AppTab = .plus

    /// Экран профиля — с аватарки в навигации витрин, поверх всего (2026-10-04).
    var isProfileShown = false

    /// Экран сущности, показанный **слоем поверх хрома** вместо пуша (см.
    /// `EntityRoute.coversChrome`). Живёт отдельно от путей: он не элемент стека,
    /// а отдельная презентация, и переживать переключение таба ему не нужно.
    var coveredRoute: EntityRoute? {
        didSet {
            // Новый слой — чистый стек: путь прошлого слоя не должен доставаться
            // следующему, в том числе при подмене корня.
            //
            // На закрытии путь не трогаем: слой со всей стопкой снимает одна
            // презентация корня. Срезанный путь заставлял каждый экран стопки снимать
            // свой экран сам — два `dismiss` разом, и второму UIKit отказывал
            // («dismiss is in progress», таб из слоя, 2026-10-04). Остаток пути без слоя
            // ничего не значит: все, кто его читает, сперва смотрят на `coveredRoute`.
            if coveredRoute != oldValue, coveredRoute != nil { coveredPath.removeAll() }
        }
    }

    /// Стопка **внутри** слоя: «Похожее» открывает следующий фильм поверх текущего,
    /// не закрывая его (решение пользователя 2026-08-25). Элемент глубины `i` —
    /// вложенный `fullScreenCover` экрана глубины `i` (см. `CoveredEntityScreen`);
    /// сам массив живёт здесь, чтобы `open`/`close` оставались одной точкой входа.
    var coveredPath: [EntityRoute] = []

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
    /// на корне — корневой экран уезжает к началу (`scrollToTopRequests`). Тап из слоя
    /// фильма (таббар его экранов) снимает слой.
    func select(_ tab: AppTab) {
        // Таббар слоя — у экранов, открытых из фильма дальше (2026-10-04): таб ведёт
        // к своему контенту, слой снимается целиком. Свой таб — ещё и стек на корень,
        // как повторный тап с пуша. Слой переключение таба не переживает и так:
        // он не элемент стека (см. `coveredRoute`).
        if coveredRoute != nil {
            coveredRoute = nil
            if tab == activeTab {
                paths[tab] = NavigationPath()
            } else {
                activeTab = tab
            }
            return
        }
        guard tab != activeTab else {
            if !(paths[tab]?.isEmpty ?? true) {
                paths[tab] = NavigationPath()
            } else {
                scrollToTopRequests[tab, default: 0] += 1
            }
            return
        }
        activeTab = tab
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
