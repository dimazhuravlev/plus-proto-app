import SwiftUI

/// «Смотреть» тайтла — общее у экрана тайтла и строки таба «Кино» выдачи поиска
/// (задача пользователя 2026-10-31): что положить в киноплеер и в чип бара.
///
/// Чипу нужен **горизонтальный** кадр, а не постер: кадр тайтла, и только если его нет —
/// обложка, с которой пришли. Шапке и таймлайну плеера — год с жанром и хронометраж.
/// Сериал — с серии, на которой остановились, иначе с первой.
@MainActor
enum MovieWatch {
    static func item(_ entity: EntityRef, details: MovieDetails, history: WatchHistory) -> MovieInProgress {
        if let current = currentEpisode(of: entity, details: details, history: history) {
            return .playing(current.episode, of: entity, details: details, still: current.still)
        }
        return MovieInProgress(
            id: entity.id,
            still: details.backdrop.map { ArtworkSource.remote($0) } ?? entity.artwork,
            title: details.title,
            subtitle: details.playerSubtitle,
            runtime: details.runtime,
            // Постер — карточке «Продолжить» промо «Главной» (задача 69): крупный, как
            // у обложки экрана, — карточка 210 pt, малый постер на ней мылится.
            poster: (details.coverPoster ?? details.poster).map { ArtworkSource.remote($0) }
        )
    }

    /// «Смотреть» сериала — серия, на которой остановились, иначе первая.
    static func currentEpisode(of entity: EntityRef, details: MovieDetails, history: WatchHistory) -> EpisodeWithStill? {
        guard details.isSeries else { return nil }
        let info = SeriesCatalog.shared.info(details.id)
        let watched = history.entries.first { $0.id == entity.id }?.movie
        let season = watched?.season ?? 1
        let number = watched?.episode ?? 1
        let episode = info?.episode(season, number)
            ?? (season == 1 && number == 1 ? info?.episodes.first : nil)
            ?? SeriesEpisode(season: season, number: number, runtime: details.episodeLength)
        return withStill(episode, details: details)
    }

    /// Серия с кадром той же раздачи, что в карусели «Сезонов и Эпизодов».
    static func withStill(_ episode: SeriesEpisode, details: MovieDetails) -> EpisodeWithStill {
        let episodes = SeriesCatalog.shared.info(details.id)?.episodes ?? [episode]
        let stills = SeriesStills.assign(episodes, titleStills: details.stills, seed: details.id)
        return EpisodeWithStill(episode: episode, still: stills[episode.id].map { ArtworkSource.remote($0) })
    }

    /// «Смотреть» строки выдачи: детали — без сети (`offlineDetails`), их нет — то, что
    /// знает строка: постер вместо кадра, год вместо жанра.
    static func start(_ hit: SearchHit, actionBar: ActionBarState) async {
        guard case .movie(let entity)? = hit.route else { return }
        let item: MovieInProgress
        if let details = await MovieDetailsStore.offlineDetails(entity) {
            item = Self.item(entity, details: details, history: actionBar.watchHistory)
        } else {
            item = MovieInProgress(
                id: entity.id,
                still: hit.artwork ?? entity.artwork,
                title: hit.title,
                subtitle: hit.subtitle.isEmpty ? nil : hit.subtitle,
                poster: hit.artwork
            )
        }
        actionBar.open(.movie(item))
    }
}
