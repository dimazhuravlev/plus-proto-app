import SwiftUI

/// Числа блока «Похоже на …» — `card / music / artist block` (`17305:29395`), карточка 343
/// на холсте 375. Карточка во всю ширину за полями 16, высота — тем же масштабом, что ширина:
/// фото сохраняет пропорции, ряд под ним — на `MusicCarouselFit.block`.
enum MusicArtistBlockLayout {
    static let side: CGFloat = 16
    static let designWidth: CGFloat = 343
    static let designHeight: CGFloat = 426
    static let radius: CGFloat = 24
    /// Фото сверху — 300 в высоту, под ним его зеркальное отражение
    static let photoHeight: CGFloat = 300
    /// Размытие низа — backdrop-blur 50 панели Figma, в коде вдвое меньше; начинается
    /// на 40 % высоты сверху и набирает силу к 60 %
    static let blur: CGFloat = 25
    static let blurStart: CGFloat = 0.403
    static let blurFull: CGFloat = 0.601
    /// Подкраска размытия тоном фона — 20 %
    static let blurTint: Double = 0.2
    /// Затемнение — с 151 сверху до низа, 50 % к 65 % своей высоты
    static let shadeTop: CGFloat = 151
    static let shadeOpacity: Double = 0.5
    static let shadeFull: CGFloat = 0.652
    static let playSize: CGFloat = 48
    static let playIcon: CGFloat = 24
    /// Микрошейдер над ▶ (`micro shader`) — 80, от кнопки на −16 по горизонтали и −21
    /// по вертикали: центр на 5 выше центра кнопки, поверх неё и начала имени
    static let shaderSize: CGFloat = 80
    static let shaderLeading: CGFloat = -16
    static let shaderRise: CGFloat = -5
    /// Блюр стеклянной ▶ — backdrop-blur 40 панели Figma
    static let playBlur: CGFloat = 20
    static let headerGap: CGFloat = 8
    static let headerBottom: CGFloat = 12
    /// «Похоже на» и имя — две строки Headline L с наездом −2
    static let titleGap: CGFloat = -2
    static let bottomPadding: CGFloat = 16
    static let rowGap: CGFloat = 8

    @MainActor
    static var width: CGFloat { PlusMetrics.screenWidth - 2 * side }
    @MainActor
    static var scale: CGFloat { width / designWidth }
    @MainActor
    static var height: CGFloat { designHeight * scale }
    /// Слот блока в ленте — с полями 16 сверху и снизу (`p-[16px]` макета).
    @MainActor
    static var slotHeight: CGFloat { height + 2 * side }
}

/// Блок «Похоже на …» — фото исполнителя на тоне фона, снизу размытое отражение, ▶ и ряд
/// похожих (исполнители и альбомы — общая `MusicCard`). Карточка — экран исполнителя
/// (правка пользователя 2026-10-17: «кавер артиста открывает экран артиста»), ▶ включает
/// его музыку, карточки ряда — свои экраны: палец на них достаётся им, карточка под ними
/// не проседает (`pressScale`, как у промо Кинопоиска).
struct MusicArtistBlockCard: View {
    let block: MusicArtistBlock

    @Environment(ActionBarState.self) private var actionBar
    @Environment(AppNavigationState.self) private var navigation
    @Environment(\.stackZoomNamespace) private var zoom

    private typealias Layout = MusicArtistBlockLayout

    private var isPlaying: Bool {
        guard let track = block.track, let music = actionBar.music else { return false }
        return actionBar.isMusicPlaying && music.containerID == track.containerID
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Layout.radius, style: .continuous)
        ZStack(alignment: .top) {
            (block.tone ?? Color.surfaceTwo)
            backdrop
            content
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .frame(width: Layout.width, height: Layout.height)
        .clipShape(shape)
        .coverBorder(shape)
        .modifier(MusicBlockZoomSource(route: block.route, zoom: zoom))
        .contentShape(shape)
        .pressScale(PressMotion.cardScale)
        .onTapGesture { navigation.open(block.route) }
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: Text(block.name)) { navigation.open(block.route) }
        .padding(Layout.side)
    }

    // MARK: Фон

    /// Фото и его отражение; ниже середины — размыто и притемнено.
    private var backdrop: some View {
        let photoHeight = Layout.photoHeight * Layout.scale
        let blurMask = LinearGradient(
            stops: [
                .init(color: .clear, location: Layout.blurStart),
                .init(color: .black, location: Layout.blurFull),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        return ZStack(alignment: .top) {
            photoPair(height: photoHeight)
            photoPair(height: photoHeight)
                .blur(radius: Layout.blur)
                .mask(blurMask)
            (block.tone ?? Color.surfaceTwo)
                .opacity(Layout.blurTint)
                .mask(blurMask)
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black.opacity(Layout.shadeOpacity), location: Layout.shadeFull),
                    .init(color: .black.opacity(Layout.shadeOpacity), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .padding(.top, Layout.shadeTop * Layout.scale)
        }
        .frame(width: Layout.width, height: Layout.height, alignment: .top)
        .clipped()
        .allowsHitTesting(false)
    }

    private func photoPair(height: CGFloat) -> some View {
        VStack(spacing: 0) {
            photo(height: height)
            photo(height: height)
                .scaleEffect(x: 1, y: -1)
        }
        .frame(width: Layout.width, height: Layout.height, alignment: .top)
    }

    private func photo(height: CGFloat) -> some View {
        Color.clear
            .frame(width: Layout.width, height: height)
            .overlay { SkeletonArtwork(source: block.photo) }
            .clipped()
    }

    // MARK: Содержимое

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Layout.headerGap) {
                playButton
                VStack(alignment: .leading, spacing: Layout.titleGap) {
                    Text("Похоже на")
                        .plusHeadline(.l)
                        .foregroundStyle(Color.fillSix)
                    Text(block.name)
                        .plusHeadline(.l)
                        .foregroundStyle(Color.fillOne)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .overlay(alignment: .leading) {
                SharedVideoLayer(video: .musicMicroShader, poster: "musicMicroShaderPoster")
                    .frame(width: Layout.shaderSize, height: Layout.shaderSize)
                    .offset(x: Layout.shaderLeading, y: Layout.shaderRise)
            }
            .padding(.horizontal, Layout.side)
            .padding(.bottom, Layout.headerBottom)

            row
                .padding(.bottom, Layout.bottomPadding)
        }
    }

    private var playButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium)
                .impactOccurred(intensity: ShowcaseMotion.tapHapticIntensity)
            if let track = block.track {
                actionBar.open(.music(track))
            }
        } label: {
            // Кнопка типа plain (`Size=L • 48px, Type=plain`, «кнопка без фона»): только
            // фоновый блюр, без заливки и бордера — не secondary (правка пользователя
            // 2026-10-17, сверено с макетом).
            PlayPauseGlyph(isPlaying: isPlaying, box: Layout.playIcon)
                .foregroundStyle(Color.fillOne)
                .frame(width: Layout.playSize, height: Layout.playSize)
                .background {
                    BackdropBlurView(radius: Layout.playBlur)
                        .clipShape(Circle())
                }
                .contentShape(Circle())
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel(isPlaying ? "Пауза" : "Слушать похожее на \(block.name)")
    }

    private var row: some View {
        let width = MusicCarouselFit.block.cardWidth
        return ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: Layout.rowGap) {
                ForEach(block.items) { item in
                    Button { MusicItemAction.perform(item, actionBar: actionBar, navigation: navigation) } label: {
                        MusicCard(
                            size: .xsmall,
                            width: width,
                            shape: item.shape,
                            cover: item.cover,
                            title: item.title,
                            subtitle: item.subtitle,
                            zoomRoute: item.route
                        )
                    }
                    .buttonStyle(PressScaleButtonStyle(pressedScale: PressMotion.cardScale))
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned)
        .contentMargins(.horizontal, Layout.side, for: .scrollContent)
        .frame(height: MusicCardLayout.height(.xsmall, width: width))
    }
}

/// Скелетон блока — та же карточка, пустая.
struct MusicArtistBlockSkeleton: View {
    var body: some View {
        RoundedRectangle(cornerRadius: MusicArtistBlockLayout.radius, style: .continuous)
            .plusSkeleton()
            .frame(width: MusicArtistBlockLayout.width, height: MusicArtistBlockLayout.height)
            .padding(MusicArtistBlockLayout.side)
            .accessibilityHidden(true)
    }
}

/// Тап по айтему музыки: экран — если есть, иначе — играть.
enum MusicItemAction {
    @MainActor
    static func perform(_ item: MusicItem, actionBar: ActionBarState, navigation: AppNavigationState) {
        if let route = item.route {
            navigation.open(route)
        } else if let playable = item.playable {
            UIImpactFeedbackGenerator(style: .medium)
                .impactOccurred(intensity: ShowcaseMotion.tapHapticIntensity)
            actionBar.open(.music(playable))
        }
    }
}

/// Источник зума экрана исполнителя — вся карточка блока: её рисунок умещается в свой кадр.
private struct MusicBlockZoomSource: ViewModifier {
    let route: EntityRoute
    let zoom: Namespace.ID?

    func body(content: Content) -> some View {
        if let zoom {
            content.matchedTransitionSource(id: route, in: zoom)
        } else {
            content
        }
    }
}
