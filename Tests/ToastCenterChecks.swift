import Foundation

// Минимальные зависимости: проверяем реальный ToastCenter без запуска приложения.
enum ArtworkSource: Equatable { case asset(String) }
struct CollectionItem: Equatable { let id: String }
@MainActor enum PlayerHaptics { static func tap() {} }
@MainActor final class CollectionStore {
    static let shared = CollectionStore()
    var saved: [CollectionItem] = []
    func setFavorite(_ item: CollectionItem, _ value: Bool) {
        if value { saved.append(item) }
    }
}

@main struct ToastCenterChecks {
    @MainActor static func main() async throws {
        let center = ToastCenter()
        var undone = 0
        center.showDislikedRecommendation { undone += 1 }
        precondition(center.current?.action == .undoRecommendation)
        center.activate()
        center.activate()
        precondition(undone == 1 && center.current == nil, "Отмена выполняется ровно один раз")

        center.showDislikedRecommendation { undone += 1 }
        center.show(title: "Новое сообщение")
        center.activate()
        precondition(undone == 1, "Замена тоста освобождает старую отмену")

        center.showDislikedRecommendation { undone += 1 }
        center.dismiss()
        center.activate()
        precondition(undone == 1, "Скрытый тост не отменяет оценку")

        center.show(title: "Старый таймер", duration: .milliseconds(10))
        center.showDislikedRecommendation { undone += 1 }
        try await Task.sleep(for: .milliseconds(40))
        precondition(center.current?.action == .undoRecommendation, "Старый таймер не закрывает новый тост")
        center.activate()
        precondition(undone == 2)

        let item = CollectionItem(id: "rated-card")
        center.show(title: "Лайк", action: .saveRecommendation(item))
        center.activate()
        precondition(CollectionStore.shared.saved == [item])
        precondition(center.current?.action == .openCollection, "Сохранение по лайку работает как прежде")
        center.dismiss()
        print("PASS: одноразовая отмена, замена/скрытие, старый таймер, сохранение по лайку")
    }
}
