import SwiftUI
import UIKit

/// Экран вместе со слоями поиска — затемнением и выдачей.
///
/// **Поиск живёт на том экране, с которого его открыли.** Слои нельзя держать
/// ни в корне приложения, ни только в корне стека:
/// - в корне приложения они рисуются поверх пуша, и открытый из выдачи альбом
///   не мог бы их накрыть — на возврате приходилось прятать выдачу, и между
///   уходом карточки и подъёмом клавиатуры мелькала витрина (2026-08-25);
/// - только в корне стека — обратная беда: пуш рисуется поверх корня, поэтому
///   поиск, открытый **с** альбома или книги, оказывался под ними и затемнения
///   не было вовсе (жалоба пользователя 2026-08-27).
///
/// Поэтому носителем слоёв может быть любой экран стека, а показывает их тот,
/// чья глубина совпадает с глубиной открытия поиска (`SearchState.hostDepth`).
/// Оба сценария сходятся сами собой: ушёл из выдачи глубже — слой остался под
/// новым экраном; открыл поиск на пуше — слой стоит поверх этого пуша.
///
/// Слои — **соседи контента в `ZStack`**, а не `.overlay` над ним: у оверлея
/// SwiftUI уводит поддерево в отдельную группу композитинга, и backdrop затемнения
/// снимает пустоту вместо экрана — блюр отдаёт чёрное, а экран под слоем пропадает
/// целиком (жалоба пользователя 2026-08-25).
struct SearchLayers<Content: View>: View {
    /// Место экрана в стеке. Глубину своего экрана `navigationDestination`
    /// изнутри не знает, и брать её неоткуда — поэтому пуш сверяется с текущей
    /// глубиной навигации: слои нужны только верхнему экрану, все, что под ним,
    /// он всё равно накрывает собой.
    enum Host {
        case stackRoot
        case pushed
    }

    let host: Host
    @ViewBuilder var content: Content

    @Environment(SearchState.self) private var search
    @Environment(AppNavigationState.self) private var navigation
    @Environment(ActionBarState.self) private var actionBar
    @Environment(KeyboardObserver.self) private var keyboard
    /// Глубина экрана в стопке слоя фильма (`CoveredEntityScreen`); `nil` — экран стека таба.
    @Environment(\.chromeLayer) private var chromeLayer
    /// Глубина этого экрана в стеке — с его появления. Текущая глубина навигации
    /// для пуша не годится: при открытии карточки из выдачи она растёт в том же
    /// апдейте, и слой гас раньше, чем карточка его накрывала, — под зумом был голый
    /// альбом, а у зума пропадал источник (проверка навигации 2026-10-03).
    @State private var ownDepth: Int?

    var body: some View {
        ZStack {
            content

            SearchOverlay(isActive: isSearchShown) {
                // Тап по затемнению закрывает поиск — и с клавиатурой, и без неё.
                actionBar.isSearchFocused = false
                search.isBrowsing = false
                search.dropSuspension()
            }

            SearchResultsView(isShown: isSearchShown)
        }
        // Пока поиск на экране, экран под ним не закрывается «смахиванием» вниз и щипком
        // (правка пользователя 2026-10-31): жест сворачивал зумом экран, на котором открыт
        // поиск, а выдача тут же вставала на предыдущем — «потянул, а поиск появился снова».
        .background {
            ZoomDismissGestureLock(isLocked: isSearchShown)
                .frame(width: 0, height: 0)
        }
        .onAppear {
            guard ownDepth == nil else { return }
            // Экран слоя знает своё место сам: на возврате на таб стопка слоя встаёт целиком
            // (`AppNavigationState.revealedLayerDepth`), и глубина навигации в этот миг —
            // глубина верхнего экрана, а не этого (ревью 2026-10-31: поиск на режиссёре под
            // альбомом потом не вставал). Верхним он глубиной стек таба + корень слоя + своя.
            ownDepth = chromeLayer.map { navigation.stackDepth + 1 + $0 } ?? navigation.depth
        }
    }

    /// Этот ли экран открывал поиск.
    private var hostsSearch: Bool {
        switch host {
        case .stackRoot: search.hostDepth == 0
        case .pushed: search.hostDepth > 0 && search.hostDepth == (ownDepth ?? navigation.depth)
        }
    }

    /// Показан ли поиск — затемнение и выдача разом, они обязаны появляться
    /// и уходить одним движением.
    ///
    /// Драйвер не только клавиатура: пока пользователь ходит по карточке, открытой
    /// из выдачи, поиск **остаётся жить под ней** и на возврате уже стоит на экране —
    /// клавиатура догоняет следом. Раньше слой был привязан к клавиатуре, и на
    /// возврате между закрытием карточки и её подъёмом мелькала витрина.
    ///
    /// Затемнение с блюром — по самому факту открытого поиска, **без оглядки
    /// на запрос**: экран уходит из фокуса сразу, как поднялась клавиатура, ещё
    /// до первой буквы. Проверка `isActive` здесь была регрессией — с пустым полем
    /// фон не появлялся вовсе (жалоба пользователя 2026-08-25).
    ///
    /// Фокус поля — третий драйвер: слой стоит с первого кадра фокуса, не дожидаясь
    /// клавиатуры. Четвёртый — просмотр выдачи без фокуса (`isBrowsing`): в него поиск
    /// переходит, когда клавиатуру опустили, и им же встречает возврат из карточки
    /// (правки пользователя 2026-10-03). С пустым полем — тоже: на экране тогда
    /// «Искали недавно» (нулевое состояние), а не пустое затемнение.
    ///
    /// Слой выдачи стоит с затемнением всегда: с запросом от двух символов в нём
    /// выдача, короче — «Искали недавно» (`SearchResultsView`).
    private var isSearchShown: Bool {
        hostsSearch && (keyboard.isUp || search.isSuspended || actionBar.isSearchFocused || search.isBrowsing)
    }

}

/// Выключает системные жесты закрытия экрана, показанного зумом, — «смахнуть содержимое
/// вниз» и щипок, — пока `isLocked`. Свайп от левого края остаётся: с ним поиск по замыслу
/// переезжает на экран, куда вернулись (`SearchNavigationSync`).
///
/// Публичного рычага нет: у SwiftUI-перехода `.zoom` опций не бывает, а UIKit держит эти
/// жесты на корневой вью контроллера экрана (замер `-debugGestureProbe` 2026-10-31:
/// `_UIContentSwipeDismissGestureRecognizer` и `_UITransformGestureRecognizer` с делегатами
/// `…SwipeDismissSubInteraction` и `…PinchDismissSubInteraction`). Узнаём их по делегату;
/// не нашлось (корень стека, другая версия iOS) — ничего не делаем.
struct ZoomDismissGestureLock: UIViewRepresentable {
    let isLocked: Bool

    func makeUIView(context: Context) -> LockView {
        LockView()
    }

    func updateUIView(_ view: LockView, context: Context) {
        view.isLocked = isLocked
    }

    static func dismantleUIView(_ view: LockView, coordinator: ()) {
        view.isLocked = false
    }

    final class LockView: UIView {
        var isLocked = false {
            didSet { if isLocked != oldValue { apply() } }
        }

        /// Что выключили мы — только это и включаем обратно.
        private var disabled: [UIGestureRecognizer] = []

        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError() }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            apply()
        }

        private func apply() {
            for recognizer in disabled { recognizer.isEnabled = true }
            disabled = []
            guard isLocked, window != nil, let host = controllerView else { return }
            for recognizer in host.gestureRecognizers ?? [] where recognizer.isEnabled && Self.dismisses(recognizer) {
                recognizer.isEnabled = false
                disabled.append(recognizer)
            }
        }

        /// Корневая вью ближайшего контроллера — экрана, на котором стоит поиск.
        private var controllerView: UIView? {
            var responder: UIResponder? = next
            while let current = responder {
                if let controller = current as? UIViewController { return controller.view }
                responder = current.next
            }
            return nil
        }

        private static func dismisses(_ recognizer: UIGestureRecognizer) -> Bool {
            guard let delegate = recognizer.delegate else { return false }
            let name = String(describing: type(of: delegate))
            return name.contains("SwipeDismiss") || name.contains("PinchDismiss")
        }
    }
}
