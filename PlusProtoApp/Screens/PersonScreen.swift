import SwiftUI

// MARK: - Геометрия

/// Экран персоны — макет `2455:32136` (исполнитель, «Taylor Swift»). Холст макета 375,
/// у проекта 402: фото во всю ширину остаётся квадратом, поля 16 — как есть.
private enum PersonLayout {
    static let side: CGFloat = EntityCoverLayout.side
    /// Фото — квадрат во всю ширину экрана, от физического верха (`. / cover` 375×375)
    static var photoSize: CGFloat { PlusMetrics.designWidth }
    /// Блок названия наезжает на фото на 79 (`mb-[-79px]` макета)
    static let titleOverlap: CGFloat = 79
    /// Сколько фото занимает в потоке — до верха блока названия
    static var photoZoneHeight: CGFloat { photoSize - titleOverlap }
    /// Затемнение к чёрному — нижние 35.73 % фото (`inset 64.27% 0 0 0` макета)
    static let scrimShare: CGFloat = 0.3573

    // «Популярные треки» — колонки по три строки, следующая выглядывает из-за края
    // (`carousel / Music / opened playlist`).
    static let tracksPerColumn = 3
    static let trackColumnPeek: CGFloat = 40
    static let trackColumnGap: CGFloat = 16
    static var trackColumnWidth: CGFloat { photoSize - side * 2 - trackColumnPeek }

    static let skeletonCards = 3
    static let skeletonRows = 6
    /// Подпись пустого списка — Text M, серым
    static let emptyTop: CGFloat = 8

    /// Пороги навбара — в той же связке с названием, что у альбома и книги:
    /// подложка — когда шапка почти ушла под бар, имя — когда под бар уходит оно.
    static var navBarThresholds: EntityNavBarThresholds {
        EntityNavBarThresholds(
            backgroundStart: photoZoneHeight - 122,
            backgroundRamp: 80,
            titleStart: photoZoneHeight - 22,
            titleRamp: 90
        )
    }
}

// MARK: - Экран

/// Экран персоны — исполнителя, режиссёра, писателя (задача пользователя 2026-10-04).
/// Шапка у всех одна (макет `2455:32136`): фото во всю ширину с затемнением к низу,
/// поверх — общий блок названия с именем кеглем по длине. Фото тянется за оттягом —
/// той же резиной, что шапки альбома и книги. Дальше — по роли:
/// - исполнитель — ряд «Слушать», «нравится», «поделиться» и секции «Популярные
///   треки» колонками по три, «Альбомы», «Похожие исполнители»;
/// - режиссёр и писатель — без ряда действий: под именем сразу все его фильмы или
///   книги плоским списком, ячейками полной выдачи поиска, без заголовка (правка
///   пользователя тем же днём).
/// Макет условный: на нём стоят компоненты, которые в проекте уже есть, — заголовки
/// секций, карточки каруселей, строки треков и выдачи, ступени кегля названия.
struct PersonScreen: View {
    let role: PersonRole
    let entity: EntityRef

    @Environment(ActionBarState.self) private var actionBar
    @Environment(AppNavigationState.self) private var navigation
    @State private var store = PersonStore()
    @State private var scrollOffset: CGFloat = 0
    /// Сердца строк — визуальные, на время экрана, как в полной выдаче.
    @State private var liked: Set<String> = []

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: 0) {
                    header
                    content
                }
                .frame(maxWidth: .infinity)
                .animation(EntityMotion.reveal, value: store.isLoaded)
            }
            .scrollIndicators(.hidden)
            // Хром (таббар + action bar) на этом экране виден — лента едет под ним.
            .contentMargins(
                .bottom,
                PlusChromeMetrics.contentBottomInset + AlbumLayout.bottomClearance,
                for: .scrollContent
            )
            // Фото начинается от физического верха экрана.
            .ignoresSafeArea(edges: .top)
            .trackNavBarScroll(into: $scrollOffset)

            EntityNavBar(
                title: entity.title,
                artwork: photo,
                isArtworkCircular: true,
                scrollOffset: scrollOffset,
                thresholds: PersonLayout.navBarThresholds
            )
        }
        .background(Color.black.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task { await store.load(role: role, entity: entity) }
    }

    // MARK: Шапка

    /// Фото маршрута; нет своего (писатель с экрана книги) — из API, когда приедет.
    private var photo: ArtworkSource? {
        let own = entity.artwork
        if own.remoteURL != nil || !(own.fallbackAsset ?? "").isEmpty { return own }
        return store.photo
    }

    /// Оттяг вниз. Скролл вверх шапку не трогает — она обычным образом уезжает.
    private var pull: CGFloat { max(0, -scrollOffset) }

    /// Рост фото: в жизни равен оттягу; в дебаге (`-debugAlbumPull <pt>`, общий
    /// с альбомом и книгой) к нему добавляется подставной, компенсация — на реальном.
    private var growth: CGFloat {
        #if DEBUG
        pull + CGFloat(UserDefaults.standard.double(forKey: "debugAlbumPull"))
        #else
        pull
        #endif
    }

    private var header: some View {
        VStack(spacing: 0) {
            photoZone

            EntityTitleBlock(
                title: entity.title,
                actions: [.like, .share],
                showsControls: role == .artist
            ) {
                EmptyView()
            } primary: {
                EntityPrimaryButton(
                    icon: isPlayingArtist ? "iconPause" : "iconPlay",
                    title: isPlayingArtist ? "Пауза" : "Слушать",
                    action: playTop
                )
            }
        }
        // Черта под шапкой — у исполнителя, перед секциями. У писателя и режиссёра
        // список начинается своей чертой над первой строкой.
        .overlay(alignment: .bottom) {
            if role == .artist {
                Rectangle()
                    .fill(Color.fillNine)
                    .frame(height: PlusMetrics.hairline)
            }
        }
    }

    /// Фото тянется за оттягом той же резиной, что фон шапок альбома и книги:
    /// компенсирует оттяг (`offset(y: -pull)`) и растёт от верхней кромки на его
    /// величину — низ остаётся приклеен к блоку названия.
    private var photoZone: some View {
        let size = PersonLayout.photoSize
        let scale = (size + growth) / size
        return ZStack(alignment: .top) {
            photoLayer
                .frame(width: size, height: size)
                .clipped()
                .overlay(alignment: .bottom) {
                    MovieScrim.gradient(peak: 1, from: .top, to: .bottom)
                        .frame(height: size * PersonLayout.scrimShare)
                }
                .scaleEffect(scale, anchor: .top)
                .offset(y: -pull)
                .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity)
        // По верху: фото выше своей зоны в потоке и заходит под блок названия.
        .frame(height: PersonLayout.photoZoneHeight, alignment: .top)
    }

    /// Фото, а пока его нет — скелетон; фото не нашлось вовсе — первая буква имени.
    @ViewBuilder
    private var photoLayer: some View {
        ZStack {
            if let photo {
                ArtworkImage(source: photo)
                    .scaledToFill()
                    .transition(.opacity)
            } else if !store.isLoaded {
                PlusSkeleton.fill
                    .transition(.opacity)
            } else {
                Color.buttonsPrimary
                    .overlay {
                        Text(String(entity.title.prefix(1)).uppercased())
                            .plusHeadline(.xxl)
                            .foregroundStyle(Color.fillSubtitle)
                    }
                    .transition(.opacity)
            }
        }
    }

    // MARK: Контент

    @ViewBuilder
    private var content: some View {
        switch role {
        case .artist:
            VStack(spacing: 0) {
                tracksSection
                albumsSection
                similarSection
            }
        case .director:
            worksSection(empty: "Фильмов не нашлось")
        case .writer:
            worksSection(empty: "Книг не нашлось")
        }
    }

    // MARK: Исполнитель

    /// «Популярные треки» — колонки по три строки, листаются колонкой целиком:
    /// следующая выглядывает из-за края (`opened playlist` макета).
    private var tracksSection: some View {
        ZStack(alignment: .top) {
            if !store.isLoaded {
                VStack(spacing: 0) {
                    EntitySectionHeaderSkeleton()
                    VStack(spacing: 0) {
                        ForEach(0..<PersonLayout.tracksPerColumn, id: \.self) { _ in
                            EntityTrackRowSkeleton()
                        }
                    }
                    .padding(.horizontal, PersonLayout.side)
                }
                .padding(.vertical, EntitySectionLayout.sectionPad)
                .transition(.opacity)
            } else if !store.tracks.isEmpty {
                VStack(spacing: 0) {
                    EntitySectionHeader(title: "Популярные треки")
                    ScrollView(.horizontal) {
                        LazyHStack(alignment: .top, spacing: PersonLayout.trackColumnGap) {
                            ForEach(trackColumns.indices, id: \.self) { index in
                                let column = trackColumns[index]
                                VStack(spacing: 0) {
                                    ForEach(column) { track in
                                        EntityTrackRow(
                                            cover: track.cover,
                                            title: track.title,
                                            artist: track.artist,
                                            isExplicit: track.isExplicit,
                                            showsDivider: track.id != column.last?.id
                                        )
                                        // Тап по строке включает трек — как в треклисте альбома.
                                        .onTapGesture { play(track) }
                                    }
                                }
                                .frame(width: PersonLayout.trackColumnWidth)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollTargetBehavior(.viewAligned)
                    .scrollIndicators(.hidden)
                    .contentMargins(.horizontal, PersonLayout.side, for: .scrollContent)
                }
                .padding(.vertical, EntitySectionLayout.sectionPad)
                .transition(.opacity)
            }
        }
    }

    private var trackColumns: [[PersonStore.Track]] {
        stride(from: 0, to: store.tracks.count, by: PersonLayout.tracksPerColumn).map { start in
            Array(store.tracks[start..<min(start + PersonLayout.tracksPerColumn, store.tracks.count)])
        }
    }

    private var albumsSection: some View {
        ZStack(alignment: .top) {
            if !store.isLoaded {
                carouselSkeleton { EntityAlbumCardSkeleton() }
                    .transition(.opacity)
            } else if !store.albums.isEmpty {
                VStack(spacing: 0) {
                    EntitySectionHeader(title: "Альбомы")
                    ScrollView(.horizontal) {
                        LazyHStack(alignment: .top, spacing: EntitySectionLayout.cardGap) {
                            ForEach(store.albums) { album in
                                Button { open(album.route) } label: {
                                    EntityAlbumCard(
                                        cover: album.artwork,
                                        title: album.title,
                                        detail: album.subtitle.isEmpty ? nil : album.subtitle,
                                        isExplicit: store.explicitAlbums.contains(album.id)
                                    )
                                }
                                .buttonStyle(PressScaleButtonStyle(pressedScale: 0.97))
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                    .contentMargins(.horizontal, PersonLayout.side, for: .scrollContent)
                }
                .padding(.vertical, EntitySectionLayout.sectionPad)
                .transition(.opacity)
            }
        }
    }

    private var similarSection: some View {
        ZStack(alignment: .top) {
            if !store.isLoaded {
                carouselSkeleton { EntityPersonCardSkeleton() }
                    .transition(.opacity)
            } else if !store.similar.isEmpty {
                VStack(spacing: 0) {
                    EntitySectionHeader(title: "Похожие исполнители")
                    ScrollView(.horizontal) {
                        LazyHStack(alignment: .top, spacing: EntitySectionLayout.cardGap) {
                            ForEach(store.similar) { artist in
                                Button { open(artist.route) } label: {
                                    EntityPersonCard(photo: artist.artwork, name: artist.title)
                                }
                                .buttonStyle(PressScaleButtonStyle(pressedScale: 0.97))
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                    .contentMargins(.horizontal, PersonLayout.side, for: .scrollContent)
                }
                .padding(.vertical, EntitySectionLayout.sectionPad)
                .transition(.opacity)
            }
        }
    }

    /// Скелетон секции-карусели: полоса заголовка и карточки — в ленте, как настоящая
    /// карусель: последняя уходит за край, а не распирает колонку.
    private func carouselSkeleton(@ViewBuilder card: () -> some View) -> some View {
        let cardView = card()
        return VStack(spacing: 0) {
            EntitySectionHeaderSkeleton()
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: EntitySectionLayout.cardGap) {
                    ForEach(0..<PersonLayout.skeletonCards, id: \.self) { _ in cardView }
                }
            }
            .scrollDisabled(true)
            .scrollIndicators(.hidden)
            .contentMargins(.horizontal, PersonLayout.side, for: .scrollContent)
        }
        .padding(.vertical, EntitySectionLayout.sectionPad)
    }

    // MARK: Режиссёр и писатель

    /// Все фильмы режиссёра или книги писателя — плоским списком, ячейками полной
    /// выдачи поиска, сразу под именем, без заголовка (правка пользователя 2026-10-04).
    private func worksSection(empty: String) -> some View {
        ZStack(alignment: .top) {
            if !store.isLoaded {
                VStack(spacing: 0) {
                    ForEach(0..<PersonLayout.skeletonRows, id: \.self) { _ in
                        SearchListSkeletonRow(isPoster: true)
                    }
                }
                .transition(.opacity)
            } else if store.works.isEmpty {
                Text(empty)
                    .plusText(.textM, .medium)
                    .foregroundStyle(Color.fillSubtitle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, PersonLayout.side)
                    .padding(.top, PersonLayout.emptyTop)
                    .transition(.opacity)
            } else {
                VStack(spacing: 0) {
                    ForEach(store.works) { hit in
                        Button { open(hit.route) } label: {
                            SearchListRow(
                                hit: hit,
                                isFirst: hit.id == store.works.first?.id,
                                isLiked: liked.contains(hit.id),
                                onLike: { toggleLike(hit.id) }
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .transition(.opacity)
            }
        }
    }

    // MARK: Действия

    /// Переход — через навигацию, а не `NavigationLink`: экран режиссёра живёт и в стеке
    /// таба, и в слое фильма (из съёмочной группы), а у слоя стека нет — там переход
    /// встаёт в его стопку (`AppNavigationState.open`).
    private func open(_ route: EntityRoute?) {
        guard let route else { return }
        navigation.open(route)
    }

    private func toggleLike(_ id: String) {
        if liked.contains(id) { liked.remove(id) } else { liked.insert(id) }
    }

    private func playerID(_ track: PersonStore.Track) -> String {
        "dz-track-\(track.id)"
    }

    /// В плеере бара — музыка этого исполнителя (играет или на паузе).
    private var isBarOnThisArtist: Bool {
        actionBar.mode == .music && actionBar.music?.artist == entity.title
    }

    /// Играет ли сейчас этот исполнитель — от этого глиф и подпись пилюли.
    private var isPlayingArtist: Bool {
        isBarOnThisArtist && actionBar.isMusicPlaying
    }

    /// «Слушать» — музыка этого исполнителя: первый альбом из списка, с первого трека
    /// (правка пользователя 2026-10-04). Уже в баре — пауза или продолжение.
    private func playTop() {
        if isBarOnThisArtist {
            UIImpactFeedbackGenerator(style: .medium)
                .impactOccurred(intensity: ShowcaseMotion.tapHapticIntensity)
            actionBar.toggleMusicPlayback()
            return
        }
        if let target = store.listenTarget {
            UIImpactFeedbackGenerator(style: .medium)
                .impactOccurred(intensity: ShowcaseMotion.tapHapticIntensity)
            actionBar.open(.music(target))
        } else if let track = store.tracks.first {
            // Альбомов нет — самый популярный трек.
            play(track)
        }
    }

    /// Тот же вход, что у альбома: `open` с тем же id — пауза/продолжение, с другим — запуск.
    private func play(_ track: PersonStore.Track) {
        UIImpactFeedbackGenerator(style: .medium)
            .impactOccurred(intensity: ShowcaseMotion.tapHapticIntensity)
        actionBar.open(.music(MusicNowPlaying(
            id: playerID(track),
            cover: track.cover ?? entity.artwork,
            title: track.title,
            artist: track.artist,
            album: track.album,
            artistPicture: photo,
            isExplicit: track.isExplicit
        )))
    }
}
