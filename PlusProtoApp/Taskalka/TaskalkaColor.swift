import SwiftUI

/// Цвет поля — функция места на карте (просьба пользователя 2026-11-01: «цветовое
/// распределение согласно координатам, чтобы цвета не повторялись; шире спектр, не только
/// яркие; в районе „Мрак“ может быть чёрный»). У каждой точки поля — свой цвет, у каждого
/// настроения — цвет его места, соседи перетекают друг в друга.
///
/// Считается в OKLCH — перцептивном пространстве: шаг светлоты выглядит ровным, а не как
/// у HSB, где жёлтый и синий одной «яркости» глазу совсем разные.
/// - **Светлота** — по горизонтали: у «мрака» почти чёрный, у «света» светлый.
/// - **Насыщенность** гаснет к «мраку» (там графит, почти без цвета) и чуть к «свету»
///   (пастель), и немного — к «чиллу».
/// - **Тон** — по вертикали, и в каждом ряду свой разбег слева направо: наверху «движ» —
///   тёмно-красный → янтарь → золото, посередине — фиолетовый → розовый, внизу «чилл» —
///   тёмно-синий → бирюза → мята.
enum TaskalkaColorMap {
    private enum Map {
        /// Светлота OKLab: у левой кромки и у правой
        static let darkest: Double = 0.17
        static let lightest: Double = 0.82
        /// Наибольшая насыщенность (OKLCH chroma) — у середины по горизонтали
        static let chroma: Double = 0.17
        /// Насколько гаснет насыщенность к «свету» и к «чиллу»
        static let lightFade: Double = 0.4
        static let calmFade: Double = 0.3
        /// Тон, градусы, у левой и правой кромки: наверху, посередине и внизу. Развёрнуты
        /// без перескока через 0°, чтобы по вертикали тон шёл кратчайшим путём.
        static let top: (Double, Double) = (15, 75)
        static let middle: (Double, Double) = (-70, -20)
        static let bottom: (Double, Double) = (-130, -210)
        /// Слово заголовка — не темнее этого, иначе почти чёрный «мрак» пропал бы на тёмном
        static let wordLightness: Double = 0.68
        /// Второй цвет градиента слова — чуть светлее и чуть сдвинут по тону
        static let wordLift: Double = 0.06
        static let wordHueShift: Double = 22
    }

    struct LCH {
        var l: Double
        var c: Double
        var h: Double
    }

    /// OKLCH в точке поля (в долях).
    static func lch(at point: CGPoint) -> LCH {
        let x = min(max(Double(point.x), 0), 1)
        let y = min(max(Double(point.y), 0), 1)
        let l = Map.darkest + (Map.lightest - Map.darkest) * x
        let rise = smoothstep(0.02, 0.4, x)
        let c = Map.chroma * rise * (1 - Map.lightFade * x * x) * (1 - Map.calmFade * y)
        func across(_ edge: (Double, Double)) -> Double { edge.0 + (edge.1 - edge.0) * x }
        let h = y < 0.5
            ? across(Map.top) + (across(Map.middle) - across(Map.top)) * (y / 0.5)
            : across(Map.middle) + (across(Map.bottom) - across(Map.middle)) * ((y - 0.5) / 0.5)
        return LCH(l: l, c: c, h: h)
    }

    /// sRGB 0…1 в точке поля — цвет точек и свечения под пальцем.
    static func rgb(at point: CGPoint) -> SIMD3<Double> {
        srgb(lch(at: point))
    }

    /// Слово заголовка — градиент двух близких оттенков цвета места (просьба пользователя
    /// 2026-11-01), высветленный до читаемого на тёмном.
    static func wordGradient(at point: CGPoint) -> LinearGradient {
        var base = lch(at: point)
        base.l = max(base.l, Map.wordLightness)
        var lifted = base
        lifted.l = min(1, base.l + Map.wordLift)
        lifted.h += Map.wordHueShift
        return LinearGradient.horizontal(TaskalkaPalette.color(srgb(base)), TaskalkaPalette.color(srgb(lifted)))
    }

    private static func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
        let t = min(max((x - edge0) / (edge1 - edge0), 0), 1)
        return t * t * (3 - 2 * t)
    }

    /// OKLCH → sRGB (Björn Ottosson, OKLab), вне охвата — обрезка по каналам.
    static func srgb(_ color: LCH) -> SIMD3<Double> {
        let hue = color.h * .pi / 180
        let a = color.c * cos(hue), b = color.c * sin(hue)
        let l_ = color.l + 0.3963377774 * a + 0.2158037573 * b
        let m_ = color.l - 0.1055613458 * a - 0.0638541728 * b
        let s_ = color.l - 0.0894841775 * a - 1.2914855480 * b
        let l = l_ * l_ * l_, m = m_ * m_ * m_, s = s_ * s_ * s_
        let linear = SIMD3(
            4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
            -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
            -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
        )
        func gamma(_ v: Double) -> Double {
            let clamped = min(max(v, 0), 1)
            return clamped <= 0.0031308 ? 12.92 * clamped : 1.055 * pow(clamped, 1 / 2.4) - 0.055
        }
        return SIMD3(gamma(linear.x), gamma(linear.y), gamma(linear.z))
    }
}
