import SwiftUI

/// Геометрия карточки альбома `2004:10757` (figma-screen1 §3.3). Координаты спеки даны
/// в кадре витрины шириной 402 — в локальные переводим вычитанием верха слота.
/// Зеркальна карточке кино: обложка справа, тексты слева, наклон противоположного знака (§6).
private enum AlbumCardLayout {
    static let slot = ShowcaseLayout.Slot.album

    /// Обложка `2004:10759` и её ореол `2004:10758` — одна пара с общим поворотом
    static let coverSize = CGSize(width: 180, height: 180)
    static let coverRotation = Angle.degrees(2)
    /// Свечение ореола для кино и альбома (§7)
    static let glowOpacity = 0.70

    /// Центр обложки. X 206.6 — из спеки. Y: повёрнутый бокс начинается ровно с верха слота,
    /// значит центр лежит на его полувысоте 90·(cos2° + sin2°) = 93.09.
    static let coverCenter = CGPoint(x: 206.6, y: 93.09)
    static let coverOrigin = CGPoint(
        x: coverCenter.x - coverSize.width / 2,
        y: coverCenter.y - coverSize.height / 2
    )

    /// Заголовок и подзаголовок `2004:10763` — слева от обложки, наезжают на её левый нижний угол
    static let titlesOrigin = CGPoint(x: 31, y: 674 - slot.top)
    static let titlesWidth: CGFloat = 107

    /// Пара ♥/✕ `2004:10760` — ниже обложки, по её левой трети
    static let buttonsOrigin = CGPoint(x: 122.68, y: 728 - slot.top)
}

/// Карточка альбома в витрине: обложка с ореолом справа, название с исполнителем слева
/// и пара ♥/✕ под ними. Кадр — слот `.album`, внутри всё расставлено абсолютно.
/// Ореол выходит за кадр карточки — клипать её нельзя.
struct AlbumCard: View {
    let block: AlbumBlock

    var body: some View {
        ZStack(alignment: .topLeading) {
            cardFrame
            cover
            titles
            buttons
        }
    }

    /// Задаёт размер слота, чтобы смещения отсчитывались от левого верхнего угла карточки
    private var cardFrame: some View {
        Color.clear
            .frame(width: ShowcaseLayout.designWidth, height: AlbumCardLayout.slot.height)
            .allowsHitTesting(false)
    }

    /// Обложка — интерактивная миниатюра карточки: только она нажимается
    /// и только она разворачивается в экран альбома.
    private var cover: some View {
        AmbilightArtwork(
            source: block.cover,
            size: AlbumCardLayout.coverSize,
            rotation: AlbumCardLayout.coverRotation,
            glowOpacity: AlbumCardLayout.glowOpacity
        )
        .showcaseThumbnail()
        .showcasePlaced(at: AlbumCardLayout.coverOrigin)
    }

    /// Обе строки 15/18 без зазора: в макете это две соседние строки одного бокса.
    ///
    /// По две строки на подпись, а не по одной, как в макете: бокс 107pt подобран под
    /// «Аквариум / Равноденствие», а у живых альбомов названия длиннее и обрезались
    /// на середине слова («Turn On The B…»). Высота блока при этом не растёт —
    /// подписи наезжают на нижний угол обложки, там есть куда.
    private var titles: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(block.title)
                .plusTextM()
                .foregroundStyle(Color.fillOne)
            Text(block.subtitle)
                .plusTextM()
                .foregroundStyle(Color.fillSubtitle)
        }
        .lineLimit(2)
        .frame(width: AlbumCardLayout.titlesWidth, alignment: .leading)
        .offset(x: AlbumCardLayout.titlesOrigin.x, y: AlbumCardLayout.titlesOrigin.y)
    }

    private var buttons: some View {
        LikeDismissPair()
            .offset(x: AlbumCardLayout.buttonsOrigin.x, y: AlbumCardLayout.buttonsOrigin.y)
    }
}
