import Foundation

/// «Смотреть дальше» — фильмы, которые реально запускали в киноплеере (задача
/// пользователя 2026-10-04, главная Кинопоиска). Пишется из единственного входа
/// киноплеера — `ActionBarState.watch`, позиция — на его закрытии. Лежит на диске:
/// история переживает перезапуск, как и сам бар.
///
/// Свежие — первыми. Повторный запуск поднимает фильм наверх и продолжает его
/// с сохранённой позиции; досмотренные из карусели уходят.
@Observable
final class WatchHistory {
    struct Entry: Codable, Equatable, Identifiable {
        var movie: MovieInProgress
        var updatedAt: Date

        var id: String { movie.id }

        /// Доля просмотренного, 0…1. `nil` — хронометража нет или фильм не начинали:
        /// полосы прогресса тогда нет, как у нетронутой карточки макета.
        var progress: Double? {
            guard let runtime = movie.runtime, runtime > 0,
                  let position = movie.position, position > 0 else { return nil }
            return min(1, position / runtime)
        }

        /// Сколько осталось, секунды. Не начинали — весь хронометраж.
        var remaining: TimeInterval? {
            guard let runtime = movie.runtime, runtime > 0 else { return nil }
            return max(0, runtime - (movie.position ?? 0))
        }

        /// Досмотрен — дальше смотреть нечего.
        var isFinished: Bool {
            guard let remaining else { return false }
            return remaining <= WatchHistory.finishedTail
        }
    }

    private(set) var entries: [Entry] = [] {
        didSet { persist() }
    }

    /// Что показывает карусель: всё, что не досмотрено.
    var continuing: [Entry] {
        entries.filter { !$0.isFinished }
    }

    /// Больше карусели не нужно, а хвост истории ничего не стоит потерять.
    private static let limit = 20
    /// Последняя минута — титры: фильм считается досмотренным.
    fileprivate static let finishedTail: TimeInterval = 60
    private static let storageKey = "watchHistory"

    init() {
        #if DEBUG
        // `-debugResetWatchHistory 1` — начать с пустой «Смотреть дальше».
        if UserDefaults.standard.bool(forKey: "debugResetWatchHistory") {
            UserDefaults.standard.removeObject(forKey: Self.storageKey)
        }
        #endif
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let saved = try? JSONDecoder().decode([Entry].self, from: data) else { return }
        entries = saved
    }

    /// Фильм запустили. Уже был — поднимается наверх; позиция, хронометраж, подпись
    /// и постер остаются от прошлого запуска, если новый их не знает (чип бара и витрина
    /// приходят без них).
    /// Постер записи — без смены порядка и даты: дозаполнение старых записей.
    func setPoster(_ poster: ArtworkSource, for id: String) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].movie.poster = poster
    }

    /// Карточке «Продолжить» промо «Главной» нужен постер, а записи, сделанные до того,
    /// как его стали сохранять (задача 69), хранят только кадр. Дозаполняем из дискового
    /// пула Кинопоиска (детали фильма туда легли, когда открывали экран тайтла) — под
    /// заставкой, до первого кадра витрины. Деталей нет — карточка остаётся с кадром.
    func backfillContinuingPoster() async {
        guard let movie = continuing.first?.movie, movie.poster == nil else { return }
        // Мок «Идеальные дни» (лента без сети): его ассет и есть постер.
        if movie.id == "perfect-days" {
            setPoster(.asset("mockMoviePoster"), for: movie.id)
            return
        }
        guard movie.id.hasPrefix("kp-"), let kp = Int(movie.id.dropFirst(3)) else { return }
        // Сперва пул; нет в пуле (фильм открывали не с витрины) — один запрос карточки:
        // постер записывается в историю и больше не запрашивается (правка пользователя
        // 2026-10-14: в «Продолжить» — постер, а не кадр).
        var details = await MoviePool.shared.details(id: kp)
        if details == nil { details = try? await KinopoiskService.shared.movie(id: kp) }
        guard let raw = details?.poster?.url(size: .medium) else { return }
        let url = TMDBImageProxy.rewrite(raw, width: 600) ?? raw
        setPoster(.remote(url), for: movie.id)
    }

    func record(_ movie: MovieInProgress) {
        var movie = movie
        if let index = entries.firstIndex(where: { $0.id == movie.id }) {
            let previous = entries.remove(at: index).movie
            // Другая серия сериала начинается с начала: позиция прежней ей не своя.
            if movie.position == nil, movie.isSameEpisode(as: previous) { movie.position = previous.position }
            if movie.runtime == nil { movie.runtime = previous.runtime }
            if movie.subtitle == nil { movie.subtitle = previous.subtitle }
            if movie.poster == nil { movie.poster = previous.poster }
            if movie.season == nil { movie.season = previous.season }
            if movie.episode == nil { movie.episode = previous.episode }
        }
        entries.insert(Entry(movie: movie, updatedAt: .now), at: 0)
        if entries.count > Self.limit {
            entries.removeLast(entries.count - Self.limit)
        }
    }

    /// Плеер закрыли на этой позиции. Хронометраж — тот, по которому шёл его таймлайн:
    /// без своего у фильма плеер берёт число макета, и карточка «Смотреть дальше»
    /// обязана показать ту же полосу, что плеер (правка пользователя 2026-10-04: прежде
    /// у такого фильма полосы на карточке не было вовсе).
    func update(id: String, position: TimeInterval, runtime: TimeInterval? = nil) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].movie.position = position
        if let runtime, runtime > 0 { entries[index].movie.runtime = runtime }
        entries[index].updatedAt = .now
    }

    /// Хронометраж, по которому фильм уже шёл, — следующий запуск продолжит по нему же.
    func runtime(for id: String) -> TimeInterval? {
        entries.first { $0.id == id }?.movie.runtime
    }

    /// Где остановились в прошлый раз — продолжить с этого места.
    func position(for id: String) -> TimeInterval? {
        entries.first { $0.id == id }?.movie.position
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}
