import SwiftUI
import UIKit

extension EnvironmentValues {
    @Entry var mixCapturePressTarget: String? = nil
}

/// Маркеры существуют только при записи сценариев, не перехватывают касания.
@MainActor struct MixCaptureTarget: ViewModifier {
    let name: String

    @ViewBuilder func body(content: Content) -> some View {
        #if DEBUG
        if MixMotionCapture.scenario != nil {
            content.environment(\.mixCapturePressTarget, name)
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
                MixCaptureTouches.shared.frames[name] = frame
            }
        } else {
            content
        }
        #else
        content
        #endif
    }
}

#if DEBUG
@MainActor @Observable final class MixCaptureTouches {
    static let shared = MixCaptureTouches()
    @ObservationIgnored var frames: [String: CGRect] = [:]
    var point = CGPoint.zero
    var opacity = 0.0
    var scale = 1.0
    var isRecording = false
    var pressedTarget: String?
    @ObservationIgnored private var generation = 0

    /// Запускает тот же PressScaleEffect, что и настоящее удержание кнопки.
    func press(target: String) async {
        guard isRecording else { return }
        tap(target: target)
        pressedTarget = target
        try? await Task.sleep(for: .milliseconds(180))
        pressedTarget = nil
    }

    func tap(target: String) {
        guard let frame = frames[target] else { return }
        let viewport = CGRect(x: 0, y: 0, width: PlusMetrics.screenWidth, height: UIScreen.main.bounds.height)
        let visible = frame.intersection(viewport)
        guard !visible.isNull else { return }
        tap(at: CGPoint(x: visible.midX, y: visible.midY))
    }

    func tap(at position: CGPoint) {
        guard isRecording else { return }
        generation += 1
        let token = generation
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) {
            point = position
            scale = 0.82
            opacity = 1
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(120))
            guard token == generation else { return }
            withAnimation(.easeOut(duration: 0.4)) {
                scale = 1.2
                opacity = 0
            }
        }
    }

    func swipe(target: String) {
        guard isRecording, let frame = frames[target] else { return }
        let start = CGPoint(x: frame.midX + 70, y: frame.midY)
        tap(at: start)
        withAnimation(.linear(duration: 0.4)) { point.x = start.x - 140 }
    }
}

struct MixCaptureTouchesOverlay: View {
    private let touches = MixCaptureTouches.shared

    var body: some View {
        if MixMotionCapture.scenario != nil {
            GeometryReader { proxy in
                let origin = proxy.frame(in: .global).origin
                Circle()
                    .fill(.white.opacity(0.24))
                    .overlay { Circle().stroke(.white.opacity(0.95), lineWidth: 2) }
                    .frame(width: 38, height: 38)
                    .shadow(color: .black.opacity(0.6), radius: 3)
                    .scaleEffect(touches.scale)
                    .position(x: touches.point.x - origin.x, y: touches.point.y - origin.y)
                    .opacity(touches.opacity)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}
#endif
