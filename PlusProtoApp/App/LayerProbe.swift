import SwiftUI
import UIKit

#if DEBUG
/// `-debugLayerProbe` — печатает дерево `UIView` окна: класс, кадр, альфу, клип, поворот.
///
/// Отвечает на вопрос, на который скриншот не отвечает: **что именно сейчас на экране —
/// живая вью или системная копия поверх неё**. Так вскрылся дефект зум-возврата
/// (2026-08-29): под `_UIMorphAnimationContainerView` лежал `_UIPortalView` источника,
/// обрезанный по его кадру, а сам источник (`_UIGraphicsView` внутри
/// `MatchedTransitionSourceMarkingView`) стоял `hidden=Y` ещё 0.7–2с после закрытия экрана.
///
/// Снимать вместе с прогоном закрытия:
///
///     xcrun simctl launch --console-pty booted com.dima.PlusProtoApp \
///       -debugMockFeed -debugTapBlock 1 -debugOpenEntity -debugCloseEntity -debugLayerProbe
enum LayerProbe {
    /// Через сколько после закрытия экрана снимать дерево: морф к этому моменту
    /// уже отыграл, но система его ещё держит — это и есть интересное состояние.
    private static let delay: Duration = .milliseconds(400)

    static func dumpAfterClose() {
        guard UserDefaults.standard.bool(forKey: "debugLayerProbe") else { return }
        // Отдельной задачей, а не `await` в вызывающем: закрытие снимает экран,
        // и его `task` отменяется вместе с ожиданием.
        Task { @MainActor in
            try? await Task.sleep(for: delay)
            dump()
        }
    }

    static func dump() {
        guard let window = keyWindow else {
            print("LAYER: ключевого окна нет")
            return
        }
        print("LAYER-START окно \(window.bounds.size)")
        walk(window, depth: 0)
        print("LAYER-END")
    }

    /// `-debugGestureProbe <сек>` — через столько секунд после появления экрана сущности
    /// печатает все распознаватели жестов окна (класс, на какой вью, включён ли, чей делегат)
    /// и цепочку контроллеров с их `preferredTransition`: так видно, какой системный жест
    /// закрывает экран зумом и выключен ли он, пока на экране поиск.
    static func dumpGesturesIfRequested() {
        let delay = UserDefaults.standard.double(forKey: "debugGestureProbe")
        guard delay > 0 else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            guard let window = keyWindow else { return }
            print("GEST-START")
            walkGestures(window, depth: 0)
            if let root = window.rootViewController { walkControllers(root, depth: 0) }
            print("GEST-END")
        }
    }

    private static func walkGestures(_ view: UIView, depth: Int) {
        for recognizer in view.gestureRecognizers ?? [] {
            let delegate = recognizer.delegate.map { String(describing: type(of: $0)) } ?? "nil"
            print("GEST \(depth) \(type(of: recognizer)) on \(type(of: view)) enabled=\(recognizer.isEnabled) delegate=\(delegate)")
        }
        for subview in view.subviews { walkGestures(subview, depth: depth + 1) }
    }

    private static func walkControllers(_ controller: UIViewController, depth: Int) {
        let transition = controller.preferredTransition.map { String(describing: $0) } ?? "nil"
        print("GESTVC \(String(repeating: "·", count: depth))\(type(of: controller)) transition=\(transition)")
        for child in controller.children { walkControllers(child, depth: depth + 1) }
        if let presented = controller.presentedViewController, presented.presentingViewController === controller {
            walkControllers(presented, depth: depth + 1)
        }
    }

    private static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
    }

    private static func walk(_ view: UIView, depth: Int) {
        let frame = view.frame
        let transform = view.layer.transform
        let isRotated = abs(transform.m12) > 0.0001 || abs(transform.m21) > 0.0001

        print(String(
            format: "LAYER %@%@ x=%.1f y=%.1f w=%.1f h=%.1f a=%.2f hidden=%@ clip=%@ rot=%@",
            String(repeating: "·", count: depth),
            String(describing: type(of: view)),
            frame.minX, frame.minY, frame.width, frame.height,
            view.alpha,
            view.isHidden ? "Y" : "n",
            view.clipsToBounds ? "Y" : "n",
            isRotated ? "Y" : "n"
        ))

        for subview in view.subviews { walk(subview, depth: depth + 1) }
    }
}
#endif

#if DEBUG
/// `-debugNavTrace 1` — печатает смены таба, слоя и появление экранов слоя: на смене таба
/// из слоя видно, кто что снял и кто что показал (проверка независимых стеков 2026-10-31).
/// Читать: `xcrun simctl launch --console-pty booted com.dima.PlusProtoApp … -debugNavTrace 1`.
enum NavTrace {
    static let isOn = UserDefaults.standard.bool(forKey: "debugNavTrace")

    static func log(_ message: @autoclosure () -> String) {
        guard isOn else { return }
        print("NAV \(String(format: "%.3f", Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 1000))) \(message())")
    }
}
#endif

#if DEBUG
/// `-debugFrameGaps 1` — печатает в консоль `[gap] …` каждый кадр главного потока, пришедший
/// позже 30 мс: так видно, что бар отстаёт от клавиатуры не из-за кривой, а потому что
/// главный поток занят (разбор подъёма бара над клавиатурой 2026-10-31).
final class FrameGapTrace: NSObject {
    private static var shared: FrameGapTrace?
    private var last: CFTimeInterval = 0

    static func startIfRequested() {
        guard shared == nil, UserDefaults.standard.bool(forKey: "debugFrameGaps") else { return }
        let trace = FrameGapTrace()
        CADisplayLink(target: trace, selector: #selector(tick(_:))).add(to: .main, forMode: .common)
        shared = trace
    }

    @objc private func tick(_ link: CADisplayLink) {
        defer { last = link.timestamp }
        guard last > 0 else { return }
        let gap = (link.timestamp - last) * 1000
        if gap > 30 { NSLog("[gap] %.0f ms", gap) }
    }
}
#endif

