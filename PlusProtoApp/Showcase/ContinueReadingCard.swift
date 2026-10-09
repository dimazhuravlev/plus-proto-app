import SwiftUI
import VariableBlur

/// Геометрия карточки «продолжить чтение» — figma-screen1 §3.6. Координаты локальные:
/// из абсолютных Y макета вычтен верх слота `ShowcaseLayout.Slot.reading` (1308.99).
private enum ReadingCardLayout {
    static let slot = ShowcaseLayout.Slot.reading

    /// Стеклянный блок `2004:10717`: 354×247 в (24, 1334). Паддинг 8 из макета не переносим —
    /// все слои внутри позиционированы абсолютно от угла блока, на них он не влияет.
    static let blockOrigin = CGPoint(x: 24, y: 1334 - slot.top)
    static let blockSize = CGSize(width: 354, height: 247)

    /// Фрагмент книги `2004:10718`: кадр 322×532 начинается выше видимой области —
    /// текст обрезан сверху и снизу, будто читаешь с середины.
    static let excerptOrigin = CGPoint(x: 15.34, y: -46.66)
    static let excerptSize = CGSize(width: 322, height: 532)

    /// Скрим `2004:10719` под строкой прогресса: чёрный 0.35 держится до 27,885%, дальше в ноль.
    /// Скругление сверху даёт клип блока, поэтому рисуем простым прямоугольником.
    static let scrimSize = CGSize(width: 354, height: 118)
    static let scrimOpacity: Double = 0.35
    static let scrimSolidUntil: Double = 0.27885

    /// Шапка блока — высота скрима: затемнение и зона тапа «к экрану книги».
    static var headerHeight: CGFloat { scrimSize.height }
    /// Прогрессивный блюр шапки — ниже и мягче скрима: в полную силу у верхнего края,
    /// к третьей строке фрагмента (строка Text L — 24) сходит на нет. Было 118 и 16 —
    /// «слишком сильный и высокий» (правки пользователя 2026-10-09).
    static let headerBlurHeight: CGFloat = 80
    static let headerBlurRadius: CGFloat = 8

    /// Где карточка ловит палец: блок и полоса над ним, где торчит мини-книга.
    static var tapArea: CGRect {
        CGRect(x: blockOrigin.x, y: 0, width: blockSize.width, height: blockOrigin.y + blockSize.height)
    }

    /// Кнопка ✕ `2004:10720` в правом верхнем углу блока. Лайка у этой карточки в макете нет.
    /// Лежит не внутри блока, а рядом: блок — интерактивная миниатюра, и кнопка внутри неё
    /// стала бы кнопкой в кнопке, то есть перестала бы нажиматься сама.
    static let dismissInset: CGFloat = 7.34
    static let dismissOrigin = CGPoint(
        x: blockOrigin.x + blockSize.width - dismissInset - PlusMetrics.circleButton,
        y: blockOrigin.y + dismissInset
    )

    /// Строка прогресса `2004:10721`: (109, 1346.55), ширина 137 = «36%» + 6 + трек 108.
    static let timelineOrigin = CGPoint(x: 109, y: 1346.55 - slot.top)
    static let timelineGap: CGFloat = 6
    static let trackWidth: CGFloat = 108
    /// Зазор между строкой прогресса и сроком в спеке не указан — строки идут вплотную (13/16).
    static let timelineRowSpacing: CGFloat = 0

    /// Мини-книга `2004:10730` торчит над левым верхним углом блока: габарит 57×90.3
    /// в (40, 1308.99) — это AABB повёрнутой на −4° обложки 51.06×86.95, и он начинается
    /// ровно с верха слота.
    static let miniBookBox = CGRect(x: 40, y: 1308.99 - slot.top, width: 57, height: 90.3)
    static let miniBookSize = CGSize(width: 51.06, height: 86.95)
    static let miniBookRotation = Angle.degrees(-4)
    /// Поворот в SwiftUI идёт вокруг центра и кадр не двигает, поэтому кадр обложки ставим
    /// по центру её AABB.
    static let miniBookOrigin = CGPoint(
        x: miniBookBox.midX - miniBookSize.width / 2,
        y: miniBookBox.midY - miniBookSize.height / 2
    )
    /// У мини-книги свой ореол: блюр 16 и opacity 0.5 вместо общих 28/0.3–0.7,
    /// поэтому `AmbilightArtwork` с его зашитым радиусом здесь не подходит.
    static let miniBookGlowBlur: CGFloat = 16
    static let miniBookGlowOpacity: Double = 0.5
}

/// Карточка «продолжить чтение»: стеклянный блок с обрезанным фрагментом книги, скримом
/// и строкой прогресса, а над его левым верхним углом торчит мини-обложка.
///
/// Нажимается целиком, двумя зонами (правка пользователя 2026-10-09): шапка — затемнение
/// с блюром, обложка, прогресс — открывает экран книги, текст ниже — сразу читалку.
/// ✕ убирает карточку целиком: гаснет, как карточки витрины на ✕, и лента схлопывается.
struct ContinueReadingCard: View {
    let block: ReadingBlock

    @Environment(\.showcaseThumbnail) private var thumbnail
    @Environment(ActionBarState.self) private var actionBar
    @Environment(AppNavigationState.self) private var navigation
    @Environment(ShowcaseCatalog.self) private var catalog
    @Environment(ShowcaseFeedbackState.self) private var feedback: ShowcaseFeedbackState?

    var body: some View {
        ZStack(alignment: .topLeading) {
            readingArea

            // Крест — своя кнопка поверх карточки: палец на нём достаётся ему, а не ей.
            GlassIconButton(icon: "iconCross", accessibilityTitle: "Скрыть", action: dismiss)
                .offset(x: ReadingCardLayout.dismissOrigin.x, y: ReadingCardLayout.dismissOrigin.y)
        }
        .frame(
            width: ShowcaseLayout.designWidth,
            height: ReadingCardLayout.slot.height,
            alignment: .topLeading
        )
        .showcaseSwappable()
        // `-debugShowcaseDismiss 5` — тот же `dismiss()`, что у тапа по кресту.
        .onChange(of: feedback?.debugDismisses) { dismiss() }
    }

    /// Блок, прогресс и мини-книга — одна нажимаемая область с общей просадкой. Куда вести,
    /// решает точка тапа (`open(at:)`), а не две кнопки: просадка у прозрачной кнопки-зоны
    /// была бы не видна. Источник зума — стеклянный блок, как у миниатюры витрины.
    private var readingArea: some View {
        ZStack(alignment: .topLeading) {
            glassBlock
                .modifier(ReadingZoomSource(context: thumbnail))
                .showcasePlaced(at: ReadingCardLayout.blockOrigin)

            timeline
                .offset(x: ReadingCardLayout.timelineOrigin.x, y: ReadingCardLayout.timelineOrigin.y)

            // Книга — сосед блока, а не его потомок: внутри её срезал бы клип.
            miniBook
                .offset(x: ReadingCardLayout.miniBookOrigin.x, y: ReadingCardLayout.miniBookOrigin.y)
        }
        .frame(
            width: ShowcaseLayout.designWidth,
            height: ReadingCardLayout.slot.height,
            alignment: .topLeading
        )
        .contentShape(Path(ReadingCardLayout.tapArea))
        .pressScale(PressMotion.cardScale)
        .onTapGesture(coordinateSpace: .local) { open(at: $0) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(block.title)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { openBook() }
        .accessibilityAction(named: "Читать") { openReader() }
    }

    // MARK: - Нажатия

    private func open(at location: CGPoint) {
        let headerBottom = ReadingCardLayout.blockOrigin.y + ReadingCardLayout.headerHeight
        if location.y < headerBottom {
            openBook()
        } else {
            openReader()
        }
    }

    private func openBook() {
        guard let thumbnail, let route = thumbnail.route else { return }
        thumbnail.onTap()
        navigation.open(route)
    }

    /// Текст — сразу в читалку, как карточки «Смотреть дальше» — сразу в плеер.
    private func openReader() {
        thumbnail?.onTap()
        actionBar.open(ShowcaseBlock.reading(block).player)
    }

    /// ✕ — карточка уходит целиком, лента схлопывается (`removeCard`).
    private func dismiss() {
        feedback?.removeCard(.reading(block), from: catalog)
    }

    // MARK: - Стеклянный блок

    private var glassBlock: some View {
        let shape = RoundedRectangle(cornerRadius: PlusRadius.readerBlock, style: .continuous)

        return ZStack(alignment: .topLeading) {
            excerpt
            // Прогрессивный блюр шапки — под затемнением: верхние строки размыты под
            // прогрессом и обложкой и проясняются к тексту (правка пользователя 2026-10-09).
            VariableBlurView(
                maxBlurRadius: ReadingCardLayout.headerBlurRadius,
                direction: .blurredTopClearBottom
            )
            .frame(width: ReadingCardLayout.blockSize.width, height: ReadingCardLayout.headerBlurHeight)
            .allowsHitTesting(false)
            scrim
        }
        .frame(
            width: ReadingCardLayout.blockSize.width,
            height: ReadingCardLayout.blockSize.height,
            alignment: .topLeading
        )
        .clipShape(shape)
        .glassSurface(shape, blur: PlusMetrics.buttonBlur, border: .white.opacity(0.06))
    }

    /// Кадр фиксирован по макету, чтобы полтысячи точек текста не перемерялись на скролле,
    /// а `drawingGroup` запекает их в один растр — под клипом это самое дорогое место карточки.
    private var excerpt: some View {
        Text(block.excerpt)
            .plusText(.textL, .medium)
            .foregroundStyle(Color.fillOne)
            .frame(
                width: ReadingCardLayout.excerptSize.width,
                height: ReadingCardLayout.excerptSize.height,
                alignment: .topLeading
            )
            .drawingGroup()
            .offset(x: ReadingCardLayout.excerptOrigin.x, y: ReadingCardLayout.excerptOrigin.y)
    }

    private var scrim: some View {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(ReadingCardLayout.scrimOpacity), location: 0),
                .init(color: .black.opacity(ReadingCardLayout.scrimOpacity), location: ReadingCardLayout.scrimSolidUntil),
                .init(color: .clear, location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(width: ReadingCardLayout.scrimSize.width, height: ReadingCardLayout.scrimSize.height)
        .allowsHitTesting(false)
    }

    // MARK: - Прогресс

    private var timeline: some View {
        VStack(alignment: .leading, spacing: ReadingCardLayout.timelineRowSpacing) {
            HStack(spacing: ReadingCardLayout.timelineGap) {
                Text(percentLabel)
                    .plusText(.textS, .medium)
                    .foregroundStyle(Color.fillSubtitle)

                PlusProgressBar(progress: block.progress, width: ReadingCardLayout.trackWidth)
            }

            Text(block.remaining)
                .plusText(.textS, .medium)
                .foregroundStyle(Color.fillOne)
        }
    }

    private var percentLabel: String {
        "\(Int((block.progress * 100).rounded()))%"
    }

    // MARK: - Мини-книга

    private var miniBook: some View {
        miniBookCover
            .background { miniBookGlow }
            .rotationEffect(ReadingCardLayout.miniBookRotation)
    }

    private var miniBookCover: some View {
        ArtworkImage(source: block.cover)
            .aspectRatio(contentMode: .fill)
            .frame(width: ReadingCardLayout.miniBookSize.width, height: ReadingCardLayout.miniBookSize.height)
            .clipped()
            .coverBorder(Rectangle())
    }

    /// Тот же приём, что в `AmbilightArtwork`: ореол запекается в один растр, иначе блюр
    /// пересчитывается на каждом кадре скролла. Кадр расширен, чтобы растр не срезал свечение.
    private var miniBookGlow: some View {
        let spill = ReadingCardLayout.miniBookGlowBlur * AmbilightConfig.spillFactor

        return miniBookCover
            .blur(radius: ReadingCardLayout.miniBookGlowBlur)
            .frame(
                width: ReadingCardLayout.miniBookSize.width + spill * 2,
                height: ReadingCardLayout.miniBookSize.height + spill * 2
            )
            .drawingGroup()
            .opacity(ReadingCardLayout.miniBookGlowOpacity)
            .allowsHitTesting(false)
            // Вторая копия той же обложки — VoiceOver не должен называть её дважды.
            .accessibilityHidden(true)
    }
}

/// Источник зума в экран книги — стеклянный блок, тем же маршрутом, что у миниатюр витрины.
private struct ReadingZoomSource: ViewModifier {
    let context: ShowcaseThumbnailContext?

    func body(content: Content) -> some View {
        if let context, let route = context.route {
            content.matchedTransitionSource(id: route, in: context.zoom)
        } else {
            content
        }
    }
}
