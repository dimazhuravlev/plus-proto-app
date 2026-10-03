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
    /// Слой уже увели свайпом за нижнюю кромку — снимать его надо без перехода.
    private var isPulledAway = false

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
        // С «уменьшением движения» экран не едет через весь дисплей, а проявляется:
        // системная настройка важнее требования к переходу — оно про обычный режим.
        controller.modalTransitionStyle = UIAccessibility.isReduceMotionEnabled
            ? .crossDissolve
            : .coverVertical
        controller.view.backgroundColor = .black
        if player.isMusic {
            // Плеер музыки уводится вниз за пальцем, и над ним должен быть виден экран,
            // с которого его открыли: `.overFullScreen` оставляет тот в окне. У `.fullScreen`
            // под уехавшим слоем была бы чернота. Статус-бар при этом решает сам плеер.
            controller.modalPresentationStyle = .overFullScreen
            controller.modalPresentationCapturesStatusBarAppearance = true
            controller.enablePullToDismiss { [weak self] in
                self?.isPulledAway = true
                actionBar.closeContentPlayer()
            }
        } else {
            controller.modalPresentationStyle = .fullScreen
        }
        presenter.present(controller, animated: true)
        host = controller
        shownID = player.id
    }

    private func dismiss(animated: Bool) {
        shownID = nil
        let pulledAway = isPulledAway
        isPulledAway = false
        guard let host else { return }
        self.host = nil
        // Слой могли уже снять вместе с презентацией под ним — тогда снимать нечего.
        guard host.presentingViewController != nil else { return }
        // Уведённый свайпом слой уже за кромкой: второй уход вниз ничего не показал бы,
        // только держал бы касания, пока идёт переход.
        host.dismiss(animated: animated && !pulledAway)
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

    private var pull: PullToDismiss?

    /// Свайп вниз уводит слой за пальцем; `onDismiss` — слой уехал за нижнюю кромку.
    func enablePullToDismiss(onDismiss: @escaping () -> Void) {
        pull = PullToDismiss(onDismiss: onDismiss)
    }

    /// Ленту SwiftUI строит не сразу — свайп цепляется к ней на раскладке, как только она есть.
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        pull?.hookIfNeeded(in: view)
    }
}

private extension ContentPlayer {
    var isMovie: Bool {
        if case .movie = self { return true }
        return false
    }

    var isMusic: Bool {
        if case .music = self { return true }
        return false
    }
}

// MARK: - Свайп вниз

/// Числа свайпа. Пороги закрытия — те же, что были у листа прежнего плеера музыки.
private enum PullToDismissConfig {
    /// Отпущен ниже этого — закрывается.
    static let dismissDistance: CGFloat = 120
    /// Бросок вниз быстрее этого закрывает с любого места; такой же бросок вверх
    /// отменяет закрытие даже за порогом.
    static let flickVelocity: CGFloat = 600
    /// Строка навбара плеера под статус-баром: потянул за неё — экран едет сразу,
    /// как бы ни была прокручена лента.
    static let handleHeight: CGFloat = 44
    /// Уход за кромку после отпускания — быстрый, палец уже всё решил.
    static let slideOutDuration: TimeInterval = 0.3
    /// Возврат, если не дотянул, — спокойнее: экран встаёт на место, а не отскакивает.
    static let settleDuration: TimeInterval = 0.4
    /// Пока экран оттянут, верхние углы скруглены — как у листа в макете (рамка
    /// экрана `6105:61569`, радиус 30). В покое углы прячет скругление дисплея.
    static let cornerRadius: CGFloat = 30
}

/// Свайп вниз уводит весь слой за пальцем — один в один и с первого же пункта хода
/// (просьбы пользователя 2026-10-03). Отпустил ниже порога или бросил вниз — слой
/// уезжает за кромку, иначе встаёт на место.
///
/// Ведёт его пан самой ленты, а не свой распознаватель. Со своим паном касание делили
/// двое, и лента успевала уехать вниз резиной раньше, чем трогался экран. Здесь касание
/// одно: пока лента у верха, ход пальца вниз двигает весь экран, а ленту держим на месте.
/// Прокрученная лента сперва доезжает до верха, и тем же движением дальше едет экран;
/// за строку навбара экран тянется сразу при любой прокрутке.
@MainActor
private final class PullToDismiss: NSObject {
    private enum Phase {
        case idle
        /// Палец скроллит ленту.
        case scrolling
        /// Палец ведёт весь экран, лента стоит.
        case pulling
    }

    private weak var view: UIView?
    private weak var scrollView: UIScrollView?
    private let onDismiss: () -> Void
    private var animator: UIViewPropertyAnimator?
    private var phase = Phase.idle
    /// Ход пальца, с которого экран едет за ним.
    private var anchor: CGFloat = 0
    /// Где держать ленту, пока тянут экран.
    private var pinnedOffset: CGFloat = 0
    /// Где был экран в момент хвата — подхватить его на возврате, не дёрнув.
    private var grabOffset: CGFloat = 0
    /// Экран подхватили на возврате: лента и так у верха, отдавать ей ход нечего.
    private var isRegrab = false

    init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
    }

    /// Подцепиться к пану ленты. Зовётся на каждой раскладке слоя, пока лента не найдётся.
    func hookIfNeeded(in view: UIView) {
        self.view = view
        guard scrollView == nil, let found = Self.findScrollView(in: view) else { return }
        scrollView = found
        found.panGestureRecognizer.addTarget(self, action: #selector(followPan(_:)))
    }

    /// Лента плеера — единственный скролл в слое; SwiftUI держит под ним `UIScrollView`.
    private static func findScrollView(in root: UIView) -> UIScrollView? {
        var queue = [root]
        while !queue.isEmpty {
            let next = queue.removeFirst()
            if let found = next as? UIScrollView { return found }
            queue.append(contentsOf: next.subviews)
        }
        return nil
    }

    // MARK: Ведение

    /// Вторая цель пана ленты: лента свой ход на этом событии уже сделала, и здесь её
    /// можно вернуть на место, пока экран едет за пальцем.
    @objc private func followPan(_ pan: UIPanGestureRecognizer) {
        guard let view, let scrollView else { return }
        // Мерим в координатах родителя: слой сам едет под пальцем, и в его собственных
        // координатах палец стоял бы на месте.
        let space = view.superview
        let translation = pan.translation(in: space).y
        let top = -scrollView.adjustedContentInset.top

        switch pan.state {
        case .began:
            // Поймали на возврате — останавливаем там, где он сейчас, и ведём оттуда.
            animator?.stopAnimation(true)
            animator = nil
            grabOffset = view.transform.ty
            isRegrab = grabOffset > 0
            let touchDown = pan.location(in: view).y - translation
            let fromHandle = touchDown < view.safeAreaInsets.top + PullToDismissConfig.handleHeight
            let atTop = scrollView.contentOffset.y <= top + 0.5
            if isRegrab || ((atTop || fromHandle) && translation > 0) {
                startPulling(from: translation, pin: isRegrab || atTop ? top : scrollView.contentOffset.y)
            } else {
                phase = .scrolling
            }

        case .changed:
            switch phase {
            case .scrolling:
                // Лента доехала до верха, а палец всё идёт вниз — дальше едет экран.
                if scrollView.contentOffset.y <= top, pan.velocity(in: space).y > 0 {
                    startPulling(from: translation, pin: top)
                    scrollView.contentOffset.y = top
                }
            case .pulling:
                let offset = grabOffset + translation - anchor
                if offset < 0, !isRegrab {
                    // Палец ушёл выше точки, с которой тянул, — ход снова у ленты.
                    view.transform = .identity
                    setRounded(false)
                    phase = .scrolling
                } else {
                    // Вверх за исходное место экран не едет: он во весь дисплей,
                    // и снизу открылась бы щель.
                    view.transform = CGAffineTransform(translationX: 0, y: max(0, offset))
                    scrollView.contentOffset.y = pinnedOffset
                }
            case .idle:
                break
            }

        case .ended, .cancelled, .failed:
            let wasPulling = phase == .pulling
            phase = .idle
            guard wasPulling else { return }
            // Лента не докатывается по инерции и не отскакивает от верха — решает экран.
            scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: pinnedOffset), animated: false)
            let offset = view.transform.ty
            guard offset > 0 else {
                setRounded(false)
                return
            }
            let velocity = pan.velocity(in: space).y
            let flickedDown = velocity > PullToDismissConfig.flickVelocity
            let pulledFar = offset > PullToDismissConfig.dismissDistance
                && velocity > -PullToDismissConfig.flickVelocity
            if pan.state == .ended, flickedDown || pulledFar {
                slideOut(from: offset, velocity: velocity)
            } else {
                settle(from: offset, velocity: velocity)
            }

        default:
            break
        }
    }

    private func startPulling(from translation: CGFloat, pin offset: CGFloat) {
        phase = .pulling
        anchor = translation
        pinnedOffset = offset
        setRounded(true)
    }

    /// Уход за нижнюю кромку с той скоростью, с какой его отпустили.
    private func slideOut(from offset: CGFloat, velocity: CGFloat) {
        guard let view else { return }
        let target = view.bounds.height
        let animator = UIViewPropertyAnimator(
            duration: PullToDismissConfig.slideOutDuration,
            timingParameters: UISpringTimingParameters(
                dampingRatio: 1,
                initialVelocity: Self.relativeVelocity(velocity, from: offset, to: target)
            )
        )
        animator.addAnimations {
            view.transform = CGAffineTransform(translationX: 0, y: target)
        }
        animator.addCompletion { [weak self] position in
            guard position == .end else { return }
            self?.onDismiss()
        }
        animator.startAnimation()
        self.animator = animator
    }

    /// Возврат на место, если не дотянул.
    private func settle(from offset: CGFloat, velocity: CGFloat) {
        guard let view else { return }
        let animator = UIViewPropertyAnimator(
            duration: PullToDismissConfig.settleDuration,
            timingParameters: UISpringTimingParameters(
                dampingRatio: 1,
                initialVelocity: Self.relativeVelocity(velocity, from: offset, to: 0)
            )
        )
        animator.addAnimations {
            view.transform = .identity
        }
        animator.addCompletion { [weak self] position in
            guard position == .end else { return }
            self?.setRounded(false)
        }
        animator.startAnimation()
        self.animator = animator
    }

    /// Скорость пальца в долях оставшегося пути в секунду — так её ждёт пружина.
    private static func relativeVelocity(_ velocity: CGFloat, from start: CGFloat, to end: CGFloat) -> CGVector {
        let distance = end - start
        guard abs(distance) > 1 else { return .zero }
        return CGVector(dx: 0, dy: velocity / distance)
    }

    private func setRounded(_ rounded: Bool) {
        guard let layer = view?.layer else { return }
        layer.cornerRadius = rounded ? PullToDismissConfig.cornerRadius : 0
        layer.cornerCurve = .continuous
        layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        layer.masksToBounds = rounded
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
