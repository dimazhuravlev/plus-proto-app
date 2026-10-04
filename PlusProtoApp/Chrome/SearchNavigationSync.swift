import SwiftUI

/// Связка поиска с навигацией: куда переезжает выдача, когда пользователь ходит
/// по экранам, и что с ней, когда он возвращается из открытой карточки.
///
/// Жила в корне (`AppRootView`). С 2026-10-04 у экранов, открытых из фильма дальше,
/// свой хром в слое (`CoveredEntityScreen`), а корень под полноэкранным слоем UIKit
/// снимает с окна — его `onChange` в это время не приходят (тот же вывод, что
/// у `ContentPlayerPresenter`). Поэтому связка висит на каждом носителе хрома — корне
/// и каждом экране слоя, — а решает за всех **верхний** экран
/// (`AppNavigationState.isTop`): он всегда на окне, и одно решение не приходит дважды.
struct SearchNavigationSync: ViewModifier {
    /// Глубина экрана в стопке слоя (`CoveredEntityScreen.depth`); `nil` — корень
    /// приложения со стеками табов.
    let layer: Int?

    @Environment(AppNavigationState.self) private var navigation
    @Environment(ActionBarState.self) private var actionBar
    @Environment(SearchState.self) private var search
    @Environment(KeyboardObserver.self) private var keyboard

    func body(content: Content) -> some View {
        content
            // Возврат из открытой сущности возвращает и поиск: сам запрос с выдачей
            // никуда не девались, поэтому достаточно вернуть выдачу на экран — без
            // клавиатуры.
            .onChange(of: navigation.level) { old, _ in
                guard navigation.isTop(layer: layer) else { return }
                let depth = navigation.depth
                // Возврат в выдачу — без клавиатуры (`SearchState.consumeResume`) и на тот
                // экран, где пользователь оказался. Уйти назад можно и дальше экрана,
                // с которого поиск открыли (поиск с альбома, повторный поиск на пуше), —
                // и выдача, привязанная к старой глубине, не вставала нигде: таббар
                // спрятан, в поле запрос, а выдачи нет (жалоба пользователя 2026-10-03).
                // Прежде привязку обновлял фокус, который возврат ставил полю.
                //
                // Просмотру отметка ухода в карточку не помеха: уход в карточку гасит просмотр
                // сам (`SearchState.suspend`), а забытая отметка — скажем, с другого таба —
                // держала бы выдачу на экране, которого уже нет.
                if search.consumeResume(tab: navigation.activeTab, depth: depth) {
                    search.host(at: depth)
                } else if search.isBrowsing || (actionBar.isSearchFocused && !search.isSuspended) {
                    if layer == nil, old.layer == 0 {
                        // Бар корня один на весь стек таба. Поиск, открытый на пуше,
                        // переезжает вместе с пользователем: свайп-назад с альбома
                        // клавиатуру не опускает, и слои обязаны оказаться на экране,
                        // куда он вернулся. Выдачу без клавиатуры — так же: свайп-назад
                        // из неё её не закрывает. Только пока из выдачи никуда не уходили —
                        // там глубина меняется как раз потому, что поиск остался позади.
                        search.host(at: depth)
                    } else if search.hostDepth != depth {
                        // Бар слоя — свой у каждого экрана: экран, на котором открыт
                        // поиск, сняли свайпом — поиска с ним больше нет. Иначе выдача
                        // ждала бы под фильмом и встала бы на витрине, когда закроют слой.
                        actionBar.isSearchFocused = false
                        search.isBrowsing = false
                    }
                }
            }
            // Поиск прикрепляется к экрану, с которого его открыли. Снятый фокус при
            // непустой выдаче переводит её в просмотр без клавиатуры — это решает бар
            // в том же апдейте, что и сам фокус (`ActionBarView`, onChange фокуса).
            .onChange(of: actionBar.isSearchFocused) { _, focused in
                guard focused, navigation.isTop(layer: layer) else { return }
                // Новый фокус — новый поиск на этом экране: отметка ухода в карточку из
                // прежней выдачи гаснет. Иначе она держала затемнение над экраном после
                // «Назад» и запрещала выдаче переходить в просмотр (проверка навигации
                // 2026-10-03). Законный возврат не страдает: `open()` ставит отметку
                // и сразу снимает фокус, а не получает его.
                // Поиск открыт заново (а не возвращён фокус в просмотре выдачи) —
                // с обзора: раскрытый раздел остался бы от прошлого поиска.
                if !search.isBrowsing {
                    search.collapse()
                }
                search.dropSuspension()
                search.host(at: navigation.depth)
            }
            // Просмотр выдачи кончается, когда поле получило клавиатуру: дальше слой держит
            // она, а снятый фокус снова решает — закрыть поиск или вернуть просмотр (выше).
            // Не на самом фокусе: бар едет по клавиатуре (`BottomChrome.raise`), и между
            // фокусом и её подъёмом он перекладывался бы из раскладки просмотра
            // в раскладку режима и обратно.
            .onChange(of: keyboard.isUp) { _, isUp in
                guard navigation.isTop(layer: layer) else { return }
                if isUp, actionBar.isSearchFocused { search.isBrowsing = false }
            }
    }
}

extension EnvironmentValues {
    /// Чей нижний хром рисуется: `nil` — корневой (`AppRootView`), число — экрана
    /// стопки слоя этой глубины (`CoveredEntityScreen`). По нему бар понимает, живой
    /// ли он (`AppNavigationState.isTop`), а отладочные прогоны идут только в корневом.
    @Entry var chromeLayer: Int?
}
