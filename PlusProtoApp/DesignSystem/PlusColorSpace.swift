import SwiftUI

/// В каком пространстве читаются числа цветов макета: хексы палитры, градиентов
/// и станций, компоненты `Color(paletteRed:…)` (решение пользователя 2026-11-04).
/// По умолчанию — Display P3: те же числа на экране айфона насыщеннее, у фиолетовых
/// Плюса на 7–12 %, у красного и зелёного — до 23 %; белый, серые и чёрный не меняются.
/// Тумблер дебаг-меню возвращает sRGB — так цвета выглядят в Фигме прототипа, пока
/// её файлы в sRGB (палитра «🌈 Стили» уже в P3).
///
/// Наблюдаемое: цвет из хекса читает пространство в `body`, и смена сразу видна на всех
/// экранах. Поэтому цвет из чисел — только вычисляемым свойством: `static let` запомнил
/// бы пространство первого обращения. Холст (`Canvas`) рисует вне `body` — цвета для него
/// берутся в `body` и передаются в замыкание.
///
/// Не касается картинок и видео (их профиль — в файле) и тонов, снятых с картинок
/// (`ArtworkLoader`): они — в пространстве картинки.
@Observable
final class PlusColorSpace {
    static let shared = PlusColorSpace()

    /// Ключ `UserDefaults`; нет записи — P3. Задаётся и аргументом запуска:
    /// `-paletteDisplayP3 NO` — sRGB.
    static let storageKey = "paletteDisplayP3"

    private(set) var isP3: Bool

    private init() {
        // `bool(forKey:)`, а не `as? Bool`: аргумент запуска приходит строкой «NO».
        let defaults = UserDefaults.standard
        isP3 = defaults.object(forKey: Self.storageKey) == nil || defaults.bool(forKey: Self.storageKey)
    }

    /// Пространство для `Color(_:red:green:blue:opacity:)`.
    var rgbSpace: Color.RGBColorSpace { isP3 ? .displayP3 : .sRGB }

    func setP3(_ value: Bool) {
        guard value != isP3 else { return }
        isP3 = value
        UserDefaults.standard.set(value, forKey: Self.storageKey)
    }

    /// Линейный sRGB → линейный Display P3 (общая точка белого D65). Для цветов,
    /// посчитанных в sRGB-координатах (OKLab), когда палитра в P3.
    static func linearP3(fromLinearSRGB rgb: SIMD3<Double>) -> SIMD3<Double> {
        SIMD3(
            0.8224621 * rgb.x + 0.1775380 * rgb.y,
            0.0331941 * rgb.x + 0.9668058 * rgb.y,
            0.0170827 * rgb.x + 0.0723974 * rgb.y + 0.9105199 * rgb.z
        )
    }
}

extension Color {
    /// Цвет макета компонентами 0…1 — в пространстве палитры (`PlusColorSpace`).
    init(paletteRed red: Double, green: Double, blue: Double, opacity: Double = 1) {
        self.init(PlusColorSpace.shared.rgbSpace, red: red, green: green, blue: blue, opacity: opacity)
    }
}
