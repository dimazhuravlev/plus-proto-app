import SwiftUI

/// Геометрия карточки книги — figma-screen1 §3.4. Координаты локальные: из абсолютных Y
/// макета вычтен верх слота `ShowcaseLayout.Slot.book` (787.96), X совпадает с макетом —
/// кадр карточки во всю ширину витрины.
private enum BookCardLayout {
    static let slot = ShowcaseLayout.Slot.book

    /// Центр обложки изометрической книги `2004:10749` в координатах экрана:
    /// (314.17, 924.02). Кадр рендера отсчитывается от него — см. `BookRender.bounds`.
    ///
    /// Прежде кадр стоял от y 825.6 — это верх полоски корешка, а не книги: верх книги —
    /// правый верхний угол обложки на 799.5, и книга стояла на 26pt ниже макета.
    /// Правым краем книга уходит за экран (до x 410.6) — так в макете.
    static let faceCenter = CGPoint(x: 314.17, y: 924.02 - slot.top)
    static let renderOrigin = CGPoint(
        x: faceCenter.x + BookRender.bounds.minX,
        y: faceCenter.y + BookRender.bounds.minY
    )

    /// Ambilight в экспорт не запечён (§7): дубль рендера в блюре 28, у книги opacity 0.30.
    static let glowOpacity = 0.30

    /// Подпись `2004:10753`: (15, 886) шириной 192, выключка вправо.
    static let captionOrigin = CGPoint(x: 15, y: 886 - slot.top)
    static let captionWidth: CGFloat = 192

    /// Зазор до пары ✕/✓ `2004:10752/10754`; её правый край сходится с краем подписи:
    /// 15 + 192 = 121 + (40 + 6 + 40). Пара — под подписью своей высоты: новая книга
    /// по ✕ встаёт вместе со своей парой (`ShowcaseFeedbackPair`).
    static let captionToButtons: CGFloat = 8
}

/// Карточка книги: изометрический рендер прижат к правому краю экрана, слева от него —
/// подпись с выключкой вправо и пара ✕/✓ под ней. Интерактивен только рендер.
struct BookCard: View {
    let block: BookBlock

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Рендер — интерактивная миниатюра карточки. Миниатюрой себя помечает
            // сам `BookRender`: ореол обязан остаться снаружи источника зума.
            BookRender(cover: block.render, glowOpacity: BookCardLayout.glowOpacity)
                .showcaseSwappable()
                .showcasePlaced(at: BookCardLayout.renderOrigin)

            VStack(alignment: .trailing, spacing: BookCardLayout.captionToButtons) {
                GradientText(block.caption, from: .fillOne, to: block.captionTint)
                    .plusText(.textM, .medium)
                    .multilineTextAlignment(.trailing)
                    .frame(width: BookCardLayout.captionWidth, alignment: .trailing)
                    .showcaseSwappable()

                ShowcaseFeedbackPair()
            }
            .offset(x: BookCardLayout.captionOrigin.x, y: BookCardLayout.captionOrigin.y)
        }
        .frame(
            width: ShowcaseLayout.designWidth,
            height: BookCardLayout.slot.height,
            alignment: .topLeading
        )
    }
}
