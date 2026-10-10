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

    // MARK: Смахивание вверх

    /// Жест начинается с 6 pt (как `minimumDistance` пана), дальше тост идёт за пальцем 1:1.
    static let swipeMinimumDistance: CGFloat = 6
    /// Вниз тост не тянется: резина 20 % хода, потолок +12 pt.
    static let pullResistance: CGFloat = 0.2
    static let pullLimit: CGFloat = 12
    /// Закрыть смахиванием: предсказанный ход вверх от 24 pt или бросок от 400 pt/с.
    static let swipeDismissPredicted: CGFloat = -24
    static let swipeDismissVelocity: CGFloat = -400
    /// Путь до полного ухода за верхнюю кромку: высота тоста + верх безопасной зоны
    /// (константа по холсту 402, не замер) + запас.
    static let safeTop: CGFloat = 62
    static let swipeOutTravel: CGFloat = ToastLayout.height + safeTop + 40
    static let swipeOut = Animation.easeOut(duration: 0.25)
    /// Недотяг: пружина на место.
    static let swipeSnapBack = Animation.spring(duration: 0.32, bounce: 0.3)
}

// MARK: - Тексты

/// Фразы тостов. В исходниках — обычные пробелы; предлоги из одной буквы получают
/// неразрывный на выдаче (`ToastCopy.glued`), чтобы не оставались на конце строки.
enum ToastCopy {
    /// Лайк и «Позже». Набор — ровно 14 фраз пользователя (2026-10-10), своих не добавлять.
    private static let added = [
        "Добавили в Любимое",
        "Сохранили — теперь в Любимом",
        "Отличный выбор! Настраиваем рекомендации",
        "Будем советовать больше такого",
        "Прямо в сердечко",
        "Да!",
        "Класс!",
        "Огонь!",
        "Теперь знаем вас чуть лучше",
        "Учли — рекомендации станут точнее",
        "Есть! В коллекции",
        "Запомнили",
        "Сохранили!",
        "Теперь не потеряется",
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

// MARK: - Геометрия

/// Размеры компонента `toast` из 🧩 Mobile · Library (файл `b8maDlvYFFs2vagJxwxc4A`,
/// набор вариантов `3350:51117`, замер с инстансов `RTL=off`). Общее для всех вариантов:
/// высота 56, пилюля, `max-width 280`, фон `Fill/Nine` + backdrop-blur 35 (CSS), бордер
/// 0.66 `Fill/Nine`, текст Text S·13/Medium (16) `Fill/One`, кнопка — круг 32
/// (padding 8 + иконка 16) `Buttons/Secondary`.
enum ToastLayout {
    static let height: CGFloat = 56
    static let maxWidth: CGFloat = 280
    /// Зазор между текстом и кнопкой (и между иконкой и текстом).
    static let gap: CGFloat = 12
    static let buttonSize: CGFloat = 32
    static let buttonIcon: CGFloat = 16
    /// Правый отступ: с кнопкой `button=on` — 12, без неё — 24 (`3350:51042`, `3350:66601`).
    static let trailingWithButton: CGFloat = 12
    static let trailingNoButton: CGFloat = 24

    /// `graphic=image`, `3350:51044`: квадрат 83 вплотную к левому краю, обрезан пилюлей
    /// (поэтому видна верхняя часть картинки); текст — после него без зазора.
    static let imageSize: CGFloat = 83
    static let imageTextInset: CGFloat = imageSize + PlusMetrics.hairline

    /// `graphic=cover`, `3350:51043`: слева 14; рамка 35.17 вокруг обложки 32 r4,
    /// повёрнутой на 6° (32·(cos 6° + sin 6°)); зазор до текста 8; тень 0 1 6 чёрный 20 %.
    static let coverLeading: CGFloat = 14
    static let coverFrame: CGFloat = 35.17
    static let coverSide: CGFloat = 32
    static let coverRadius: CGFloat = 4
    static let coverGap: CGFloat = 8
    static let coverShadowRadius: CGFloat = 6
    static let coverShadowY: CGFloat = 1

    /// `graphic=cover` с прямоугольной обложкой (фильм, книга), `3350:66433` в `3350:66431`
    /// (зеркальный RTL-вариант того же `3350:51043`: отступ 14 и зазор 8 те же): обложка
    /// 32×44 r4 с тем же наклоном 6°, обводкой 0.66 `Fill/Nine` и тенью 0 1 6 чёрный 20 %,
    /// рамка 36.424×47.104 (32·cos 6° + 44·sin 6°, 32·sin 6° + 44·cos 6°).
    static let posterWidth: CGFloat = 32
    static let posterHeight: CGFloat = 44
    static let posterFrameWidth: CGFloat = 36.424
    static let posterFrameHeight: CGFloat = 47.104

    /// `graphic=icon`, `3350:51042` / `3350:66556`: слева 16, слот иконки 24, зазор 12.
    /// Глиф `iconDone` нарисован на холсте 20×20 и стоит по центру слота.
    static let iconLeading: CGFloat = 16
    static let iconSlot: CGFloat = 24
    static let iconGlyph: CGFloat = 20

    /// `graphic=none`, `3350:66601` / `3350:66621`: слева 24.
    static let noneLeading: CGFloat = 24

    // MARK: Ширина по тексту

    /// Левый отступ до графики (у `image` — до текста: картинка лежит поверх отступа).
    static func leadingInset(for graphic: ToastGraphic) -> CGFloat {
        switch graphic {
        case .image: imageTextInset
        case .cover, .poster: coverLeading
        case .icon: iconLeading
        case .none: noneLeading
        }
    }

    /// Графика вместе с зазором до текста.
    static func graphicWidth(for graphic: ToastGraphic) -> CGFloat {
        switch graphic {
        case .cover: coverFrame + coverGap
        case .poster: posterFrameWidth + coverGap
        case .icon: iconSlot + gap
        case .image, .none: 0
        }
    }

    /// Всё в ряду, кроме текста: отступы, графика, кнопка с зазором.
    private static func nonTextWidth(for config: ToastConfig) -> CGFloat {
        let hasButton = config.action != nil
        var width = leadingInset(for: config.graphic) + graphicWidth(for: config.graphic)
        width += hasButton ? gap + buttonSize + trailingWithButton : trailingNoButton
        return width
    }

    /// Места под фразу: от `max-width` вычитаем всё остальное в ряду.
    static func textMaxWidth(for config: ToastConfig) -> CGFloat {
        maxWidth - nonTextWidth(for: config)
    }

    /// Ширина фразы: самая длинная строка после переноса по словам в `maxWidth`.
    ///
    /// Почему замер строкой, а не чтением размера вью (геометрия, preference): размер пилюли
    /// зависит от ширины текста, а читать размер вью, от которого зависит её же
    /// раскладка, нельзя (правило 120 fps, CLAUDE.md) — раскладка идёт от констант.
    /// Шрифт — тот же YS Text Medium 13, что у `plusText(.textS, .medium)`; перенос
    /// здесь и в `Text` с `.frame(width:)` одинаковый, потому что ширина одна и та же.
    static func textWidth(_ title: String, maxWidth: CGFloat) -> CGFloat {
        let size = PlusTextSize.textS.size
        let font = UIFont(name: PlusFont.textMedium, size: size)
            ?? UIFont.systemFont(ofSize: size, weight: .medium)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        let text = NSAttributedString(
            string: title,
            attributes: [.font: font, .paragraphStyle: paragraph]
        )
        let rect = text.boundingRect(
            with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        return min(ceil(rect.width), maxWidth)
    }

    /// Ширина пилюли: обнимает текст, не шире `maxWidth`.
    static func pillWidth(for config: ToastConfig) -> CGFloat {
        nonTextWidth(for: config)
            + textWidth(config.title, maxWidth: textMaxWidth(for: config))
    }
}

// MARK: - Вид

/// Пилюля тоста по компоненту `toast` из Library: графика слева (обложка / картинка /
/// иконка / ничего), фраза до двух строк, кнопка-шеврон — только если у тоста есть действие.
struct ToastView: View {
    let config: ToastConfig
    var coverRotation: Double = ToastMotion.coverRestRotation
    var coverOffsetY: CGFloat = 0

    private var hasButton: Bool { config.action != nil }

    private var leadingInset: CGFloat { ToastLayout.leadingInset(for: config.graphic) }

    private var trailingInset: CGFloat {
        hasButton ? ToastLayout.trailingWithButton : ToastLayout.trailingNoButton
    }

    /// Ширина фразы считается заранее (`ToastLayout.textWidth`), от констант и шрифта.
    private var textWidth: CGFloat {
        ToastLayout.textWidth(config.title, maxWidth: ToastLayout.textMaxWidth(for: config))
    }

    var body: some View {
        HStack(spacing: 0) {
            switch config.graphic {
            case .cover(let source):
                cover(
                    source,
                    width: ToastLayout.coverSide,
                    height: ToastLayout.coverSide,
                    frameWidth: ToastLayout.coverFrame,
                    frameHeight: ToastLayout.coverFrame
                )
                .padding(.trailing, ToastLayout.coverGap)
            case .poster(let source):
                cover(
                    source,
                    width: ToastLayout.posterWidth,
                    height: ToastLayout.posterHeight,
                    frameWidth: ToastLayout.posterFrameWidth,
                    frameHeight: ToastLayout.posterFrameHeight
                )
                .padding(.trailing, ToastLayout.coverGap)
            case .icon(let name):
                icon(name)
                    .padding(.trailing, ToastLayout.gap)
            case .image, .none:
                EmptyView()
            }

            Text(config.title)
                .plusText(.textS, .medium)
                .foregroundStyle(Color.fillOne)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .frame(width: textWidth, alignment: .leading)
                .contentTransition(.opacity)

            if hasButton {
                chevronButton
                    .padding(.leading, ToastLayout.gap)
            }
        }
        .padding(.leading, leadingInset)
        .padding(.trailing, trailingInset)
        .frame(width: ToastLayout.pillWidth(for: config), height: ToastLayout.height, alignment: .leading)
        .overlay(alignment: .topLeading) {
            if case .image(let source) = config.graphic {
                // Картинка 83×83 от левого верхнего угла, пилюля обрезает её по высоте 56.
                Color.clear
                    .frame(width: ToastLayout.imageSize, height: ToastLayout.imageSize)
                    .overlay { ArtworkImage(source: source).scaledToFill() }
                    .clipped()
                    .transition(.opacity)
            }
        }
        .clipShape(Capsule(style: .continuous))
        .chromeGlass(Capsule(style: .continuous))
    }

    /// Обложка r4 с наклоном 6° и тенью внутри рамки (квадрат 32 в 35.17 или портрет 32×44
    /// в 36.424×47.104). Кадр задаёт распорка, картинка — `scaledToFill` в overlay (см. CLAUDE.md).
    private func cover(
        _ source: ArtworkSource,
        width: CGFloat,
        height: CGFloat,
        frameWidth: CGFloat,
        frameHeight: CGFloat
    ) -> some View {
        Color.clear
            .frame(width: width, height: height)
            .overlay { ArtworkImage(source: source).scaledToFill() }
            .clipShape(RoundedRectangle(cornerRadius: ToastLayout.coverRadius))
            .overlay {
                RoundedRectangle(cornerRadius: ToastLayout.coverRadius)
                    .strokeBorder(Color.fillNine, lineWidth: PlusMetrics.hairline)
            }
            .shadow(color: .black.opacity(0.2), radius: ToastLayout.coverShadowRadius, y: ToastLayout.coverShadowY)
            .rotationEffect(.degrees(coverRotation))
            .offset(y: coverOffsetY)
            .frame(width: frameWidth, height: frameHeight)
            .transition(.opacity)
    }

    private func icon(_ name: String) -> some View {
        Image(name)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: ToastLayout.iconGlyph, height: ToastLayout.iconGlyph)
            .foregroundStyle(Color.fillOne)
            .frame(width: ToastLayout.iconSlot, height: ToastLayout.iconSlot)
            .transition(.opacity)
    }

    private var chevronButton: some View {
        Color.clear
            .frame(width: ToastLayout.buttonSize, height: ToastLayout.buttonSize)
            .overlay {
                Image("iconChevronRight")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: ToastLayout.buttonIcon, height: ToastLayout.buttonIcon)
                    .foregroundStyle(Color.fillOne)
            }
            .chromeGlass(Circle())
            .transition(.opacity)
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
    /// Смещение под пальцем при смахивании: отдельно от `yOffset`, чтобы не мешать пружине появления.
    @State private var dragY: CGFloat = 0
    /// Палец ведёт тост (или только что отпущен): тап этого касания тостом не считается.
    @State private var swipeActive = false
    /// Тост смахнут и летит за верхнюю кромку: размонтируется сразу, без собственного затухания.
    @State private var flyingOut = false
    /// Палец на тосте — таймер автоскрытия на паузе. `@GestureState` сбрасывается и при отмене жеста.
    @GestureState private var isHolding = false

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
                    .offset(y: dragY)
                    .opacity(opacity)
                    .blur(radius: blurRadius)
                    .onTapGesture { tap() }
                    .simultaneousGesture(swipeGesture)
                    .accessibilityAddTraits(config.action != nil ? .isButton : [])
                    .onAppear { animateIn() }
                    .onDisappear { OverlayLayerState.shared.setInteractiveFrame(nil, for: "toast") }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: center.current) { _, new in
            if let new { present(new) } else { retire() }
        }
        .onChange(of: isHolding) { _, holding in
            if holding {
                center.holdTimer()
            } else if !flyingOut {
                // Отпустили без ухода: таймер заново, на полный срок.
                center.resumeTimer()
            }
        }
    }

    // MARK: Смахивание

    /// Вверх — за пальцем 1:1 без анимации; вниз — резина. `.global`: тост сам едет под пальцем.
    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: ToastMotion.swipeMinimumDistance, coordinateSpace: .global)
            .updating($isHolding) { _, holding, _ in holding = true }
            .onChanged { value in
                if !swipeActive { swipeActive = true }
                let height = value.translation.height
                dragY = height < 0
                    ? height
                    : min(height * ToastMotion.pullResistance, ToastMotion.pullLimit)
            }
            .onEnded { value in finishSwipe(value) }
    }

    /// Тап по тосту. Тап того же касания, что вело тост, не считается: рядом с порогом жеста
    /// (6 pt) системный тап ещё может сработать.
    private func tap() {
        guard !swipeActive, !flyingOut else { return }
        center.activate()
    }

    private func finishSwipe(_ value: DragGesture.Value) {
        // Флаг снимаем позже текущего прохода: тап того же касания проверяет его раньше.
        Task { @MainActor in swipeActive = false }

        let isDismiss = value.predictedEndTranslation.height <= ToastMotion.swipeDismissPredicted
            || value.velocity.height <= ToastMotion.swipeDismissVelocity
        guard isDismiss else {
            // Недотяг: на место. Reduce Motion — без пружины.
            withAnimation(reduceMotion ? ToastMotion.reducedFade : ToastMotion.swipeSnapBack) {
                dragY = 0
            }
            return
        }
        guard !reduceMotion else {
            // Остаётся там, где отпустили, и гаснет (`retire`).
            center.dismiss()
            return
        }
        // За верхнюю кромку, потом закрываем: тост уже не виден, собственное затухание не нужно.
        flyingOut = true
        exitToken += 1
        let mine = exitToken
        withAnimation(ToastMotion.swipeOut, completionCriteria: .logicallyComplete) {
            dragY = -ToastMotion.swipeOutTravel
        } completion: {
            // Пришёл новый тост или уход уже обработан — закрывать нечего.
            guard mine == exitToken, flyingOut else { return }
            center.dismiss()
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
        if flyingOut {
            // Прежний тост улетает за кромку: новый встаёт как свежий, а не под потолком.
            flyingOut = false
            var instant = Transaction()
            instant.disablesAnimations = true
            withTransaction(instant) {
                displayed = config
                dragY = 0
            }
            animateIn()
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
        if flyingOut {
            // Тост уже за кромкой — затухание не нужно.
            unmount()
            return
        }
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
            unmount()
        }
    }

    /// Демонтаж без анимации и возврат к стартовому состоянию.
    private func unmount() {
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) {
            displayed = nil
            yOffset = ToastMotion.startOffset
            dragY = 0
            opacity = 0
            blurRadius = 0
            coverRotation = ToastMotion.coverStartRotation
            coverOffsetY = ToastMotion.coverStartOffset
            flyingOut = false
        }
    }
}

// MARK: - Корень окна

/// SwiftUI-корень `OverlayWindow`: всё, что должно лежать поверх экрана фильма и плееров.
/// Снизу вверх: экран шеринга (пока он открыт, окно ловит все касания — `ShareState`),
/// над ним тост.
struct OverlayLayer: View {
    private let share = ShareState.shared

    var body: some View {
        ZStack {
            if let entity = share.presented {
                ShareOverlay(entity: entity)
                    .id(share.presentationID)
                    .transition(.opacity)
                    .zIndex(1)
            }
            ToastPresenter()
                .zIndex(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #if DEBUG
        // `-debugToast 1` — четыре тоста подряд: лайк (прямоугольная обложка фильма + кнопка) через 2 с, ✓ (иконка,
        // без кнопки) через 6 с, простой текст через 10 с, короткий «Да!» с обложкой и кнопкой через 14 с
        // (узкая пилюля).
        // `-debugShare 1` — экран шеринга альбома через 2 с.
        .task {
            guard UserDefaults.standard.bool(forKey: "debugShare") else { return }
            try? await Task.sleep(for: .seconds(2))
            ShareState.shared.present(.album(
                title: "Videotape",
                artist: "Tame Impala",
                year: "2026",
                cover: .asset("mockAlbumCover"),
                artistPicture: .asset("mockAvatar")
            ))
        }
        .task {
            guard UserDefaults.standard.bool(forKey: "debugToast") else { return }
            try? await Task.sleep(for: .seconds(2))
            ToastCenter.shared.show(
                title: ToastCopy.randomAdded(),
                graphic: .poster(.asset("mockMoviePoster")),
                action: .openCollection
            )
            try? await Task.sleep(for: .seconds(4))
            ToastCenter.shared.show(title: ToastCopy.randomDone(), graphic: .icon("iconDone"))
            try? await Task.sleep(for: .seconds(4))
            ToastCenter.shared.show(title: "Проверка связи")
            try? await Task.sleep(for: .seconds(4))
            ToastCenter.shared.show(
                title: "Да!",
                graphic: .cover(.asset("mockAlbumCover")),
                action: .openCollection
            )
        }
        #endif
    }
}
