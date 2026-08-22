import SwiftUI

/// Фон витрины: обложка первого блока, растянутая на две ширины экрана и размытая
/// (`2004:10702`, figma-screen1 §0). Цвет фона наследуется от контента — поэтому
/// экран 1 в макете зелёно-тёмный, а экран 2 тёпло-красный.
///
/// Живёт под лентой и **не скроллится вместе с ней**: в макете это ambient-подсветка
/// всего экрана, а не первый элемент списка.
struct ShowcaseBackdrop: View {
    let source: ArtworkSource

    var body: some View {
        // Координаты макета отсчитываются от левого верхнего угла кадра витрины,
        // поэтому кладём слой в topLeading и смещаем на (-201, -81) как есть.
        ZStack(alignment: .topLeading) {
            Color.clear
            ArtworkImage(source: source)
                .scaledToFill()
                .frame(
                    width: ShowcaseLayout.Backdrop.size.width,
                    height: ShowcaseLayout.Backdrop.size.height
                )
                .clipped()
                .blur(radius: ShowcaseLayout.Backdrop.blur)
                .opacity(ShowcaseLayout.Backdrop.opacity)
                // Растр вместо живого блюра: 100pt по картинке 804×2269 — самая дорогая
                // операция экрана, а пересчитывать её нужно только при смене контента.
                .drawingGroup()
                .offset(
                    x: ShowcaseLayout.Backdrop.origin.x,
                    y: ShowcaseLayout.Backdrop.origin.y
                )
        }
        .allowsHitTesting(false)
    }
}
