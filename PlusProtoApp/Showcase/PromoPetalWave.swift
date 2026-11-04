import Foundation

/// События волны привязаны к идентичности слота, а не к его меняющемуся номеру.
/// Точка каждого запуска остаётся неизменной, пока шейдер проигрывает эффект.
struct PromoPetalWave<Slot: Hashable> {
    struct Pulse {
        let trigger: Int
        let origin: CGPoint
    }

    private struct Touch {
        let slot: Slot
        let origin: CGPoint
        let time: TimeInterval
    }

    let duration: TimeInterval
    private(set) var pulses: [Slot: Pulse] = [:]
    private var touch: Touch?
    private var startedAt = -TimeInterval.infinity

    init(duration: TimeInterval) {
        self.duration = duration
    }

    mutating func recordTouch(_ point: CGPoint, at slot: Slot, time: TimeInterval) {
        touch = Touch(slot: slot, origin: point, time: time)
    }

    mutating func launch(at slot: Slot, fallbackOrigin: CGPoint, time: TimeInterval) {
        guard time - startedAt >= duration else { return }
        let origin: CGPoint
        if let touch, touch.slot == slot, (0...0.5).contains(time - touch.time) {
            origin = touch.origin
        } else {
            // VoiceOver и программное действие не дают координату SpatialTapGesture.
            origin = fallbackOrigin
        }
        pulses[slot] = Pulse(trigger: (pulses[slot]?.trigger ?? 0) + 1, origin: origin)
        startedAt = time
        touch = nil
    }

    mutating func retain(_ slots: Set<Slot>) {
        pulses = pulses.filter { slots.contains($0.key) }
        if let touch, !slots.contains(touch.slot) { self.touch = nil }
    }

    mutating func reset() {
        pulses.removeAll()
        touch = nil
        startedAt = -.infinity
    }
}
