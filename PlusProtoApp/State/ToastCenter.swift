import SwiftUI

/// Один тост: обложка (необязательна) и фраза.
struct ToastConfig: Equatable, Identifiable {
    let id = UUID()
    var title: String
    var cover: ArtworkSource?
    var duration: Duration
}

/// Один «текущий» тост. Новый, пока старый на экране, заменяет его на месте
/// (`ToastPresenter`), а таймер начинается заново.
///
/// Показывать может любой код: `ToastCenter.shared.show(title:)`. Рисует тост окно
/// `OverlayWindow` — окружения корня там нет, поэтому всё здесь, а не в `@Environment`.
@MainActor
@Observable
final class ToastCenter {
    static let shared = ToastCenter()

    private(set) var current: ToastConfig?

    /// Закрыть тост может только последний таймер: к новому показу токен меняется,
    /// и таймер старого тоста уже ничего не закроет.
    @ObservationIgnored
    private var token = 0

    func show(title: String, cover: ArtworkSource? = nil, duration: Duration = .seconds(4)) {
        token += 1
        let mine = token
        current = ToastConfig(title: title, cover: cover, duration: duration)
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: duration)
            guard let self, self.token == mine else { return }
            self.dismiss()
        }
    }

    func dismiss() {
        token += 1
        current = nil
    }
}
