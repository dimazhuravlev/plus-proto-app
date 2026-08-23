import Foundation

/// Окно ротации витрины и детерминированный выбор контента внутри него.
///
/// Зачем: у Кинопоиска 200 запросов в сутки, и если каждый запуск тянет случайную
/// подборку со случайной страницы, отладка сжигает квоту за час. Ни один из трёх API
/// не присылает `Cache-Control` (проверено 2026-08-23), а сервисы ходят с политикой
/// `returnCacheDataElseLoad` — значит **повторный запрос по тому же URL приходит
/// с диска и сети не касается**.
///
/// Поэтому случайность не убирается, а привязывается ко времени: внутри окна каждый
/// запуск строит ровно те же URL (сеть не трогается вовсе), окно сменилось — витрина
/// собралась заново. Побочно это делает скриншотную сверку воспроизводимой.
enum ShowcaseRotation {
    /// Длина окна. 30 минут — это максимум 48 сборок в сутки при квоте 200.
    static let window: TimeInterval = 30 * 60

    /// Номер текущего окна. Он же зерно генератора.
    static var slot: UInt64 {
        #if DEBUG
        // `-debugFreshFeed` — принудительно свежая выборка, минуя окно.
        if UserDefaults.standard.bool(forKey: "debugFreshFeed") {
            return UInt64(Date().timeIntervalSince1970)
        }
        #endif
        return UInt64(max(0, Date().timeIntervalSince1970) / window)
    }

    /// Генератор для кино. Кино живёт не по окну, а по запасу на диске (`MoviePool`):
    /// новый фильм обязан быть при **каждом** холодном запуске, а запросов это не стоит —
    /// выборка идёт из уже скачанной пачки. Поэтому зерно честно случайное.
    ///
    /// `-debugFrozenFeed` фиксирует его: скриншотная сверка должна быть воспроизводимой,
    /// а моков, на которых её раньше делали, у кино больше нет.
    static func movieGenerator() -> SeededGenerator {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "debugFrozenFeed") {
            return SeededGenerator(seed: Salt.movies)
        }
        #endif
        return SeededGenerator(seed: UInt64.random(in: .min ... .max))
    }

    /// Генератор на домен. Соль нужна, чтобы кино, музыка и книги не выбирали
    /// один и тот же индекс из своих пулов — иначе выборки коррелируют.
    static func generator(salt: UInt64) -> SeededGenerator {
        SeededGenerator(seed: slot &* 0x9E3779B97F4A7C15 &+ salt)
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
