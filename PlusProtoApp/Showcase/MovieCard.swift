import SwiftUI

/// Геометрия карточки кино `2004:10766` (figma-screen1 §3.2). В спеке координаты даны
/// в кадре витрины шириной 402 — в локальные переводим вычитанием верха слота.
private enum MovieCardLayout {
    static let slot = ShowcaseLayout.Slot.movie

    /// Постер `2004:10768` и его ореол `2004:10767` — одна пара с общим поворотом
    static let posterSize = CGSize(width: 180, height: 270)
    static let posterRotation = Angle.degrees(-3)
    /// Свечение ореола для кино и альбома (§7)
    static let glowOpacity = 0.70

    /// Центр постера. X 122 — из спеки. Y: повёрнутый бокс начинается ровно с верха слота,
    /// значит центр лежит на его полувысоте (270·cos3° + 180·sin3°)/2 = 139.52
    /// (в кадре витрины это ровно 360).
    static let posterCenter = CGPoint(x: 122, y: 139.52)
    static let posterOrigin = CGPoint(
        x: posterCenter.x - posterSize.width / 2,
        y: posterCenter.y - posterSize.height / 2
    )

    /// Подпись `2004:10769` — справа от постера, первые буквы наезжают на его край
    static let captionOrigin = CGPoint(x: 190.66, y: 391.65 - slot.top)
    static let captionWidth: CGFloat = 182.68

    /// Пара ♥/✕ `2004:10770` — под левым нижним углом постера, слегка на него заходит
    static let buttonsOrigin = CGPoint(x: 50, y: 478.99 - slot.top)
}

/// Карточка кино в витрине: постер с ореолом, подпись справа и пара ♥/✕.
/// Кадр — слот `.movie`, внутри всё расставлено абсолютно, как в макете.
/// Ореол выходит за кадр карточки — клипать её нельзя.
struct MovieCard: View {
    let block: MovieBlock

    var body: some View {
        ZStack(alignment: .topLeading) {
            cardFrame
            poster
            caption
            buttons
        }
    }

    /// Задаёт размер слота, чтобы смещения отсчитывались от левого верхнего угла карточки
    private var cardFrame: some View {
        Color.clear
            .frame(width: ShowcaseLayout.designWidth, height: MovieCardLayout.slot.height)
            .allowsHitTesting(false)
    }

    /// Постер — интерактивная миниатюра карточки: он и нажимается, и разворачивается
    /// в экран фильма. Миниатюрой себя помечает сам `AmbilightArtwork`: граница
    /// источника зума проходит между постером и его ореолом, и знает о ней он.
    /// Зум стартует с габарита повёрнутого постера, а не с раздутого свечением бокса.
    private var poster: some View {
        AmbilightArtwork(
            source: block.poster,
            size: MovieCardLayout.posterSize,
            rotation: MovieCardLayout.posterRotation,
            glowOpacity: MovieCardLayout.glowOpacity
        )
        .showcasePlaced(at: MovieCardLayout.posterOrigin)
    }

    /// Градиент уведён в цвет постера с той стороны, где постер лежит (§1)
    private var caption: some View {
        GradientText(block.caption, from: block.captionTint, to: .fillOne)
            .plusTextM()
            .frame(width: MovieCardLayout.captionWidth, alignment: .leading)
            .offset(x: MovieCardLayout.captionOrigin.x, y: MovieCardLayout.captionOrigin.y)
    }

    private var buttons: some View {
        LikeDismissPair()
            .offset(x: MovieCardLayout.buttonsOrigin.x, y: MovieCardLayout.buttonsOrigin.y)
    }
}
