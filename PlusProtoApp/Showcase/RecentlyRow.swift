import SwiftUI
import UIKit

// MARK: - Геометрия

/// Ряд «продолженного потребления» — макет `2713:26833` (экран `2713:26782`). Числа
/// сняты с инстансов и не масштабируются: ряд — лента плиток разной фиксированной ширины,
/// а не карусель с выглядывающей карточкой (задача 71). Высота ряда, отступ от навигации
/// и до промо — в `ShowcaseLayout`.
enum RecentlyLayout {
    /// Зазор между плитками — 6 на экране (правка пользователя 2026-10-16; было 8).
    static let spacing: CGFloat = 6
    /// Поля ленты — поле экрана с обеих сторон (правка пользователя 2026-10-16: в макете
    /// `pl 4` — под каплю «Моей волны»). Поля — у содержимого скролла,
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

    /// Скругление плиток — 6 на экране у всех видов (у книги — правые углы), бордер —
    /// 0.67 `fill/9` (правка пользователя 2026-10-16). Плитки ужимаются целиком, поэтому
    /// в числах плитки оба значения — с поправкой на `tileScale`.
    @MainActor
    static var radius: CGFloat { 6 / tileScale }
    @MainActor
    static var borderWidth: CGFloat { CoverBorder.width / tileScale }

    /// «Моя волна» `2785:32127`: плитка 80×80; капля и свечение шире плитки, ▶ 32 по центру.
    enum Vibe {
        static let size = CGSize(width: 80, height: 80)
        /// Капля `wave` — 100, на 10 % меньше макетных 111 (правка пользователя 2026-10-16);
        /// центр на (−0.5, −0.5) от центра плитки, как в макете.
        static let drop: CGFloat = 100
        static let dropOffset = CGSize(width: -0.5, height: -0.5)
        /// Свечение — та же капля 138×137, центр на (+6, −0.5), 14 %, блюр 8.
        static let glow = CGSize(width: 138, height: 137)
        static let glowOffset = CGSize(width: 6, height: -0.5)
        static let glowOpacity: Double = 0.14
        static let glowBlur: CGFloat = 8
        static let icon: CGFloat = 32
    }

    /// Фильм `2713:26839`: кадр во всю плитку, таймлайн у низа кадра. Ширина — 85 % макетной
    /// (правка пользователя 2026-10-16, кадр `scaledToFill` срезается по бокам); высота —
    /// вся плитка, как у остальных видов (правка пользователя 2026-10-16: в макете 78 из 80,
    /// и кадр выходил ниже соседей).
    enum Movie {
        static let widthShare: CGFloat = 0.85
        static let size = CGSize(width: 138 * widthShare, height: 80)
        static let frame = size
        /// Полоса 3 в высоту в (4, 71) кадра — по 4 от левой, правой и нижней кромки.
        static let trackInset: CGFloat = 4
        static let trackHeight: CGFloat = 3
        static var trackWidth: CGFloat { frame.width - 2 * trackInset }
        /// Подложка полосы: backdrop-blur 6 панели Figma → 3 в коде.
        static let trackBlur: CGFloat = 3
    }

    /// Альбом/трек `2713:26844`: квадрат во всю высоту плитки (в макете 78 из 80 — правка
    /// пользователя 2026-10-16: высоты всех видов одинаковые), позади — копия 74 в блюре.
    enum Album {
        static let size = CGSize(width: 80, height: 80)
        static let cover: CGFloat = 80
        static let glow: CGFloat = 74
        static let glowOpacity: Double = 0.25
    }

    /// Книга `2713:26847`: рисунок `BookFigure` (блок страниц, сгиб у корешка, бордер
    /// с трёх сторон) во всю высоту плитки — от верха блока страниц до низа обложки, как
    /// у остальных видов (правка пользователя 2026-10-16; в макете обложка 78.99 на 1.01).
    /// Ширина — от пропорций обложки, как у остальных книг приложения.
    enum Book {
        static let height: CGFloat = 80
        /// Обложка — высота плитки без выступа блока страниц (`pagesTop` = 2/128 обложки).
        static let coverHeight: CGFloat = height / (1 + 2 / BookFigureGeometry.referenceHeight)

        /// Скругление и бордер — общие для ряда (`RecentlyLayout.radius`, `borderWidth`).
        @MainActor
        static var geometry: BookFigureGeometry {
            var geometry = BookFigureGeometry(coverHeight: coverHeight)
            geometry.radiusTrim = geometry.coverRadius - RecentlyLayout.radius
            geometry.borderWidth = RecentlyLayout.borderWidth
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
/// слушать, читать (`RecentlyConsumed`), свежее первым. «Моя волна» — не закреплённой
/// первой, а в общем порядке, и только после главной волны таба Музыки (правки
/// пользователя 2026-10-16).
///
/// Тап: фильм — сразу киноплеер с места остановки, книга — сразу читалка, «Моя волна» —
/// волна; альбом (плейлист) и исполнитель — их экраны (правка пользователя 2026-10-13).
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
        case .myVibe:
            // Поток, а не трек: настоящий трек волны; волна уже играет — пауза.
            actionBar.openMainVibe()
        }
    }
}

// MARK: - Плитки

private struct RecentlyTile: View {
    let item: RecentItem
    let zoom: Namespace.ID

    @Environment(ActionBarState.self) private var actionBar
    /// Пропорции обложки книги (`BookCoverAspect`): `nil` — картинка ещё не в памяти, плитка
    /// стоит 2:3. Обложки ряда грузятся под заставкой, так что почти всегда — с первого кадра.
    @State private var bookAspect: CGFloat??

    init(item: RecentItem, zoom: Namespace.ID) {
        self.item = item
        self.zoom = zoom
        if case .book(let book) = item {
            _bookAspect = State(initialValue: BookCoverAspect.cached(of: book.cover))
        }
    }

    var body: some View {
        Group {
            switch item {
            case .movie(let movie): movieTile(movie)
            case .music(let track): albumTile(track)
            case .book(let book): bookTile(book.cover)
            case .artist(let artist): artistTile(artist)
            case .myVibe: vibeTile
            }
        }
        .ppTile(designSize)
        .task(id: item.id) {
            guard case .book(let book) = item, bookAspect == nil else { return }
            let aspect = await BookCoverAspect.load(of: book.cover)
            // Обложка приехала после показа — ряд доезжает той же кривой, что перестановка.
            withAnimation(RecentlyMotion.reorder) { bookAspect = .some(aspect) }
        }
    }

    private var designSize: CGSize {
        switch item {
        case .movie: RecentlyLayout.Movie.size
        case .music: RecentlyLayout.Album.size
        case .book: CGSize(width: bookFrame.width, height: RecentlyLayout.Book.height)
        case .artist: CGSize(width: RecentlyLayout.Artist.size, height: RecentlyLayout.Artist.size)
        case .myVibe: RecentlyLayout.Vibe.size
        }
    }

    // MARK: «Моя волна»

    /// Волна играет — на плитке пауза: тап по ней ставит волну на паузу (`openMyVibe`),
    /// и ▶ обещал бы обратное.
    private var isVibePlaying: Bool {
        actionBar.isMiniPlayerVisible && MyVibeTracks.isVibe(actionBar.music?.id) && actionBar.isMusicPlaying
    }

    private var vibeTile: some View {
        typealias L = RecentlyLayout.Vibe
        // Капля и свечение шире плитки — фоном распорки, раскладку не раздувают.
        return Color.clear
            .frame(width: L.size.width, height: L.size.height)
            .background {
                ZStack {
                    Image("vibeRecentDrop")
                        .resizable()
                        .frame(width: L.glow.width, height: L.glow.height)
                        .blur(radius: L.glowBlur)
                        .opacity(L.glowOpacity)
                        .offset(L.glowOffset)
                    // Капля — живой шейдер «Моей волны» (тот же ролик, что на экране Музыки;
                    // правка пользователя 2026-10-13). Чёрный фон ролика убирает «экран»;
                    // до первого кадра — постер из него же (`PPVibeShader`).
                    PPVibeShader()
                        .frame(width: L.drop, height: L.drop)
                        .offset(L.dropOffset)
                }
                .allowsHitTesting(false)
            }
            .overlay {
                // Тени ▶ — четыре видимых из пяти макета; радиус — половина блюра панели.
                PlayPauseGlyph(isPlaying: isVibePlaying, box: L.icon)
                    .foregroundStyle(Color.fillOne)
                    .shadow(color: .black.opacity(0.10), radius: 1, x: -1, y: 1)
                    .shadow(color: .black.opacity(0.09), radius: 2, x: -3, y: 3)
                    .shadow(color: .black.opacity(0.05), radius: 3, x: -6, y: 7)
                    .shadow(color: .black.opacity(0.01), radius: 3.5, x: -11, y: 13)
                    .allowsHitTesting(false)
            }
            .contentShape(.rect)
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
        let shape = RoundedRectangle(cornerRadius: RecentlyLayout.radius, style: .continuous)
        return PlusSkeleton.fill
            .overlay { SkeletonArtwork(source: movie.still) }
            .overlay(alignment: .bottomLeading) {
                if let progress = progress(of: movie) {
                    track(progress)
                }
            }
            .frame(width: L.frame.width, height: L.frame.height)
            .clipShape(shape)
            .ppBorder(shape)
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
        let shape = RoundedRectangle(cornerRadius: RecentlyLayout.radius, style: .continuous)
        return PlusSkeleton.fill
            .overlay { SkeletonArtwork(source: cover) }
            .frame(width: L.cover, height: L.cover)
            .clipShape(shape)
            .ppBorder(shape)
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

    private var bookCoverWidth: CGFloat {
        RecentlyLayout.Book.geometry.coverWidth(aspect: bookAspect ?? nil)
    }

    private var bookFrame: CGSize {
        RecentlyLayout.Book.geometry.frameSize(coverWidth: bookCoverWidth)
    }

    private func bookTile(_ cover: ArtworkSource) -> some View {
        typealias L = RecentlyLayout.Book
        let geometry = L.geometry
        // Без свечения под обложкой — правка пользователя 2026-10-13 (в макете было 0.45).
        return BookFigure(geometry: geometry, coverWidth: bookCoverWidth) {
            SkeletonArtwork(source: cover)
        }
        .frame(width: bookFrame.width, height: L.height, alignment: .topLeading)
    }

    // MARK: Исполнитель

    private func artistTile(_ artist: EntityRef) -> some View {
        typealias L = RecentlyLayout.Artist
        return PlusSkeleton.fill
            .overlay { SkeletonArtwork(source: artist.artwork) }
            .frame(width: L.size, height: L.size)
            .clipShape(Circle())
            .ppBorder(Circle())
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
    /// Бордер плитки — `CoverBorder` толщиной 0.67 на экране, а не в числах плитки.
    func ppBorder<S: InsettableShape>(_ shape: S) -> some View {
        overlay {
            shape
                .strokeBorder(CoverBorder.color, lineWidth: RecentlyLayout.borderWidth)
                .allowsHitTesting(false)
        }
    }

    /// Плитка ПП: раскладка — в числах макета (`size`, высота 80), на экране — ужатая до
    /// высоты ряда целиком (`RecentlyLayout.tileScale`), без смены пропорций.
    func ppTile(_ size: CGSize) -> some View {
        let scale = RecentlyLayout.tileScale
        return frame(width: size.width, height: size.height)
            .scaleEffect(scale)
            .frame(width: size.width * scale, height: size.height * scale)
    }
}

/// Живая капля «Моей волны» в ряду ПП: зацикленный ролик шейдера (`my-vibe-shader`) поверх
/// фона «экраном» — чёрное поле ролика не видно.
///
/// Ролик — общий на все появления плитки (`PPVibeShaderPlayback`): экран «Главной»
/// пересоздаётся на каждом заходе в таб, и свой плеер у каждой копии стартовал заново — до
/// первого кадра стояла капля макета, другого цвета, и проявление видео читалось как подмена
/// (жалоба пользователя 2026-10-16). Теперь ролик уже показывал кадры — плитка встаёт сразу
/// с видео; самый первый показ — с постера из первого кадра ролика (`vibeShaderPoster`),
/// с которого видео и стартует, так что смены не видно.
private struct PPVibeShader: View {
    @State private var isReady = PPVibeShaderPlayback.shared.hasShownFrame
    /// Эта копия числится зрителем общего ролика — снять её ровно один раз.
    @State private var isAttached = false

    var body: some View {
        ZStack {
            Image("vibeShaderPoster")
                .resizable()
                .blendMode(.screen)
                .opacity(isReady ? 0 : 1)
            LoopingVideoLayer(player: PPVibeShaderPlayback.shared.playback.queue) {
                PPVibeShaderPlayback.shared.hasShownFrame = true
                isReady = true
            }
            .blendMode(.screen)
            .opacity(isReady ? 1 : 0)
        }
        .animation(.easeOut(duration: 0.4), value: isReady)
        .allowsHitTesting(false)
        .onAppear { setWatching(true) }
        .onDisappear { setWatching(false) }
        .accessibilityHidden(true)
    }

    private func setWatching(_ watching: Bool) {
        guard watching != isAttached else { return }
        isAttached = watching
        if watching {
            PPVibeShaderPlayback.shared.attach()
        } else {
            PPVibeShaderPlayback.shared.detach()
        }
    }
}

/// Один ролик шейдера на все копии плитки «Моей волны»: играет, пока на экране хоть одна.
@MainActor
private final class PPVibeShaderPlayback {
    static let shared = PPVibeShaderPlayback()

    let playback = LoopingVideoPlayback()
    /// Слой хоть раз показал кадр — новые копии плитки встают сразу с видео.
    var hasShownFrame = false
    private var viewers = 0

    func attach() {
        viewers += 1
        guard viewers == 1 else { return }
        playback.start(bundled: "my-vibe-shader")
    }

    func detach() {
        viewers = max(0, viewers - 1)
        guard viewers == 0 else { return }
        playback.pause()
    }
}
