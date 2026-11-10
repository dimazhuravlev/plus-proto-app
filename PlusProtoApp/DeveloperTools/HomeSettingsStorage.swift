import Foundation

/// Одни локальные настройки для всех конфигураций приложения.
struct HomeSettingsStorage {
    let defaults: [String: Any]

    func object(forKey key: String) -> Any? {
        UserDefaults.standard.object(forKey: key) ?? defaults[key]
    }

    func dictionary(forKey key: String) -> [String: Any]? {
        object(forKey: key) as? [String: Any]
    }

    /// Типизированное чтение учитывает и YES/NO из одноразовых параметров запуска.
    func bool(forKey key: String) -> Bool {
        if UserDefaults.standard.object(forKey: key) != nil {
            return UserDefaults.standard.bool(forKey: key)
        }
        return defaults[key] as? Bool ?? false
    }

    static func save(_ value: Any, forKey key: String) {
        UserDefaults.standard.set(value, forKey: key)
    }
}
