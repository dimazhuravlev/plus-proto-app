import SwiftUI
import UIKit

/// Числа «Моей волны» — макет `generator` (файл Music, `13668:68497`). Кадр 375 перенесён
/// на холст 402: вертикаль считается от низа навигации (в макете 100, у нас — безопасная
/// зона + ряд 56), поля 16 те же.
enum MyVibeLayout {
    /// Шейдер — квадрат во всю ширину экрана, верх на 85 выше низа навигации (y 15 в макете)
    static var shaderSize: CGFloat { PlusMetrics.designWidth }
    static let shaderAboveNav: CGFloat = 85
    /// Затемнение шейдера — чёрный 25 % (`bg image` макета)
    static let shaderDim: Double = 0.25
    /// Заголовок на 156 ниже низа навигации (y 256 в макете)
    static let headerBelowNav: CGFloat = 156
    static let side: CGFloat = 16
    static let blockGap: CGFloat = 16
    static let playSize: CGFloat = 48
    static let playIcon: CGFloat = 24
    static let titleToPlay: CGFloat = 8
    static let infoIcon: CGFloat = 16
    static let descriptionGap: CGFloat = 4
    /// Чипы станций: высота 48, зазор 6, фото 40 с полем 4
    static let chipHeight: CGFloat = 48
    static let chipGap: CGFloat = 6
    static let chipPhoto: CGFloat = 40
    static let chipPhotoInset: CGFloat = 4
    static let chipTextInset: CGFloat = 20
    static let chipContentGap: CGFloat = 6
    static let chipBlur: CGFloat = 12
    /// Треки — колонки по три строки, следующая выглядывает на 40
    /// (`carousel / Music / opened playlist`, как «Популярные треки» исполнителя)
    static let tracksPerColumn = 3
    static let trackColumnPeek: CGFloat = 40
    static let trackColumnGap: CGFloat = 16
    static var trackColumnWidth: CGFloat { PlusMetrics.designWidth - side * 2 - trackColumnPeek }
    static let tracksTop: CGFloat = 8
}

/// Главная Музыки — содержимое таба (задача пользователя 2026-10-04): сверху общая
/// навигация витрин с фильтрами «Моя волна», «Для вас», «Тренды» (кнопок справа
/// из скриншота нет — справа аватар, как на всех витринах). «Моя волна» — по макету
/// `generator`: живой шейдер фоном, заголовок с белой кнопкой, станции, треки.
/// «Для вас» и «Тренды» не спроектированы — название раздела.
struct MusicHomeScreen: View {
    @Environment(MusicHomeCatalog.self) private var catalog
    @Environment(AppNavigationState.self) private var navigation

    static let filters = ["Моя волна", "Для вас", "Тренды"]

    @State private var filter = 0
    @State private var scrollOffset: CGFloat = 0
    @State private var scrollPosition = ScrollPosition(edge: .top)

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            if filter == 0 {
                feed
            } else {
                ServiceFilterStub(title: Self.filters[filter])
            }
        }
        .overlay(alignment: .top) {
            ServiceTopNav(
                filters: Self.filters,
                selection: $filter,
                scrollOffset: filter == 0 ? scrollOffset : 0
            )
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await catalog.loadIfNeeded() }
    }

    private var feed: some View {
        ScrollView {
            MyVibeBlock()
                .padding(.bottom, CinemaLayout.feedBottom)
        }
        .scrollIndicators(.hidden)
        // Шейдер начинается за навигацией — от физического верха экрана.
        .ignoresSafeArea(edges: .top)
        .scrollPosition($scrollPosition)
        .trackNavBarScroll(into: $scrollOffset)
        .onChange(of: navigation.scrollToTopRequests[.music]) {
            withAnimation(ShowcaseScrollMotion.toTop) { scrollPosition.scrollTo(edge: .top) }
        }
    }
}

/// Блок «Моя волна»: шейдер, заголовок с кнопкой, подпись, станции и треки.
private struct MyVibeBlock: View {
    @Environment(MusicHomeCatalog.self) private var catalog
    @Environment(ActionBarState.self) private var actionBar

    /// Низ навигации от физического верха — от него отмеряется вертикаль макета.
    private var navBottom: CGFloat {
        ServiceTopNavLayout.topSafeArea + ServiceTopNavLayout.rowHeight
    }

    var body: some View {
        ZStack(alignment: .top) {
            VibeShader()
                .frame(width: MyVibeLayout.shaderSize, height: MyVibeLayout.shaderSize)
                .padding(.top, navBottom - MyVibeLayout.shaderAboveNav)

            VStack(alignment: .leading, spacing: MyVibeLayout.blockGap) {
                header
                    .padding(.horizontal, MyVibeLayout.side)
                stations
                tracks
                    .padding(.top, MyVibeLayout.tracksTop)
            }
            .padding(.top, navBottom + MyVibeLayout.headerBelowNav)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Заголовок

    private var isVibePlaying: Bool {
        actionBar.mode == .music && actionBar.music?.id == MusicHomeCatalog.vibeID && actionBar.isMusicPlaying
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .bottom, spacing: MyVibeLayout.titleToPlay) {
                Text("Моя волна")
                    .plusHeadline(.xxl)
                    .foregroundStyle(Color.fillOne)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: playVibe) {
                    Image(isVibePlaying ? "iconPause" : "iconPlay")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: MyVibeLayout.playIcon, height: MyVibeLayout.playIcon)
                        .foregroundStyle(Color.black)
                        .frame(width: MyVibeLayout.playSize, height: MyVibeLayout.playSize)
                        .background(Color.white, in: Circle())
                }
                .buttonStyle(PressScaleButtonStyle())
                .accessibilityLabel(isVibePlaying ? "Пауза" : "Слушать Мою волну")
            }

            HStack(spacing: MyVibeLayout.descriptionGap) {
                Text("Персональный поток музыки")
                    .plusText(.textM, .medium)
                    .foregroundStyle(Color.fillSubtitle)
                Image("iconInfo")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: MyVibeLayout.infoIcon, height: MyVibeLayout.infoIcon)
                    .foregroundStyle(Color.fillSubtitle)
            }
        }
    }

    /// Та же «Моя Волна», что у блока витрины: тот же id — повторный тап ставит её
    /// на паузу, а не включает заново.
    private func playVibe() {
        UIImpactFeedbackGenerator(style: .medium)
            .impactOccurred(intensity: ShowcaseMotion.tapHapticIntensity)
        actionBar.open(.music(MusicNowPlaying(
            id: MusicHomeCatalog.vibeID,
            cover: .asset("mockPlayerCover"),
            title: "Моя Волна",
            artist: "Атмосферный постпанк, когда внутри пасмурно"
        )))
    }

    // MARK: Станции

    private var stations: some View {
        ScrollView(.horizontal) {
            HStack(spacing: MyVibeLayout.chipGap) {
                ForEach(catalog.stations) { station in
                    Button { play(station) } label: { chip(station) }
                        .buttonStyle(PressScaleButtonStyle())
                }
            }
        }
        .scrollIndicators(.hidden)
        .contentMargins(.horizontal, MyVibeLayout.side, for: .scrollContent)
        .frame(height: MyVibeLayout.chipHeight)
    }

    private func chip(_ station: MusicHomeCatalog.Station) -> some View {
        HStack(spacing: MyVibeLayout.chipContentGap) {
            if station.isArtist {
                PlusSkeleton.fill
                    .overlay {
                        if let photo = station.photo {
                            SkeletonArtwork(source: photo)
                        }
                    }
                    .frame(width: MyVibeLayout.chipPhoto, height: MyVibeLayout.chipPhoto)
                    .clipShape(Circle())
                    .overlay { Circle().strokeBorder(Color.fillNine, lineWidth: PlusMetrics.hairline) }
            }
            Text(station.title)
                .plusText(.textM, .medium)
                .foregroundStyle(Color.fillOne)
                .fixedSize()
        }
        .padding(.leading, station.isArtist ? MyVibeLayout.chipPhotoInset : MyVibeLayout.chipTextInset)
        .padding(.trailing, MyVibeLayout.chipTextInset)
        .frame(height: MyVibeLayout.chipHeight)
        .glassSurface(Capsule(style: .continuous), blur: MyVibeLayout.chipBlur)
    }

    /// Станция — та же «Моя Волна», только настроенная на исполнителя или настроение.
    private func play(_ station: MusicHomeCatalog.Station) {
        UIImpactFeedbackGenerator(style: .medium)
            .impactOccurred(intensity: ShowcaseMotion.tapHapticIntensity)
        actionBar.open(.music(MusicNowPlaying(
            id: "\(MusicHomeCatalog.vibeID)-\(station.id)",
            cover: station.photo ?? .asset("mockPlayerCover"),
            title: "Моя Волна",
            artist: station.title
        )))
    }

    // MARK: Треки

    private var trackColumns: [[MusicHomeCatalog.Track]] {
        stride(from: 0, to: catalog.tracks.count, by: MyVibeLayout.tracksPerColumn).map {
            Array(catalog.tracks[$0..<min($0 + MyVibeLayout.tracksPerColumn, catalog.tracks.count)])
        }
    }

    @ViewBuilder
    private var tracks: some View {
        let height = EntityTrackRow.height * CGFloat(MyVibeLayout.tracksPerColumn)
        ZStack(alignment: .top) {
            if catalog.isLoaded {
                ScrollView(.horizontal) {
                    LazyHStack(alignment: .top, spacing: MyVibeLayout.trackColumnGap) {
                        ForEach(trackColumns.indices, id: \.self) { index in
                            let column = trackColumns[index]
                            VStack(spacing: 0) {
                                ForEach(column) { track in
                                    EntityTrackRow(
                                        cover: track.cover,
                                        title: track.title,
                                        artist: track.artist,
                                        showsDivider: track.id != column.last?.id
                                    )
                                    .onTapGesture { play(track) }
                                }
                            }
                            .frame(width: MyVibeLayout.trackColumnWidth)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollIndicators(.hidden)
                .contentMargins(.horizontal, MyVibeLayout.side, for: .scrollContent)
                .transition(.opacity)
            } else {
                VStack(spacing: 0) {
                    ForEach(0..<MyVibeLayout.tracksPerColumn, id: \.self) { _ in
                        EntityTrackRowSkeleton()
                    }
                }
                .padding(.horizontal, MyVibeLayout.side)
                .transition(.opacity)
            }
        }
        // Высота — явная, как у каруселей витрин: `LazyHStack` её сам не меряет.
        .frame(height: height)
        .animation(EntityMotion.reveal, value: catalog.isLoaded)
    }

    private func play(_ track: MusicHomeCatalog.Track) {
        UIImpactFeedbackGenerator(style: .medium)
            .impactOccurred(intensity: ShowcaseMotion.tapHapticIntensity)
        actionBar.open(.music(track.nowPlaying))
    }
}

/// Шейдер «Моей волны» — видео из макета (прислано пользователем, `New_shader.mov`):
/// 1080×1080, 30 к/с, петля сшита кроссфейдом в секунду — у исходника первый
/// и последний кадры не совпадали. Поверх — чёрный 25 %, как в макете; режим
/// наложения «экран» на чёрном фоне равен обычному.
private struct VibeShader: View {
    @State private var playback = LoopingVideoPlayback()
    @State private var isReady = false

    var body: some View {
        LoopingVideoLayer(player: playback.queue) {
            isReady = true
        }
        .opacity(isReady ? 1 : 0)
        .animation(.easeOut(duration: 0.4), value: isReady)
        .overlay { Color.black.opacity(MyVibeLayout.shaderDim) }
        .allowsHitTesting(false)
        .onAppear { playback.start(bundled: "my-vibe-shader") }
        .onDisappear { playback.pause() }
        .accessibilityHidden(true)
    }
}
