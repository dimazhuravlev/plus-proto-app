import SwiftUI

/// Числа строк табов разделов выдачи — `list-item / media` макетов `19184:22008` (кино)
/// и `19191:22495` (книги): обложка 76 слева, зазор 12, поля 16 и 8. Постер фильма
/// и фото режиссёра — 2:3 (76 × 114, строка 130), аудиокнига — квадрат, автор — круг.
enum SearchMediaLayout {
    static let side: CGFloat = 16
    static let vertical: CGFloat = 8
    static let gap: CGFloat = 12
    static let cover: CGFloat = 76
    static let posterAspect: CGFloat = 2.0 / 3.0
    static var posterHeight: CGFloat { cover / posterAspect }
    static let coverRadius: CGFloat = 8
    /// Подпись подтянута к названию на 2 — как у строк полной выдачи.
    static let captionGap: CGFloat = -2
    /// Текст → «Смотреть»
    static let buttonGap: CGFloat = 8
    /// Точка-разделитель подписи 3 с зазорами 4
    static let dot: CGFloat = 3
    static let dotGap: CGFloat = 4
    /// Закладка и «+» — plain M: круг 40 под отрицательным отступом, у края — глиф 20.
    static var accessoryInset: CGFloat { -(PlusButtonSize.m.height - PlusButtonSize.m.iconBox) / 2 }
    /// Список — на 8 ниже чипсов (колдунщик музыки держит этот отступ сам).
    static let listTop: CGFloat = 8
    /// Скелетон — на высоту экрана: строки кино 130, музыки 96.
    static let skeletonRows = 6
    static let musicSkeletonRows = 7
    /// Обложка строки музыки — 80 (`CollectionListLayout.cover`) со скруглением 8
    /// (`. / card / image-music` макета `19151:18648`); у исполнителя — круг.
    static let musicCoverRadius: CGFloat = 8
    /// Кнопка play на обложке трека — secondary S, 4 от кромок обложки
    static let playButton = PlusButtonSize.s
    static let playInset: CGFloat = 4
    /// Полоски скелетона — те же, что у строк полной выдачи.
    static let skeletonTitleBar: CGFloat = 160
    static let skeletonSubtitleBar: CGFloat = 100
    static let skeletonBarGap: CGFloat = 8
}

extension SearchHit {
    /// Аудиокнига выдачи — `audiobook-dz-<id альбома Deezer>` (`SearchState.withAudiobooks`);
    /// у прежних моков в коллекции — `audiobook-<id книги>`.
    static let audiobookPrefix = "audiobook-"
}

// MARK: - Список таба

/// Список таба раздела выдачи сеткой — полная выдача раздела строками (задача
/// пользователя 2026-10-31). Музыка — колдунщик и строки полной выдачи; кино и книги —
/// строки макетов (`SearchMediaRow`). Пока выдача раздела собирается — скелетон строк.
///
/// Тело — плоский список строк: вью встаёт секцией ленивой ленты (`SearchMosaicView`),
/// и строки создаются по мере скролла.
struct SearchTabRows: View {
    let kind: SearchState.Section.Kind
    let results: SearchState.TabResults?
    let filter: SearchSubfilter
    /// Уход в сущность — тот же, что из сетки: отметка ухода, клавиатура вниз.
    let open: (EntityRoute) -> Void
    let zoom: Namespace.ID?

    @Environment(SearchState.self) private var search
    @Environment(ActionBarState.self) private var actionBar
    @Environment(CollectionStore.self) private var collection
    @Environment(KeyboardObserver.self) private var keyboard
    /// Сердца строк, которых коллекция не хранит (персоны), — на время экрана.
    @State private var liked: Set<String> = []

    var body: some View {
        if let results {
            let rows = results.rows(filter)
            let wizard = filter == .all ? results.wizard : nil
            // Трек экран не открывает — источником зума его альбома он не будет;
            // аудиокнига ведёт на экран своей книги, источник у него — книга.
            let zoomSources = rows.filter { $0.kind != .track }.firstPerRouteIDs
            if let wizard {
                MusicWizardCard(
                    wizard: wizard,
                    isLiked: isLiked(wizard.artist),
                    onLike: { toggleLike(wizard.artist) },
                    remember: search.remember,
                    open: open,
                    zoom: zoom
                )
            } else {
                Color.clear.frame(height: SearchMediaLayout.listTop)
            }
            ForEach(rows) { hit in
                row(hit, in: rows, results: results, isFirst: hit.id == rows.first?.id, zooms: zoomSources.contains(hit.id))
            }
        } else {
            Color.clear.frame(height: SearchMediaLayout.listTop)
            let count = kind == .music ? SearchMediaLayout.musicSkeletonRows : SearchMediaLayout.skeletonRows
            ForEach(0..<count, id: \.self) { index in
                SearchMediaSkeletonRow(kind: kind, isFirst: index == 0)
            }
        }
    }

    @ViewBuilder
    private func row(
        _ hit: SearchHit,
        in rows: [SearchHit],
        results: SearchState.TabResults,
        isFirst: Bool,
        zooms: Bool
    ) -> some View {
        if kind == .music {
            musicRow(hit, in: rows, isFirst: isFirst, zooms: zooms)
        } else {
            let content = SearchMediaRow(
                hit: hit,
                caption: caption(hit, results),
                isFirst: isFirst,
                onWatch: results.isWatchable(hit) ? { watch(hit) } : nil,
                accessory: accessory(hit, results),
                isPressable: hit.route != nil
            )
            if let route = hit.route {
                Button {
                    search.remember(hit)
                    open(route)
                } label: { content }
                    .buttonStyle(BareButtonStyle())
                    .modifier(SearchResultsView.SearchZoomSource(route: route, zoom: zooms ? zoom : nil))
            } else {
                content
            }
        }
    }

    // MARK: Музыка

    /// Строка музыки — `list-item / music` макета `19151:18648`: общая строка полных
    /// списков (`CollectionListItem`) с обложкой 80, сердце справа. Трек играет тапом по
    /// всей строке — на обложке кнопка play (задача пользователя 2026-10-31), остальное
    /// открывает свой экран.
    @ViewBuilder
    private func musicRow(_ hit: SearchHit, in rows: [SearchHit], isFirst: Bool, zooms: Bool) -> some View {
        let content = CollectionListItem(
            title: hit.title,
            caption: musicCaption(hit),
            isFirst: isFirst,
            isPressable: hit.kind == .track || hit.route != nil
        ) {
            SearchMusicThumbnail(hit: hit)
        } trailing: {
            PlusButton(type: .plain, size: .m, accessibilityTitle: isLiked(hit) ? "Убрать из избранного" : "В избранное") {
                toggleLike(hit)
            } icon: {
                LikeGlyph(isLiked: isLiked(hit), box: PlusButtonSize.m.iconBox, offColor: .fillFive)
            }
            // Круг 40 — под отрицательным отступом: в раскладке строки глиф 20, до текста 12.
            .padding(.horizontal, SearchMediaLayout.accessoryInset)
        }
        if hit.kind == .track {
            Button {
                search.remember(hit)
                playSearchTrack(hit, queue: rows, actionBar: actionBar)
            } label: { content }
                .buttonStyle(BareButtonStyle())
                .accessibilityHint("Включить трек")
        } else if let route = hit.route {
            Button {
                search.remember(hit)
                open(route)
            } label: { content }
                .buttonStyle(BareButtonStyle())
                .modifier(SearchResultsView.SearchZoomSource(route: route, zoom: zooms ? zoom : nil))
        } else {
            content
        }
    }

    /// Подпись строки музыки (макет и задача пользователя 2026-10-31). На «Всём» — тип
    /// и деталь через точку: «Трек · Исполнитель», «Альбом · Исполнитель», «Исполнитель»,
    /// «Плейлист · 53 трека». На чипсе своего типа тип не пишем: трек — исполнитель,
    /// исполнитель — без подписи, плейлист — число треков, альбом — «Исполнитель · Год».
    private func musicCaption(_ hit: SearchHit) -> [CaptionPart] {
        let typed = filter == .all
        var parts: [CaptionPart] = []
        switch hit.kind {
        case .track:
            if typed { parts.append(CaptionPart(text: "Трек")) }
            if !hit.subtitle.isEmpty { parts.append(CaptionPart(text: hit.subtitle, truncates: true)) }
        case .album:
            if typed { parts.append(CaptionPart(text: "Альбом")) }
            if !hit.subtitle.isEmpty { parts.append(CaptionPart(text: hit.subtitle, truncates: true)) }
            if !typed, let year = hit.year { parts.append(CaptionPart(text: year)) }
        case .artist:
            if typed { parts.append(CaptionPart(text: "Исполнитель")) }
        case .playlist:
            if typed { parts.append(CaptionPart(text: "Плейлист")) }
            if let count = hit.trackCount {
                let tracks = CollectionCopy.plural(count, one: "трек", few: "трека", many: "треков")
                parts.append(CaptionPart(text: "\(count) \(tracks)"))
            } else if !hit.subtitle.isEmpty {
                // Числа нет — автор плейлиста, как прежде.
                parts.append(CaptionPart(text: hit.subtitle, truncates: true))
            }
        case .movie, .book, .director, .writer, .actor:
            break
        }
        return parts
    }

    private func isLiked(_ hit: SearchHit) -> Bool {
        collection.isFavorite(hit: hit) ?? liked.contains(hit.id)
    }

    private func toggleLike(_ hit: SearchHit) {
        if collection.toggleFavorite(hit: hit) { return }
        if liked.contains(hit.id) { liked.remove(hit.id) } else { liked.insert(hit.id) }
    }

    // MARK: Кино и книги

    /// Подпись через точку (макеты): фильм — оригинальное название и год; книга —
    /// «Книга» и автор, аудиокнига — «Аудио» и автор; режиссёр и автор — роль и, если их
    /// работ в выдаче больше одной, сколько (решение пользователя 2026-10-31).
    private func caption(_ hit: SearchHit, _ results: SearchState.TabResults) -> [CaptionPart] {
        switch hit.kind {
        case .movie:
            var parts: [CaptionPart] = []
            if let original = hit.altTitle, !original.isEmpty,
               original.compare(hit.title, options: [.caseInsensitive, .diacriticInsensitive]) != .orderedSame {
                parts.append(CaptionPart(text: original, truncates: true))
            }
            if !hit.subtitle.isEmpty { parts.append(CaptionPart(text: hit.subtitle)) }
            return parts
        case .book:
            var parts = [CaptionPart(text: hit.isAudiobook == true ? "Аудио" : "Книга")]
            if !hit.subtitle.isEmpty { parts.append(CaptionPart(text: hit.subtitle, truncates: true)) }
            return parts
        case .director:
            return role("Режиссёр", works: results.personCounts[hit.id], one: "фильм", few: "фильма", many: "фильмов")
        case .writer:
            return role("Автор", works: results.personCounts[hit.id], one: "книга", few: "книги", many: "книг")
        case .actor:
            let title = hit.subtitle.isEmpty ? "Актёр" : hit.subtitle
            return role(title, works: results.personCounts[hit.id], one: "фильм", few: "фильма", many: "фильмов")
        case .track, .album, .artist, .playlist:
            return musicCaption(hit)
        }
    }

    private func role(_ title: String, works: Int?, one: String, few: String, many: String) -> [CaptionPart] {
        guard let works, works > 1 else { return [CaptionPart(text: title)] }
        let count = "\(works) \(CollectionCopy.plural(works, one: one, few: few, many: many))"
        return [CaptionPart(text: title), CaptionPart(text: count)]
    }

    /// Справа: у фильма — закладка «Позже» (то же «Любимое», что на экране тайтла),
    /// у книги — «+» в «Буду читать», у аудиокниги — свой «+», отдельно от книги
    /// (решение пользователя 2026-10-31); у персон — ничего.
    private func accessory(_ hit: SearchHit, _ results: SearchState.TabResults) -> SearchRowAccessory? {
        switch hit.kind {
        case .movie:
            return .bookmark(isOn: collection.isFavorite(hit: hit) ?? false) {
                _ = collection.toggleFavorite(hit: hit)
            }
        case .book:
            return .add(isOn: collection.isFavorite(hit: hit) ?? false) {
                _ = collection.toggleFavorite(hit: hit)
            }
        case .track, .album, .artist, .playlist, .director, .writer, .actor:
            return nil
        }
    }

    /// «Смотреть» строки — сразу киноплеер, как кнопка экрана тайтла: фильм, сериал —
    /// с серии, на которой остановились. Клавиатура уходит — плеер встаёт поверх всего.
    private func watch(_ hit: SearchHit) {
        UIImpactFeedbackGenerator(style: .medium)
            .impactOccurred(intensity: ShowcaseMotion.tapHapticIntensity)
        search.remember(hit)
        if actionBar.isSearchFocused { keyboard.dismissSmoothly() }
        Task { await MovieWatch.start(hit, actionBar: actionBar) }
    }
}

// MARK: - Строка кино и книг

/// Часть подписи строки. Название, автор и исполнитель уступают место соседям —
/// обрезаются первыми: «Le Fabuleux Destin d… · 2003», «Книга · Янис Варуфа…».
struct CaptionPart: Hashable {
    let text: String
    var truncates = false
}

/// Что справа у строки — закладка фильма или «+» книги.
enum SearchRowAccessory {
    case bookmark(isOn: Bool, toggle: () -> Void)
    case add(isOn: Bool, toggle: () -> Void)
}

/// Строка таба «Кино» или «Книги» — `list-item / media` макетов: обложка 76, название
/// до двух строк, подпись через точку; у фильма, который можно смотреть, — «Смотреть»
/// под подписью (энциклопедический тайтл — без неё); справа — закладка или «+».
///
/// Содержимое встаёт на место скелетона без кроссфейда строки: заливка обложки та же,
/// что у скелетона, проявляются только картинка и текст (как карточки сетки).
struct SearchMediaRow: View {
    let hit: SearchHit
    let caption: [CaptionPart]
    let isFirst: Bool
    var onWatch: (() -> Void)? = nil
    var accessory: SearchRowAccessory? = nil
    /// Строка внутри кнопки — проседает под пальцем; без маршрута — стоит.
    var isPressable = true

    /// Картинка и текст проявились — один раз на строку.
    @State private var isContentShown = false

    var body: some View {
        HStack(spacing: SearchMediaLayout.gap) {
            SearchMediaCover(hit: hit, isContentShown: isContentShown)

            VStack(alignment: .leading, spacing: SearchMediaLayout.buttonGap) {
                VStack(alignment: .leading, spacing: SearchMediaLayout.captionGap) {
                    Text(hit.title)
                        .plusText(.textM, .medium)
                        .foregroundStyle(Color.fillOne)
                        .lineLimit(2)
                    if !caption.isEmpty {
                        DotCaptionLine(parts: caption)
                    }
                }
                if let onWatch {
                    PlusButton("Смотреть", icon: "iconPlay", type: .secondary, size: .s, haptic: .inAction, action: onWatch)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(isContentShown ? 1 : 0)

            accessoryButton
                .padding(.trailing, SearchMediaLayout.accessoryInset)
                .opacity(isContentShown ? 1 : 0)
        }
        .padding(.horizontal, SearchMediaLayout.side)
        .padding(.vertical, SearchMediaLayout.vertical)
        .contentShape(.rect)
        // Отклик рисует строка, а не кнопка вокруг (`BareButtonStyle`): проседает
        // содержимое, черты стоят. Палец на «Смотреть» и закладке достаётся им.
        .pressScale(PressMotion.rowScale, isEnabled: isPressable)
        .overlay(alignment: .bottom) { SearchRowDivider() }
        .overlay(alignment: .top) { if isFirst { SearchRowDivider() } }
        .onAppear {
            guard !isContentShown else { return }
            withAnimation(MosaicMotion.contentAppear) { isContentShown = true }
        }
    }

    @ViewBuilder
    private var accessoryButton: some View {
        switch accessory {
        case .bookmark(let isOn, let toggle):
            PlusButton(type: .plain, size: .m, accessibilityTitle: isOn ? "Убрать из «Позже»" : "Позже", action: toggle) {
                BookmarkGlyph(isSaved: isOn, box: PlusButtonSize.m.iconBox, offColor: .fillFive, offIcon: "iconBookmarkPlain")
            }
        case .add(let isOn, let toggle):
            PlusButton(type: .plain, size: .m, accessibilityTitle: isOn ? "Убрать из «Буду читать»" : "Буду читать", action: toggle) {
                AddGlyph(isAdded: isOn, box: PlusButtonSize.m.iconBox, offColor: .fillFive)
            }
        case nil:
            EmptyView()
        }
    }
}

/// Разделитель строк — Fill/Eight 0.5 с полями экрана, как у строк полной выдачи.
private struct SearchRowDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.fillEight)
            .frame(height: 0.5)
            .padding(.horizontal, SearchMediaLayout.side)
    }
}

/// Подпись через точку 3 с зазорами 4 — строки табов выдачи и полных списков.
struct DotCaptionLine: View {
    let parts: [CaptionPart]

    var body: some View {
        HStack(spacing: SearchMediaLayout.dotGap) {
            ForEach(parts.indices, id: \.self) { index in
                if index > 0 {
                    Circle()
                        .fill(Color.fillSeven)
                        .frame(width: SearchMediaLayout.dot, height: SearchMediaLayout.dot)
                }
                let part = parts[index]
                Text(part.text)
                    .plusText(.textM, .medium)
                    .foregroundStyle(Color.fillSubtitle)
                    .lineLimit(1)
                    .fixedSize(horizontal: !part.truncates, vertical: false)
                    .layoutPriority(part.truncates ? 0 : 1)
            }
        }
    }
}

/// Обложка строки музыки — 80: квадрат r8, у исполнителя круг; у трека — кнопка play
/// слева снизу (знак, что строка играет, а не открывает альбом). Играет этот трек —
/// на ней пауза.
private struct SearchMusicThumbnail: View {
    let hit: SearchHit

    @Environment(ActionBarState.self) private var actionBar

    var body: some View {
        Group {
            if hit.kind == .artist {
                CollectionArtwork(
                    source: hit.artwork,
                    width: CollectionListLayout.cover,
                    height: CollectionListLayout.cover,
                    shape: Circle()
                )
            } else {
                CollectionArtwork(
                    source: hit.artwork,
                    width: CollectionListLayout.cover,
                    height: CollectionListLayout.cover,
                    shape: RoundedRectangle(cornerRadius: SearchMediaLayout.musicCoverRadius, style: .continuous)
                )
            }
        }
        .overlay(alignment: .bottomLeading) {
            if hit.kind == .track {
                MosaicPlayBadge(isPlaying: isPlaying, size: SearchMediaLayout.playButton)
                    .padding(SearchMediaLayout.playInset)
            }
        }
    }

    private var isPlaying: Bool {
        actionBar.isMiniPlayerVisible && actionBar.music?.id == hit.id && actionBar.isMusicPlaying
    }
}

/// Обложка строки: постер 2:3 у фильма и режиссёра, книга в проекции (`BookFigure`),
/// квадрат у аудиокниги, круг у автора.
private struct SearchMediaCover: View {
    let hit: SearchHit
    let isContentShown: Bool

    var body: some View {
        if hit.kind == .book, hit.isAudiobook != true {
            // Книга — общий рисунок по ширине обложки: высоту дают пропорции, снятые
            // до показа.
            let book = BookFigureGeometry.fitting(width: SearchMediaLayout.cover, aspect: hit.artworkAspect)
            BookFigure(geometry: book.geometry, coverWidth: book.coverWidth) { artwork }
        } else {
            let form = shape
            // Заливка — та же, что у скелетона: строка встаёт на его место без смены цвета.
            PlusSkeleton.fill
                .frame(width: SearchMediaLayout.cover, height: height)
                .overlay { artwork }
                .coverArtworkMissing(hit.artwork == nil)
                .clipShape(form)
                .coverBorder(form)
        }
    }

    private var height: CGFloat {
        switch hit.kind {
        case .movie, .director, .actor: SearchMediaLayout.posterHeight
        case .track, .album, .artist, .playlist, .book, .writer: SearchMediaLayout.cover
        }
    }

    private var shape: AnyShape {
        switch hit.kind {
        case .writer, .artist:
            AnyShape(Circle())
        case .track, .album, .playlist, .movie, .book, .director, .actor:
            AnyShape(RoundedRectangle(cornerRadius: SearchMediaLayout.coverRadius, style: .continuous))
        }
    }

    @ViewBuilder
    private var artwork: some View {
        if let source = hit.artwork {
            ResolvedArtwork(source: source, appear: MosaicMotion.contentAppear) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color.clear
            }
            .opacity(isContentShown ? 1 : 0)
        }
    }
}

/// Скелетон строки таба — того же габарита, пока выдача раздела собирается: постер 2:3
/// у кино, книга в проекции у книг, квадрат 80 у музыки, полоски на месте строк.
/// Разделители — сразу, как у строк (правка пользователя 2026-10-31); кромки у обложки
/// скелетона нет.
struct SearchMediaSkeletonRow: View {
    let kind: SearchState.Section.Kind
    let isFirst: Bool

    var body: some View {
        HStack(spacing: SearchMediaLayout.gap) {
            cover
            VStack(alignment: .leading, spacing: SearchMediaLayout.skeletonBarGap) {
                SkeletonBar(width: SearchMediaLayout.skeletonTitleBar)
                SkeletonBar(width: SearchMediaLayout.skeletonSubtitleBar)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, SearchMediaLayout.side)
        .padding(.vertical, SearchMediaLayout.vertical)
        .overlay(alignment: .bottom) { divider }
        .overlay(alignment: .top) { if isFirst { divider } }
        .accessibilityHidden(true)
    }

    /// Разделитель — тот же, что у строк своего таба: музыка — строка полных списков.
    @ViewBuilder
    private var divider: some View {
        if kind == .music {
            ListDivider().padding(.horizontal, CollectionListLayout.side)
        } else {
            SearchRowDivider()
        }
    }

    @ViewBuilder
    private var cover: some View {
        if kind == .books {
            let book = BookFigureGeometry.fitting(width: SearchMediaLayout.cover, aspect: nil)
            BookFigure(geometry: book.geometry, coverWidth: book.coverWidth) { EmptyView() }
        } else if kind == .music {
            RoundedRectangle(cornerRadius: SearchMediaLayout.musicCoverRadius, style: .continuous)
                .plusSkeleton()
                .frame(width: CollectionListLayout.cover, height: CollectionListLayout.cover)
        } else {
            RoundedRectangle(cornerRadius: SearchMediaLayout.coverRadius, style: .continuous)
                .plusSkeleton()
                .frame(width: SearchMediaLayout.cover, height: SearchMediaLayout.posterHeight)
        }
    }
}
