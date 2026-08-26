import Foundation

/// Выбор контента витрины: своя случайность на каждый холодный запуск.
///
/// Раньше случайность привязывалась к 30-минутному окну: внутри него каждый запуск
/// строил ровно те же URL, и сеть не трогалась вовсе (ни один из трёх API не шлёт
/// `Cache-Control`, а сервисы ходят с `returnCacheDataElseLoad`). Экономило это
/// квоту Кинопоиска — но кино давно живёт не по окну, а по дисковому запасу
/// (`MoviePool`), а музыке и книгам квота не жмёт вовсе: у Deezer ключа нет,
/// у Google Books ~1000 запросов в сутки против двух-трёх на запуск.
///
/// Ценой окна была главная жалоба пользователя (2026-08-25): полчаса подряд витрина
/// показывала один и тот же альбом и те же книги. Поэтому окна больше нет — зерно
/// у всех трёх доменов случайное на запуск, а воспроизводимость скриншотов даёт
/// `-debugFrozenFeed`, который фиксирует зерно у **всей** витрины, а не только у кино.
enum ShowcaseRotation {
    /// Генератор домена. Соль нужна, чтобы кино, музыка и книги не выбирали
    /// один и тот же индекс из своих пулов — иначе выборки коррелируют.
    static func generator(salt: UInt64) -> SeededGenerator {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "debugFrozenFeed") {
            return SeededGenerator(seed: salt)
        }
        #endif
        return SeededGenerator(seed: UInt64.random(in: .min ... .max))
    }

    /// Генератор для кино — тот же случайный выбор, отдельным именем ради читаемости
    /// вызова в `ShowcaseCatalog`.
    static func movieGenerator() -> SeededGenerator {
        generator(salt: Salt.movies)
    }

    enum Salt {
        static let movies: UInt64 = 1
        static let music: UInt64 = 2
        static let books: UInt64 = 3
    }
}

/// splitmix64 — детерминированный генератор с равномерным распределением.
/// Системный `SystemRandomNumberGenerator` не годится: его нельзя засеять.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
