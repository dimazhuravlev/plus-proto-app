import SwiftUI

// MARK: - Геометрия

/// Карточка «Моя Волна» — `2004:10733`, figma-screen1 §3.5.
/// Кадр карточки — слот витрины: ширина экрана, высота 316 макета. По X координаты остаются
/// в системе кадра витрины, по Y из спеки вычтен верх слота. Геометрия орба — общая
/// с промо «Главной» (`VibeOrbGeometry`). Числа здесь — макет на 402; на экране они
/// умножаются на `ShowcaseLayout.scale`.
private enum VibeGeometry {
    static let slot = ShowcaseLayout.Slot.vibe

    /// `2004:10738` — текстовая колонка в (208, 1118), внутренний зазор 12.
    static let textOrigin = CGPoint(x: 208, y: 1118 - slot.top)
    static let textGap: CGFloat = 12
    static let titleWidth: CGFloat = 115
    /// Подзаголовок в макете шире колонки — перенос строк считается по 124.
    static let subtitleWidth: CGFloat = 124
    static let subtitleOpacity: Double = 0.6

    /// Доля карточки на экране, с которой орб оживает.
    static let visibilityThreshold: Double = 0.1
}

// MARK: - Карточка

/// «Моя Волна»: неоновый орб слева, заголовок с подзаголовком и пара ✕/✓ справа
/// (`ShowcaseFeedbackPair`: ✕ — другая «Волна», ✓ — то, что надо).
struct MyVibeCard: View {
    let block: VibeBlock

    /// Орб анимируется только пока карточка на экране: таймлайн вхолостую съедает кадры ленты.
    @State private var isVisible = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Орб — интерактивная миниатюра карточки: заголовок, подзаголовок и ♥/✕
            // остаются снаружи. Своей сущности у «Моей Волны» нет, поэтому тап только
            // включает плеер — разворачиваться некуда.
            // Смена по ✕ — у каждого слоя орба своя (`VibeOrb`), не у орба целиком.
            VibeOrb(art: block.art, isAnimating: isVisible, scale: ShowcaseLayout.scale)
                .showcaseThumbnail()
                .showcasePlaced(at: ShowcaseLayout.scaled(VibeOrbGeometry.haloOrigin))

            textColumn
        }
        .frame(width: PlusMetrics.screenWidth, height: VibeGeometry.slot.frameHeight, alignment: .topLeading)
        .onScrollVisibilityChange(threshold: VibeGeometry.visibilityThreshold) { isVisible = $0 }
    }

    // MARK: Текст

    private var textColumn: some View {
        VStack(alignment: .leading, spacing: VibeGeometry.textGap) {
            GradientText(block.title, from: .fillOne, to: .white.opacity(0.7))
                .plusText(.textM, .medium)
                .frame(width: VibeGeometry.titleWidth * ShowcaseLayout.scale, alignment: .leading)
                .showcaseSwappable()

            GradientText(block.subtitle, from: .fillOne, to: .white.opacity(0.6))
                .plusText(.textM, .medium)
                .frame(width: VibeGeometry.subtitleWidth * ShowcaseLayout.scale, alignment: .leading)
                .opacity(VibeGeometry.subtitleOpacity)
                .showcaseSwappable()

            ShowcaseFeedbackPair()
        }
        .offset(x: VibeGeometry.textOrigin.x * ShowcaseLayout.scale, y: VibeGeometry.textOrigin.y * ShowcaseLayout.scale)
    }
}

#Preview {
    // ScrollView обязателен: без него `onScrollVisibilityChange` не сработает и орб не оживёт.
    ScrollView {
        MyVibeCard(block: VibeBlock(
            id: "my-vibe",
            title: "Моя Волна",
            subtitle: "Атмосферный постпанк, когда внутри пасмурно",
            cover: .asset("mockPlayerCover")
        ))
    }
    .background(Color.black)
}
