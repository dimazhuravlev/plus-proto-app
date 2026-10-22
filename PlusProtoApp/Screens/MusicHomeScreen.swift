import SwiftUI
import UIKit

/// Числа «Моей волны» — по скриншоту Музыки (задача пользователя 2026-10-04): шейдер,
/// крупное название и большая белая кнопка под ним. Блок «название + кнопка» — посередине
/// между навигацией и барабаном станций (правка пользователя 2026-10-09).
enum MyVibeLayout {
    /// Шейдер — квадрат шире экрана с центром у названия: пятно в кадре занимает
    /// ~70 %, и на скриншоте оно почти во всю ширину
    static let shaderSize: CGFloat = 500
    /// Непрозрачность шейдера — приглушено по правке пользователя 2026-10-12
    static let shaderOpacity: Double = 0.9
    /// Кнопка — белый круг 96 на 118 ниже центра названия, глиф 34 градиентом
    static let playSize: CGFloat = 96
    static let playIcon: CGFloat = 34
    static let titleToPlay: CGFloat = 118
    /// Глиф кнопки — фиолетовый градиент сверху слева вниз направо
    static let playGradient = LinearGradient(
        colors: [
            Color(red: 0x5C / 255, green: 0x28 / 255, blue: 0xB1 / 255),
            Color(red: 0x9C / 255, green: 0x38 / 255, blue: 1),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

/// Главная Музыки — содержимое таба (задача пользователя 2026-10-04): общая навигация
/// витрин с фильтрами «Моя волна», «Для вас», «Подкасты», «Тренды» (кнопок справа
/// из скриншота нет — справа аватар, как на всех витринах; табы листаются и уходят
/// под маску перед ним). «Моя волна» — по скриншоту: живой шейдер фоном (видео
/// пользователя), название и кнопка. Остальные не спроектированы — название раздела.
struct MusicHomeScreen: View {
    /// «Подкасты» — после «Для вас», «Детям» — последним, как во всех витринах
    /// (правки пользователя тем же днём)
    static let filters = ["Моя волна", "Для вас", "Подкасты", "Тренды", "Детям"]

    @Environment(MusicHomeCatalog.self) private var catalog
    @Environment(AppNavigationState.self) private var navigation

    @State private var filter = 0
    @State private var scrollOffset: CGFloat = 0
    @State private var forYouPosition = ScrollPosition(edge: .top)

    /// «Для вас» — лента каруселей (`MusicForYouFeed`, задача пользователя 2026-10-17).
    private static let forYou = 1

    var body: some View {
        ZStack(alignment: .top) {
            Color.surfaceOne.ignoresSafeArea()

            if filter == 0 {
                // Экран в один кадр, но пружинит при оттяге, как остальные витрины:
                // за оттягом едет и навигация (правка пользователя 2026-10-04).
                // Вверх ему ехать некуда — нижнее поле под хром снято.
                ScrollView {
                    MyVibeHero()
                        .containerRelativeFrame(.vertical)
                }
                .scrollBounceBehavior(.always, axes: .vertical)
                .scrollIndicators(.hidden)
                .contentMargins(.bottom, 0, for: .scrollContent)
                // Экран — от кромки до кромки: барабан отмеряется от низа экрана, где стоит
                // нижний хром, а не от безопасной зоны.
                .ignoresSafeArea(edges: [.top, .bottom])
                .trackNavBarScroll(into: $scrollOffset)
            } else if filter == Self.forYou {
                MusicForYouFeed(scrollOffset: $scrollOffset, scrollPosition: $forYouPosition)
            } else {
                ServiceFilterStub(title: Self.filters[filter])
            }
        }
        .overlay(alignment: .top) {
            ServiceTopNav(
                filters: Self.filters,
                selection: $filter,
                scrollOffset: filter == 0 || filter == Self.forYou ? scrollOffset : 0,
                // У «Моей волны» затемнения сверху нет (правка пользователя 2026-10-10).
                showsTopShade: filter != 0
            )
        }
        // Лента таба, вернувшаяся после другого фильтра, доложит свой сдвиг сама —
        // прежний, оставшийся от неё, на миг проявил бы подложку навигации.
        .onChange(of: filter) { scrollOffset = 0 }
        // Повторный тап по табу на корне — к началу ленты «Для вас», как у витрин.
        .onChange(of: navigation.scrollToTopRequests[.music]) {
            guard filter == Self.forYou else { return }
            withAnimation(ShowcaseScrollMotion.toTop) { forYouPosition.scrollTo(edge: .top) }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await catalog.loadIfNeeded() }
        #if DEBUG
        // `-debugMusicFilter <n>` — стартовый фильтр таба (1 — «Для вас»): тапнуть табы
        // навигации из шелла нечем. Тактом позже раскладки: до замера ширины ленты табов
        // навигация «докручивала» выбранный таб за левый край.
        .task {
            let start = UserDefaults.standard.integer(forKey: "debugMusicFilter")
            guard start > 0, Self.filters.indices.contains(start) else { return }
            try? await Task.sleep(for: .milliseconds(300))
            filter = start
        }
        #endif
    }
}

/// «Моя волна»: шейдер, название и кнопка — та же «Моя Волна», что у блока витрины.
private struct MyVibeHero: View {
    @Environment(ActionBarState.self) private var actionBar


    private var navBottom: CGFloat {
        ServiceTopNavLayout.topSafeArea + ServiceTopNavLayout.rowHeight
    }

    /// Верх action bar от низа экрана: безопасная зона, ряд табов, зазор, сам бар.
    private var actionBarTop: CGFloat {
        PlusChromeMetrics.chromeBottom + PlusChromeMetrics.tabsRowHeight
            + PlusChromeMetrics.actionBarToTabsGap + PlusMetrics.actionBarHeight
    }

    private var isPlaying: Bool {
        actionBar.isMiniPlayerVisible && MyVibeTracks.isVibe(actionBar.music?.id) && actionBar.isMusicPlaying
    }

    var body: some View {
        // Оверлеем на распорке: шейдер шире экрана, и своей шириной он раздувал экран —
        // навигация центрировалась по 500pt и срезалась с обеих сторон (кадр 2026-10-04).
        Color.clear
            .overlay { hero }
            .clipped()
    }

    /// Навигация — блок — барабан. Блок держат две равные распорки: отступ от навигации
    /// и до барабана одинаковый на любом экране, без замера вью.
    private var hero: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: navBottom)
            Spacer(minLength: 0)
            titleAndPlay
            Spacer(minLength: 0)
            // Барабан — видимой частью над action bar, остальное уходит под нижний хром.
            VibeDrum { _ in play() }
                .frame(height: VibeDrumLayout.visibleHeight + actionBarTop, alignment: .top)
        }
    }

    private var titleAndPlay: some View {
        VStack(spacing: MyVibeLayout.titleToPlay - PlusHeadline.xxl.size / 2 - MyVibeLayout.playSize / 2) {
            Text("Моя волна")
                .plusHeadline(.xxl)
                .foregroundStyle(Color.fillOne)
                .frame(height: PlusHeadline.xxl.size)

            Button(action: play) {
                PlayPauseGlyph(isPlaying: isPlaying, box: MyVibeLayout.playIcon)
                    .foregroundStyle(MyVibeLayout.playGradient)
                    .frame(width: MyVibeLayout.playSize, height: MyVibeLayout.playSize)
                    .background(Color.buttonsInverted, in: Circle())
            }
            .buttonStyle(PressScaleButtonStyle())
            .accessibilityLabel(isPlaying ? "Пауза" : "Слушать Мою волну")
        }
        // Шейдер — под названием, с центром на нём; фоном, чтобы ширина 500 не раздувала блок.
        .background(alignment: .top) {
            VibeShader()
                .frame(width: MyVibeLayout.shaderSize, height: MyVibeLayout.shaderSize)
                .offset(y: PlusHeadline.xxl.size / 2 - MyVibeLayout.shaderSize / 2)
        }
    }

    /// Настоящий трек волны (`MyVibeTracks`); волна уже в баре — пауза и снятие с неё.
    /// Это главная волна — заигравшая, она встаёт плиткой в ряд ПП «Главной».
    private func play() {
        UIImpactFeedbackGenerator(style: .medium)
            .impactOccurred(intensity: ShowcaseMotion.tapHapticIntensity)
        actionBar.openMainVibe()
    }
}

/// Шейдер «Моей волны» — видео, присланное пользователем (`New_shader.mov`):
/// 1080×1080, 30 к/с, петля сшита кроссфейдом в секунду — у исходника первый
/// и последний кадры не совпадали. Пятно на чёрном — кромок у кадра нет.
struct VibeShader: View {
    var isPlaying = true
    var opacity: Double = MyVibeLayout.shaderOpacity
    @State private var playback = LoopingVideoPlayback()
    @State private var isReady = false

    var body: some View {
        LoopingVideoLayer(player: playback.queue) {
            isReady = true
        }
        .opacity(isReady ? opacity : 0)
        .animation(.easeOut(duration: 0.4), value: isReady)
        .allowsHitTesting(false)
        .onAppear {
            playback.prepare(bundled: "my-vibe-shader")
            updatePlayback()
        }
        .onChange(of: isPlaying) { _, _ in updatePlayback() }
        .onDisappear { playback.pause() }
        .accessibilityHidden(true)
    }

    private func updatePlayback() {
        if isPlaying { playback.start(bundled: "my-vibe-shader") }
        else { playback.pause() }
    }
}
