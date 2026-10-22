import Foundation

/// Начатые книги — то, что открывали в читалке, свежие первыми: «Читаю» в коллекции
/// и начатое в карусели «Книги» полки «Любимое» (задача пользователя 2026-10-19).
/// Книжная пара `WatchHistory`: пишется под выехавшей читалкой (`ActionBarState`).
///
/// Пропорции обложки — в записи: карточка книги встаёт своей ширины сразу. Не пришли
/// с запуском — меряются по картинке и дописываются.
@Observable
final class ReadingHistory {
    struct Entry: Codable, Equatable, Identifiable {
        var book: BookInProgress
        var aspect: CGFloat?
        var updatedAt: Date
        /// Сколько прочитано, 0…1 — доля прокрутки текста читалки на её закрытии
        /// (текст книги — аннотация). Полоса под карточкой продолженного.
        var progress: Double?

        var id: String { book.id }
    }

    private(set) var entries: [Entry] = [] {
        didSet { persist() }
    }

    private static let limit = 20
    private static let storageKey = "readingHistory"
    private static let seededKey = "readingHistorySeeded"
    private static let progressSeededKey = "readingHistoryProgressSeeded"

    init() {
        let defaults = UserDefaults.standard
        #if DEBUG
        // `-debugResetReadingHistory 1` — стереть историю и посеять стартовый набор заново.
        if defaults.bool(forKey: "debugResetReadingHistory") {
            defaults.removeObject(forKey: Self.storageKey)
            defaults.removeObject(forKey: Self.seededKey)
        }
        #endif
        if let data = defaults.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode([Entry].self, from: data) {
            entries = saved
        }
        // Стартовым книгам, посеянным до полосы прогресса, — их доля из набора: один раз.
        if !defaults.bool(forKey: Self.progressSeededKey) {
            let seeded = Self.seeds(now: .now)
            for index in entries.indices where entries[index].progress == nil {
                entries[index].progress = seeded.first { $0.id == entries[index].id }?.progress
            }
            defaults.set(true, forKey: Self.progressSeededKey)
        }
        guard !defaults.bool(forKey: Self.seededKey) else { return }
        if entries.isEmpty { entries = Self.seeds(now: .now) }
        defaults.set(true, forKey: Self.seededKey)
    }

    /// Книга открыта в читалке — в начало.
    func record(_ book: BookInProgress, aspect: CGFloat? = nil) {
        var list = entries
        let previous = list.first { $0.id == book.id }
        list.removeAll { $0.id == book.id }
        var book = book
        if book.author == nil { book.author = previous?.book.author }
        list.insert(Entry(book: book, aspect: aspect ?? previous?.aspect, updatedAt: .now, progress: previous?.progress), at: 0)
        if list.count > Self.limit {
            list.removeLast(list.count - Self.limit)
        }
        entries = list
        guard list[0].aspect == nil else { return }
        Task { @MainActor [weak self] in
            guard let measured = await BookCoverAspect.load(of: book.cover),
                  let self, let index = self.entries.firstIndex(where: { $0.id == book.id }) else { return }
            self.entries[index].aspect = measured
        }
    }

    /// Начатые книги — прочитано больше 1 % (`ContentProgress`): «Читаю». Просто
    /// открытая книга начатой не считается (правка пользователя 2026-10-22).
    var started: [Entry] {
        entries.filter { ContentProgress.isStarted($0.progress) }
    }

    /// Сколько прочитано у книги в процессе чтения — полоса под карточкой
    /// (`CardProgressBar`). Не начата или дочитана — `nil`: полосы нет.
    func readingProgress(for id: String) -> Double? {
        guard let progress = entries.first(where: { $0.id == id })?.progress,
              ContentProgress.isStarted(progress), progress < 1 else { return nil }
        return progress
    }

    /// Где закрыли читалку — пишется раз, на закрытии, а не на каждом шаге прокрутки.
    func setProgress(_ progress: Double, for id: String) {
        guard let index = entries.firstIndex(where: { $0.id == id }),
              entries[index].progress != progress else { return }
        entries[index].progress = min(max(progress, 0), 1)
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    /// Стартовый набор — книги стартового ряда ПП «Главной» (`RecentlySeeds`): начатое
    /// там и здесь одно и то же. Даты — чуть старше стартовой коллекции.
    private static func seeds(now: Date) -> [Entry] {
        [
            ("wuiaEAAAQBAJ", "Мастер и Маргарита", "Михаил Булгаков", 0.6686, 0.35),
            ("8pCRDwAAQBAJ", "Краткая история времени", "Стивен Хокинг", 0.6602, 0.12),
        ].enumerated().map { index, book in
            Entry(
                book: BookInProgress(
                    id: "gb-\(book.0)",
                    cover: CollectionSeeds.googleBooks(book.0),
                    title: book.1,
                    author: book.2
                ),
                aspect: book.3,
                updatedAt: now.addingTimeInterval(-Double(index + 1) * 30 * 60),
                progress: book.4
            )
        }
    }
}
