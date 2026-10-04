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

/// Бордер серых кнопок — 0.67 × белый 8 % (`Fill/Nine`), у всех один.
enum SecondaryButtonBorder {
    static let color = Color.fillNine
    static let width: CGFloat = 0.67
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

    /// Серая «вторичная» кнопка — стекло: блюр фона под полупрозрачной заливкой и бордер
    /// 0.67 × белый 8 %. Одна поверхность на все серые кнопки проекта — круглые 40,
    /// капсулы, чипы бара, кнопки плееров и виджетов (правка пользователя 2026-10-04:
    /// прежде бордер был то 6 %, то 15 %, то не было его вовсе, как и блюра).
    /// Заливка у кнопок своя: Buttons/Primary 10 % или Buttons/Secondary 8 %.
    func secondaryButtonSurface<S: InsettableShape>(
        _ shape: S,
        fill: Color = .buttonsPrimary,
        blur: CGFloat = PlusMetrics.buttonBlur
    ) -> some View {
        glassSurface(
            shape,
            blur: blur,
            fill: fill,
            border: SecondaryButtonBorder.color,
            borderWidth: SecondaryButtonBorder.width
        )
    }

    /// Пилюли action bar (r32 при высоте 60 схлопывается в капсулу) — figma-actionbar §3.
    func glassPill() -> some View {
        secondaryButtonSurface(Capsule(style: .continuous), blur: PlusMetrics.glassBlur)
    }

    /// Круглые кнопки 40pt — общий бордер серых кнопок. ~~Бордер white 6 % по figma-screen1
    /// §2~~ — с 2026-10-04 у всех серых кнопок один: 0.67 × белый 8 %.
    func glassCircle() -> some View {
        secondaryButtonSurface(Circle())
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
///
/// Не `private`: этим же блюром расфокусируется весь экран под активным поиском
/// (`SearchOverlay`), и радиус там едет от нуля.
struct BackdropBlurView: UIViewRepresentable {
    let radius: CGFloat

    func makeUIView(context: Context) -> UIVisualEffectView {
        let view = UIVisualEffectView(effect: nil)
        view.isUserInteractionEnabled = false
        sync(view)
        return view
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        sync(uiView)
    }

    /// Нулевой радиус — это **отсутствие блюра**, а не блюр силой ноль.
    ///
    /// Разница принципиальная: живой `UIVisualEffectView` всегда снимает всё, что под ним,
    /// в уменьшенном масштабе и растягивает обратно — даже когда `inputRadius == 0`.
    /// Слой поиска висит в дереве постоянно, и из-за этого весь контент под ним
    /// (то есть все экраны во всех табах) шёл размытым, а хром — он выше по цепочке
    /// модификаторов — оставался резким. Поэтому на нуле эффект снимается целиком.
    private func sync(_ view: UIVisualEffectView) {
        guard radius > 0 else {
            view.effect = nil
            return
        }
        if view.effect == nil {
            view.effect = UIBlurEffect(style: .systemUltraThinMaterialDark)
            // Тонировка материала дала бы серый налёт поверх нашей заливки —
            // гасим, оставляем чистый блюр.
            for tint in view.subviews.dropFirst() { tint.alpha = 0 }
        }
        applyRadius(to: view)
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
