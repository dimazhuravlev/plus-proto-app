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
/// 35 — весь хром (`chromeGlass`: пилюли r32, тост, тайлы табов, круглые кнопки навбаров),
/// 20 — прочие круглые кнопки 40pt и стеклянные блоки.
struct GlassSurface<S: InsettableShape>: ViewModifier {
    let shape: S
    let blur: CGFloat
    let fill: Color
    let border: Color
    let borderWidth: CGFloat
    /// Затемнение размытого фона — чёрный слой между блюром и заливкой. Ноль у всех,
    /// кроме хрома (`ChromeGlass`).
    var dim: Double = 0

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    BackdropBlurView(radius: blur)
                    Color.black.opacity(dim)
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

/// Стекло хрома — один рецепт (`chromeGlass`) на пилюли action bar (поиск, «назад»,
/// мини-плееры, чипы книги и кино), тост, тайлы табов и круглые кнопки навбаров и читалки:
/// блюр 35, затемнение, белый 10 %, бордер серых кнопок. Макетный рецепт (блюр + белый 10 %)
/// над светлыми обложками светлел, и белые текст и иконки в нём тонули (правка пользователя
/// 2026-10-10). Под заливку лёг чёрный слой: чёрный фон он не меняет, светлый приглушает.
/// Сила — одним слайдером в дебаг-меню профиля, хранится в `UserDefaults`; каждая
/// поверхность читает её из того же `@AppStorage`, локальных значений нет.
enum ChromeGlass {
    static let dimKey = "chromeGlassDim"
    static let defaultDim: Double = 0.4
}

/// Стекло хрома: общий рецепт серых кнопок с затемнением фона из дебаг-меню.
/// Бордер — серых кнопок; своим бывает только у тайлов табов.
private struct ChromeGlassSurface<S: InsettableShape>: ViewModifier {
    @AppStorage(ChromeGlass.dimKey) private var dim = ChromeGlass.defaultDim
    let shape: S
    let blur: CGFloat
    let border: Color
    let borderWidth: CGFloat

    func body(content: Content) -> some View {
        content.modifier(GlassSurface(
            shape: shape,
            blur: blur,
            fill: .buttonsPrimary,
            border: border,
            borderWidth: borderWidth,
            dim: dim
        ))
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
        chromeGlass(Capsule(style: .continuous))
    }

    /// Стекло хрома произвольной формы — пилюля, чипы книги и кино в action bar, тост, тайлы
    /// табов, круглые кнопки навбаров и читалки. Рецепт один: блюр 35, затемнение из дебаг-меню,
    /// белый 10 %, бордер серых кнопок. Параметры у бордера — только для тайлов табов.
    func chromeGlass<S: InsettableShape>(
        _ shape: S,
        blur: CGFloat = PlusMetrics.glassBlur,
        border: Color = SecondaryButtonBorder.color,
        borderWidth: CGFloat = SecondaryButtonBorder.width
    ) -> some View {
        modifier(ChromeGlassSurface(shape: shape, blur: blur, border: border, borderWidth: borderWidth))
    }

    /// Тайл иконки таба 40×40 r14 — figma-tabbar §5. В макете (`2004:9375` / `2004:9387`) это
    /// плоская заливка white 10 % без блюра; решением пользователя 2026-10-10 тайл — то же
    /// стекло хрома, что у остального хрома (блюр 35, затемнение). Свой остался бордер:
    /// white 4 % (неактивный) / 6 % × 0.733pt (активный).
    func glassIconTile(
        border: Color = .white.opacity(0.04),
        borderWidth: CGFloat = PlusMetrics.hairline
    ) -> some View {
        chromeGlass(
            RoundedRectangle(cornerRadius: PlusRadius.iconTile, style: .continuous),
            border: border,
            borderWidth: borderWidth
        )
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
