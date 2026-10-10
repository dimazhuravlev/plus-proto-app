import Foundation

/// Экран шеринга: что показывается и когда его снимать. Рисует его `ShareOverlay` в окне
/// `OverlayWindow` (`OverlayLayer`) — там же, где тост, поэтому открывается поверх всего,
/// и поверх экрана фильма тоже. Показывать может любой код: `ShareState.shared.present(_:)`.
///
/// Отложенное снятие хранится здесь и отменяется при новом `present` — иначе после второго
/// показа от прошлого закрытия остался бы невидимый слой, перехватывающий касания
/// (перенос `ShareOverlayState` из MusicPlayer).
@MainActor
@Observable
final class ShareState {
    static let shared = ShareState()

    private(set) var presented: ShareableEntity?
    /// Меняется на каждый `present`: вью шеринга не переиспользует состояние прошлого показа.
    private(set) var presentationID = UUID()

    @ObservationIgnored
    private var pendingRemoval: Task<Void, Never>?

    func present(_ entity: ShareableEntity) {
        cancelRemoval()
        presentationID = UUID()
        presented = entity
        OverlayLayerState.shared.isInteractive = true
    }

    func dismissImmediately() {
        cancelRemoval()
        presented = nil
        OverlayLayerState.shared.isInteractive = false
    }

    /// После анимации закрытия. Отменяется следующим `present` / `dismissImmediately`.
    func scheduleRemovalAfterAnimation(_ delay: TimeInterval) {
        cancelRemoval()
        pendingRemoval = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self else { return }
            self.pendingRemoval = nil
            self.dismissImmediately()
        }
    }

    private func cancelRemoval() {
        pendingRemoval?.cancel()
        pendingRemoval = nil
    }
}
