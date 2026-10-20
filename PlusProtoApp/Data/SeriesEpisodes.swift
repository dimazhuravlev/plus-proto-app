import Foundation

// MARK: - Серии сериала

/// Серия сериала — из сезонов Кинопоиска (`/v1.4/season`, `SeriesCatalog`).
struct SeriesEpisode: Codable, Hashable, Identifiable {
    let season: Int
    let number: Int
    /// Название серии. Заглушки Кинопоиска («Episode #2.2») — `nil`: строка тогда
    /// подписана номером («Серия 2»).
    var name: String?
    /// Кадр серии (`get-ott`). Нет — карточка берёт кадр сериала (`SeriesInfo.still`).
    var still: URL?
    /// Хронометраж, секунды: у серий Кинопоиск его не отдаёт — это длина серии
    /// сериала. Нет — ни времени на кадре, ни размера загрузки.
    var runtime: TimeInterval?

    var id: String { "s\(season)e\(number)" }

    /// «Сезон 1, серия 1» — подпись карточки карусели экрана тайтла (`2052:10621`).
    var seasonTitle: String { "Сезон \(season), серия \(number)" }

    /// «1. Заезд» — строки списков серий, как в «Загрузках» Кинопоиска.
    var listTitle: String { "\(number). \(name ?? "Серия \(number)")" }
}

/// Сезон — номер и вышедшие серии по порядку.
struct SeriesSeason: Codable, Hashable, Identifiable {
    let number: Int
    let episodes: [SeriesEpisode]

    var id: Int { number }
}

/// Всё, что знаем о сериях сериала: вышедшие сезоны по порядку.
struct SeriesInfo: Codable, Hashable {
    let seasons: [SeriesSeason]

    var episodes: [SeriesEpisode] { seasons.flatMap(\.episodes) }

    func episode(_ season: Int, _ number: Int) -> SeriesEpisode? {
        seasons.first { $0.number == season }?.episodes.first { $0.number == number }
    }
}

extension SeriesInfo {
    /// Из ответа Кинопоиска: сезоны с номером от первого, серии — только вышедшие
    /// (у «Белого лотоса» в ответе есть анонсированный четвёртый сезон с одной
    /// безымянной серией без даты). Пустые сезоны выпадают.
    init(seasons raw: [KinopoiskSeason], episodeLength: TimeInterval?, now: Date = .now) {
        let dates = ISO8601DateFormatter()
        dates.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        seasons = raw
            .compactMap { season -> SeriesSeason? in
                guard let number = season.number, number > 0 else { return nil }
                let episodes = (season.episodes ?? [])
                    .compactMap { episode -> SeriesEpisode? in
                        guard let index = episode.number, index > 0,
                              let aired = episode.airDate.flatMap(dates.date(from:)), aired <= now else { return nil }
                        let minutes = episode.duration ?? 0
                        return SeriesEpisode(
                            season: number,
                            number: index,
                            name: Self.name(episode),
                            // Кадр серии — тот же пресет, что у кадров `get-ott` тайтла.
                            still: episode.still?.url(size: .frame),
                            runtime: minutes > 0 ? TimeInterval(minutes * 60) : episodeLength
                        )
                    }
                    .sorted { $0.number < $1.number }
                return episodes.isEmpty ? nil : SeriesSeason(number: number, episodes: episodes)
            }
            .sorted { $0.number < $1.number }
    }

    /// Русское название, иначе оригинальное; заглушка «Episode #2.2» — не название.
    private static func name(_ episode: KinopoiskEpisode) -> String? {
        [episode.name, episode.enName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty && $0.range(of: #"^Episode\s*#?\s*\d"#, options: .regularExpression) == nil }
    }
}

// MARK: - Скачанная серия

/// Скачанная серия — запись «Скачанного» внутри записи сериала (`CollectionItem.episodes`).
struct DownloadedEpisode: Codable, Hashable, Identifiable {
    var episode: SeriesEpisode
    /// Кадр, которым серия показана в списках, — её собственный или кадр сериала.
    var still: ArtworkSource?
    var downloadedAt: Date

    var id: String { episode.id }
}

// MARK: - Размер загрузки

/// Размер скачанного — оценка по хронометражу (решение пользователя 2026-10-20):
/// ~10 МБ на минуту. Хронометража нет — нет и размера: придумывать его нечестно.
enum DownloadSize {
    static let megabytesPerMinute: Double = 10

    static func megabytes(_ runtime: TimeInterval?) -> Double? {
        guard let runtime, runtime > 0 else { return nil }
        return runtime / 60 * megabytesPerMinute
    }

    /// «1,24 ГБ», «188,6 МБ» — как в «Загрузках» Кинопоиска.
    static func text(megabytes: Double) -> String {
        if megabytes >= 1000 {
            return format(megabytes / 1000, digits: 2) + " ГБ"
        }
        return format(megabytes, digits: 1) + " МБ"
    }

    static func text(_ runtime: TimeInterval?) -> String? {
        megabytes(runtime).map { text(megabytes: $0) }
    }

    /// Сумма серий — только если размер известен у каждой: частичная сумма соврала бы.
    static func text(episodes: [SeriesEpisode]) -> String? {
        let sizes = episodes.map { megabytes($0.runtime) }
        guard !sizes.isEmpty, sizes.allSatisfy({ $0 != nil }) else { return nil }
        return text(megabytes: sizes.compactMap { $0 }.reduce(0, +))
    }

    private static func format(_ value: Double, digits: Int) -> String {
        value.formatted(.number.precision(.fractionLength(0...digits)).locale(Locale(identifier: "ru_RU")))
    }
}

enum SeriesCopy {
    /// «1 серия», «3 серии», «8 серий»
    static func episodes(_ count: Int) -> String {
        "\(count) \(CollectionCopy.plural(count, one: "серия", few: "серии", many: "серий"))"
    }
}
