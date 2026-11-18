import SwiftUI
import UIKit

/// Только для dev-демо: панель в отдельном неклавишном окне остаётся доступной
/// поверх модальной sheet, а касания вне панели уходят в форму и её клавиатуру.
struct SurveyDemoNavigationHost<Content: View>: UIViewRepresentable {
    @ViewBuilder let content: () -> Content

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> Anchor {
        let anchor = Anchor()
        anchor.isUserInteractionEnabled = false
        anchor.onScene = { [weak coordinator = context.coordinator] scene in
            coordinator?.install(in: scene, content: content())
        }
        return anchor
    }

    func updateUIView(_ uiView: Anchor, context: Context) {
        context.coordinator.update(content: content())
    }

    static func dismantleUIView(_ uiView: Anchor, coordinator: Coordinator) {
        coordinator.tearDown()
    }

    final class Anchor: UIView {
        var onScene: ((UIWindowScene) -> Void)?
        override func didMoveToWindow() {
            super.didMoveToWindow()
            if let scene = window?.windowScene { onScene?(scene) }
        }
    }

    @MainActor
    final class Coordinator {
        private var window: SurveyDemoNavigationWindow?
        private var controller: SurveyDemoHostingController<SurveyDemoNavigationRoot<Content>>?

        func install(in scene: UIWindowScene, content: Content) {
            guard window == nil else { update(content: content); return }
            let window = SurveyDemoNavigationWindow(windowScene: scene)
            let controller = SurveyDemoHostingController(rootView: SurveyDemoNavigationRoot(content: content))
            window.rootViewController = controller
            window.windowLevel = UIWindow.Level(rawValue: UIWindow.Level.alert.rawValue + 1)
            window.overrideUserInterfaceStyle = .dark
            // Не делаем окно key: поля формы продолжают получать клавиатурный ввод.
            window.isHidden = false
            self.controller = controller
            self.window = window
        }

        func update(content: Content) {
            controller?.rootView = SurveyDemoNavigationRoot(content: content)
        }

        func tearDown() {
            window?.isHidden = true
            window?.rootViewController = nil
            window = nil
            controller = nil
        }
    }
}

/// У этой dev-панели нет делегирования статус-бара ключевому окну:
/// при смене WebView UIKit мог назначить её окну key, а общий OverlayHostingController
/// находил сам себя и бесконечно вызывал prefersStatusBarHidden.
fileprivate final class SurveyDemoHostingController<Content: View>: UIHostingController<Content> {
    override init(rootView: Content) {
        super.init(rootView: rootView)
        view.backgroundColor = .clear
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) не используется")
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }
    override var prefersStatusBarHidden: Bool { false }
    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
}

fileprivate struct SurveyDemoNavigationRoot<Content: View>: View {
    let content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
                .foregroundStyle(Color.fillOne)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, SurveyDemoNavigationWindow.sideInset)
                .padding(.top, SurveyDemoNavigationWindow.topGap)
            Spacer(minLength: 0)
        }
        .preferredColorScheme(.dark)
    }
}

fileprivate final class SurveyDemoNavigationWindow: UIWindow {
    static let sideInset: CGFloat = 12
    static let topGap: CGFloat = 8
    static let panelHeight: CGFloat = 44

    // isHidden = false само по себе не гарантирует, что UIKit не сделает окно key
    // позже, например после endEditing у уходящей формы.
    override var canBecomeKey: Bool { false }

    override var backgroundColor: UIColor? {
        get { .clear }
        set { super.backgroundColor = .clear }
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let top = rootViewController?.view.safeAreaInsets.top ?? safeAreaInsets.top
        let panel = CGRect(x: Self.sideInset, y: top + Self.topGap,
                           width: bounds.width - Self.sideInset * 2, height: Self.panelHeight)
        guard panel.contains(point) else { return nil }
        return super.hitTest(point, with: event)
    }
}
