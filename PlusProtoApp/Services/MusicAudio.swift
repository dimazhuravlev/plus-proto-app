import AVFoundation
import Foundation

/// Звук плеера музыки — 30-секундные превью Deezer (задача пользователя 2026-10-05).
/// Играет ровно тогда, когда плеер в баре «играет»: `ActionBarState` сообщает сюда
/// каждый поворот транспорта — запуск трека, паузу, перемотку. Пока превью играет,
/// прогресс плеера идёт за ним (`tickerFraction`); превью нет (сеть, трек не нашёлся) —
/// прогресс идёт по моку, как без звука.
///
/// Громкость — в дебаг-меню профиля, по умолчанию 50 % (`volumeKey`).
@MainActor
final class MusicAudio {
    static let shared = MusicAudio()

    static let volumeKey = "musicVolume"
    static let defaultVolume = 0.5
    static var storedVolume: Double {
        UserDefaults.standard.object(forKey: volumeKey) as? Double ?? defaultVolume
    }

    private enum Readiness {
        case idle
        case loading(since: Date)
        case ready
        case unavailable
    }

    /// Сколько прогресс ждёт превью, прежде чем пойти по моку: на старте трека полоса
    /// стоит, а не уезжает вперёд, чтобы потом отпрыгнуть к началу звука.
    private static let loadHold: TimeInterval = 3
    /// Сколько живёт найденная ссылка на превью: она подписана и протухает.
    private static let previewLifetime: TimeInterval = 10 * 60

    private let player = AVPlayer()
    private var readiness = Readiness.idle
    private var trackID: String?
    private var wantsPlaying = false
    /// Куда встать, когда превью загрузится: доля трека, на которой стоит прогресс.
    private var pendingFraction: Double = 0
    private var didRetryFresh = false
    private var resolving: Task<Void, Never>?
    private var statusObservation: NSKeyValueObservation?
    private var previews: [String: (url: URL, found: Date)] = [:]

    private init() {
        player.volume = Float(Self.storedVolume)
        // Конец превью — снова с начала: прогресс плеера у мока тоже идёт по кругу.
        player.actionAtItemEnd = .none
        NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let item = note.object as? AVPlayerItem
            MainActor.assumeIsolated { self?.itemDidEnd(item) }
        }
    }

    func setVolume(_ volume: Double) {
        player.volume = Float(volume)
    }

    /// Доля трека по звуку, 0…1; `nil` — превью не играет, прогресс идёт по моку.
    var tickerFraction: Double? {
        guard case .ready = readiness, let item = player.currentItem else { return nil }
        let duration = item.duration.seconds
        guard duration.isFinite, duration > 0 else { return nil }
        return min(max(player.currentTime().seconds / duration, 0), 1)
    }

    /// Превью в пути — прогресс стоит (не дольше `loadHold`).
    var isAwaitingAudio: Bool {
        guard case .loading(let since) = readiness else { return false }
        return Date().timeIntervalSince(since) < Self.loadHold
    }

    /// Трек в плеере: новый — найти превью и встать на долю `fraction`, тот же —
    /// только играть или стоять.
    func play(_ music: MusicNowPlaying, from fraction: Double, isPlaying: Bool) {
        wantsPlaying = isPlaying
        guard music.id != trackID else {
            applyPlayback()
            return
        }
        trackID = music.id
        pendingFraction = fraction
        didRetryFresh = false
        load(music, fresh: false)
    }

    func setPlaying(_ isPlaying: Bool) {
        wantsPlaying = isPlaying
        applyPlayback()
    }

    /// Перемотка таймлайном и «назад» — доля трека.
    func seek(to fraction: Double) {
        pendingFraction = fraction
        guard case .ready = readiness, let item = player.currentItem else { return }
        let duration = item.duration.seconds
        guard duration.isFinite, duration > 0 else { return }
        player.seek(
            to: CMTime(seconds: fraction * duration, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
    }

    // MARK: - Загрузка

    private func load(_ music: MusicNowPlaying, fresh: Bool) {
        resolving?.cancel()
        statusObservation = nil
        player.pause()
        player.replaceCurrentItem(with: nil)
        readiness = .loading(since: Date())
        resolving = Task {
            guard let url = await previewURL(for: music, fresh: fresh) else {
                if !Task.isCancelled, trackID == music.id { readiness = .unavailable }
                return
            }
            guard !Task.isCancelled, trackID == music.id else { return }
            let item = AVPlayerItem(url: url)
            statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
                Task { @MainActor in self?.statusChanged(item, music: music) }
            }
            player.replaceCurrentItem(with: item)
        }
    }

    private func statusChanged(_ item: AVPlayerItem, music: MusicNowPlaying) {
        guard item === player.currentItem else { return }
        switch item.status {
        case .readyToPlay:
            guard case .loading = readiness else { return }
            readiness = .ready
            seek(to: pendingFraction)
            applyPlayback()
        case .failed:
            // Скорее всего, протухла ссылка: один раз — за свежей, дальше без звука.
            previews[music.id] = nil
            if didRetryFresh {
                readiness = .unavailable
            } else {
                didRetryFresh = true
                load(music, fresh: true)
            }
        default:
            break
        }
    }

    private func applyPlayback() {
        if wantsPlaying, case .ready = readiness {
            AppAudioSession.useForMusic()
            player.play()
        } else {
            player.pause()
        }
    }

    private func itemDidEnd(_ item: AVPlayerItem?) {
        guard let item, item === player.currentItem else { return }
        player.seek(to: .zero)
        if wantsPlaying { player.play() }
    }

    // MARK: - Превью

    private func previewURL(for music: MusicNowPlaying, fresh: Bool) async -> URL? {
        if !fresh, let cached = previews[music.id],
           Date().timeIntervalSince(cached.found) < Self.previewLifetime {
            return cached.url
        }
        guard let url = await Self.findPreview(for: music) else { return nil }
        previews[music.id] = (url, Date())
        return url
    }

    private nonisolated static func findPreview(for music: MusicNowPlaying) async -> URL? {
        if let id = deezerTrackID(in: music.id),
           let track = try? await DeezerService.shared.freshTrack(id: id),
           let url = track.preview.flatMap(URL.init(string:)) {
            return url
        }
        // Трека в id нет — альбом с витрины, моковая очередь, «Моя Волна»: ищем
        // по исполнителю с названием, потом по одному названию.
        for query in ["\(music.artist) \(music.title)", music.title] {
            guard let hits = try? await DeezerService.shared.freshSearchTracks(query: query) else { continue }
            let byArtist = hits.first { hit in
                hit.artist?.name.localizedCaseInsensitiveCompare(music.artist) == .orderedSame
            }
            if let url = (byArtist ?? hits.first)?.preview.flatMap(URL.init(string:)) {
                return url
            }
        }
        return nil
    }

    /// Трек Deezer в id плеера: `dz-<альбом>-t<трек>` (альбом, плейлист),
    /// `dz-track-<трек>` (исполнитель), `track-<трек>` (поиск).
    nonisolated static func deezerTrackID(in id: String) -> Int? {
        guard let match = id.firstMatch(of: #/(?:-t|track-)(\d+)$/#) else { return nil }
        return Int(match.1)
    }
}

/// Категория аудиосессии — одна на приложение. Беззвучным клипам — `.ambient`: иначе
/// их старт обрывал бы музыку у пользователя. Своей музыке — `.playback`, как у любого
/// плеера: звук не гаснет от бесшумного режима. После первого включения музыки
/// категория остаётся `.playback`, и клипы её уже не перебивают.
enum AppAudioSession {
    private static var isAmbientSet = false
    private static var isPlaybackSet = false

    static func useAmbientForSilentVideo() {
        guard !isAmbientSet, !isPlaybackSet else { return }
        isAmbientSet = true
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
    }

    static func useForMusic() {
        guard !isPlaybackSet else { return }
        isPlaybackSet = true
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback)
        try? session.setActive(true)
    }
}
