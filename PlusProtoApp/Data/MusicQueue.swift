import Foundation

/// Трек очереди «Что дальше» в полноэкранном плеере музыки.
struct MusicQueueItem: Identifiable, Equatable {
    let id: String
    let title: String
    let artist: String
    let cover: ArtworkSource
    /// Бейдж 18+ рядом с названием.
    var isExplicit = false
    /// Значок «скачан» у ручки перетаскивания.
    var isDownloaded = false

    var nowPlaying: MusicNowPlaying {
        MusicNowPlaying(id: id, cover: cover, title: title, artist: artist, isExplicit: isExplicit)
    }
}

/// Очередь — моковая, ровно макет `6105:61569`: у Deezer нет «что дальше» для трека,
/// а собирать её из чужих альбомов значило бы выдумывать рекомендации. Живым остаётся
/// сам играющий трек; «Дальше» и дизлайк переключают на следующий трек отсюда.
enum MusicQueue {
    static let items: [MusicQueueItem] = [
        MusicQueueItem(id: "queue-karma-police", title: "Karma Police", artist: "New Order", cover: .asset("mockQueue1")),
        MusicQueueItem(id: "queue-how-do-you", title: "How Do You?", artist: "Shellac", cover: .asset("mockQueue2"), isExplicit: true),
        MusicQueueItem(id: "queue-drone", title: "Drone", artist: "Chastity Belt", cover: .asset("mockQueue3"), isDownloaded: true),
        MusicQueueItem(id: "queue-joe-le-taxi", title: "Joe le Taxi", artist: "The Buggles", cover: .asset("mockQueue4")),
        MusicQueueItem(id: "queue-circulars", title: "Circulars", artist: "Still Corners", cover: .asset("mockQueue5")),
    ]

    /// Обложка предыдущего трека — левая соседка в карусели паузы.
    static let previousCover: ArtworkSource = .asset("mockPrevCover")

    /// Что играет после трека `id`: если он сам из очереди — следующие за ним по кругу,
    /// иначе очередь целиком. Список не растёт и не пустеет — у мока нет конца.
    static func upcoming(after id: String?) -> [MusicQueueItem] {
        guard let id, let index = items.firstIndex(where: { $0.id == id }) else { return items }
        let tail = items[(index + 1)...]
        let head = items[..<index]
        return Array(tail + head)
    }
}
