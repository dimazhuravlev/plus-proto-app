import SwiftUI
import UIKit

// MARK: - Мост из состояния в презентацию

/// Невидимый слой корня: заводит презентер и отдаёт ему состояния приложения.
/// Сам за плеером не следит — см. `ContentPlayerPresenter.attach`.
struct ContentPlayerHost: View {
    @Environment(ActionBarState.self) private var actionBar
    @Environment(AppNavigationState.self) private var navigation
    @State private var presenter = ContentPlayerPresenter()

    var body: some View {
        Color.clear
            .allowsHitTesting(false)
            .onAppear { presenter.attach(actionBar: actionBar, navigation: navigation) }
    }
}

// MARK: - Презентер

/// Показывает киноплеер, читалку и полноэкранный плеер музыки поверх всего приложения.
///
/// **UIKit-презентация, а не `fullScreenCover`.** Плеер открывается из трёх мест:
/// «Смотреть» на карточке тайтла, «Читать» на экране книги и action bar (чипы
/// и пилюля мини-плеера). Карточка тайтла сама показана `fullScreenCover`-слоем
/// (и бывает вложенной — «Похожее»),
/// а SwiftUI презентует только с того уровня, где висит модификатор: пока слой открыт,
/// корень приложения не покажет ничего. Свой `fullScreenCover` на каждом экране —
/// это столько же точек входа, сколько кнопок. Здесь вход один: состояние в
/// `ActionBarState`, а презентер находит самый верхний контроллер и показывает с него.
///
/// Переход — штатный `coverVertical`: экран выезжает снизу и уезжает вниз, прозрачность
/// не трогается, а экран под ним стоит на месте (требование пользователя 2026-10-03,
/// для плеера музыки — тоже: раньше он формился из мини-плеера, теперь едет как все).
@MainActor
final class ContentPlayerPresenter {
    private weak var host: UIViewController?
    private var shownID: ContentPlayer.ID?
    private var isAttached = false

    /// Начать следить за `ActionBarState.contentPlayer`.
    ///
    /// Через `withObservationTracking`, а не `onChange` вью: на время показа плеера
    /// UIKit снимает корень приложения с окна (так устроена `.fullScreen`-презентация),
    /// и обновлений от вью корня в это время ждать нельзя — нажатие «закрыть»
    /// не дошло бы до того, кто плеер снимает.
    func attach(actionBar: ActionBarState, navigation: AppNavigationState) {
        guard !isAttached else { return }
        isAttached = true
        track(actionBar, navigation)
    }

    private func track(_ actionBar: ActionBarState, _ navigation: AppNavigationState) {
        let player = withObservationTracking {
            actionBar.contentPlayer
        } onChange: { [weak self] in
            // Срабатывает до записи нового значения — читаем его следующим тактом.
            // Подписка одноразовая, поэтому каждый такт ставит её заново.
            Task { @MainActor [weak self] in self?.track(actionBar, navigation) }
        }
        show(player, actionBar: actionBar, navigation: navigation)
    }

    private func show(_ player: ContentPlayer?, actionBar: ActionBarState, navigation: AppNavigationState) {
        guard let player else {
            dismiss(animated: true)
            return
        }
        guard player.id != shownID else { return }
        // Подмена плеера на лету бывает только в отладочных прогонах: из интерфейса
        // второй не открыть — первый накрывает всё.
        dismiss(animated: false)
        guard let presenter = Self.topViewController() else { return }

        let root = ContentPlayerRoot(player: player)
            .environment(actionBar)
            .environment(navigation)
            .preferredColorScheme(.dark)
        let controller = ContentPlayerHostingController(rootView: root)
        controller.isImmersive = player.isMovie
        controller.modalPresentationStyle = .fullScreen
        // С «уменьшением движения» экран не едет через весь дисплей, а проявляется:
        // системная настройка важнее требования к переходу — оно про обычный режим.
        controller.modalTransitionStyle = UIAccessibility.isReduceMotionEnabled
            ? .crossDissolve
            : .coverVertical
        controller.view.backgroundColor = .black
        presenter.present(controller, animated: true)
        host = controller
        shownID = player.id
    }

    private func dismiss(animated: Bool) {
        shownID = nil
        guard let host else { return }
        self.host = nil
        // Слой могли уже снять вместе с презентацией под ним — тогда снимать нечего.
        guard host.presentingViewController != nil else { return }
        host.dismiss(animated: animated)
    }

    /// Самый верхний показанный контроллер окна: корень или верх стопки слоёв.
    /// Уходящие пропускаем — с контроллера, который сам снимается, не презентуют.
    private static func topViewController() -> UIViewController? {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
        var top = (windows.first(where: \.isKeyWindow) ?? windows.first)?.rootViewController
        while let next = top?.presentedViewController, !next.isBeingDismissed {
            top = next
        }
        return top
    }
}

/// Хостинг, который сам отвечает за статус-бар и home indicator. Не через SwiftUI
/// (`statusBarHidden`, `persistentSystemOverlays`): у презентованного контроллера
/// это настройки самого контроллера, и модификатор внутри него — лишнее звено,
/// на котором можно потерять предпочтение.
private final class ContentPlayerHostingController<Content: View>: UIHostingController<Content> {
    /// Киноплеер — весь экран под кадр: статус-бар скрыт (просьба пользователя
    /// 2026-10-03; повёрнутый, он стоял бы боком вдоль левой кромки), полоска
    /// home indicator гаснет без касаний, как в системных видеоплеерах. Читалке
    /// и плееру музыки статус-бар нужен — он есть в их макетах, светлым по тёмному.
    var isImmersive = false

    override var prefersStatusBarHidden: Bool { isImmersive }
    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
    override var prefersHomeIndicatorAutoHidden: Bool { isImmersive }
    /// Альбомный кадр плеера рисуется повёрнутым внутри портрета (см. `MoviePlayerView`):
    /// поверни интерфейс система — повёрнутый холст лёг бы боком.
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }
}

private extension ContentPlayer {
    var isMovie: Bool {
        if case .movie = self { return true }
        return false
    }
}

// MARK: - Корень презентации

private struct ContentPlayerRoot: View {
    let player: ContentPlayer
    @Environment(ActionBarState.self) private var actionBar

    var body: some View {
        Group {
            switch player {
            case .movie(let movie):
                MoviePlayerView(movie: movie)
            case .reader(let book, let showsMusic):
                BookReaderView(book: book, showsMusic: showsMusic)
            case .music:
                MusicPlayerView()
            }
        }
        // Слой сняли не кнопкой — вместе с презентацией под ним. Состояние обязано
        // догнать экран, иначе следующий тап по «Смотреть» не открыл бы ничего.
        .onDisappear { actionBar.contentPlayerDidDisappear(id: player.id) }
        #if DEBUG
        // `-debugCloseContent 1` — закрыть плеер или читалку через 3с: снять уход вниз
        // и проверить, что закрытие доходит до презентера, пока корень снят с окна.
        .task {
            guard UserDefaults.standard.bool(forKey: "debugCloseContent") else { return }
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            actionBar.closeContentPlayer()
        }
        #endif
    }
}
