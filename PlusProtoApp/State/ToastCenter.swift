import SwiftUI

/// Графика слева — варианты `graphic` компонента `toast` из Library.
enum ToastGraphic: Equatable {
    /// Нет графики.
    case none
    /// `graphic=cover`: квадратная обложка 32 с наклоном.
    case cover(ArtworkSource)
    /// `graphic=cover` с прямоугольной обложкой 32×44 (фильм, книга), тот же наклон 6°.
    case poster(ArtworkSource)
    /// Круглая аватарка 40 внутри пилюли (у артиста — фото). В макете `graphic=image` — квадрат
    /// вплотную к торцу, у фото артиста он выходил полукругом с прямым краем (правка 2026-10-12).
    case avatar(ArtworkSource)
    /// `graphic=icon`: иконка из ассетов (template, `fillOne`).
    case icon(String)
}

/// Действие тоста. Есть действие — справа кнопка-шеврон (`button=on`), тап по всему тосту
/// его выполняет. Замыканий внутри нет: `ToastConfig` остаётся `Equatable`.
enum ToastAction: Equatable {
    /// Открыть таб «Моё».
    case openCollection
}

/// Один тост: графика (необязательна), фраза, действие (необязательно).
struct ToastConfig: Equatable, Identifiable {
    let id = UUID()
    var title: String
    var graphic: ToastGraphic = .none
    var action: ToastAction?
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

    /// Открывает «Моё» откуда угодно (закрывает фильм, плееры, профиль, поиск). Регистрирует
    /// корень приложения: окно тоста окружения корня не видит, а навигация живёт в `@State` корня.
    @ObservationIgnored
    var openCollection: (@MainActor () -> Void)?

    func show(
        title: String,
        graphic: ToastGraphic = .none,
        action: ToastAction? = nil,
        duration: Duration = .seconds(4)
    ) {
        current = ToastConfig(title: title, graphic: graphic, action: action, duration: duration)
        startTimer(duration)
    }

    /// Таймер автоскрытия. Меняет токен — предыдущий таймер больше ничего не закроет.
    private func startTimer(_ duration: Duration) {
        token += 1
        let mine = token
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: duration)
            guard let self, self.token == mine else { return }
            self.dismiss()
        }
    }

    /// Палец на тосте (смахивание): автоскрытие на паузе.
    func holdTimer() {
        token += 1
    }

    /// Палец отпущен, тост остался: таймер заново, на полный срок.
    func resumeTimer() {
        guard let current else { return }
        startTimer(current.duration)
    }

    /// Тап по тосту: тост уходит; есть действие — выполняем его, с хаптикой кнопки. Тост без
    /// кнопки закрывается молча. В окне затухания (`current == nil`) тап ничего не делает.
    func activate() {
        guard let action = current?.action else {
            if current != nil { dismiss() }
            return
        }
        PlayerHaptics.tap()
        dismiss()
        switch action {
        case .openCollection: openCollection?()
        }
    }

    func dismiss() {
        token += 1
        current = nil
    }
}
