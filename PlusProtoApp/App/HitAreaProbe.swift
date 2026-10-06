import SwiftUI
import UIKit

#if DEBUG
/// `-debugHitProbe` — печатает дерево доступности с кадрами элементов в консоль.
///
/// Тапнуть по симулятору из шелла нечем, а «что именно нажимается и где» — вопрос,
/// который скриншот не закрывает. Дерево доступности отвечает на него численно:
/// у каждой кнопки в нём честный кадр в координатах экрана. Снимать так:
///
///     xcrun simctl launch --console-pty booted com.dima.PlusProtoApp -debugMockFeed -debugHitProbe
enum HitAreaProbe {
    /// Даём витрине доехать: живые обложки и каскад появления меняют раскладку.
    private static let delay: Duration = .seconds(5)

    static func dumpIfRequested() async {
        await sweepIfRequested()
        guard UserDefaults.standard.bool(forKey: "debugHitProbe") else { return }
        try? await Task.sleep(for: delay)
        guard !Task.isCancelled else { return }

        guard let window = keyWindow else {
            print("PROBE: ключевого окна нет")
            return
        }
        print("PROBE-START окно \(window.bounds.size)")
        walk(window, depth: 0)
        print("PROBE-END")
    }

    /// `-debugHitSweep <x>` — какой UIKit-вью достаётся касание в точках вертикали
    /// `x`, сверху вниз шагом 8 pt: дерево доступности не видит UIKit-слоёв, которые
    /// перехватывают касания поверх SwiftUI (блюры, представления). Печатает только смены.
    private static func sweepIfRequested() async {
        let x = UserDefaults.standard.double(forKey: "debugHitSweep")
        guard x > 0 else { return }
        try? await Task.sleep(for: delay)
        guard !Task.isCancelled, let window = keyWindow else { return }
        print("SWEEP-START x=\(x)")
        var previous = ""
        for y in stride(from: 0.0, through: window.bounds.height, by: 8) {
            let point = CGPoint(x: x, y: y)
            let hit = window.hitTest(point, with: nil)
            let chain = sequence(first: hit, next: { $0?.superview })
                .prefix(4)
                .compactMap { view -> String? in
                    guard let view else { return nil }
                    let frame = view.convert(view.bounds, to: window)
                    var text = String(format: "%@(y %.0f h %.0f)", String(describing: type(of: view)), frame.minY, frame.height)
                    if let scroll = view as? UIScrollView {
                        text += String(format: "[content %.0f×%.0f]", scroll.contentSize.width, scroll.contentSize.height)
                    }
                    return text
                }
                .joined(separator: " < ")
            if chain != previous {
                print(String(format: "SWEEP y=%.0f %@", y, chain))
                previous = chain
            }
        }
        print("SWEEP-END")
    }

    private static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
    }

    private static func walk(_ node: NSObject, depth: Int) {
        if node.isAccessibilityElement {
            print(line(for: node, depth: depth))
        }

        let count = node.accessibilityElementCount()
        if count != NSNotFound, count > 0 {
            for index in 0..<count {
                guard let child = node.accessibilityElement(at: index) as? NSObject else { continue }
                walk(child, depth: depth + 1)
            }
        } else if let view = node as? UIView {
            for subview in view.subviews { walk(subview, depth: depth + 1) }
        }
    }

    private static func line(for node: NSObject, depth: Int) -> String {
        let frame = node.accessibilityFrame
        let label = (node.accessibilityLabel ?? "")
            .replacingOccurrences(of: "\n", with: " ")

        return String(
            format: "PROBE %@ [%@] x=%.1f y=%.1f w=%.1f h=%.1f | %@",
            String(repeating: "·", count: depth),
            kinds(of: node.accessibilityTraits),
            frame.minX, frame.minY, frame.width, frame.height,
            String(label.prefix(48))
        )
    }

    private static func kinds(of traits: UIAccessibilityTraits) -> String {
        let named: [(UIAccessibilityTraits, String)] = [
            (.button, "button"),
            (.link, "link"),
            (.image, "image"),
            (.staticText, "text"),
            (.header, "header"),
        ]
        let matched = named.filter { traits.contains($0.0) }.map(\.1)
        return matched.isEmpty ? "—" : matched.joined(separator: "+")
    }
}

extension View {
    func debugHitAreaProbe() -> some View {
        task { await HitAreaProbe.dumpIfRequested() }
    }
}
#endif
