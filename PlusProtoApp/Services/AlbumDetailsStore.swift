import Foundation

/// Детали альбома для его экрана — по шаблону `MovieDetailsStore`: экземпляр живёт
/// на экране, разобранные ответы в общем кэше. У Deezer квоты нет (50 запросов
/// за 5 секунд), кэш здесь бережёт не сеть, а повторный разбор и мигание секций
/// при возврате на тот же альбом.
@MainActor
@Observable
final class AlbumDetailsStore {
    private(set) var details: AlbumDetails?
    /// Идёт первая загрузка — экран показывает то, что знает из витрины.
    private(set) var isLoading = false
    /// Что не доехало. Не ошибка экрана: шапка остаётся на данных витрины.
    private(set) var failure: String?

    private static var cache: [Int: AlbumDetails] = [:]
    private var requested: Int?

    /// Один заход на альбом за жизнь экрана.
    func load(_ entity: EntityRef) async {
        guard let id = Self.debugID ?? entity.deezerID, requested != id else { return }
        requested = id

        if let hit = Self.cache[id] {
            details = hit
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            async let albumRequest = DeezerService.shared.album(id: id)
            async let tracksRequest = DeezerService.shared.albumTracks(id: id)
            let (album, tracks) = try await (albumRequest, tracksRequest)

            // Дискография — отдельным запросом по id артиста из ответа альбома.
            // Её отказ не роняет экран: секция «Другие альбомы» просто не появится.
            var otherAlbums: [DeezerAlbumBrief] = []
            if let artistID = album.artist?.id {
                otherAlbums = (try? await DeezerService.shared.artistAlbums(id: artistID)) ?? []
            }

            let parsed = AlbumDetails(album: album, tracks: tracks, otherAlbums: otherAlbums)
            Self.cache[id] = parsed
            details = parsed
            failure = nil
            preloadArtwork(parsed)
        } catch {
            failure = error.localizedDescription
        }
    }

    /// Аватар артиста нужен в первом же кадре шапки, карусель — ниже по скроллу.
    /// Заказываем всё сразу: загрузчик дедуплицирует, а без прогрева карусель въезжает дырами.
    private func preloadArtwork(_ details: AlbumDetails) {
        ArtworkLoader.shared.preload([details.artistPicture] + details.others.map(\.cover))
    }
}

extension AlbumDetailsStore {
    /// `-debugAlbumId <id>` — открыть экран конкретного альбома Deezer, минуя витрину.
    /// Флаг зарегистрирован в `parseDebugLaunchArguments`, как велит HANDOFF §4.
    static var debugID: Int? {
        #if DEBUG
        let id = UserDefaults.standard.integer(forKey: "debugAlbumId")
        return id > 0 ? id : nil
        #else
        return nil
        #endif
    }
}

extension EntityRef {
    /// Числовой id Deezer из id блока витрины: та кладёт туда `dz-<id>`
    /// (см. `ShowcaseCatalog`). `nil` — сущность не из Deezer (моковая лента).
    var deezerID: Int? {
        guard id.hasPrefix("dz-") else { return nil }
        return Int(id.dropFirst(3))
    }
}
