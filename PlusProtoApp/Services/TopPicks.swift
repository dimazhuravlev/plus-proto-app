import Foundation

/// Набор карусели «Топ-10» из уже собранных подборок — без своих запросов к API.
enum TopPicks {
    /// Мест в «Топ-10»
    static let limit = 10

    /// По одному из каждого списка по кругу — первые, потом вторые… Повторы по `key`
    /// (одна книга в двух темах, одно название двумя томами) пропускаются.
    static func roundRobin<Item>(_ lists: [[Item]], limit: Int = limit, key: (Item) -> String) -> [Item] {
        var picked: [Item] = []
        var seen = Set<String>()
        let longest = lists.map(\.count).max() ?? 0
        for index in 0..<longest {
            for list in lists where index < list.count {
                guard picked.count < limit else { return picked }
                if seen.insert(key(list[index]).lowercased()).inserted {
                    picked.append(list[index])
                }
            }
        }
        return picked
    }
}
