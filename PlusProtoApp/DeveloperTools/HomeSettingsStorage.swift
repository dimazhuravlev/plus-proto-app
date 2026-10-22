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

    static func save(_ value: Any, forKey key: String) {
        UserDefaults.standard.set(value, forKey: key)
    }
}
