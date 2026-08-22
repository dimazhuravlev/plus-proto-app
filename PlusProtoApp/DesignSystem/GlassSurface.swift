import SwiftUI
import UIKit

// MARK: - Модификатор

/// «Стекло» из макета: backdrop-blur под полупрозрачной заливкой + hairline-бордер.
/// Рецепт один на все поверхности (figma-actionbar §1), различается только форма,
/// радиус блюра и непрозрачность бордера.
///
/// Радиус — в CSS-единицах: у поля поиска CSS отдаёт `backdrop-blur 35` при `BACKGROUND_BLUR 70`
/// в панели Figma, и так же вдвое меньше записаны все блюр-константы проекта
/// (glass 35↔70, button 20↔40, ambilight 28↔56, backdrop 100↔200) — единицы меняются только все разом.
/// 35 — пилюли r32, 20 — круглые кнопки 40pt и стеклянные блоки. У тайла иконки таба блюра нет.
struct GlassSurface<S: InsettableShape>: ViewModifier {
    let shape: S
    let blur: CGFloat
    let fill: Color
    let border: Color
    let borderWidth: CGFloat

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    BackdropBlurView(radius: blur)
                    fill
                }
                .clipShape(shape)
            }
            .overlay {
                shape.strokeBorder(border, lineWidth: borderWidth)
            }
            .contentShape(shape)
    }
}

extension View {
    /// Произвольная стеклянная поверхность. Дефолты — общий рецепт: заливка white 10%, бордер white 8% × 0.66pt.
    func glassSurface<S: InsettableShape>(
        _ shape: S,
        blur: CGFloat,
        fill: Color = .buttonsPrimary,
        border: Color = .fillNine,
        borderWidth: CGFloat = PlusMetrics.hairline
    ) -> some View {
        modifier(GlassSurface(shape: shape, blur: blur, fill: fill, border: border, borderWidth: borderWidth))
    }

    /// Пилюли action bar (r32 при высоте 60 схлопывается в капсулу) — figma-actionbar §3.
    func glassPill() -> some View {
        glassSurface(Capsule(style: .continuous), blur: PlusMetrics.glassBlur)
    }

    /// Круглые кнопки 40pt на карточках — figma-screen1 §2: бордер там white 6%, а не 8% как у пилюль.
    func glassCircle() -> some View {
        glassSurface(Circle(), blur: PlusMetrics.buttonBlur, border: .white.opacity(0.06))
    }

    /// Тайл иконки таба 40×40 r14 — figma-tabbar §5. Стекла у него нет: замер обоих вариантов
    /// компонента (`2004:9375` / `2004:9387`) не даёт ни `backdrop-filter`, ни `filter: blur()` —
    /// это плоская заливка white 10% с хайрлайном white 4% (неактивный) / 6% × 0.733pt (активный).
    func glassIconTile(
        border: Color = .white.opacity(0.04),
        borderWidth: CGFloat = PlusMetrics.hairline
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: PlusRadius.iconTile, style: .continuous)
        return background { shape.fill(Color.buttonsPrimary) }
            .overlay { shape.strokeBorder(border, lineWidth: borderWidth) }
            .contentShape(shape)
    }
}

// MARK: - Backdrop blur с управляемым радиусом

/// `.ultraThinMaterial` радиус блюра не отдаёт, а в макете он у каждой поверхности свой.
/// Поэтому подменяем фильтры backdrop-слоя `UIVisualEffectView` — тот же приём,
/// на котором построен VariableBlur из MusicPlayer. Если приватный `CAFilter` недоступен,
/// вью остаётся системным материалом.
private struct BackdropBlurView: UIViewRepresentable {
    let radius: CGFloat

    func makeUIView(context: Context) -> UIVisualEffectView {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        view.isUserInteractionEnabled = false
        // Тонировка материала дала бы серый налёт поверх нашей заливки — гасим, оставляем чистый блюр.
        for tint in view.subviews.dropFirst() { tint.alpha = 0 }
        applyRadius(to: view)
        return view
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        applyRadius(to: uiView)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UIVisualEffectView, context: Context) -> CGSize? {
        nil
    }

    private func applyRadius(to view: UIVisualEffectView) {
        guard let backdrop = view.subviews.first?.layer else { return }

        if let installed = backdrop.filters?.first as? NSObject,
           installed.value(forKey: "inputRadius") != nil {
            installed.setValue(radius, forKey: "inputRadius")
            return
        }

        guard let filterClass = NSClassFromString("CAFilter") as? NSObject.Type,
              let blur = filterClass
                  .perform(NSSelectorFromString("filterWithType:"), with: "gaussianBlur")?
                  .takeUnretainedValue() as? NSObject
        else { return }

        blur.setValue(radius, forKey: "inputRadius")
        blur.setValue(true, forKey: "inputNormalizeEdges")
        backdrop.filters = [blur]
    }
}
