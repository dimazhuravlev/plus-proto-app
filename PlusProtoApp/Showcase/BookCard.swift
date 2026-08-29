import SwiftUI

/// Геометрия карточки книги — figma-screen1 §3.4. Координаты локальные: из абсолютных Y
/// макета вычтен верх слота `ShowcaseLayout.Slot.book` (787.96), X совпадает с макетом —
/// кадр карточки во всю ширину витрины.
private enum BookCardLayout {
    static let slot = ShowcaseLayout.Slot.book

    /// Плоский рендер изометрической книги `2004:10746`: 186×257, в координатах экрана
    /// x 216→402, y 825.6→1082.6. Пять слоёв со skew не пересобираем — в PNG уже запечён
    /// поворот −9,47°.
    static let render = CGSize(width: 186, height: 257)

    /// Книга уходит за правый край экрана, в экспорте только видимая часть, поэтому кадр
    /// прижат к правому краю (216 + 186 = 402). По низу рендер на 11,33 выходит за слот —
    /// так в макете, карточку клипать нельзя.
    static let renderOrigin = CGPoint(
        x: ShowcaseLayout.designWidth - render.width,
        y: 825.6 - slot.top
    )

    /// Ambilight в экспорт не запечён (§7): дубль рендера в блюре 28, у книги opacity 0.30.
    static let glowOpacity = 0.30

    /// Подпись `2004:10753`: (15, 886) шириной 192, выключка вправо.
    static let captionOrigin = CGPoint(x: 15, y: 886 - slot.top)
    static let captionWidth: CGFloat = 192

    /// Зазор до пары ♥/✕ `2004:10752/10754`. Подпись — ровно 4 строки по 18 (72),
    /// поэтому пара садится на абсолютные (121, 966) макета, а её правый край сходится
    /// с краем подписи: 15 + 192 = 121 + (40 + 6 + 40).
    static let captionToButtons: CGFloat = 8
}

/// Карточка книги: изометрический рендер прижат к правому краю экрана, слева от него —
/// подпись с выключкой вправо и пара ♥/✕ под ней. Интерактивен только рендер.
struct BookCard: View {
    let block: BookBlock

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Рендер — интерактивная миниатюра карточки. Миниатюрой себя помечает
            // сам `BookRender`: ореол обязан остаться снаружи источника зума.
            BookRender(
                cover: block.render,
                box: BookCardLayout.render,
                glowOpacity: BookCardLayout.glowOpacity
            )
            .showcasePlaced(at: BookCardLayout.renderOrigin)

            VStack(alignment: .trailing, spacing: BookCardLayout.captionToButtons) {
                GradientText(block.caption, from: .fillOne, to: block.captionTint)
                    .plusTextM()
                    .multilineTextAlignment(.trailing)
                    .frame(width: BookCardLayout.captionWidth, alignment: .trailing)

                LikeDismissPair()
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
