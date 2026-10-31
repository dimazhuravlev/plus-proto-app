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
    /// Запросы в пути — по id тайтла: второй заход за тем же тайтлом ждёт первый,
    /// а не отвечает «не знаем» (табы выдачи поиска ждут ответа перед показом списка).
    @ObservationIgnored private var inFlight: [Int: Task<Void, Never>] = [:]

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

    /// Фильм точно нельзя смотреть: Кинопоиск ответил, и Kinopoisk HD среди площадок нет.
    /// Не знаем (ключей нет, квота кончилась, не спрашивали) — можно: кнопки «Смотреть»
    /// в демо не пропадают из-за квоты (решение пользователя 2026-10-31). Сериалы
    /// смотреть можно всегда — ограничение только у фильмов (там же), это решает вызывающий.
    func isKnownUnavailable(_ id: Int) -> Bool {
        known[id] == false
    }

    /// Узнать про тайтлы, которых ещё не знаем, — одним запросом; те, о которых уже
    /// спрашивают, — дождаться.
    func load(_ ids: [Int]) async {
        let unknown = Set(ids).subtracting(known.keys)
        var waiting = Set(unknown.compactMap { inFlight[$0] })
        let missing = unknown.filter { inFlight[$0] == nil }
        if !missing.isEmpty, APIKeysCheck.isKinopoiskConfigured {
            let ids = Array(missing)
            let request = Task { await self.fetch(ids) }
            for id in ids { inFlight[id] = request }
            waiting.insert(request)
        }
        for request in waiting { await request.value }
    }

    private func fetch(_ ids: [Int]) async {
        defer { for id in ids { inFlight[id] = nil } }
        guard let platforms = try? await KinopoiskService.shared.watchability(ids: ids) else { return }
        for id in ids {
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
