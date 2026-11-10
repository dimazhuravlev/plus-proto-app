import SwiftUI

/// Графика слева — варианты `graphic` компонента `toast` из Library.
enum ToastGraphic: Equatable {
    /// Нет графики.
    case none
    /// `graphic=cover`: квадратная обложка 32 с наклоном.
    case cover(ArtworkSource)
    /// `graphic=cover` с прямоугольной обложкой 32×44 (фильм), тот же наклон 6°.
    case poster(ArtworkSource)
    /// То же для книги: в кадре постера — карточка книги (`card / book`).
    case book(ArtworkSource)
    /// Круглая аватарка 40 внутри пилюли (у артиста — фото). В макете `graphic=image` — квадрат
    /// вплотную к торцу, у фото артиста он выходил полукругом с прямым краем (правка 2026-10-12).
    case avatar(ArtworkSource)
    /// `graphic=icon`: иконка из ассетов (template, `fillOne`).
    case icon(String)
}

/// Прежние значения действий сохранены для совместимости вызовов.
/// Информационные тосты их не отображают и не выполняют.
enum ToastAction: Equatable {
    /// Открыть таб «Моё».
    case openCollection
    case saveRecommendation(CollectionItem)
    case undoRecommendation

    var requiresExplicitButton: Bool {
        switch self {
        case .saveRecommendation, .undoRecommendation: true
        case .openCollection: false
        }
    }

    var isSaveRecommendation: Bool {
        if case .saveRecommendation = self { return true }
        return false
    }
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
        // Аргументы графики и действия оставлены для совместимости вызовов.
        // Все тосты информационные: только текст, без скрытых действий по тапу.
        current = ToastConfig(title: title, graphic: .none, action: nil, duration: duration)
        startTimer(duration)
    }

    /// Подтверждение дизлайка — только текст. Старый параметр отмены не сохраняется.
    func showDislikedRecommendation(title: String = "Будем показывать меньше такого", undo: @escaping @MainActor () -> Void) {
        show(title: title)
    }

    /// V2 карусели сохраняет сразу. Повторное сохранение не меняет дату и порядок
    /// коллекции; тост только подтверждает результат.
    func saveRecommendation(_ item: CollectionItem, title: String, duration: Duration = .seconds(4)) {
        let alreadySaved = CollectionStore.shared.isFavorite(item.id)
        if !alreadySaved { CollectionStore.shared.setFavorite(item, true) }
        show(title: alreadySaved ? "Уже сохранено" : title, duration: duration)
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

    /// Текстовый тост только закрывается, без действий с коллекцией или оценкой.
    func activate() {
        dismiss()
    }

    func dismiss() {
        token += 1
        current = nil
    }
}
