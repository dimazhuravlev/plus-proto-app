import SwiftUI

extension HomeQuickAccess {
    var experimentItems: [HomeRecentlyExperimentItem] {
        let preview = HomePresentationSettings.shared.recentlyPreviewIndex >= 0
        var result = [HomeRecentlyExperimentItem(id: "wave", kind: .station, title: "Моя волна",
            subtitle: "Музыка под ваше настроение", artwork: .asset("quickAccessWave"), route: nil)]
        let continuing = preview ? nil : actionBar.watchHistory.continuing.first
        let selectedMovie = continuing.map { MovieBlock(continuing: $0.movie) } ?? movie
        func appendMovie(_ position: Int) {
            guard moviePosition == position, let value = selectedMovie else { return }
            result.append(.init(id: "movie", kind: .movie, title: value.title,
                subtitle: value.resume?.episodeText ?? "Продолжить просмотр", artwork: value.still,
                route: ShowcaseBlock.movie(value).entityRoute,
                movie: value.resume ?? MovieInProgress(id: value.id, still: value.still, title: value.title),
                progress: continuing?.progress))
        }
        func appendShelf(_ item: HomeShelfItem, id: String) {
            let kind: HomePromoKind
            switch item.route {
            case .book: kind = .book
            case .artist: kind = .artist
            default: kind = .album
            }
            result.append(.init(id: id, kind: kind, title: item.title, subtitle: item.subtitle,
                artwork: item.artwork, route: item.route,
                progress: kind == .book ? actionBar.readingHistory.entries.first { $0.id == item.route.ref.id }?.progress : nil))
        }
        appendMovie(0)
        if let album {
            result.append(.init(id: "album", kind: .album, title: album.subtitle, subtitle: album.title,
                artwork: album.cover, route: ShowcaseBlock.album(album).entityRoute))
        }
        appendMovie(1)
        if !preview, let current = actionBar.book {
            result.append(.init(id: "book", kind: .book, title: current.title, subtitle: current.author ?? "Продолжить чтение",
                artwork: current.cover, route: .book(.init(id: current.id, title: current.title,
                subtitle: current.author ?? "", artwork: current.cover)), book: current,
                progress: actionBar.readingHistory.entries.first { $0.id == current.id }?.progress))
        } else if let book {
            result.append(.init(id: "book", kind: .book, title: book.title, subtitle: "Книга",
                artwork: book.cover, route: ShowcaseBlock.book(book).entityRoute,
                progress: actionBar.readingHistory.entries.first { $0.id == book.id }?.progress))
        }
        appendMovie(2)
        if preview {
            let pool = HomeShelfSamples.artists
            appendShelf(pool[HomePresentationSettings.shared.recentlyPreviewIndex % pool.count], id: "artist")
        } else if let artist {
            result.append(.init(id: "artist", kind: .artist, title: artist.name, subtitle: "Исполнитель",
                artwork: artist.picture, route: artist.route))
        }
        appendMovie(3)
        for (index, item) in additionalItems.enumerated() {
            appendShelf(item, id: "additional-\(index)")
            appendMovie(index + 4)
            if index < compactStations.count {
                let station = compactStations[index]
                let route = station.photo.map { ArtistBlock(id: 5535442, name: station.title, picture: .remote($0)).route }
                result.append(.init(id: "station-\(index)", kind: station.photo == nil ? .station : .artist,
                    title: station.title, subtitle: station.photo == nil ? "" : "Исполнитель",
                    artwork: station.photo.map { .remote($0) } ?? .asset("quickAccessWave"), route: route,
                    station: station))
            }
        }
        return result
    }

    @ViewBuilder func experimentThumbnail(_ item: HomeRecentlyExperimentItem) -> some View {
        switch item.kind {
        case .movie:
            movieThumbnail(item.artwork, movieID: item.movie?.id ?? item.id, progress: item.progress)
        case .book:
            bookThumbnail(item.artwork)
        case .album:
            artwork(item.artwork, width: 78, height: 78, radius: 12)
        case .artist:
            artwork(item.artwork, width: 80, height: 80, radius: 40)
        case .station:
            if let station = item.station {
                CompactVibePetal(station: station, height: HomeQuickAccessLayout.height)
                    .frame(width: item.width * HomeQuickAccessLayout.scale, height: HomeQuickAccessLayout.height)
            } else {
                RecentWaveShader(isPlaying: actionBar.isMusicPlaying)
                    .frame(width: item.width * HomeQuickAccessLayout.scale, height: HomeQuickAccessLayout.height)
            }
        }
    }
}
