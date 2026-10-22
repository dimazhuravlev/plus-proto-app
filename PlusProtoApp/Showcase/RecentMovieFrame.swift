import SwiftUI
import UIKit

/// Recently показывает сцену, а не постер. Даже поле `still` старой истории может
/// содержать fallback-постер: проверяем пропорции изображения до первого показа.
struct RecentMovieFrame: View {
    let movieID: String
    let source: ArtworkSource
    @State private var image: UIImage?

    private struct Request: Hashable {
        let movieID: String
        let source: ArtworkSource
    }

    init(movieID: String, source: ArtworkSource) {
        self.movieID = movieID
        self.source = source
        let cached: UIImage?
        switch source {
        case .asset(let name): cached = UIImage(named: name)
        case .remote(let url, _): cached = ArtworkLoader.shared.cached(url)
        }
        _image = State(initialValue: cached.flatMap { $0.size.width > $0.size.height ? $0 : nil })
    }

    var body: some View {
        Group {
            if let image { Image(uiImage: image).resizable().scaledToFill() }
            else { PlusSkeleton.fill }
        }
        .task(id: Request(movieID: movieID, source: source)) {
            guard !Task.isCancelled else { return }
            var candidate = source
            if movieID.hasPrefix("kp-") {
                let suffix = movieID.replacingOccurrences(of: "kp-w-", with: "").replacingOccurrences(of: "kp-", with: "")
                if let id = Int(suffix) {
                    let stills = await MoviePool.shared.stills(for: id)
                    if let frame = stills.first(where: { ($0.width ?? 0) > ($0.height ?? 0) }),
                       let url = frame.url(size: .wide) { candidate = .remote(url) }
                }
            }
            // Не начинаем загрузку арта старого запроса после смены карточки.
            guard !Task.isCancelled else { return }
            let resolved: UIImage?
            switch candidate {
            case .asset(let name): resolved = UIImage(named: name)
            case .remote(let url, _): resolved = await ArtworkLoader.shared.image(for: url)
            }
            guard !Task.isCancelled else { return }
            image = resolved.flatMap { $0.size.width > $0.size.height ? $0 : nil }
        }
    }
}
