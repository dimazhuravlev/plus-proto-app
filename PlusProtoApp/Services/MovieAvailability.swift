import Foundation
import Observation

/// Можно ли посмотреть тайтл в Кинопоиске — чипс «Можно посмотреть» полного списка
/// «Буду смотреть» (задача пользователя 2026-10-22). Правда — площадки тайтла
/// у Кинопоиска (`watchability`): в списке есть Kinopoisk HD — можно.
///
/// Один запрос на пачку тайтлов, которых ещё не знаем; ответ ложится на диск
/// (`Caches/movie-availability.json`) и больше не спрашивается — квота 200 в сутки.
/// Ключей нет или сеть упала — про тайтл не знаем, в «Можно посмотреть» его нет.
@MainActor
@Observable
final class MovieAvailability {
    static let shared = MovieAvailability()

    /// По id Кинопоиска
    private(set) var known: [Int: Bool] = [:]

    @ObservationIgnored private let fileURL: URL
    @ObservationIgnored private var inFlight: Set<Int> = []

    private static let platform = "Kinopoisk HD"

    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        fileURL = caches.appendingPathComponent("movie-availability.json")
        if let data = try? Data(contentsOf: fileURL),
           let saved = try? JSONDecoder().decode([String: Bool].self, from: data) {
            for (key, value) in saved {
                if let id = Int(key) { known[id] = value }
            }
        }
    }

    func isAvailable(_ id: Int) -> Bool {
        known[id] ?? false
    }

    /// Узнать про тайтлы, которых ещё не знаем, — одним запросом.
    func load(_ ids: [Int]) async {
        let missing = Array(Set(ids).subtracting(known.keys).subtracting(inFlight))
        guard !missing.isEmpty, APIKeysCheck.isKinopoiskConfigured else { return }
        inFlight.formUnion(missing)
        defer { inFlight.subtract(missing) }
        guard let platforms = try? await KinopoiskService.shared.watchability(ids: missing) else { return }
        for id in missing {
            known[id] = platforms[id]?.contains(Self.platform) ?? false
        }
        save()
    }

    private func save() {
        let snapshot = Dictionary(uniqueKeysWithValues: known.map { ("\($0.key)", $0.value) })
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
