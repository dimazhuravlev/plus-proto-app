import SwiftUI
import UIKit

/// Экран плейлиста — точь-в-точь экран альбома (задача пользователя 2026-10-05): та же
/// резиновая шапка с кавером, название, ряд «Слушать» и отметок коллекции, тот же
/// навбар. Отличий два:
/// - блока исполнителя нет — треки плейлиста от разных исполнителей;
/// - треклист — строками с обложкой альбома каждого трека (`EntityTrackRow`, она
///   и нарисована по макету открытого плейлиста), а не номерами.
///
/// Данные — `/playlist/{id}` Deezer (`PlaylistDetailsStore`); пока ответ едет, шапка
/// стоит на данных карточки, треклист — скелетоном. Сюда ведут все плейлисты
/// приложения: выдача поиска, история, коллекция.
struct PlaylistScreen: View {
    let entity: EntityRef

    @Environment(ActionBarState.self) private var actionBar
    @State private var store = PlaylistDetailsStore()
    @State private var scrollOffset: CGFloat = 0

    /// Строк скелетона, пока едет треклист, — первый экран.
    private static let skeletonRows = 8

    private var details: PlaylistDetails {
        store.details ?? .placeholder(for: entity)
    }

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    trackList
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .task { await store.load(entity) }
            .scrollIndicators(.hidden)
            // Хром на этом экране виден — лента едет под ним, как у альбома.
            .contentMargins(
                .bottom,
                PlusChromeMetrics.contentBottomInset + AlbumLayout.bottomClearance,
                for: .scrollContent
            )
            // Зона кавера начинается от физического верха экрана, а не от safe area.
            .ignoresSafeArea(edges: .top)
            .trackNavBarScroll(into: $scrollOffset)

            EntityNavBar(
                title: details.title,
                artwork: entity.artwork,
                scrollOffset: scrollOffset,
                thresholds: AlbumLayout.navBarThresholds
            )
        }
        .background(Color.black.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        #if DEBUG
        // `-debugTapPlay` — нажать «Слушать», как на альбоме.
        .task {
            guard UserDefaults.standard.bool(forKey: "debugTapPlay") else { return }
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            togglePlayback()
        }
        #endif
    }

    // MARK: Шапка

    /// Шапка — общая с альбомом и книгой (`EntityHeader`), только без строки исполнителя.
    private var header: some View {
        EntityHeader(
            artwork: entity.artwork,
            coverSize: CGSize(width: AlbumLayout.coverSize, height: AlbumLayout.coverSize),
            scrollOffset: scrollOffset,
            title: details.title,
            collectionItem: collectionItem
        ) {
            cover
        } person: {
            EmptyView()
        } primary: {
            EntityPrimaryButton(
                icon: isPlayingThisPlaylist ? "iconPause" : "iconPlay",
                title: isPlayingThisPlaylist ? "Пауза" : "Слушать",
                action: togglePlayback
            )
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.fillNine)
                .frame(height: PlusMetrics.hairline)
        }
    }

    /// Плейлист в коллекции «Моё» — его отмечают «нравится» и «скачать» шапки. id —
    /// тот же, что у карточек выдачи (`playlist-<id Deezer>`): отметка одна, откуда
    /// бы её ни поставили.
    private var collectionItem: CollectionItem {
        .playlist(
            id: "playlist-\(entity.deezerID.map(String.init) ?? entity.id)",
            title: details.title,
            owner: details.owner,
            cover: entity.artwork
        )
    }

    private var cover: some View {
        let shape = RoundedRectangle(cornerRadius: AlbumLayout.coverRadius, style: .continuous)
        return ArtworkImage(source: entity.artwork)
            .scaledToFill()
            .frame(width: AlbumLayout.coverSize, height: AlbumLayout.coverSize)
            .clipShape(shape)
            .overlay { shape.stroke(Color.fillNine, lineWidth: PlusMetrics.hairline) }
    }

    // MARK: Воспроизведение

    /// Идентификатор трека для плеера — в формате треклиста альбома
    /// (`dz-<…>-t<id трека>`): по нему коллекция узнаёт трек, откуда бы его ни включили.
    private func playerID(_ track: PlaylistDetails.Track) -> String {
        "\(entity.id)-t\(track.id)"
    }

    private func nowPlaying(_ track: PlaylistDetails.Track) -> MusicNowPlaying {
        MusicNowPlaying(
            id: playerID(track),
            cover: track.cover ?? entity.artwork,
            title: track.title,
            artist: track.artist,
            album: track.album,
            isExplicit: track.isExplicit
        )
    }

    /// Трек этого плейлиста, который сейчас в плеере, — играет он или на паузе.
    private var currentTrack: PlaylistDetails.Track? {
        guard actionBar.mode == .music, let id = actionBar.music?.id else { return nil }
        return details.tracks.first { playerID($0) == id }
    }

    private var isPlayingThisPlaylist: Bool {
        guard actionBar.mode == .music, actionBar.isMusicPlaying else { return false }
        return currentTrack != nil || actionBar.music?.id == entity.id
    }

    /// Что включает «Слушать»: трек, уже стоящий в плеере (тогда пауза или продолжение),
    /// иначе первый. Пока треки едут — плейлист целиком: кнопка не бывает мёртвой.
    private var playButtonTarget: MusicNowPlaying {
        if let track = currentTrack ?? details.tracks.first {
            return nowPlaying(track)
        }
        return MusicNowPlaying(id: entity.id, cover: entity.artwork, title: details.title, artist: details.owner)
    }

    private func togglePlayback() {
        play(playButtonTarget)
    }

    /// Тот же вход, что у альбома: `open` с тем же id — пауза/продолжение, с другим —
    /// запуск. Хаптика — как у тапа по карточке.
    private func play(_ item: MusicNowPlaying) {
        UIImpactFeedbackGenerator(style: .medium)
            .impactOccurred(intensity: ShowcaseMotion.tapHapticIntensity)
        actionBar.open(.music(item))
    }

    // MARK: Треклист

    /// Строки с обложкой альбома трека. Тап включает трек — как в треклисте альбома.
    @ViewBuilder
    private var trackList: some View {
        let tracks = details.tracks
        if tracks.isEmpty, store.details == nil, !store.didFail, entity.deezerID != nil {
            VStack(spacing: 0) {
                ForEach(0..<Self.skeletonRows, id: \.self) { _ in
                    EntityTrackRowSkeleton()
                }
            }
            .padding(.horizontal, AlbumLayout.side)
        } else {
            LazyVStack(spacing: 0) {
                // По позиции, а не по id: один трек в плейлисте бывает дважды.
                ForEach(Array(tracks.enumerated()), id: \.offset) { index, track in
                    EntityTrackRow(
                        cover: track.thumbnail,
                        title: track.title,
                        artist: track.artist,
                        isExplicit: track.isExplicit,
                        showsDivider: index < tracks.count - 1
                    )
                    // Жестом, а не кнопкой: внутри строки своя кнопка «ещё».
                    .onTapGesture { play(nowPlaying(track)) }
                }
            }
            .padding(.horizontal, AlbumLayout.side)
        }
    }
}
