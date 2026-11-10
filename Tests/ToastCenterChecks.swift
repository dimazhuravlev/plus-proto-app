import Foundation

// Минимальные зависимости: проверяем реальный ToastCenter без запуска приложения.
enum ArtworkSource: Equatable { case asset(String) }
struct CollectionItem: Equatable { let id: String }
@MainActor enum PlayerHaptics { static func tap() {} }
@MainActor final class CollectionStore {
    static let shared = CollectionStore()
    var saved: [CollectionItem] = []
    func isFavorite(_ id: String) -> Bool { saved.contains { $0.id == id } }
    func setFavorite(_ item: CollectionItem, _ value: Bool) {
        if value { saved.append(item) }
    }
}

@main struct ToastCenterChecks {
    @MainActor static func main() async throws {
        let center = ToastCenter()
        var undone = 0
        center.showDislikedRecommendation { undone += 1 }
        precondition(center.current?.action == nil)
        center.activate()
        center.activate()
        precondition(undone == 0 && center.current == nil, "Текстовый тост не отменяет оценку")

        center.show(title: "Старый таймер", duration: .milliseconds(10))
        center.show(title: "Новое сообщение")
        let latest = center.current?.id
        try await Task.sleep(for: .milliseconds(40))
        precondition(center.current?.id == latest, "Старый таймер не закрывает новый тост")
        center.dismiss()
        precondition(center.current == nil)

        let item = CollectionItem(id: "rated-card")
        center.show(title: "Лайк", graphic: .cover(.asset("cover")), action: .saveRecommendation(item))
        precondition(center.current?.graphic == ToastGraphic.none && center.current?.action == nil,
                     "Даже старые вызовы показывают только текст")
        center.activate()
        precondition(CollectionStore.shared.saved.isEmpty, "Нажатие на тост не сохраняет скрытым действием")

        var opened = 0
        center.openCollection = { opened += 1 }
        center.show(title: "Сообщение", action: .openCollection)
        center.activate()
        precondition(opened == 0 && center.current == nil, "Тап только закрывает текстовый тост")

        let savedItem = CollectionItem(id: "saved-card-v2")
        center.saveRecommendation(savedItem, title: "Сохранили в «Моё»")
        precondition(CollectionStore.shared.saved == [savedItem], "V2 сохраняет сразу")
        precondition(center.current?.title == "Сохранили в «Моё»" && center.current?.action == nil)
        center.activate()
        precondition(CollectionStore.shared.saved == [savedItem], "Тост не сохраняет повторно")
        center.saveRecommendation(savedItem, title: "Сохранили в «Моё»")
        precondition(CollectionStore.shared.saved == [savedItem] && center.current?.title == "Уже сохранено")
        center.dismiss()
        print("PASS: text-only toasts, no hidden actions, replacement and timers, immediate V2 save and safe repeat")

    }
}
