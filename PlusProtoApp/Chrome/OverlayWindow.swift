import SwiftUI
import UIKit

// MARK: - Состояние слоя

/// Что в слое «поверх всего» принимает касания. Окно с прозрачным фоном иначе съело бы
/// все тапы приложения: `hitTest` пропускает всё, кроме кадров из этого списка и режима
/// `isInteractive` (задел под шеринг — там слой закрывает экран целиком).
@MainActor
@Observable
final class OverlayLayerState {
    static let shared = OverlayLayerState()

    /// Слой целиком ловит касания: шторка шеринга, которой нужен весь экран.
    var isInteractive = false

    /// Кадры интерактивных вью в координатах окна: ключ — кто сообщил (`"toast"`).
    @ObservationIgnored
    private(set) var interactiveFrames: [String: CGRect] = [:]

    func setInteractiveFrame(_ frame: CGRect?, for key: String) {
        interactiveFrames[key] = frame
    }

    func accepts(_ point: CGPoint) -> Bool {
        isInteractive || interactiveFrames.values.contains { $0.contains(point) }
    }
}

// MARK: - Окно

/// Окно слоя «поверх всего».
///
/// **Почему окно, а не оверлей корня.** Экран фильма (`fullScreenCover`), профиль и плееры
/// (`ContentPlayerPresenter`, UIKit-презентация — корень приложения на время показа снимается
/// с окна) лежат выше корневого `ZStack`: тост в нём под ними не виден. Отдельное окно
/// выше уровнем видно поверх всего.
///
/// Окно **не ключевое** (ключевым его не делаем): `topViewController()` презентера плееров
/// и `keyWindow` хрома ищут ключевое окно приложения, и подмена сломала бы им поиск.
final class OverlayWindow: UIWindow {
    /// Фон — всегда прозрачный: `UIWindow.appearance().backgroundColor = .black` в `PlusProtoAppApp`
    /// иначе закрасил бы и это окно.
    override var backgroundColor: UIColor? {
        get { .clear }
        set { super.backgroundColor = .clear }
    }

    /// Вне своих вью касание уходит в окно под нами (`nil`).
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard OverlayLayerState.shared.accepts(point) else { return nil }
        return super.hitTest(point, with: event)
    }
}

/// Хостинг слоя: прозрачный, портрет, статус-бар — как у ключевого окна.
final class OverlayHostingController<Content: View>: UIHostingController<Content> {
    override init(rootView: Content) {
        super.init(rootView: rootView)
        view.backgroundColor = .clear
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) не используется")
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }

    // Статус-бар решает самый верхний контроллер ключевого окна (плеер, экран фильма),
    // а не наш пустой корень: иначе окно уровнем выше показало бы или скрыло бы его по-своему.
    override var prefersStatusBarHidden: Bool {
        appContentController?.prefersStatusBarHidden ?? false
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        appContentController?.preferredStatusBarStyle ?? .lightContent
    }

    private var appContentController: UIViewController? {
        let appWindow = view.window?.windowScene?.windows
            .first { $0.isKeyWindow && !($0 is OverlayWindow) }
        var top = appWindow?.rootViewController
        while let next = top?.presentedViewController, !next.isBeingDismissed {
            top = next
        }
        return top
    }
}

// MARK: - Мост из дерева корня

/// Невидимый мост: создаёт окно слоя и держит его. Лежит в `.background` корня по образцу
/// `ContentPlayerHost`. Окно создаётся лениво — когда мост попал в окно и узнал свою сцену.
struct OverlayWindowHost: UIViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> Anchor {
        let anchor = Anchor()
        anchor.isUserInteractionEnabled = false
        anchor.onScene = { [weak coordinator = context.coordinator] scene in
            coordinator?.install(in: scene)
        }
        return anchor
    }

    func updateUIView(_ uiView: Anchor, context: Context) {}

    static func dismantleUIView(_ uiView: Anchor, coordinator: Coordinator) {
        coordinator.tearDown()
    }

    /// Вью, которая сообщает сцену, как только окажется в окне.
    final class Anchor: UIView {
        var onScene: ((UIWindowScene) -> Void)?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if let scene = window?.windowScene { onScene?(scene) }
        }
    }

    @MainActor
    final class Coordinator {
        /// Сильная ссылка: без неё окно исчезло бы сразу после создания.
        private var window: OverlayWindow?

        func install(in scene: UIWindowScene) {
            guard window == nil else { return }
            let window = OverlayWindow(windowScene: scene)
            window.rootViewController = OverlayHostingController(rootView: OverlayLayer())
            window.windowLevel = .alert
            window.backgroundColor = .clear
            window.overrideUserInterfaceStyle = .dark
            window.isHidden = false
            self.window = window
        }

        func tearDown() {
            window?.isHidden = true
            window = nil
        }
    }
}
