import SwiftUI

// MARK: - Движение

/// Константы появления и ухода тоста. Перенос из MusicPlayer (`Toast.swift`) — тот же
/// характер: пружина сверху, обложка «вкатывается» с наклоном, уход — затухание с блюром.
enum ToastMotion {
    static let springIn = Animation.spring(response: 0.5, dampingFraction: 0.75)
    /// Обложка догоняет контейнер: короткая задержка пружины.
    static let coverDelay: Double = 0.15
    /// Где тост стоит в покое (от верха безопасной зоны) и откуда выезжает.
    static let restOffset: CGFloat = -16
    static let startOffset: CGFloat = -100
    static let coverStartRotation: Double = -12
    static let coverRestRotation: Double = 6
    static let coverStartOffset: CGFloat = -30
    static let fadeOut = Animation.linear(duration: 0.5)
    static let fadeBlur: CGFloat = 16
    /// Демонтаж после ухода — чуть позже самой анимации.
    static let unmountDelay: Duration = .milliseconds(520)
    /// Reduce Motion: только прозрачность, без сдвига, поворота и блюра.
    static let reducedFade = Animation.easeInOut(duration: 0.2)
    static let reducedUnmountDelay: Duration = .milliseconds(220)
    /// Смена содержимого на месте, пока тост на экране: ширина пилюли и текст едут вместе.
    static let swap = Animation.easeInOut(duration: 0.25)
}

// MARK: - Тексты

/// Фразы тостов. В исходниках — обычные пробелы; предлоги из одной буквы получают
/// неразрывный на выдаче (`ToastCopy.glued`), чтобы не оставались на конце строки.
enum ToastCopy {
    /// Лайк и «Позже».
    private static let added = [
        "Добавили в Моё",
        "Сохранили — теперь это в Моём",
        "Отличный выбор! Настраиваем рекомендации",
        "Будем советовать больше такого",
        "Вкус что надо — добавили в Моё",
        "Прямо в сердечко",
        "Да!",
        "Ещё бы!",
        "Ммм… вкусно!",
        "Класс!",
        "Огонь!",
        "Вот это вайб",
        "Теперь знаем вас чуть лучше",
        "Учли — рекомендации станут точнее",
        "Есть! В коллекции",
        "Запомнили",
    ]

    /// ✓ на «Главной».
    private static let done = [
        "Учтём на будущее",
        "Теперь знаем о вас больше",
        "Будем рекомендовать такое чаще",
        "Рекомендации только что стали чуть точнее",
    ]

    static func randomAdded() -> String { glued(added.randomElement() ?? added[0]) }

    static func randomDone() -> String { glued(done.randomElement() ?? done[0]) }

    /// Пробел после однобуквенного слова (в, с, о, к, у, и…) — неразрывный.
    private static func glued(_ text: String) -> String {
        text.replacingOccurrences(
            of: "(^|\\s)([А-Яа-яЁё]) ",
            with: "$1$2\u{00A0}",
            options: .regularExpression
        )
    }
}

// MARK: - Вид

/// Пилюля тоста: обложка, фраза, кнопка-шеврон (визуальная, как в MusicPlayer).
struct ToastView: View {
    let config: ToastConfig
    var coverRotation: Double = ToastMotion.coverRestRotation
    var coverOffsetY: CGFloat = 0

    var body: some View {
        HStack(spacing: 8) {
            if let cover = config.cover {
                // Кадр задаёт распорка, картинка — `scaledToFill` в overlay (см. CLAUDE.md).
                Color.clear
                    .frame(width: 32, height: 32)
                    .overlay { ArtworkImage(source: cover).scaledToFill() }
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay {
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.fillNine, lineWidth: PlusMetrics.hairline)
                    }
                    .rotationEffect(.degrees(coverRotation))
                    .offset(y: coverOffsetY)
                    .transition(.opacity)
            }

            Text(config.title)
                .plusText(.textS, .medium)
                .foregroundStyle(Color.fillOne)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .layoutPriority(1)
                .contentTransition(.opacity)

            Spacer(minLength: 12)

            Circle()
                .fill(Color.buttonsPrimary)
                .frame(width: 32, height: 32)
                .overlay {
                    Image("iconChevronRight")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 16, height: 16)
                        .foregroundStyle(Color.fillOne)
                }
        }
        .padding(.trailing, 12)
        .padding(.leading, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: 280)
        .fixedSize(horizontal: true, vertical: false)
        .background {
            RoundedRectangle(cornerRadius: 80)
                .fill(Color.black.opacity(0.01)) // лёгкая подкладка, чтобы blendMode сработал
                .background(.ultraThinMaterial)
                .blendMode(.overlay)
                .clipShape(RoundedRectangle(cornerRadius: 80))
                .overlay {
                    RoundedRectangle(cornerRadius: 80)
                        .stroke(Color.fillNine, lineWidth: PlusMetrics.hairline)
                }
        }
        // blendMode не должен затронуть остальное дерево.
        .compositingGroup()
    }
}

// MARK: - Показ

/// Показывает `ToastCenter.shared.current`: появление, смена на месте, уход.
///
/// Три исправления против MusicPlayer: завершение ухода проверяет, что нового тоста нет
/// (иначе он убивался в окне демонтажа); новый тост при видимом старом меняет содержимое
/// на месте, без сброса сдвига — тост не дёргается, таймер перезапускает центр; Reduce Motion —
/// только прозрачность.
private struct ToastPresenter: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let center = ToastCenter.shared

    /// То, что смонтировано сейчас: на время ухода живёт дольше `center.current`.
    @State private var displayed: ToastConfig?
    // В покое (ничего не смонтировано) состояние всегда стартовое — новый тост
    // встаёт с него без дополнительного сброса.
    @State private var yOffset: CGFloat = ToastMotion.startOffset
    @State private var opacity: Double = 0
    @State private var blurRadius: CGFloat = 0
    @State private var coverRotation: Double = ToastMotion.coverStartRotation
    @State private var coverOffsetY: CGFloat = ToastMotion.coverStartOffset
    /// Меняется с каждым уходом и возвращением: устаревшее завершение ничего не демонтирует.
    @State private var exitToken = 0

    var body: some View {
        ZStack(alignment: .top) {
            if let config = displayed {
                ToastView(config: config, coverRotation: coverRotation, coverOffsetY: coverOffsetY)
                    // Кадр для hitTest окна: касания вне тоста уходят в приложение.
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
                        OverlayLayerState.shared.setInteractiveFrame(frame, for: "toast")
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .offset(y: yOffset)
                    .opacity(opacity)
                    .blur(radius: blurRadius)
                    .onTapGesture { center.dismiss() }
                    .onAppear { animateIn() }
                    .onDisappear { OverlayLayerState.shared.setInteractiveFrame(nil, for: "toast") }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: center.current) { _, new in
            if let new { present(new) } else { retire() }
        }
    }

    // MARK: Логика

    private func present(_ config: ToastConfig) {
        exitToken += 1
        guard displayed != nil else {
            // Свежий показ: вью встанет в стартовом состоянии и сама запустит `animateIn`.
            displayed = config
            return
        }
        // Тост ещё на экране (или уходит): меняем содержимое на месте и возвращаем видимость.
        withAnimation(reduceMotion ? ToastMotion.reducedFade : ToastMotion.swap) {
            displayed = config
            opacity = 1
            blurRadius = 0
        }
    }

    private func animateIn() {
        if reduceMotion {
            var instant = Transaction()
            instant.disablesAnimations = true
            withTransaction(instant) {
                yOffset = ToastMotion.restOffset
                coverRotation = 0
                coverOffsetY = 0
                blurRadius = 0
            }
            withAnimation(ToastMotion.reducedFade) { opacity = 1 }
            return
        }
        // Из стартового положения, без анимации к нему.
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) {
            coverRotation = ToastMotion.coverStartRotation
            coverOffsetY = ToastMotion.coverStartOffset
            yOffset = ToastMotion.startOffset
            opacity = 1
            blurRadius = 0
        }
        withAnimation(ToastMotion.springIn) {
            yOffset = ToastMotion.restOffset
        }
        // Обложка «вкатывается» чуть позже контейнера.
        withAnimation(ToastMotion.springIn.delay(ToastMotion.coverDelay)) {
            coverRotation = ToastMotion.coverRestRotation
            coverOffsetY = 0
        }
    }

    private func retire() {
        exitToken += 1
        let mine = exitToken
        if reduceMotion {
            withAnimation(ToastMotion.reducedFade) { opacity = 0 }
        } else {
            withAnimation(ToastMotion.fadeOut) {
                opacity = 0
                blurRadius = ToastMotion.fadeBlur
            }
        }
        let delay = reduceMotion ? ToastMotion.reducedUnmountDelay : ToastMotion.unmountDelay
        Task { @MainActor in
            try? await Task.sleep(for: delay)
            // Пришёл новый тост или повторный уход — демонтировать нечего.
            guard mine == exitToken, center.current == nil else { return }
            var instant = Transaction()
            instant.disablesAnimations = true
            withTransaction(instant) {
                displayed = nil
                yOffset = ToastMotion.startOffset
                opacity = 0
                blurRadius = 0
                coverRotation = ToastMotion.coverStartRotation
                coverOffsetY = ToastMotion.coverStartOffset
            }
        }
    }
}

// MARK: - Корень окна

/// SwiftUI-корень `OverlayWindow`: всё, что должно лежать поверх экрана фильма и плееров.
/// Сейчас тост; шеринг встанет сюда же.
struct OverlayLayer: View {
    var body: some View {
        ZStack {
            ToastPresenter()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #if DEBUG
        // `-debugToast 1` — тост с обложкой через 2 с и тост ✓ без обложки через 6 с.
        .task {
            guard UserDefaults.standard.bool(forKey: "debugToast") else { return }
            try? await Task.sleep(for: .seconds(2))
            ToastCenter.shared.show(title: ToastCopy.randomAdded(), cover: .asset("mockAlbumCover"))
            try? await Task.sleep(for: .seconds(4))
            ToastCenter.shared.show(title: ToastCopy.randomDone())
        }
        #endif
    }
}
