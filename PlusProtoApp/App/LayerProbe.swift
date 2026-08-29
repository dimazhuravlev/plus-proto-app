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
