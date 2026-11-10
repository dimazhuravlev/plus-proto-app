import SwiftUI

extension HomeQuickAccess {
    @ViewBuilder func historyCard(_ item: RecentItem) -> some View {
        switch item {
        case .myVibe:
            captioned("Моя волна", width: 70) { vibeButton }
        case .station(let id):
            if let station = VibeStation.all.first(where: { $0.id == id }) {
                Button {
                    actionBar.openMyVibe()
                    actionBar.recently.record(.station(id))
                } label: {
                    captioned(station.title, width: 80, centered: station.photo != nil) {
                        CompactVibePetal(station: station, height: HomeQuickAccessLayout.height, fillsContainer: true)
                    }
                }.accessibilityLabel(station.title)
            }
        case .book(let book):
            historyBook(title: book.title, source: book.cover) { actionBar.read(book) }
        case .movie(let movie):
            Button { actionBar.watch(movie) } label: {
                captioned(movie.title, width: 138) {
                    movieThumbnail(movie.still, movieID: movie.id,
                                   progress: actionBar.watchHistory.entries.first { $0.id == movie.id }?.progress)
                }
            }.accessibilityLabel(movie.title)
        case .music(let track):
            Button {
                if let route = track.containerRoute { navigation.open(route) }
                else { actionBar.open(.music(track)) }
            } label: {
                captioned(track.album ?? track.title, width: 78) {
                    artwork(track.cover, width: 78, height: 78, radius: 12)
                }
            }.accessibilityLabel(track.album ?? track.title)
        case .artist(let ref):
            historyEntity(.artist(ref))
        case .entity(let route):
            historyEntity(route)
        }
    }

    @ViewBuilder private func historyEntity(_ route: EntityRoute) -> some View {
        let ref = route.ref
        switch route {
        case .book:
            historyBook(title: ref.title, source: ref.artwork) { navigation.open(route) }
        case .artist, .director, .writer, .actor:
            let isArtist: Bool = { if case .artist = route { return true }; return false }()
            Button { navigation.open(route) } label: {
                captioned(ref.title, width: 80, centered: isArtist) { artwork(ref.artwork, width: 80, height: 80, radius: 40) }
            }.accessibilityLabel(ref.title)
        case .movie, .episodes:
            Button { navigation.open(route) } label: {
                captioned(ref.title, width: 138) {
                    movieThumbnail(ref.artwork, movieID: ref.id, progress: nil)
                }
            }.accessibilityLabel(ref.title)
        default:
            Button { navigation.open(route) } label: {
                captioned(ref.title, width: 78) { artwork(ref.artwork, width: 78, height: 78, radius: 12) }
            }.accessibilityLabel(ref.title)
        }
    }

    private func historyBook(title: String, source: ArtworkSource, action: @escaping () -> Void) -> some View {
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
