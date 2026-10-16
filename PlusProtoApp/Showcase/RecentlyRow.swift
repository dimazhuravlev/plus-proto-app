import SwiftUI
import UIKit

// MARK: - Геометрия

/// Ряд «продолженного потребления» — макет `2713:26833` (экран `2713:26782`). Числа
/// сняты с инстансов и не масштабируются: ряд — лента плиток разной фиксированной ширины,
/// а не карусель с выглядывающей карточкой (задача 71). Высота ряда, отступ от навигации
/// и до промо — в `ShowcaseLayout`.
enum RecentlyLayout {
    static let spacing: CGFloat = 8
    /// Поля ленты — поле экрана с обеих сторон (правка пользователя 2026-10-16: в макете
    /// `pl 4` — под каплю «Моей волны», её из ряда убрали). Поля — у содержимого скролла,
    /// а сам скролл во всю ширину: плитки уезжают ровно за кромки экрана.
    static let leading: CGFloat = 16
    static let trailing: CGFloat = 16
    /// Свечения — копии картинок в блюре 24 панели Figma (в коде вдвое меньше, конвенция
    /// `GlassSurface`).
    static let glowBlur: CGFloat = 12
    /// Плитки рисуются в числах макета (высота 80) и ужимаются целиком до высоты ряда:
    /// пропорции, скругления и свечения те же, зазоры и поля ряда — без масштаба (правка
    /// пользователя 2026-10-13: ряд 72).
    static let designHeight: CGFloat = 80
    @MainActor
    static var tileScale: CGFloat { ShowcaseLayout.recentlyHeight / designHeight }

    /// Фильм `2713:26839`: кадр 138×78 по центру плитки 138×80, таймлайн у низа кадра.
    enum Movie {
        static let size = CGSize(width: 138, height: 80)
        static let frame = CGSize(width: 138, height: 78)
        /// Скругление — как у альбома (12; в макете 6): плитки фильма и альбома одинаковые —
        /// правка пользователя 2026-10-13.
        static let radius: CGFloat = 12
        /// Полоса 130×3 в (4, 71) кадра — по 4 от левой, правой и нижней кромки.
        static let trackInset: CGFloat = 4
        static let trackHeight: CGFloat = 3
        static var trackWidth: CGFloat { frame.width - 2 * trackInset }
        /// Подложка полосы: backdrop-blur 6 панели Figma → 3 в коде.
        static let trackBlur: CGFloat = 3
    }

    /// Альбом/трек `2713:26844`: квадрат 78 в плитке 78×80, позади — копия 74 в блюре.
    enum Album {
        static let size = CGSize(width: 78, height: 80)
        static let cover: CGFloat = 78
        static let radius: CGFloat = 12
        static let glow: CGFloat = 74
        static let glowOpacity: Double = 0.25
    }

    /// Книга `2713:26847`: обложка 52.66×78.99 с верхом на 1.01 в плитке 54×80 — рисунок
    /// `BookFigure` (блок страниц, сгиб у корешка, бордер с трёх сторон); позади — копия
    /// обложки в блюре.
    enum Book {
        static let size = CGSize(width: 54, height: 80)
        static let cover = CGSize(width: 52.66, height: 78.99)
        static let coverTop: CGFloat = 1.01
        /// Скругление обложки макета — меньше, чем дала бы `BookFigure` на этой высоте (4.94).
        static let coverRadius: CGFloat = 4.05
        static let glowOpacity: Double = 0.45

        static var geometry: BookFigureGeometry {
            var geometry = BookFigureGeometry(coverHeight: cover.height)
            geometry.radiusTrim = geometry.coverRadius - coverRadius
            return geometry
        }
    }

    /// Исполнитель `2713:26852`: круг 80, позади — круг 72 в блюре.
    enum Artist {
        static let size: CGFloat = 80
        static let glow: CGFloat = 72
        static let glowOpacity: Double = 0.25
    }
}

enum RecentlyMotion {
    /// Запущенный трек встаёт в начало ряда — движение по экрану, ease-in-out. Фильм
    /// и книга переставляются под плеером, их движения не видно.
    static let reorder: Animation = .timingCurve(0.4, 0, 0.2, 1, duration: 0.45)
}

// MARK: - Ряд

/// Ряд «продолженного потребления» над промо «Главной» (задача 71): что начинали смотреть,
/// слушать, читать (`RecentlyConsumed`), свежее первым. Плитки «Моей волны» первой больше
/// нет (правка пользователя 2026-10-16).
///
/// Тап: фильм — сразу киноплеер с места остановки, книга — сразу читалка; альбом
/// (плейлист) и исполнитель — их экраны (правка пользователя 2026-10-13).
/// Трек без известного альбома — играет, экрана у него нет.
///
/// Свечения — статичные блюры копий картинок фоном плиток: раскладку они не раздувают,
/// а `scrollClipDisabled` не режет их по высоте ряда.
struct RecentlyRow: View {
    /// Namespace зум-перехода ленты — у исполнителя экран разворачивается из круга.
    let zoom: Namespace.ID

    @Environment(ActionBarState.self) private var actionBar
    @Environment(AppNavigationState.self) private var navigation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let items = actionBar.recently.items
        ScrollView(.horizontal) {
            LazyHStack(spacing: RecentlyLayout.spacing) {
                ForEach(items) { item in
                    Button { open(item) } label: {
                        RecentlyTile(item: item, zoom: zoom)
                    }
                    .buttonStyle(PressScaleButtonStyle(pressedScale: PressMotion.cardScale))
                    .accessibilityLabel(item.title)
                }
            }
            .frame(height: ShowcaseLayout.recentlyHeight)
            // Reduce Motion — без переезда: ряд встаёт в новом порядке сразу.
            .animation(reduceMotion ? nil : RecentlyMotion.reorder, value: items.map(\.id))
        }
        .contentMargins(.leading, RecentlyLayout.leading, for: .scrollContent)
        .contentMargins(.trailing, RecentlyLayout.trailing, for: .scrollContent)
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .frame(height: ShowcaseLayout.recentlyHeight)
    }

    // MARK: Тап

    /// Хаптика — как у карточек ленты.
    private func haptic() {
        UIImpactFeedbackGenerator(style: .medium)
            .impactOccurred(intensity: ShowcaseMotion.tapHapticIntensity)
    }

    private func open(_ item: RecentItem) {
        haptic()
        switch item {
        case .movie(var movie):
            // С места остановки — из истории просмотра: позиции в ряду нет, у стартового
            // набора она своя, пока фильм не запускали.
            if let position = actionBar.watchHistory.position(for: movie.id) { movie.position = position }
            if let runtime = actionBar.watchHistory.runtime(for: movie.id) { movie.runtime = runtime }
            actionBar.open(.movie(movie))
        case .music(let track):
            if let route = track.containerRoute {
                navigation.open(route)
            } else {
                actionBar.open(.music(track))
            }
        case .book(let book):
            actionBar.open(.book(book))
        case .artist(let artist):
            navigation.open(.artist(artist))
        }
    }
}

// MARK: - Плитки

private struct RecentlyTile: View {
    let item: RecentItem
    let zoom: Namespace.ID

    @Environment(ActionBarState.self) private var actionBar

    var body: some View {
        Group {
            switch item {
            case .movie(let movie): movieTile(movie)
            case .music(let track): albumTile(track)
            case .book(let book): bookTile(book.cover)
            case .artist(let artist): artistTile(artist)
            }
        }
        .ppTile(designSize)
    }

    private var designSize: CGSize {
        switch item {
        case .movie: RecentlyLayout.Movie.size
        case .music: RecentlyLayout.Album.size
        case .book: RecentlyLayout.Book.size
        case .artist: CGSize(width: RecentlyLayout.Artist.size, height: RecentlyLayout.Artist.size)
        }
    }

    // MARK: Фильм

    /// Доля просмотренного — живая, из истории просмотра; у стартового набора, пока
    /// фильм не запускали, — его собственная. Нет хронометража или не начинали — полосы нет.
    private func progress(of movie: MovieInProgress) -> Double? {
        if let entry = actionBar.watchHistory.entries.first(where: { $0.id == movie.id }) {
            return entry.progress
        }
        guard let runtime = movie.runtime, runtime > 0,
              let position = movie.position, position > 0 else { return nil }
        return min(1, position / runtime)
    }

    private func movieTile(_ movie: MovieInProgress) -> some View {
        typealias L = RecentlyLayout.Movie
        let shape = RoundedRectangle(cornerRadius: L.radius, style: .continuous)
        return PlusSkeleton.fill
            .overlay { SkeletonArtwork(source: movie.still) }
            .overlay(alignment: .bottomLeading) {
                if let progress = progress(of: movie) {
                    track(progress)
                }
            }
            .frame(width: L.frame.width, height: L.frame.height)
            .clipShape(shape)
            .coverBorder(shape)
            .frame(width: L.size.width, height: L.size.height)
    }

    /// Таймлайн кадра: подложка белый 10 % на блюре, заливка — акцент Плюса.
    private func track(_ progress: Double) -> some View {
        typealias L = RecentlyLayout.Movie
        return Capsule()
            .fill(Color.buttonsPrimary)
            .background {
                BackdropBlurView(radius: L.trackBlur)
                    .clipShape(Capsule())
            }
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(Color.plusAccent)
                    .frame(width: L.trackWidth * min(max(progress, 0), 1))
            }
            .frame(width: L.trackWidth, height: L.trackHeight)
            .padding(L.trackInset)
            .allowsHitTesting(false)
    }

    // MARK: Альбом / трек

    private func albumTile(_ track: MusicNowPlaying) -> some View {
        typealias L = RecentlyLayout.Album
        let cover = track.cover
        let shape = RoundedRectangle(cornerRadius: L.radius, style: .continuous)
        return PlusSkeleton.fill
            .overlay { SkeletonArtwork(source: cover) }
            .frame(width: L.cover, height: L.cover)
            .clipShape(shape)
            .coverBorder(shape)
            // Экран альбома разворачивается из обложки, как у исполнителя из круга.
            .matchedTransitionSource(id: track.containerRoute ?? EntityRoute.album(EntityRef(
                id: "recent-\(track.id)", title: track.title, subtitle: "", artwork: cover
            )), in: zoom)
            .background {
                glow(cover, size: CGSize(width: L.glow, height: L.glow), in: Rectangle(), opacity: L.glowOpacity)
            }
            .frame(width: L.size.width, height: L.size.height)
    }

    // MARK: Книга

    private func bookTile(_ cover: ArtworkSource) -> some View {
        typealias L = RecentlyLayout.Book
        let geometry = L.geometry
        // Без свечения под обложкой — правка пользователя 2026-10-13 (в макете было 0.45).
        return ZStack(alignment: .topLeading) {
            // Верх обложки — на 1.01, как в макете: над ней выглядывает блок страниц.
            BookFigure(geometry: geometry, coverWidth: L.cover.width) {
                SkeletonArtwork(source: cover)
            }
            .offset(y: L.coverTop - geometry.pagesTop)
        }
        .frame(width: L.size.width, height: L.size.height, alignment: .topLeading)
    }

    // MARK: Исполнитель

    private func artistTile(_ artist: EntityRef) -> some View {
        typealias L = RecentlyLayout.Artist
        return PlusSkeleton.fill
            .overlay { SkeletonArtwork(source: artist.artwork) }
            .frame(width: L.size, height: L.size)
            .clipShape(Circle())
            .coverBorder(Circle())
            // Источник зума — только круг: свечение снаружи, в портлет перехода не попадает.
            .matchedTransitionSource(id: EntityRoute.artist(artist), in: zoom)
            .background {
                glow(artist.artwork, size: CGSize(width: L.glow, height: L.glow), in: Circle(), opacity: L.glowOpacity)
            }
    }

    // MARK: Свечение

    /// Копия картинки в блюре позади плитки — статичная, без анимации. Форма — до блюра,
    /// как у слоя макета: размывается уже обрезанная картинка.
    private func glow<S: Shape>(_ source: ArtworkSource, size: CGSize, in shape: S, opacity: Double) -> some View {
        SkeletonArtwork(source: source)
            .frame(width: size.width, height: size.height)
            .clipShape(shape)
            .blur(radius: RecentlyLayout.glowBlur)
            .opacity(opacity)
            .allowsHitTesting(false)
    }
}

private extension View {
    /// Плитка ПП: раскладка — в числах макета (`size`, высота 80), на экране — ужатая до
    /// высоты ряда целиком (`RecentlyLayout.tileScale`), без смены пропорций.
    func ppTile(_ size: CGSize) -> some View {
        let scale = RecentlyLayout.tileScale
        return frame(width: size.width, height: size.height)
            .scaleEffect(scale)
            .frame(width: size.width * scale, height: size.height * scale)
    }
}
