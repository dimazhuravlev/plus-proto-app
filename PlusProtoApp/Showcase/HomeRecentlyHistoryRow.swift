import SwiftUI

extension HomeQuickAccess {
    @ViewBuilder func historyCard(_ item: RecentItem) -> some View {
        switch item {
        case .myVibe:
            captioned("Моя волна", width: 70, centered: true) { vibeButton }
        case .station(let id):
            if let station = VibeStation.all.first(where: { $0.id == id }) {
                historyStation(station)
            }
        case .stationSnapshot(let station):
            historyStation(station)
        case .book(let book):
            historyBook(id: book.id, title: book.title, source: book.cover) { actionBar.read(book) }
        case .movie(let movie):
            let saved = actionBar.watchHistory.entries.first { $0.id == movie.id }
            let current = saved?.movie ?? movie
            Button { actionBar.watch(current) } label: {
                captioned(current.title, width: HomeQuickAccessLayout.movieWidth, subtitle: current.episodeText) {
                    movieThumbnail(current.still, movieID: current.id, progress: saved?.progress,
                                   time: current.remainingTime)
                }
            }.accessibilityLabel(current.title)
        case .music(let track):
            Button {
                if let route = track.containerRoute { navigation.open(route) }
                else { actionBar.open(.music(track)) }
            } label: {
                captioned(track.album ?? track.title, width: HomeQuickAccessLayout.mediaBaseHeight) {
                    artwork(track.cover, width: HomeQuickAccessLayout.mediaBaseHeight, height: HomeQuickAccessLayout.mediaBaseHeight, radius: 12)
                }
            }.accessibilityLabel(track.album ?? track.title)
        case .artist(let ref):
            historyEntity(.artist(ref))
        case .entity(let route):
            historyEntity(route)
        }
    }

    private func historyStation(_ station: VibeStation) -> some View {
        Button { actionBar.openMyVibe(station: station) } label: {
            captioned(station.title, width: 80, centered: station.hasArtistArtwork) {
                CompactVibePetal(station: station, height: HomeQuickAccessLayout.height, fillsContainer: true)
            }
        }.accessibilityLabel(station.title)
    }

    @ViewBuilder private func historyEntity(_ route: EntityRoute) -> some View {
        let ref = route.ref
        switch route {
        case .book:
            historyBook(id: ref.id, title: ref.title, source: ref.artwork) { navigation.open(route) }
        case .artist, .director, .writer, .actor:
            let isArtist: Bool = { if case .artist = route { return true }; return false }()
            Button { navigation.open(route) } label: {
                captioned(ref.title, width: 80, centered: isArtist) { artwork(ref.artwork, width: 80, height: 80, radius: 40) }
            }.accessibilityLabel(ref.title)
        case .movie, .episodes:
            Button { navigation.open(route) } label: {
                captioned(ref.title, width: HomeQuickAccessLayout.movieWidth) {
                    movieThumbnail(ref.artwork, movieID: ref.id, progress: nil)
                }
            }.accessibilityLabel(ref.title)
        default:
            Button { navigation.open(route) } label: {
                captioned(ref.title, width: HomeQuickAccessLayout.mediaBaseHeight) {
                    artwork(ref.artwork, width: HomeQuickAccessLayout.mediaBaseHeight, height: HomeQuickAccessLayout.mediaBaseHeight, radius: 12)
                }
            }.accessibilityLabel(ref.title)
        }
    }

    private func historyBook(id: String, title: String, source: ArtworkSource, action: @escaping () -> Void) -> some View {
        HomeRecentlyBookWidth(source: source) { width in
            Button(action: action) {
                captioned(title, width: width) {
                    let scale = HomeQuickAccessLayout.scale
                    let geometry = BookFigureGeometry(coverHeight: 80 * scale)
                        .cornerRadius(HomeQuickAccessLayout.cornerRadius)
                    BookFigure(geometry: geometry, coverWidth: width * scale) {
                        ResolvedArtwork(source: source) { image in
                            image.resizable().scaledToFit()
                        }
                    }
                    .overlay(alignment: .topLeading) {
                        if let entry = actionBar.readingHistory.entries.first(where: { $0.id == id }) {
                            RecentlyBookProgress(progress: entry.progress ?? 0)
                                .padding(4)
                        }
                    }
                }
            }.accessibilityLabel(title)
        }
    }
}

/// Measure each cover once; changes of pull progress never relayout its text.
private struct HomeRecentlyBookWidth<Content: View>: View {
    let source: ArtworkSource
    @ViewBuilder let content: (CGFloat) -> Content
    @State private var aspect: CGFloat?
    init(source: ArtworkSource, @ViewBuilder content: @escaping (CGFloat) -> Content) {
        self.source = source
        self.content = content
        _aspect = State(initialValue: BookCoverAspect.cached(of: source) ?? nil)
    }
    var body: some View {
        content(80 * ((aspect ?? 0) > 0 ? aspect! : BookFigureGeometry.defaultAspect))
            .task(id: source) { aspect = await BookCoverAspect.load(of: source) }
    }
}
