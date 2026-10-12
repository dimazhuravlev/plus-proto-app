import SwiftUI
import UIKit

// MARK: - Движение

/// Все константы жеста «схватил — тащишь — отпустил»: пороги, пружина, вылет при закрытии.
/// Перенос из MusicPlayer (`ShareOverlay.swift`) один в один.
enum ShareCardDragConfig {
    /// Смещение от центра, на котором нижний блок и фон уже сошли на нет.
    static let dismissDistanceThreshold: CGFloat = 120
    /// Порог скорости выброса (длина предсказанного пути), чтобы закрыть оверлей.
    static let dismissVelocityThreshold: CGFloat = 300

    static let rotationSensitivity: Double = 0.18
    static let inertiaTranslationFactor: CGFloat = 0.25
    static let inertiaRotationFactor: Double = 0.2

    /// Масштаб карточки при «захвате» и возврат в 1.
    static let grabScale: CGFloat = 0.98
    static let grabAnimationDuration: Double = 0.2
    static let closeButtonHideOnDragDuration: Double = 0.2
    static let minDragBeforeGrabFeedback: CGFloat = 4
    /// Ниже этого смещения при отпускании — без инерции (тап, дрожь пальца), только пружина в центр.
    static let noInertiaMaxReleaseDistance: CGFloat = 12

    static let returnSpringResponse: Double = 0.52
    static let returnSpringDamping: Double = 0.72

    static let flyOutDuration: Double = 0.42
    static let flyOutDistance: CGFloat = 720
    static let flyVelocityBoost: CGFloat = 0.3
    /// Фон гаснет после вылета карточки: карточка должна уехать раньше.
    static let blurFadeAfterFlyDuration: Double = 0.24
}

enum ShareOverlayOpenConfig {
    static let blurIn: Double = 0.4
    /// Общая задержка карточки и нижнего блока (синхронно).
    static let cardAndBottomDelay: Double = 0.2
    static let cardIn: Double = 0.3
    static let bottomIn: Double = 0.3
    /// Шаг между соседними кнопками каналов: волна слева направо.
    static let bottomButtonStagger: Double = 0.06
    static let bottomButtonItemIn: Double = 0.2
    static let bottomButtonInitialOffsetY: CGFloat = 10
    static let initialCardScale: CGFloat = 0.97
    static let bottomOffsetY: CGFloat = 8
}

enum ShareOverlayDismissConfig {
    static let contentOut: Double = 0.3
    static let blurOut: Double = 0.4
    static let closeButtonFade: Double = 0.25
}

/// Reduce Motion: открытие и закрытие — только прозрачность; вылет — прозрачностью.
enum ShareOverlayReducedMotion {
    static let fade = Animation.easeInOut(duration: 0.25)
    static let duration: Double = 0.25
}

// MARK: - Раскладка карточки

/// Размеры карточки. Высота считается от констант и формы обложки, а не мерится:
/// размер вью, от которого зависит её же раскладка, не читаем (правило 120 fps) —
/// высота нужна жесту для якоря вращения.
enum ShareCardLayout {
    static let width: CGFloat = 254
    static let cornerRadius: CGFloat = 18

    static let logoHeight: CGFloat = 20
    /// Отступ логотипа сверху и снизу.
    static let logoInset: CGFloat = 24
    static let coverGap: CGFloat = 8
    static let titleHeight = PlusHeadline.l.lineHeight
    static let titleToMeta: CGFloat = 4
    static let metaHeight: CGFloat = 40
    static let metaGap: CGFloat = 8
    static let avatarSize: CGFloat = 40
    /// Поля заголовка и мета-строки.
    static let side: CGFloat = 12
    static let bottomInset: CGFloat = 12

    /// Квадрат (альбом, плейлист) и круг (исполнитель).
    static let squareCover: CGFloat = 230
    /// Постер фильма 2:3 шириной 180: на полной высоте 230 карточка выросла бы до 500.
    static let posterSize = CGSize(width: 180, height: 270)
    static let bookCoverHeight: CGFloat = 230

    static func book(aspect: CGFloat?) -> (geometry: BookFigureGeometry, coverWidth: CGFloat) {
        let geometry = BookFigureGeometry(coverHeight: bookCoverHeight)
        return (geometry, geometry.coverWidth(aspect: aspect))
    }

    /// Кадр обложки по виду сущности.
    static func coverSize(for shape: ShareableEntity.Shape) -> CGSize {
        switch shape {
        case .square, .circle:
            return CGSize(width: squareCover, height: squareCover)
        case .poster:
            return posterSize
        case .book(let aspect):
            let (geometry, coverWidth) = book(aspect: aspect)
            return geometry.frameSize(coverWidth: coverWidth)
        }
    }

    static func height(for entity: ShareableEntity) -> CGFloat {
        var height = logoInset + logoHeight + logoInset
        height += coverSize(for: entity.shape).height + coverGap
        height += titleHeight
        if entity.hasMetaRow { height += titleToMeta + metaHeight }
        return height + bottomInset
    }
}

// MARK: - Каналы

private struct ShareChannel {
    let icon: String
    let title: String
}

/// Действий у кнопок нет: ссылки на сущность в прототипе нет.
private let shareChannels: [ShareChannel] = [
    ShareChannel(icon: "iconTelegram", title: "Telegram"),
    ShareChannel(icon: "iconWhatsapp", title: "WhatsApp"),
    ShareChannel(icon: "iconCopyLink", title: "Ссылка"),
    ShareChannel(icon: "iconMore", title: "Ещё"),
]

// MARK: - Экран

/// Экран шеринга сущности: размытый тёмный фон, карточка с логотипом Плюса, обложкой в форме
/// сущности, названием и подписью; карточку можно таскать и выбросить; снизу — четыре
/// канала. Живёт в `OverlayLayer` (окно поверх всего). Перенос из MusicPlayer с адаптацией
/// под кино и книги.
struct ShareOverlay: View {
    let entity: ShareableEntity

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Появление и уход: каждая часть — одна величина 0…1, из неё считаются прозрачность
    // и сдвиг/масштаб, поэтому уходит всё одной анимацией.
    @State private var scrimShown = false
    @State private var cardShown = false
    @State private var bottomShown = false
    @State private var closeShown = false
    @State private var buttonShown = Array(repeating: false, count: shareChannels.count)
    /// Уходим: касания и жесты больше ничего не меняют.
    @State private var isClosing = false

    // Жест (по касанию, не покадровая анимация).
    @State private var dragOffset: CGSize = .zero
    @State private var dragRotation: Double = 0
    @State private var grabAnchor: UnitPoint = .center
    @State private var cardDragActive = false
    @State private var closeHiddenByDrag = false
    @State private var cardInteractionScale: CGFloat = 1
    @State private var dragGrabFeedbackStarted = false

    private var cardHeight: CGFloat { ShareCardLayout.height(for: entity) }

    var body: some View {
        ZStack {
            // Фон в `.background` + ignoresSafeArea: контент остаётся в безопасной зоне
            // (крестик и нижний блок на месте).
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { dismiss() }
                .background {
                    ZStack {
                        BackdropBlurView(radius: PlusMetrics.glassBlur)
                        Color.black.opacity(scrimBlackOpacity)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .opacity(scrimShown ? 1 : 0)
                    .ignoresSafeArea()
                }

            // Карточка по центру, нижний блок снизу; когда карточку уводят, нижний блок гаснет.
            VStack(spacing: 0) {
                Spacer()
                shareCardWithDrag
                    .opacity(cardShown ? 1 : 0)
                    .scaleEffect(restingCardScale * cardInteractionScale)
                Spacer()
                bottomBlock
                    .opacity(dragAwayVisibility)
                    .blur(radius: 6 * dragAwayProgress)
                    .offset(y: bottomRestOffset + 16 * dragAwayProgress)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .topTrailing) {
                closeButton
                    .opacity(closeShown && !closeHiddenByDrag ? 1 : 0)
                    .padding(.top, 16)
                    .padding(.trailing, 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.keyboard)
        .onAppear { runOpenAnimation() }
        // После возврата карточки в центр крестик снова виден (во время жеста он скрыт).
        .onChange(of: dragOffset) { _, new in
            guard !cardDragActive, closeHiddenByDrag, !isClosing, hypot(new.width, new.height) < 2 else { return }
            withAnimation(.easeOut(duration: ShareOverlayDismissConfig.closeButtonFade)) {
                closeHiddenByDrag = false
            }
        }
    }

    // MARK: Производные

    /// Насколько карточка ушла от центра, 0…1: общий прогресс для фона и нижнего блока.
    private var dragAwayProgress: CGFloat {
        let distance = hypot(dragOffset.width, dragOffset.height)
        return min(1, max(0, distance / ShareCardDragConfig.dismissDistanceThreshold))
    }

    private var dragAwayVisibility: Double { 1 - Double(dragAwayProgress) }

    private var scrimBlackOpacity: Double { 0.48 + 0.12 * dragAwayVisibility }

    /// Масштаб и сдвиг появления — только вне Reduce Motion: там уходит и приходит одна прозрачность.
    private var restingCardScale: CGFloat {
        cardShown || reduceMotion ? 1 : ShareOverlayOpenConfig.initialCardScale
    }

    private var bottomRestOffset: CGFloat {
        bottomShown || reduceMotion ? 0 : ShareOverlayOpenConfig.bottomOffsetY
    }

    private func buttonRestOffset(_ index: Int) -> CGFloat {
        buttonShown[index] || reduceMotion ? 0 : ShareOverlayOpenConfig.bottomButtonInitialOffsetY
    }

    // MARK: Крестик

    private var closeButton: some View {
        Button(action: dismiss) {
            Image("iconCross")
                .resizable()
                .renderingMode(.template)
                .foregroundStyle(Color.fillOne)
                .frame(width: 16, height: 16)
                .padding(6)
                .secondaryButtonSurface(Circle())
        }
        .frame(width: 28, height: 28)
        .buttonStyle(PressScaleButtonStyle())
        // Зона тапа шире кнопки, раскладка не едет.
        .padding(8)
        .contentShape(Rectangle())
        .padding(-8)
        .accessibilityLabel("Закрыть")
    }

    // MARK: Карточка

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: ShareCardLayout.cornerRadius, style: .continuous)
    }

    private var shareCardContent: some View {
        VStack(spacing: 0) {
            Image("logoYandexPlus")
                .resizable()
                .scaledToFit()
                .frame(height: ShareCardLayout.logoHeight)
                .padding(.vertical, ShareCardLayout.logoInset)

            cover
                .padding(.bottom, ShareCardLayout.coverGap)

            Text(entity.title)
                .plusHeadline(.l)
                .foregroundStyle(Color.fillOne)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: ShareCardLayout.titleHeight)
                .padding(.horizontal, ShareCardLayout.side)
                .padding(.bottom, entity.hasMetaRow ? ShareCardLayout.titleToMeta : 0)

            if entity.hasMetaRow {
                metaRow
            }
        }
        .padding(.bottom, ShareCardLayout.bottomInset)
        .frame(width: ShareCardLayout.width, height: cardHeight, alignment: .top)
        .secondaryButtonSurface(cardShape, fill: .fillNine)
        .contentShape(cardShape)
    }

    private var metaRow: some View {
        HStack(spacing: ShareCardLayout.metaGap) {
            if let avatar = entity.avatar {
                Color.clear
                    .frame(width: ShareCardLayout.avatarSize, height: ShareCardLayout.avatarSize)
                    .overlay { ArtworkImage(source: avatar).scaledToFill() }
                    .clipShape(Circle())
            }
            VStack(alignment: .leading, spacing: 0) {
                if let subtitle = entity.subtitle {
                    Text(subtitle)
                        .plusText(.textM, .medium)
                        .foregroundStyle(Color.fillOne)
                        .lineLimit(1)
                }
                if let year = entity.year {
                    Text(year)
                        .plusText(.textM, .medium)
                        .foregroundStyle(Color.fillSubtitle)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(height: ShareCardLayout.metaHeight)
        .padding(.horizontal, ShareCardLayout.side)
    }

    /// Обложка в форме сущности, как в коллекции «Моё»: кадр задаёт распорка, картинка —
    /// `scaledToFill` в overlay. Живая картинка проявляется на заливке скелетона: чужая
    /// моковая обложка на её месте не рисуется.
    @ViewBuilder
    private var cover: some View {
        let size = ShareCardLayout.coverSize(for: entity.shape)
        switch entity.shape {
        case .square, .poster:
            coverImage(size: size, shape: RoundedRectangle(cornerRadius: ShareCardLayout.cornerRadius, style: .continuous))
        case .circle:
            coverImage(size: size, shape: Circle())
        case .book(let aspect):
            let (geometry, coverWidth) = ShareCardLayout.book(aspect: aspect)
            BookFigure(geometry: geometry, coverWidth: coverWidth) {
                if let cover = entity.cover {
                    ArtworkImage(source: cover).scaledToFill()
                }
            }
            .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 2)
        }
    }

    private func coverImage<S: InsettableShape>(size: CGSize, shape: S) -> some View {
        PlusSkeleton.fill
            .frame(width: size.width, height: size.height)
            .overlay {
                if let cover = entity.cover {
                    ArtworkImage(source: cover).scaledToFill()
                }
            }
            .clipShape(shape)
            .coverBorder(shape)
            .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 2)
    }

    // MARK: Жест

    private var shareCardWithDrag: some View {
        shareCardContent
            .offset(x: dragOffset.width, y: dragOffset.height)
            .rotationEffect(.degrees(dragRotation), anchor: grabAnchor)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged(handleDragChanged)
                    .onEnded(handleDragEnded)
            )
    }

    /// Тащишь пальцем — карточка едет вместе с ним и чуть заваливается, будто схвачена за тот
    /// угол, куда ткнул.
    private func handleDragChanged(_ value: DragGesture.Value) {
        guard !isClosing else { return }
        let cfg = ShareCardDragConfig.self
        if !cardDragActive {
            cardDragActive = true
            grabAnchor = UnitPoint(
                x: max(0.05, min(0.95, value.startLocation.x / ShareCardLayout.width)),
                y: max(0.05, min(0.95, value.startLocation.y / cardHeight))
            )
        }
        let dx = value.translation.width
        let dy = value.translation.height
        if hypot(dx, dy) > cfg.minDragBeforeGrabFeedback, !dragGrabFeedbackStarted {
            dragGrabFeedbackStarted = true
            withAnimation(.easeOut(duration: cfg.closeButtonHideOnDragDuration)) {
                closeHiddenByDrag = true
            }
            withAnimation(.easeOut(duration: cfg.grabAnimationDuration)) {
                cardInteractionScale = cfg.grabScale
            }
        }
        let ax = Double(grabAnchor.x) - 0.5
        let ay = Double(grabAnchor.y) - 0.5
        dragRotation = cfg.rotationSensitivity * (ax * Double(dy) - ay * Double(dx))
        dragOffset = CGSize(width: dx, height: dy)
    }

    /// Закрытие жестом: далеко увели или резко смахнули — карточка улетает, потом гаснет фон.
    /// Иначе возврат: короткое смещение — пружина; длиннее — инерция и пружина в центр.
    /// Тап по карточке не закрывает.
    private func handleDragEnded(_ value: DragGesture.Value) {
        cardDragActive = false
        dragGrabFeedbackStarted = false
        guard !isClosing else { return }
        let cfg = ShareCardDragConfig.self
        let dx = value.translation.width
        let dy = value.translation.height
        let distance = hypot(dx, dy)
        let vx = value.predictedEndLocation.x - value.location.x
        let vy = value.predictedEndLocation.y - value.location.y
        let velocity = hypot(vx, vy)

        if distance > cfg.dismissDistanceThreshold || velocity > cfg.dismissVelocityThreshold {
            dismissWithDrag(translation: CGSize(width: dx, height: dy), velocity: CGSize(width: vx, height: vy))
            return
        }

        withAnimation(.easeOut(duration: cfg.grabAnimationDuration)) {
            cardInteractionScale = 1
        }

        let springBack = {
            // Следующий проход главного цикла: инерционный сдвиг успевает отрисоваться.
            DispatchQueue.main.async {
                withAnimation(.spring(response: cfg.returnSpringResponse, dampingFraction: cfg.returnSpringDamping)) {
                    dragOffset = .zero
                    dragRotation = 0
                }
            }
        }

        if distance < cfg.noInertiaMaxReleaseDistance {
            springBack()
            return
        }

        let ax = Double(grabAnchor.x) - 0.5
        let ay = Double(grabAnchor.y) - 0.5
        let angularVelocity = cfg.rotationSensitivity * (ax * Double(vy) - ay * Double(vx))
        dragOffset = CGSize(
            width: dragOffset.width + vx * cfg.inertiaTranslationFactor,
            height: dragOffset.height + vy * cfg.inertiaTranslationFactor
        )
        dragRotation += angularVelocity * cfg.inertiaRotationFactor
        springBack()
    }

    // MARK: Нижний блок

    private var bottomBlock: some View {
        VStack(spacing: 24) {
            Text("Поделиться с друзьями")
                .plusText(.textM, .medium)
                .foregroundStyle(Color.fillOne)
                .opacity(bottomShown ? 1 : 0)
            HStack(spacing: 16) {
                ForEach(Array(shareChannels.enumerated()), id: \.offset) { index, channel in
                    ShareChannelButton(icon: channel.icon, title: channel.title)
                        .opacity(buttonShown[index] ? 1 : 0)
                        .offset(y: buttonRestOffset(index))
                }
            }
        }
        .padding(.bottom, 32)
    }

    // MARK: Появление и уход

    private func runOpenAnimation() {
        let open = ShareOverlayOpenConfig.self
        if reduceMotion {
            withAnimation(ShareOverlayReducedMotion.fade) {
                scrimShown = true
                cardShown = true
                bottomShown = true
                closeShown = true
                buttonShown = Array(repeating: true, count: shareChannels.count)
            }
            return
        }
        withAnimation(.easeOut(duration: open.blurIn)) { scrimShown = true }
        withAnimation(.easeOut(duration: open.cardIn).delay(open.cardAndBottomDelay)) {
            cardShown = true
        }
        withAnimation(.easeOut(duration: open.bottomIn).delay(open.cardAndBottomDelay)) {
            bottomShown = true
            closeShown = true
        }
        // Кнопки каналов — волной слева направо.
        for index in shareChannels.indices {
            withAnimation(
                .easeOut(duration: open.bottomButtonItemIn)
                    .delay(open.cardAndBottomDelay + open.bottomButtonStagger * Double(index))
            ) {
                buttonShown[index] = true
            }
        }
    }

    /// Всё, кроме карточки и фона, уходит.
    private func hideChrome() {
        closeShown = false
        bottomShown = false
        buttonShown = Array(repeating: false, count: shareChannels.count)
    }

    /// Закрытие тапом по фону или крестиком.
    private func dismiss() {
        guard !isClosing else { return }
        isClosing = true
        let out = ShareOverlayDismissConfig.self
        if reduceMotion {
            fadeEverythingOut()
            return
        }
        withAnimation(.easeIn(duration: out.contentOut)) {
            hideChrome()
            cardShown = false
        }
        withAnimation(.easeIn(duration: out.blurOut).delay(out.contentOut)) { scrimShown = false }
        ShareState.shared.scheduleRemovalAfterAnimation(out.contentOut + out.blurOut)
    }

    /// Закрытие выбросом карточки.
    private func dismissWithDrag(translation: CGSize, velocity: CGSize) {
        isClosing = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let cfg = ShareCardDragConfig.self
        if reduceMotion {
            // Карточка остаётся под пальцем и гаснет: вылета нет.
            fadeEverythingOut()
            return
        }
        let tx = translation.width + velocity.width * cfg.flyVelocityBoost
        let ty = translation.height + velocity.height * cfg.flyVelocityBoost
        let norm = hypot(tx, ty)
        let ux = norm > 1 ? tx / norm : 1
        let uy = norm > 1 ? ty / norm : 0
        let ax = Double(grabAnchor.x) - 0.5
        let ay = Double(grabAnchor.y) - 0.5
        let flyX = ux * cfg.flyOutDistance
        let flyY = uy * cfg.flyOutDistance
        let totalDx = translation.width + flyX
        let totalDy = translation.height + flyY
        let finalRotation = cfg.rotationSensitivity * (ax * Double(totalDy) - ay * Double(totalDx))

        // Карточка уезжает за экран, крестик и нижний блок сразу гаснут.
        withAnimation(.easeOut(duration: cfg.flyOutDuration)) {
            hideChrome()
            dragOffset = CGSize(width: totalDx, height: totalDy)
            dragRotation = finalRotation
        }
        // После вылета фон гаснет и слой снимается.
        withAnimation(.easeIn(duration: cfg.blurFadeAfterFlyDuration).delay(cfg.flyOutDuration)) {
            scrimShown = false
        }
        ShareState.shared.scheduleRemovalAfterAnimation(cfg.flyOutDuration + cfg.blurFadeAfterFlyDuration)
    }

    /// Reduce Motion: одна прозрачность.
    private func fadeEverythingOut() {
        withAnimation(ShareOverlayReducedMotion.fade) {
            hideChrome()
            cardShown = false
            scrimShown = false
        }
        ShareState.shared.scheduleRemovalAfterAnimation(ShareOverlayReducedMotion.duration)
    }
}

// MARK: - Кнопка канала

/// Круг 52 и подпись. Действия нет, но отклик нажатия и хаптика — как у любой кнопки.
private struct ShareChannelButton: View {
    let icon: String
    let title: String

    var body: some View {
        Button(action: PlayerHaptics.tap) {
            VStack(spacing: 6) {
                Image(icon)
                    .resizable()
                    .renderingMode(.template)
                    .foregroundStyle(Color.fillOne)
                    .frame(width: 24, height: 24)
                    .frame(width: 52, height: 52)
                    .secondaryButtonSurface(Circle())
                Text(title)
                    .plusText(.textS, .medium)
                    .foregroundStyle(Color.fillSubtitle)
                    .lineLimit(1)
            }
            .frame(width: 64)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel(title)
    }
}
