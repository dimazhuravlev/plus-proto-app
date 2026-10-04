import SwiftUI
import UIKit

/// Числа «Моей волны» — по скриншоту Музыки (задача пользователя 2026-10-04): шейдер,
/// крупное название по центру и большая белая кнопка под ним. Вертикаль — от низа
/// навигации.
enum MyVibeLayout {
    /// Центр названия — на 170 ниже низа навигации
    static let titleBelowNav: CGFloat = 170
    /// Шейдер — квадрат шире экрана с центром у названия: пятно в кадре занимает
    /// ~70 %, и на скриншоте оно почти во всю ширину
    static let shaderSize: CGFloat = 500
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
    /// «Подкасты» — после «Для вас» (правка пользователя тем же днём)
    static let filters = ["Моя волна", "Для вас", "Подкасты", "Тренды"]

    @State private var filter = 0

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            if filter == 0 {
                MyVibeHero()
            } else {
                ServiceFilterStub(title: Self.filters[filter])
            }
        }
        .overlay(alignment: .top) {
            ServiceTopNav(filters: Self.filters, selection: $filter)
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

/// «Моя волна»: шейдер, название и кнопка — та же «Моя Волна», что у блока витрины.
private struct MyVibeHero: View {
    @Environment(ActionBarState.self) private var actionBar

    /// «Моя волна» в баре — тот же id, что у блока витрины: включить её с витрины
    /// и отсюда — одно и то же, и повторный тап ставит на паузу.
    private static let vibeID = "my-vibe"

    private var titleCenter: CGFloat {
        ServiceTopNavLayout.topSafeArea + ServiceTopNavLayout.rowHeight + MyVibeLayout.titleBelowNav
    }

    private var isPlaying: Bool {
        actionBar.mode == .music && actionBar.music?.id == Self.vibeID && actionBar.isMusicPlaying
    }

    var body: some View {
        // Оверлеем на распорке: шейдер шире экрана, и своей шириной он раздувал экран —
        // навигация центрировалась по 500pt и срезалась с обеих сторон (кадр 2026-10-04).
        Color.clear
            .overlay(alignment: .top) { hero }
            .clipped()
            .ignoresSafeArea(edges: .top)
    }

    private var hero: some View {
        ZStack(alignment: .top) {
            VibeShader()
                .frame(width: MyVibeLayout.shaderSize, height: MyVibeLayout.shaderSize)
                .offset(y: titleCenter - MyVibeLayout.shaderSize / 2)

            Text("Моя волна")
                .plusHeadline(.xxxl)
                .foregroundStyle(Color.fillOne)
                .frame(height: PlusHeadline.xxxl.size)
                .offset(y: titleCenter - PlusHeadline.xxxl.size / 2)

            Button(action: play) {
                Image(isPlaying ? "iconPause" : "iconPlay")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: MyVibeLayout.playIcon, height: MyVibeLayout.playIcon)
                    .foregroundStyle(MyVibeLayout.playGradient)
                    .frame(width: MyVibeLayout.playSize, height: MyVibeLayout.playSize)
                    .background(Color.white, in: Circle())
            }
            .buttonStyle(PressScaleButtonStyle())
            .accessibilityLabel(isPlaying ? "Пауза" : "Слушать Мою волну")
            .offset(y: titleCenter + MyVibeLayout.titleToPlay - MyVibeLayout.playSize / 2)
        }
    }

    private func play() {
        UIImpactFeedbackGenerator(style: .medium)
            .impactOccurred(intensity: ShowcaseMotion.tapHapticIntensity)
        actionBar.open(.music(MusicNowPlaying(
            id: Self.vibeID,
            cover: .asset("mockPlayerCover"),
            title: "Моя Волна",
            artist: "Атмосферный постпанк, когда внутри пасмурно"
        )))
    }
}

/// Шейдер «Моей волны» — видео, присланное пользователем (`New_shader.mov`):
/// 1080×1080, 30 к/с, петля сшита кроссфейдом в секунду — у исходника первый
/// и последний кадры не совпадали. Пятно на чёрном — кромок у кадра нет.
private struct VibeShader: View {
    @State private var playback = LoopingVideoPlayback()
    @State private var isReady = false

    var body: some View {
        LoopingVideoLayer(player: playback.queue) {
            isReady = true
        }
        .opacity(isReady ? 1 : 0)
        .animation(.easeOut(duration: 0.4), value: isReady)
        .allowsHitTesting(false)
        .onAppear { playback.start(bundled: "my-vibe-shader") }
        .onDisappear { playback.pause() }
        .accessibilityHidden(true)
    }
}
