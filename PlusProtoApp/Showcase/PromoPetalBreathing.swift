import SwiftUI

/// Анимирует готовый компонент снаружи: геометрия лепестка и его растр не меняются.
struct PromoPetalBreathing: ViewModifier {
    let active: Bool
    let anchor: UnitPoint
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var started: Date?
    @State private var returnStarted: Date?
    @State private var returnPose = Pose()
    @State private var entrancePose = Pose()

    private static let returnDuration: TimeInterval = 0.45

    private var running: Bool { active && scenePhase == .active && !reduceMotion }

    func body(content: Content) -> some View {
        Group {
            if scenePhase == .active, !reduceMotion, running || started != nil {
                TimelineView(.animation(minimumInterval: 1.0 / 60)) { timeline in
                    render(content, pose: pose(at: timeline.date))
                }
            } else {
                render(content, pose: Pose())
            }
        }
        .onChange(of: running, initial: true) { _, enabled in
            if enabled {
                entrancePose = pose(at: .now)
                started = .now
                returnStarted = nil
            } else if started != nil, scenePhase == .active, !reduceMotion {
                let now = Date.now
                returnPose = pose(at: now)
                returnStarted = now
            } else {
                started = nil
                returnStarted = nil
                entrancePose = Pose()
            }
        }
        .task(id: returnStarted) {
            guard let returning = returnStarted else { return }
            do { try await Task.sleep(for: .seconds(Self.returnDuration)) }
            catch { return }
            guard !running, returnStarted == returning else { return }
            // Timeline живёт только во время движения, включая короткий возврат.
            started = nil
            returnStarted = nil
            entrancePose = Pose()
        }
    }

    private func pose(at date: Date) -> Pose {
        if let returnStarted {
            let t = min(1, max(0, date.timeIntervalSince(returnStarted) / Self.returnDuration))
            return returnPose.scaled(by: pow(1 - t, 3))
        }
        let time = started.map { max(0, date.timeIntervalSince($0)) } ?? 0
        let entrance = (1 - cos(min(time / 1.6, 1) * .pi)) / 2
        return motion(at: time).adding(entrancePose.scaled(by: 1 - entrance))
    }

    private func render(_ content: Content, pose: Pose) -> some View {
        content
            .background {
                content
                    .blur(radius: 20)
                    .scaleEffect(1.12, anchor: anchor)
                    .opacity(pose.glow)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .brightness(pose.light)
            .scaleEffect(x: 1 + pose.width, y: 1 + pose.height, anchor: anchor)
            .rotationEffect(.degrees(pose.angle), anchor: anchor)
            .offset(x: pose.drift, y: pose.lift)
    }

    private struct Pose {
        var width = 0.0
        var height = 0.0
        var angle = 0.0
        var drift = 0.0
        var lift = 0.0
        var glow = 0.0
        var light = 0.0

        func scaled(by factor: Double) -> Pose {
            Pose(width: width * factor, height: height * factor, angle: angle * factor,
                 drift: drift * factor, lift: lift * factor, glow: glow * factor, light: light * factor)
        }

        func adding(_ other: Pose) -> Pose {
            Pose(width: width + other.width, height: height + other.height, angle: angle + other.angle,
                 drift: drift + other.drift, lift: lift + other.lift, glow: glow + other.glow, light: light + other.light)
        }
    }

    private func motion(at time: TimeInterval) -> Pose {
        // Мягкий вдох: нулевая скорость на старте и в конце, без второй implicit-анимации.
        let entranceDuration = 1.6
        let t = min(time / entranceDuration, 1)
        let entrance = (1 - cos(t * .pi)) / 2
        let elapsed = max(0, time - entranceDuration)
        let breath = (1 + cos(elapsed * 2 * .pi / 4.8)) / 2
        let sway = sin(elapsed * 2 * .pi / 8)
        let stretch = sin(elapsed * 2 * .pi / 6.4)
        return Pose(
            width: entrance * (0.025 + 0.065 * breath + 0.015 * stretch),
            height: entrance * (0.035 + 0.095 * breath - 0.015 * stretch),
            angle: entrance * (-3 + 6 * sway),
            drift: entrance * 3 * sway,
            lift: -entrance * (2 + 8 * breath),
            glow: entrance * (0.12 + 0.28 * breath),
            light: entrance * (0.01 + 0.035 * breath)
        )
    }
}
