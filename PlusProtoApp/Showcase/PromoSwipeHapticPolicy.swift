import Foundation

/// Один импульс при переходе видимого центра к соседнему слоту за жест.
/// Не зависит от порядка обновления scrollPosition(id:) и фазы idle.
final class PromoSwipeHapticPolicy {
    private var start: Int?
    private var interacting = false
    private var emitted = false

    func begin(at position: CGFloat) {
        guard start == nil else { return }
        start = Int(position.rounded())
        emitted = false
    }

    func interact(at position: CGFloat) -> Bool {
        begin(at: position)
        interacting = true
        return moved(to: position)
    }

    func moved(to position: CGFloat) -> Bool {
        guard interacting, !emitted, let start, Int(position.rounded()) != start else { return false }
        emitted = true
        return true
    }

    func reset() { start = nil; interacting = false; emitted = false }
}
