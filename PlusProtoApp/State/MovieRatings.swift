import SwiftUI

/// Оценка тайтла — четыре реакции блока «Уже смотрели? Как вам?» экрана тайтла.
enum MovieRating: String, Codable, CaseIterable, Identifiable {
    case dislike, meh, good, love

    var id: String { rawValue }

    /// Ассет эмодзи — картинка, а не глиф: эмодзи-шрифт симулятора рисует квадраты.
    var emoji: String {
        switch self {
        case .dislike: "emojiRateDislike"
        case .meh: "emojiRateMeh"
        case .good: "emojiRateGood"
        case .love: "emojiRateLove"
        }
    }

    /// Подписи — как у блока оценки на витрине (правка пользователя 2026-10-09).
    var title: String {
        switch self {
        case .dislike: "Нет"
        case .meh: "Норм"
        case .good: "Супер"
        case .love: "Шедевр"
        }
    }

    /// Сколько эмодзи улетает из кнопки — по силе оценки.
    var burst: Int {
        switch self {
        case .dislike, .meh: 1
        case .good: 2
        case .love: 6
        }
    }
}

/// «Мои оценки» — фильмы, которые пользователь оценил на экране тайтла (задача
/// пользователя 2026-10-20): карусель экрана «Кино» коллекции. Свежие — первыми;
/// повторный тап по выбранной реакции снимает оценку, фильм уходит из карусели.
///
/// Одна на приложение (`shared`), лежит на диске (`UserDefaults`, JSON). Стартового
/// набора нет (решение пользователя 2026-10-20): пока ничего не оценено, карусели нет.
@MainActor
@Observable
final class MovieRatings {
    static let shared = MovieRatings()

    struct Entry: Codable, Identifiable, Equatable {
        /// Фильм — записью коллекции: его рисуют те же карточки и строки.
        var item: CollectionItem
        var rating: MovieRating
        var ratedAt: Date

        var id: String { item.id }
    }

    private(set) var entries: [Entry] = [] {
        didSet { persist() }
    }

    private static let storageKey = "movieRatings"

    private init() {
        #if DEBUG
        // `-debugResetCollection 1` — с пустых оценок, как коллекция со стартового набора.
        if UserDefaults.standard.bool(forKey: "debugResetCollection") {
            UserDefaults.standard.removeObject(forKey: Self.storageKey)
        }
        #endif
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode([Entry].self, from: data) {
            entries = saved
        }
    }

    func rating(for id: String) -> MovieRating? {
        entries.first { $0.id == id }?.rating
    }

    /// Поставить оценку или снять её (`nil`). Новая оценка поднимает фильм наверх.
    func set(_ rating: MovieRating?, for item: CollectionItem) {
        var list = entries
        list.removeAll { $0.id == item.id }
        if let rating {
            list.insert(Entry(item: item, rating: rating, ratedAt: .now), at: 0)
        }
        entries = list
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}

/// Оценка на постере — эмодзи в белом круге 18 у левого верхнего угла обложки:
/// на 8 от левой кромки и на 6 выше верхней (задача пользователя 2026-10-20). Ставится
/// оверлеем на постер; ленте карусели нужно не обрезать выступ (`allowsOverflow`).
struct MovieRatingBadge: View {
    let rating: MovieRating

    enum Layout {
        static let circle: CGFloat = 18
        /// Эмодзи — в круге с полями по 3
        static let emoji: CGFloat = 12
        static let leading: CGFloat = 8
        /// Насколько круг выступает над верхней кромкой обложки
        static let rise: CGFloat = 6
    }

    var body: some View {
        Circle()
            .fill(Color.fillOne)
            .frame(width: Layout.circle, height: Layout.circle)
            .overlay {
                Image(rating.emoji)
                    .resizable()
                    .scaledToFit()
                    .frame(width: Layout.emoji, height: Layout.emoji)
            }
            .padding(.leading, Layout.leading)
            .offset(y: -Layout.rise)
            .allowsHitTesting(false)
            .accessibilityLabel("Моя оценка: \(rating.title)")
    }
}
