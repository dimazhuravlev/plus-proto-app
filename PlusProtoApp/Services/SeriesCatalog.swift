import Foundation
import Observation

/// Сезоны и серии сериалов — карусель «Сезоны и Эпизоды» экрана тайтла, экран всех
/// серий и загрузка серий (2026-10-20).
///
/// Квота Кинопоиска — 200 запросов в сутки на ключ, поэтому сериал стоит один запрос
/// за всё время жизни приложения: ответ ложится на диск (`Caches/series-seasons.json`)
/// и больше не спрашивается. Второй запрос — длина серии — только у сериалов, которым
/// её не знают детали (лежат в пуле с тех пор, как поле не запрашивали).
///
/// Ключей нет или квота кончилась — серий нет: моков серий не заводим, карусель
/// и экран серий тогда не показываются (нет данных — нет элемента).
@MainActor
@Observable
final class SeriesCatalog {
    static let shared = SeriesCatalog()

    enum Status: Equatable {
        case loading
        case loaded(SeriesInfo)
        case failed
    }

    /// По id Кинопоиска
    private(set) var statuses: [Int: Status] = [:]

    @ObservationIgnored private let fileURL: URL
    @ObservationIgnored private var tasks: [Int: Task<Void, Never>] = [:]

    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        fileURL = caches.appendingPathComponent("series-seasons.json")
        if let data = try? Data(contentsOf: fileURL),
           let saved = try? JSONDecoder().decode([String: SeriesInfo].self, from: data) {
            for (key, info) in saved {
                if let id = Int(key) { statuses[id] = .loaded(info) }
            }
        }
    }

    func status(_ id: Int) -> Status? {
        statuses[id]
    }

    func info(_ id: Int) -> SeriesInfo? {
        if case .loaded(let info) = statuses[id] { return info }
        return nil
    }

    /// Сезоны сериала: с диска сразу, иначе один запрос. Повторный вызов, пока запрос
    /// в пути, ждёт его же. Ошибка не запоминается на диск: на следующем запуске
    /// попробуем снова.
    func load(_ id: Int, episodeLength: TimeInterval?) async {
        if case .loaded = statuses[id] { return }
        if let task = tasks[id] {
            await task.value
            return
        }
        guard APIKeysCheck.isKinopoiskConfigured else {
            statuses[id] = .failed
            return
        }
        statuses[id] = .loading
        let task = Task { @MainActor in
            do {
                async let seasons = KinopoiskService.shared.seasons(movieID: id)
                var length = episodeLength
                if length == nil {
                    let minutes = try? await KinopoiskService.shared.seriesLength(id: id)
                    length = minutes.flatMap { $0 > 0 ? TimeInterval($0 * 60) : nil }
                }
                let info = SeriesInfo(seasons: try await seasons, episodeLength: length)
                statuses[id] = info.seasons.isEmpty ? .failed : .loaded(info)
                if !info.seasons.isEmpty { save() }
            } catch {
                statuses[id] = .failed
            }
            tasks[id] = nil
        }
        tasks[id] = task
        await task.value
    }

    private func save() {
        var snapshot: [String: SeriesInfo] = [:]
        for (id, status) in statuses {
            if case .loaded(let info) = status { snapshot["\(id)"] = info }
        }
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
