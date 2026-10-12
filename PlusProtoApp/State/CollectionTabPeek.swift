import SwiftUI

/// Константы показа миниатюры на табе «Моё».
enum CollectionTabPeekConfig {
    /// Сколько миниатюра держится на табе после того, как встала (задача 10: 2 с).
    static let hold: Duration = .seconds(2)
    /// Сколько ждём обложку, прежде чем сдаться: нет картинки к этому сроку — пика нет.
    static let warmupLimit: Duration = .seconds(1)
}

/// Миниатюра добавленной сущности вместо сердца на табе «Моё».
///
/// Состояние живёт в общем объекте, а не в `@State`/`.task` вью: таббар существует в
/// нескольких копиях (`BottomChrome` корня и каждый `CoveredEntityScreen` без
/// `coversChrome`), и таймер вью на каждой копии шёл бы свой. Здесь он один, а копии
/// просто читают `item`.
///
/// Подписка на `CollectionStore.lastAddition` — через `withObservationTracking`, тоже
/// в объекте: так копии таббара ничего не дублируют и не пропускают событие, если их
/// на экране в этот момент нет.
@MainActor
@Observable
final class CollectionTabPeek {
    static let shared = CollectionTabPeek()

    /// Что показано сейчас. `nil` — на табе сердце.
    private(set) var item: CollectionItem?
    /// Последняя показанная сущность — остаётся и после ухода пика: уходящая миниатюра
    /// гаснет вместе со своей картинкой, а не пустой формой.
    private(set) var displayed: CollectionItem?

    /// Новый показ и таймер снимают старый: закрыть пик может только последний.
    @ObservationIgnored private var token = 0
    @ObservationIgnored private var lastSeen: UUID?

    private init() {
        observe()
    }

    private func observe() {
        withObservationTracking {
            _ = CollectionStore.shared.lastAddition
        } onChange: { [weak self] in
            // `onChange` срабатывает до записи значения и один раз: читаем уже после
            // записи и подписываемся заново.
            Task { @MainActor in
                guard let self else { return }
                self.handle(CollectionStore.shared.lastAddition)
                self.observe()
            }
        }
    }

    private func handle(_ addition: CollectionAddition?) {
        guard let addition, addition.id != lastSeen else { return }
        lastSeen = addition.id
        show(addition.item)
    }

    private func show(_ item: CollectionItem) {
        token += 1
        let mine = token
        Task { @MainActor [weak self] in
            // Прогрев: без него `ArtworkImage` на холодной картинке рисует скелетон, и
            // серая вспышка вставала бы в тайл вместо обложки.
            guard let self else { return }
            let isReady = await Self.warmed(item.artwork)
            guard self.token == mine else { return }
            // Новая сущность без обложки к сроку — пика нет, а прошлый уже не закроет
            // свой таймер (токен сменился): без этого он висел бы на табе навсегда.
            guard isReady else {
                self.item = nil
                return
            }
            self.displayed = item
            self.item = item
            try? await Task.sleep(for: CollectionTabPeekConfig.hold)
            guard self.token == mine else { return }
            self.item = nil
        }
    }

    /// Обложка в памяти — сразу или за `warmupLimit`. Бандленная (`.asset`) есть всегда.
    private static func warmed(_ source: ArtworkSource?) async -> Bool {
        guard let source else { return false }
        guard let url = source.remoteURL else { return true }
        if ArtworkLoader.shared.cached(url) != nil { return true }
        return await withTaskGroup(of: Bool.self) { group in
            group.addTask { @MainActor in await ArtworkLoader.shared.image(for: url) != nil }
            group.addTask {
                try? await Task.sleep(for: CollectionTabPeekConfig.warmupLimit)
                return false
            }
            let first = await group.next() ?? false
            group.cancelAll()
            return first
        }
    }
}
