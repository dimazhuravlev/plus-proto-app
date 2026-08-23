import SwiftUI

enum AmbilightConfig {
    /// Насколько ореол выходит за края обложки — в радиусах блюра.
    /// Нужно, чтобы растеризация не срезала свечение по границе макета.
    static let spillFactor: CGFloat = 2.5
}

/// Обложка с ореолом: за резкой копией лежит та же картинка в блюре (figma-screen1 §7).
/// Поворот применяется к паре целиком, поэтому ореол всегда точно под обложкой.
/// `glowOpacity` из макета: 0.7 — кино и альбом, 0.5 — видеокадр, 0.3 — изометрическая книга.
struct AmbilightArtwork: View {
    let source: ArtworkSource
    let size: CGSize
    let corner: CGFloat
    let rotation: Angle
    let glowOpacity: Double
    let borderWidth: CGFloat

    init(
        source: ArtworkSource,
        size: CGSize,
        corner: CGFloat = PlusRadius.card,
        rotation: Angle = .zero,
        glowOpacity: Double,
        borderWidth: CGFloat = 1
    ) {
        self.source = source
        self.size = size
        self.corner = corner
        self.rotation = rotation
        self.glowOpacity = glowOpacity
        self.borderWidth = borderWidth
    }

    init(
        image name: String,
        size: CGSize,
        corner: CGFloat = PlusRadius.card,
        rotation: Angle = .zero,
        glowOpacity: Double,
        borderWidth: CGFloat = 1
    ) {
        self.init(
            source: .asset(name),
            size: size,
            corner: corner,
            rotation: rotation,
            glowOpacity: glowOpacity,
            borderWidth: borderWidth
        )
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
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
            artwork(image)
                .clipShape(shape)
                .overlay { shape.strokeBorder(Color.fillNine, lineWidth: borderWidth) }
                .background { glow(image) }
        } placeholder: {
            // Плейсхолдер обязан совпадать с обложкой кадром и формой. Дефолтный —
            // это голый `Color`: он тянется по предложению родителя и рисуется прямым
            // прямоугольником, поэтому до прилёта картинки обложка была и не того
            // размера, и без скруглений, а потом прыгала в кадр.
            Color.buttonsPrimary
                .frame(width: size.width, height: size.height)
                .clipShape(shape)
                .overlay { shape.strokeBorder(Color.fillNine, lineWidth: borderWidth) }
        }
        .rotationEffect(rotation)
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
