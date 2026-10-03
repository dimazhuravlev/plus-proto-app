import SwiftUI

/// Полная выдача одного раздела — Музыка, Кино или Книги (задача пользователя
/// 2026-10-03; макет музыки `2440:27920`, кино и книги — те же, с другими фильтрами).
///
/// Сверху вниз: заголовок раздела, чипсы фильтров, у музыки — колдунщик (самый
/// подходящий исполнитель), дальше список строк. Открывается переходом по заголовку
/// карусели, живёт подэкраном слоя выдачи (`SearchResultsView`), «Назад» в баре
/// сворачивает её к обзору.
struct SearchSectionView: View {
    let kind: SearchState.Section.Kind
    /// Уход в сущность — тот же, что из каруселей: отметка ухода, клавиатура вниз.
    let open: (EntityRoute) -> Void
    let zoom: Namespace.ID?

    @Environment(SearchState.self) private var search
    @Environment(KeyboardObserver.self) private var keyboard
    @Environment(ActionBarState.self) private var actionBar

    @State private var filter: SearchFilter = .all
    /// Сердца — визуальные, на время экрана: избранного в прототипе нет.
    @State private var liked: Set<String> = []

    private enum Layout {
        static let side: CGFloat = 16
        static let headerTop: CGFloat = 16
        static let headerBottom: CGFloat = 12
        /// Строка заголовка — как у `header / static`: 56 = 16 + 28 + 12.
        static let headerLine: CGFloat = 28
        static let chipsVertical: CGFloat = 8
        static let chipGap: CGFloat = 8
        static let barGap: CGFloat = 12
        static let skeletonRows = 7
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                header
                chips

                if let full = search.fullResults {
                    if filter == .all, let wizard = full.wizard {
                        MusicWizardCard(wizard: wizard, open: open, zoom: zoom)
                    }
                    let rows = full.hits.filter { filter.matches($0.kind) }
                    if rows.isEmpty {
                        Text("Ничего не нашлось")
                            .plusText(.textS, .medium)
                            .foregroundStyle(Color.fillSubtitle)
                            .padding(.horizontal, Layout.side)
                            .padding(.vertical, Layout.headerTop)
                    } else {
                        ForEach(rows) { hit in
                            row(hit, isFirst: hit.id == rows.first?.id)
                        }
                    }
                } else {
                    ForEach(0..<Layout.skeletonRows, id: \.self) { index in
                        SearchListSkeletonRow(isFirst: index == 0)
                    }
                }
            }
            // Как у обзора: список уходит под поле и клавиатуру, последняя строка
            // выкручивается из-под них.
            .padding(.bottom, keyboard.overlap + PlusMetrics.actionBarHeight + Layout.barGap)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.never)
        // Клавиатура уходит с первого движения скролла — как в обзоре.
        .onScrollPhaseChange { _, phase in
            guard phase == .interacting, actionBar.isSearchFocused else { return }
            keyboard.dismissSmoothly()
        }
        // Новый запрос — с «Всего»: фильтр прошлого запроса мог оставить пустой список.
        .onChange(of: search.fullResults?.text) { filter = .all }
    }

    private var header: some View {
        Text(kind.title)
            .plusHeadline(.m)
            .foregroundStyle(Color.fillOne)
            .frame(height: Layout.headerLine)
            .padding(.top, Layout.headerTop)
            .padding(.bottom, Layout.headerBottom)
            .padding(.horizontal, Layout.side)
            .accessibilityAddTraits(.isHeader)
    }

    private var chips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Layout.chipGap) {
                ForEach(SearchFilter.options(for: kind), id: \.self) { option in
                    SearchFilterChip(title: option.title, isActive: option == filter) {
                        filter = option
                    }
                }
            }
            .padding(.horizontal, Layout.side)
            .padding(.vertical, Layout.chipsVertical)
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private func row(_ hit: SearchHit, isFirst: Bool) -> some View {
        let content = SearchListRow(
            hit: hit,
            isFirst: isFirst,
            isLiked: liked.contains(hit.id),
            onLike: { toggleLike(hit.id) }
        )
        if let route = hit.route {
            Button { open(route) } label: { content }
                .buttonStyle(.plain)
                .modifier(SearchResultsView.SearchZoomSource(route: route, zoom: zoom))
        } else {
            content
        }
    }

    private func toggleLike(_ id: String) {
        if liked.contains(id) { liked.remove(id) } else { liked.insert(id) }
    }
}

// MARK: - Фильтры

/// Фильтры полной выдачи. Музыка — по макету; кино и книги — по задаче пользователя:
/// «Кино — Кино, Режиссёры», «Книги — Книги, Авторы»; «Всё» первым у каждого раздела,
/// как в макете музыки.
enum SearchFilter: Hashable {
    case all, artists, albums, playlists, tracks, movies, directors, books, writers

    static func options(for kind: SearchState.Section.Kind) -> [SearchFilter] {
        switch kind {
        case .music: [.all, .artists, .albums, .playlists, .tracks]
        case .movies: [.all, .movies, .directors]
        case .books: [.all, .books, .writers]
        }
    }

    var title: String {
        switch self {
        case .all: "Всё"
        case .artists: "Исполнители"
        case .albums: "Альбомы"
        case .playlists: "Плейлисты"
        case .tracks: "Треки"
        case .movies: "Кино"
        case .directors: "Режиссёры"
        case .books: "Книги"
        case .writers: "Авторы"
        }
    }

    func matches(_ kind: SearchHit.Kind) -> Bool {
        switch self {
        case .all: true
        case .artists: kind == .artist
        case .albums: kind == .album
        case .playlists: kind == .playlist
        case .tracks: kind == .track
        case .movies: kind == .movie
        case .directors: kind == .director
        case .books: kind == .book
        case .writers: kind == .writer
        }
    }
}

/// Чипс фильтра — `chips-row` макета: 15/20 Semibold, поля 16 × 10, капсула.
/// Активный — фиолетовый с подсветкой снизу, остальные — стекло кнопок.
private struct SearchFilterChip: View {
    let title: String
    let isActive: Bool
    let action: () -> Void

    /// Фиолетовый активного чипса — #A332FF макета. Один вызов — токен не заводим.
    private static let accent = Color(red: 163 / 255, green: 50 / 255, blue: 1)

    var body: some View {
        Button(action: action) {
            Text(title)
                .plusText(.textM, .semibold)
                .foregroundStyle(isActive ? Color.fillOne : Color.fillFour)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background {
                    if isActive {
                        ZStack {
                            Self.accent.opacity(0.5)
                            // Подсветка снизу — радиальный градиент макета.
                            RadialGradient(
                                colors: [Self.accent.opacity(0.4), Self.accent.opacity(0)],
                                center: .bottom,
                                startRadius: 0,
                                endRadius: 36
                            )
                        }
                    } else {
                        Color.white.opacity(0.08)
                    }
                }
                .clipShape(Capsule())
                .overlay {
                    Capsule().strokeBorder(
                        Color.white.opacity(isActive ? 0.3 : 0.15),
                        lineWidth: PlusMetrics.hairline
                    )
                }
                .contentShape(Capsule())
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

// MARK: - Строка

/// Строка полной выдачи — `list-item / music` макета: 64 = 8 + обложка 48 + 8,
/// название и подпись 15/20, сердце справа, разделители 0.5.
private struct SearchListRow: View {
    let hit: SearchHit
    let isFirst: Bool
    let isLiked: Bool
    let onLike: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            SearchRowThumbnail(hit: hit)

            VStack(alignment: .leading, spacing: -2) {
                Text(hit.title)
                    .plusText(.textM, .medium)
                    .foregroundStyle(Color.fillOne)
                    .lineLimit(1)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .plusText(.textM, .medium)
                        .foregroundStyle(Color.fillSubtitle)
                        .lineLimit(1)
                }
            }
            .padding(.leading, 12)
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onLike) {
                Image(isLiked ? "iconLiked" : "iconLove")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 20, height: 20)
                    .foregroundStyle(isLiked ? Color.fillOne : Color.fillFour)
                    .padding(10)
                    .contentShape(.rect)
            }
            .buttonStyle(PressScaleButtonStyle())
            .padding(.trailing, -10)
            .accessibilityLabel(isLiked ? "Убрать из избранного" : "В избранное")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(height: 64)
        .overlay(alignment: .bottom) { divider }
        .overlay(alignment: .top) { if isFirst { divider } }
        .contentShape(.rect)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.fillNine)
            .frame(height: 0.5)
            .padding(.horizontal, 16)
    }

    /// Подпись — вид результата и, где есть, исполнитель, год или автор:
    /// «Трек · New Order», как в макете.
    private var subtitle: String {
        let detail = hit.subtitle
        func joined(_ label: String) -> String { detail.isEmpty ? label : "\(label) · \(detail)" }
        switch hit.kind {
        case .track: return joined("Трек")
        case .album: return joined("Альбом")
        case .artist: return "Исполнитель"
        case .playlist: return "Плейлист"
        case .movie: return joined("Фильм")
        case .book: return joined("Книга")
        case .director: return "Режиссёр"
        case .writer: return "Писатель"
        }
    }
}

/// Обложка строки высотой 48: квадрат у музыки, круг у исполнителя и персон,
/// постер 2:3 у фильма и книги — ширина по пропорциям, высота строки та же.
private struct SearchRowThumbnail: View {
    let hit: SearchHit

    var body: some View {
        let shape = self.shape
        Color.fillNine
            .frame(width: width, height: 48)
            .overlay {
                if let source = hit.artwork {
                    ResolvedArtwork(source: source, appear: .easeOut(duration: 0.15)) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Color.clear
                    }
                }
            }
            .clipShape(shape)
            .overlay { shape.stroke(Color.fillNine, lineWidth: PlusMetrics.hairline) }
    }

    private var width: CGFloat {
        switch hit.kind {
        case .movie, .book: 32
        default: 48
        }
    }

    private var shape: AnyShape {
        switch hit.kind {
        case .artist, .director, .writer: AnyShape(Circle())
        case .movie, .book: AnyShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        default: AnyShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
    }
}

/// Строка-скелетон — того же габарита, пока полная выдача собирается.
private struct SearchListSkeletonRow: View {
    let isFirst: Bool

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.fillNine)
                .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 8) {
                Rectangle().fill(Color.fillNine).frame(width: 160, height: 12)
                Rectangle().fill(Color.fillNine).frame(width: 100, height: 12)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(height: 64)
        .accessibilityHidden(true)
    }
}

// MARK: - Колдунщик

/// Колдунщик музыки — `search widget` макета (`2440:29310`): самый подходящий запросу
/// исполнитель. Строка 48: фото кругом, имя и «Исполнитель», сердце и play; ниже —
/// карусель его альбомов (95, обложка со скруглением 12). Фон — размытая фотография
/// исполнителя на 20 % поверх тонкой подложки.
private struct MusicWizardCard: View {
    let wizard: SearchState.MusicWizard
    let open: (EntityRoute) -> Void
    let zoom: Namespace.ID?

    @Environment(ActionBarState.self) private var actionBar
    @State private var isLiked = false

    private enum Layout {
        static let radius: CGFloat = 16
        static let inner: CGFloat = 12
        static let avatar: CGFloat = 48
        static let albumWidth: CGFloat = 95
        static let albumRadius: CGFloat = 12
        static let albumGap: CGFloat = 8
        static let playSize: CGFloat = 40
    }

    var body: some View {
        VStack(spacing: Layout.inner) {
            topRow
            if !wizard.albums.isEmpty {
                albums
            }
        }
        .padding(.vertical, Layout.inner)
        .background { background }
        .clipShape(RoundedRectangle(cornerRadius: Layout.radius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Layout.radius, style: .continuous)
                .strokeBorder(Color.fillNine, lineWidth: PlusMetrics.hairline)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    private var topRow: some View {
        HStack(spacing: 0) {
            Color.fillNine
                .frame(width: Layout.avatar, height: Layout.avatar)
                .overlay { artwork(wizard.artist.artwork) }
                .clipShape(Circle())
                .overlay { Circle().stroke(Color.fillNine, lineWidth: PlusMetrics.hairline) }

            VStack(alignment: .leading, spacing: -2) {
                Text(wizard.artist.title)
                    .plusText(.textM, .medium)
                    .foregroundStyle(Color.fillOne)
                    .lineLimit(1)
                Text("Исполнитель")
                    .plusText(.textM, .medium)
                    .foregroundStyle(Color.fillSubtitle)
            }
            .padding(.leading, 12)
            .frame(maxWidth: .infinity, alignment: .leading)

            Button { isLiked.toggle() } label: {
                Image(isLiked ? "iconLiked" : "iconLove")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 20, height: 20)
                    .foregroundStyle(isLiked ? Color.fillOne : Color.fillFour)
                    .padding(10)
                    .contentShape(.rect)
            }
            .buttonStyle(PressScaleButtonStyle())
            .accessibilityLabel(isLiked ? "Убрать из избранного" : "В избранное")
            .padding(.trailing, 6)

            Button(action: togglePlay) {
                Image(isPlayingThis ? "iconPause" : "iconPlay")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 20, height: 20)
                    .foregroundStyle(Color.fillOne)
                    .frame(width: Layout.playSize, height: Layout.playSize)
                    .background(Color.white.opacity(0.08), in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(PressScaleButtonStyle())
            .accessibilityLabel(isPlayingThis ? "Пауза" : "Слушать")
        }
        .frame(height: Layout.avatar)
        .padding(.horizontal, Layout.inner)
    }

    private var albums: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: Layout.albumGap) {
                ForEach(wizard.albums) { album in
                    albumCard(album)
                }
            }
            .padding(.horizontal, Layout.inner)
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private func albumCard(_ album: SearchHit) -> some View {
        let card = VStack(alignment: .leading, spacing: 6) {
            Color.fillNine
                .frame(width: Layout.albumWidth, height: Layout.albumWidth)
                .overlay { artwork(album.artwork) }
                .clipShape(RoundedRectangle(cornerRadius: Layout.albumRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Layout.albumRadius, style: .continuous)
                        .stroke(Color.fillNine, lineWidth: PlusMetrics.hairline)
                }
            Text(album.title)
                .plusText(.textS, .medium)
                .foregroundStyle(Color.fillOne)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.trailing, 8)
        }
        .frame(width: Layout.albumWidth, alignment: .leading)
        .contentShape(.rect)

        if let route = album.route {
            Button { open(route) } label: { card }
                .buttonStyle(PressScaleButtonStyle())
                .modifier(SearchResultsView.SearchZoomSource(route: route, zoom: zoom))
        } else {
            card
        }
    }

    private var background: some View {
        ZStack {
            artwork(wizard.artist.artwork)
                .blur(radius: 60)
                .opacity(0.2)
            Color.fillNine
        }
    }

    @ViewBuilder
    private func artwork(_ source: ArtworkSource?) -> some View {
        if let source {
            ResolvedArtwork(source: source, appear: .easeOut(duration: 0.15)) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color.clear
            }
        }
    }

    // MARK: Play

    /// Играет ли сейчас этот исполнитель — play превращается в паузу.
    private var isPlayingThis: Bool {
        actionBar.isMusicPlaying && actionBar.music?.artist == wizard.artist.title
    }

    /// Включить исполнителя: его трек из выдачи, а нет — первый альбом. Уже играет —
    /// пауза. Мини-плеер появится в баре, когда из поиска выйдут.
    private func togglePlay() {
        if actionBar.music?.artist == wizard.artist.title {
            actionBar.toggleMusicPlayback()
            return
        }
        guard let pick = wizard.topTrack ?? wizard.albums.first else { return }
        let albumTitle: String? = if case .album(let ref) = pick.route { ref.title } else { nil }
        actionBar.startMusic(MusicNowPlaying(
            id: pick.id,
            cover: pick.artwork ?? .asset("mockAlbumCover"),
            title: pick.title,
            artist: wizard.artist.title,
            album: albumTitle,
            artistPicture: wizard.artist.artwork
        ))
    }
}
