import Foundation

/// «Искали недавно» — карусель нулевого состояния поиска (макет `2118:17378`, задача
/// пользователя 2026-10-03): одна лента вперемешку — музыка, кино, книги.
///
/// **Найденное — то, во что перешли из выдачи** (определение пользователя): карточка
/// карусели, строка полного списка, альбом колдунщика; трек, включённый из полного
/// списка, — тоже, это тот же выбор из выдачи. Что выдача просто показала, сюда
/// не попадает. Свежее — первым, повтор поднимается в начало.
///
/// Стартового набора больше нет (задача пользователя 2026-10-30): пока не найдено ничего —
/// и с первого запуска, и после «Удалить историю» — на месте ленты пустое нулевое
/// состояние, три карусели рекомендаций (`SearchDiscovery`). Найденное хранится
/// локально (`UserDefaults`).
enum SearchRecents {
    /// Сколько найденного храним — весь полный список истории.
    static let limit = 20
    /// Сколько карточек в ленте нулевого состояния; остальное — в полном списке
    /// (правка пользователя 2026-10-03).
    static let carouselLimit = 12

    private static let storageKey = "searchRecents.v1"

    /// Найденное с диска, свежее первым. Битые данные — пустая история, а не падение.
    static func load() -> [SearchHit] {
        #if DEBUG
        // `-debugResetSearchRecents 1` — начать с пустой истории: на экране поиска —
        // пустое нулевое состояние (`SearchDiscovery`).
        if UserDefaults.standard.bool(forKey: "debugResetSearchRecents") {
            UserDefaults.standard.removeObject(forKey: storageKey)
            return []
        }
        // `-debugRestoreSearchRecents <hex>` — вернуть историю, снятую до прогона с
        // `-debugResetSearchRecents` (байты ключа `searchRecents.v1` в hex). Только изнутри
        // приложения: запись в его plist снаружи (`defaults write <путь>`) сервис настроек
        // не видит и перезаписывает файл своей копией (2026-10-30).
        if let hex = UserDefaults.standard.string(forKey: "debugRestoreSearchRecents"),
           let restored = Data(hex: hex) {
            UserDefaults.standard.set(restored, forKey: storageKey)
        }
        #endif
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return [] }
        let saved = (try? JSONDecoder().decode([SearchHit].self, from: data)) ?? []
        return saved.map(repairingPlaylist)
    }

    /// Плейлист, найденный до экрана плейлиста (2026-10-05), — с переходом на него:
    /// иначе в истории он так и остался бы ненажимаемым.
    private static func repairingPlaylist(_ hit: SearchHit) -> SearchHit {
        guard hit.kind == .playlist, hit.route == nil,
              hit.id.hasPrefix("playlist-"), let id = Int(hit.id.dropFirst("playlist-".count))
        else { return hit }
        return SearchHit(
            id: hit.id,
            kind: hit.kind,
            title: hit.title,
            subtitle: hit.subtitle,
            artwork: hit.artwork,
            route: .playlist(EntityRef(
                id: "dz-\(id)",
                title: hit.title,
                subtitle: hit.subtitle,
                artwork: hit.artwork ?? .asset("")
            )),
            authority: hit.authority,
            artworkAspect: hit.artworkAspect,
            altTitle: hit.altTitle
        )
    }

    static func save(_ hits: [SearchHit]) {
        guard let data = try? JSONEncoder().encode(hits) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}

#if DEBUG
private extension Data {
    /// Байты из hex-строки (`-debugRestoreSearchRecents`); нечётная длина или не hex — `nil`.
    init?(hex: String) {
        let chars = Array(hex.utf8)
        guard chars.count.isMultiple(of: 2) else { return nil }
        var bytes: [UInt8] = []
        bytes.reserveCapacity(chars.count / 2)
        var index = 0
        while index < chars.count {
            guard let byte = UInt8(String(decoding: chars[index..<index + 2], as: UTF8.self), radix: 16) else { return nil }
            bytes.append(byte)
            index += 2
        }
        self.init(bytes)
    }
}
#endif
