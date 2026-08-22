import SwiftUI

/// Заголовок витрины с врезками (`2004:10773`, figma-screen1 §3.1).
///
/// Между словами стоят повёрнутые миниатюры сущностей. Вложением в `Text` их не сделать:
/// картинку внутри строки нельзя повернуть, поэтому текст набран с широкими пробелами
/// (U+2007, figure space — не схлопывается и равен ширине цифры), а врезки лежат
/// поверх абсолютным слоем.
struct ShowcaseHeader: View {
    let headline: ShowcaseHeadline

    /// Локальные Y врезок: в модели они в координатах кадра витрины.
    private var slotTop: CGFloat { ShowcaseLayout.Slot.header.top }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear

            FigmaText(
                text: headline.text,
                family: PlusFont.displaySemibold,
                size: 32,
                lineHeight: 36,
                tracking: -0.2
            )
            .foregroundStyle(
                LinearGradient.horizontal(.white, .white.opacity(0.6))
            )
            .lineLimit(nil)
            .frame(width: 354, alignment: .topLeading)
            // Бокс заголовка в макете ниже трёх строк — без fixedSize текст усекается
            // многоточием вместо того, чтобы выйти за него.
            .fixedSize(horizontal: false, vertical: true)
            .offset(x: PlusMetrics.screenMargin, y: 1.21)

            ForEach(headline.chips) { chip in
                chipView(chip)
                    .frame(width: chip.size.width, height: chip.size.height)
                    .rotationEffect(chip.rotation)
                    .offset(x: chip.origin.x, y: chip.origin.y - slotTop)
            }
        }
        .frame(height: ShowcaseLayout.Slot.header.height)
    }

    @ViewBuilder
    private func chipView(_ chip: ShowcaseHeadlineChip) -> some View {
        switch chip.kind {
        case .avatar:
            ArtworkImage(source: chip.artwork)
                .scaledToFill()
                .clipShape(Circle())

        case .poster:
            ArtworkImage(source: chip.artwork)
                .scaledToFill()
                .clipShape(RoundedRectangle(cornerRadius: HeaderChip.posterRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: HeaderChip.posterRadius, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                }

        case .book:
            // Корешок рисуем сами: в Figma он отдельным слоем, но экспорт даёт мусорный
            // слайвер — дешевле поставить полоску по левому краю обложки.
            ZStack(alignment: .leading) {
                ArtworkImage(source: chip.artwork)
                    .scaledToFill()
                Rectangle()
                    .fill(.black.opacity(0.35))
                    .frame(width: HeaderChip.bookSpineWidth)
            }
            .clipShape(RoundedRectangle(cornerRadius: HeaderChip.bookRadius, style: .continuous))
        }
    }
}

/// Числа врезок заголовка — встречаются только здесь.
private enum HeaderChip {
    static let posterRadius: CGFloat = 3
    static let bookRadius: CGFloat = 2
    static let bookSpineWidth: CGFloat = 3
}
