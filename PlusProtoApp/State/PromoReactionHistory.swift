import Foundation

/// Реакции микс-карусели переживают перезапуск, но не перестраивают текущий круг после лайка.
@MainActor
final class PromoReactionHistory {
    static let shared = PromoReactionHistory()

    enum Reaction: String { case like, dislike }
    private let defaults: UserDefaults
    private let storageKey = "homePromoReactions.v1"
    private var reactions: [String: String]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        reactions = defaults.dictionary(forKey: storageKey) as? [String: String] ?? [:]
    }

    var reactedIDs: Set<String> { Set(reactions.keys) }

    /// Отмена меняет только реакцию этой карточки и сохраняет остальные отметки.
    @discardableResult
    func record(_ reaction: Reaction, for id: String) -> @MainActor () -> Void {
        let previous = reactions[id]
        reactions[id] = reaction.rawValue
        persist()
        return { [weak self] in
            guard let self, self.reactions[id] == reaction.rawValue else { return }
            self.reactions[id] = previous
            self.persist()
        }
    }

    private func persist() { defaults.set(reactions, forKey: storageKey) }
}
