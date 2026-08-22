import SwiftUI
import CoreText

/// Регистрирует бандленные шрифты в рантайме — UIAppFonts в Info.plist не используется.
/// Вызывается один раз из `PlusProtoAppApp.init()`.
enum FontManager {
    /// Имена файлов без расширения. Все — .ttf из ~/Yandex/Шрифты.
    private static let files = [
        "YS Display-Medium",
        "YS Display-Bold",
        "YS Text-Medium",
        "YS Text-Bold",
    ]

    static func registerFonts() {
        for name in files {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else {
                assertionFailure("Шрифт \(name).ttf не найден в бандле")
                continue
            }
            var error: Unmanaged<CFError>?
            if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                // Повторная регистрация при hot reload — не ошибка, остальное стоит увидеть
                let code = CFErrorGetCode(error?.takeRetainedValue())
                if code != CTFontManagerError.alreadyRegistered.rawValue {
                    assertionFailure("Не удалось зарегистрировать \(name): код \(code)")
                }
            }
        }
    }
}
