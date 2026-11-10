import SwiftUI

/// Данные карточек экспериментальных вариантов Recently.
struct HomeRecentlyExperimentItem: Identifiable {
    let id: String
    let kind: HomePromoKind
    let title: String
    let subtitle: String
    let artwork: ArtworkSource
    let route: EntityRoute?
    var movie: MovieInProgress? = nil
    var book: BookInProgress? = nil
    var progress: Double? = nil
    var station: VibeStation? = nil
    var canJoinStack: Bool { kind != .station }
    var hasOutline: Bool { canJoinStack && station == nil }
    var mediaHeight: CGFloat { kind == .movie || kind == .album ? 78 : 80 }

    var width: CGFloat {
        switch kind {
        case .movie: 138
        case .book: 54
        case .album: 78
        case .artist: 80
        case .station: 70
        }
    }
    var radius: CGFloat {
        switch kind {
        case .movie: 6
        case .book: 3
        case .album: 12
        case .artist, .station: 40
        }
    }

}
