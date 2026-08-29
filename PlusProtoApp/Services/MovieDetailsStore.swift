import Foundation

/// Детали тайтла для карточки фильма.
///
/// Экземпляр живёт на экране, а разобранные ответы лежат в общем кэше: квота
/// Кинопоиска — 200 запросов в сутки, а на карточку одного и того же тайтла
/// возвращаются по нескольку раз за сессию. `URLCache` сессии сервиса закрывает сеть,
/// этот кэш закрывает ещё и разбор.
@MainActor
@Observable
final class MovieDetailsStore {
    private(set) var details: MovieDetails?
    /// Идёт первая загрузка — экран показывает то, что знает из витрины.
    private(set) var isLoading = false
    /// Что не доехало. Не ошибка экрана: карточка остаётся на данных витрины.
    private(set) var failure: String?

    private static var cache: [Int: MovieDetails] = [:]
    private var requested: Int?

    /// Один заход на тайтл за жизнь экрана.
    func load(_ entity: EntityRef) async {
        guard let id = Self.debugID ?? entity.kinopoiskID, requested != id else { return }
        requested = id

        if let hit = Self.cache[id] {
            details = hit
            return
        }

        // Запас витрины приносит и содержимое карточки: тем же запросом, которым
        // набирается пул, приезжают состав, похожие и ролики (см. `KinopoiskService.movieFields`).
        // Поэтому открытие карточки фильма с витрины не стоит ни одного запроса из квоты,
        // а сеть остаётся только тайтлам не из запаса — то есть `-debugMovieId`.
        if let pooled = await MoviePool.shared.details(id: id) {
            let parsed = MovieDetails(movie: pooled, stills: await stills(for: id, pooled: true))
            Self.cache[id] = parsed
            details = parsed
            failure = nil
            preloadArtwork(parsed)
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let parsed = MovieDetails(
                movie: try await KinopoiskService.shared.movie(id: id),
                stills: await stills(for: id, pooled: false)
            )
            Self.cache[id] = parsed
            details = parsed
            failure = nil
            preloadArtwork(parsed)
        } catch {
            failure = error.localizedDescription
        }
    }

    /// Кадры сцен для кавера и видеокарточек. Из запаса, если там есть; иначе —
    /// добираются отдельным запросом: экран похожего фильма обязан наполняться так же,
    /// как витринный (правка пользователя 2026-08-25 — раньше кадры были только у
    /// тайтлов из запаса, и карточки похожих жили на забандленном ролике).
    ///
    /// Цена — один запрос на впервые открытый тайтл без кадров; повторные открытия
    /// закрывает URLCache сервиса, а разобранный результат — кэш этого стора.
    /// Тайтлу из запаса найденное возвращается в пул (с его же правилами отбора):
    /// пригодится витрине, и переспрашивать не придётся. Чужие тайтлы в пул не пишем —
    /// его файл чистится только по списку своих фильмов, осиротевшие кадры копились бы
    /// вечно. Правила отбора общие — `MoviePool.pickStills`.
    private func stills(for id: Int, pooled: Bool) async -> [KinopoiskStill] {
        let stored = await MoviePool.shared.stills(for: id)
        if !stored.isEmpty { return stored }
        guard let fetched = try? await KinopoiskService.shared.stills(movieIDs: [id], limit: 40) else {
            return []
        }
        if pooled {
            await MoviePool.shared.store(stills: fetched, asked: [id])
            return await MoviePool.shared.stills(for: id)
        }
        return MoviePool.pickStills(fetched)
    }

    /// Кадр и логотип нужны в первом же кадре экрана, актёры и похожее — ниже по скроллу.
    /// Заказываем всё сразу: загрузчик дедуплицирует, а без прогрева карусели въезжают дырами.
    private func preloadArtwork(_ details: MovieDetails) {
        let urls = [details.backdrop, details.logo, details.trailer?.poster].compactMap { $0 }
            + details.cast.compactMap(\.photo)
            + details.crew.compactMap(\.photo)
            + details.similar.compactMap(\.poster)
        ArtworkLoader.shared.preload(urls.map { .remote($0) })
    }
}

extension MovieDetailsStore {
    /// `-debugMovieId <id>` — открыть карточку конкретного тайтла Кинопоиска.
    ///
    /// Отладочный тап по витрине срабатывает раньше, чем доезжают живые блоки, и уводит
    /// на моковый тайтл — проверить карточку на настоящих данных иначе нечем. Заодно это
    /// единственный способ посмотреть тайтл с логотипом: у российских релизов его нет.
    /// Значение читается прямо из аргументов запуска, регистрировать флаг не нужно —
    /// так же устроен `-debugScrollTo`.
    static var debugID: Int? {
        #if DEBUG
        let id = UserDefaults.standard.integer(forKey: "debugMovieId")
        return id > 0 ? id : nil
        #else
        return nil
        #endif
    }
}

extension EntityRef {
    /// Числовой id Кинопоиска из id блока витрины. Витрина кладёт туда `kp-<id>`
    /// («посмотреть») или `kp-w-<id>` («продолжить смотреть») — см. `ShowcaseCatalog`.
    /// `nil` — сущность не из Кинопоиска (моковая лента, книга, альбом).
    var kinopoiskID: Int? {
        let tail = id
            .replacingOccurrences(of: "kp-w-", with: "")
            .replacingOccurrences(of: "kp-", with: "")
        return Int(tail)
    }
}
