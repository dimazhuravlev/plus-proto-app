import SwiftUI

/// Объёмная книга из плоской обложки: передняя доска, блок страниц под ней и ореол.
///
/// В макете на этом месте лежал готовый PNG `2004:10746` — рендер конкретной книги.
/// У живой обложки из Google Books такого рендера нет, поэтому объём собирается здесь,
/// а геометрия снята с мокового PNG замером:
/// - углы четырёхугольника в pt: (1.0, 26.0), (156.7, 0), (185.7, 232.0), (38.0, 256.7) —
///   это прямоугольник, повёрнутый на −9.47°, с едва заметной перспективой (правая кромка
///   завалена на 7.1° вместо 9.5°). Перспективу не воспроизводим: расхождение 8pt на 158,
///   а честный проективный трансформ требует `CATransform3D` и второго прохода растеризации;
/// - блок страниц **только снизу**, ровно 8.0pt, градиент (206,215,218) → (161,161,161);
/// - слева не страницы, а притенённый корешок: 2.7pt потемнения самой обложки.
struct BookRender: View {
    let cover: ArtworkSource
    /// Габарит из макета — AABB повёрнутой книги.
    let box: CGSize
    let glowOpacity: Double

    private static let rotation = Angle.degrees(-9.47)
    /// Высота блока страниц под обложкой.
    private static let pageThickness: CGFloat = 8
    /// Ширина потемнения у корешка.
    private static let spineWidth: CGFloat = 2.7
    /// Скругление углов у мокового рендера почти нулевое.
    private static let corner: CGFloat = 2

    var body: some View {
        ZStack {
            // Ореол — тот же рендер в блюре. Запекаем растром: живой блюр 28pt
            // пересчитывался бы на каждом кадре скролла.
            //
            // Лежит **снаружи** миниатюры, а не внутри неё: зум-переход показывает
            // источник портлетом, обрезанным по кадру источника, и ореол внутри
            // срезался бы вместе с ним — на возврате книга стояла бы без свечения,
            // пока система не уберёт портлет (жалоба 2026-08-29).
            slab
                .blur(radius: PlusMetrics.ambilightBlur)
                .drawingGroup()
                .opacity(glowOpacity)
                .allowsHitTesting(false)
                // Вторая копия той же обложки — VoiceOver не должен называть её дважды.
                .accessibilityHidden(true)

            // Кадр по AABB повёрнутой книги: в него рендер помещается целиком,
            // значит портлет перехода ничего у него не срежет.
            slab
                .frame(width: box.width, height: box.height)
                .showcaseThumbnail()
        }
        .frame(width: box.width, height: box.height)
    }

    /// Книга целиком, повёрнутая **одним** модификатором: раздельные повороты доски
    /// и блока страниц крутились бы вокруг разных центров и разъехались бы на кромке.
    private var slab: some View {
        VStack(spacing: 0) {
            face
            pages
        }
        .frame(width: slabSize.width, height: slabSize.height)
        .rotationEffect(Self.rotation)
    }

    private var face: some View {
        ResolvedArtwork(source: cover) { image in
            image
                .resizable()
                .scaledToFill()
        }
        .frame(width: slabSize.width, height: slabSize.height - Self.pageThickness)
        .clipped()
        // Потемнение у корешка: без него обложка читается как наклеенная картинка,
        // а не как передняя доска переплёта.
        .overlay(alignment: .leading) {
            LinearGradient(
                colors: [.black.opacity(0.45), .black.opacity(0.12), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: Self.spineWidth * 2)
            .allowsHitTesting(false)
        }
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: Self.corner,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: Self.corner,
                style: .continuous
            )
        )
    }

    /// Блок страниц под доской.
    private var pages: some View {
        UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: Self.corner,
            bottomTrailingRadius: Self.corner,
            topTrailingRadius: 0,
            style: .continuous
        )
        .fill(
            LinearGradient(
                colors: [
                    Color(red: 206 / 255, green: 215 / 255, blue: 218 / 255),
                    Color(white: 161 / 255),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .frame(height: Self.pageThickness)
    }

    /// Стороны невращённой книги, при которых её AABB совпадает с боксом макета.
    /// Из системы `w·cos + h·sin = box.w`, `w·sin + h·cos = box.h`.
    private var slabSize: CGSize {
        let c = cos(abs(Self.rotation.radians))
        let s = sin(abs(Self.rotation.radians))
        let det = c * c - s * s
        return CGSize(
            width: (box.width * c - box.height * s) / det,
            height: (box.height * c - box.width * s) / det
        )
    }
}
