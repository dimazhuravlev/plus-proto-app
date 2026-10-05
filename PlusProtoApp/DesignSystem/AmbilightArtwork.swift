import SwiftUI

enum AmbilightConfig {
    /// Насколько ореол выходит за края обложки — в радиусах блюра.
    /// Нужно, чтобы растеризация не срезала свечение по границе макета.
    static let spillFactor: CGFloat = 2.5
}

/// Обложка с ореолом: за резкой копией лежит та же картинка в блюре (figma-screen1 §7).
/// Поворот применяется к обложке вместе со слоями поверх неё, ореол поворачивается тем же
/// углом, поэтому всегда лежит точно под ней.
/// `glowOpacity` из макета: 0.7 — кино и альбом, 0.5 — видеокадр, 0.3 — изометрическая книга.
///
/// Компонент **сам** помечает обложку интерактивной миниатюрой витрины
/// (`showcaseThumbnail`), а не отдаёт это карточке. Это требование зум-перехода:
/// граница источника проходит между обложкой и ореолом, и знает о ней только этот
/// компонент — см. `cover`.
struct AmbilightArtwork<Overlay: View>: View {
    let source: ArtworkSource
    let size: CGSize
    let corner: CGFloat
    let rotation: Angle
    let glowOpacity: Double
    /// Слои поверх обложки, внутри её кадра: видео и подпись у «продолжить смотреть».
    /// Едут параметром внутрь компонента, а не навешиваются на него снаружи, потому что
    /// источником зума обязана быть обложка **вместе с ними**: иначе на возврате
    /// вместо видеокадра с прогрессом на секунду встанет голый постер.
    @ViewBuilder let overlay: () -> Overlay

    init(
        source: ArtworkSource,
        size: CGSize,
        corner: CGFloat = PlusRadius.card,
        rotation: Angle = .zero,
        glowOpacity: Double,
        @ViewBuilder overlay: @escaping () -> Overlay
    ) {
        self.source = source
        self.size = size
        self.corner = corner
        self.rotation = rotation
        self.glowOpacity = glowOpacity
        self.overlay = overlay
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
    }

    /// Габарит повёрнутой обложки. Кадр миниатюры равен именно ему, а не сторонам
    /// обложки: `rotationEffect` кадр не двигает, и на этой разнице (у постера кино
    /// 180×270 под −3° это 193.9×279.1) зум-переход срезал углы — см. `cover`.
    private var tiltedBox: CGSize {
        let c = abs(cos(rotation.radians))
        let s = abs(sin(rotation.radians))
        return CGSize(
            width: size.width * c + size.height * s,
            height: size.width * s + size.height * c
        )
    }

    private func artwork(_ image: Image) -> some View {
        image
            .resizable()
            .scaledToFill()
            .frame(width: size.width, height: size.height)
            .clipped()
    }

    var body: some View {
        // Картинка разрешается один раз на весь компонент: и кадр, и ореол должны
        // смениться в одном апдейте, иначе на прилёте живой обложки свечение
        // отстанет от неё на кадр.
        ResolvedArtwork(source: source) { image in
            ZStack {
                // Ореол — сосед миниатюры, а не её фон: фон попал бы внутрь
                // источника зума и был бы срезан вместе с ним (см. `cover`).
                glow(image).rotationEffect(rotation)
                cover { artwork(image) }
            }
        } placeholder: {
            // Плейсхолдер обязан совпадать с обложкой кадром и формой. Дефолтный —
            // это голый `Color`: он тянется по предложению родителя и рисуется прямым
            // прямоугольником, поэтому до прилёта картинки обложка была и не того
            // размера, и без скруглений, а потом прыгала в кадр.
            cover { Color.buttonsPrimary.frame(width: size.width, height: size.height) }
        }
        // Кадр компонента — стороны обложки, как их знает макет. Наклон и ореол
        // выходят за него, но карточки миниатюру не клипают, а позиции в слотах
        // считаны именно от этого кадра.
        .frame(width: size.width, height: size.height)
    }

    /// Обложка со слоями поверх — и **ровно она** источник зум-перехода.
    ///
    /// Система показывает источник не живой вью, а портлетом, обрезанным по кадру
    /// источника, и держит его на экране ещё 0.7–2с после того, как экран сущности
    /// уже закрылся. Всё, что вью рисует за своим кадром, в этом портлете срезано:
    /// пока источником была обложка целиком, на возврате постер стоял с отрезанными
    /// углами и без ореола, а потом скачком становился нормальным (жалоба 2026-08-29).
    ///
    /// Поэтому граница проходит здесь: наклон уезжает **внутрь** кадра (кадр расширен
    /// до `tiltedBox`), а ореол остаётся снаружи — соседом по `ZStack`, а не фоном
    /// миниатюры. Портлет получается копией карточки пиксель в пиксель, и сколько бы
    /// система его ни держала, подмены не видно.
    private func cover(@ViewBuilder _ face: () -> some View) -> some View {
        ZStack {
            face()
                .clipShape(shape)
            overlay()
        }
        .frame(width: size.width, height: size.height)
        .coverBorder(shape)
        // Внутри кадра лежат слои шире его самого; без явной формы хит-зона
        // раздувалась до их габарита (замер дампом доступности: 359×156
        // против видимых 277×156 у видеокадра).
        .contentShape(shape)
        .rotationEffect(rotation)
        .frame(width: tiltedBox.width, height: tiltedBox.height)
        .showcaseThumbnail()
    }

    /// Запекаем ореол в один растр: блюр этого размера иначе пересчитывается рендер-сервером
    /// на каждом кадре скролла. Рамка увеличена, чтобы растеризация не срезала свечение.
    private func glow(_ image: Image) -> some View {
        let spill = PlusMetrics.ambilightBlur * AmbilightConfig.spillFactor
        return artwork(image)
            .blur(radius: PlusMetrics.ambilightBlur)
            .frame(width: size.width + spill * 2, height: size.height + spill * 2)
            .drawingGroup()
            .opacity(glowOpacity)
            .allowsHitTesting(false)
            // Ореол — вторая копия той же картинки: без этого VoiceOver называет обложку дважды.
            .accessibilityHidden(true)
    }
}

extension AmbilightArtwork where Overlay == EmptyView {
    init(
        source: ArtworkSource,
        size: CGSize,
        corner: CGFloat = PlusRadius.card,
        rotation: Angle = .zero,
        glowOpacity: Double
    ) {
        self.init(
            source: source,
            size: size,
            corner: corner,
            rotation: rotation,
            glowOpacity: glowOpacity
        ) { EmptyView() }
    }

    init(
        image name: String,
        size: CGSize,
        corner: CGFloat = PlusRadius.card,
        rotation: Angle = .zero,
        glowOpacity: Double
    ) {
        self.init(
            source: .asset(name),
            size: size,
            corner: corner,
            rotation: rotation,
            glowOpacity: glowOpacity
        )
    }
}
