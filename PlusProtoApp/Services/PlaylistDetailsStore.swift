import Foundation

/// Детали плейлиста для его экрана — по шаблону `AlbumDetailsStore`: экземпляр живёт
/// на экране, разобранные ответы в общем кэше. Один запрос — `/playlist/{id}` Deezer
/// отдаёт плейлист вместе с треками и их альбомами.
@MainActor
@Observable
final class PlaylistDetailsStore {
    private(set) var details: PlaylistDetails?
    /// Ответ не пришёл — экран снимает скелетон треклиста и остаётся на данных карточки.
    private(set) var didFail = false

    private static var cache: [Int: PlaylistDetails] = [:]
    private var requested: Int?

    /// Сколько обложек строк прогреть сразу — первый экран треклиста и запас под скролл.
    private static let preloadedRows = 20

    /// Один заход на плейлист за жизнь экрана.
    func load(_ entity: EntityRef) async {
        guard let id = entity.deezerID, requested != id else { return }
        requested = id

        if let hit = Self.cache[id] {
            details = hit
            return
        }

        guard let playlist = try? await DeezerService.shared.playlist(id: id) else {
            didFail = true
            return
        }
        let parsed = PlaylistDetails(playlist: playlist)
        Self.cache[id] = parsed
        details = parsed
        ArtworkLoader.shared.preload(parsed.tracks.prefix(Self.preloadedRows).compactMap(\.thumbnail))
    }
}
