/// Первый показ выбирает карточку без исполнителя; дальнейшие свайпы не ограничены.
enum HomePromoStartPolicy {
    static func index<Item>(in items: [Item], preferred: Int, isArtist: (Item) -> Bool) -> Int? {
        guard !items.isEmpty else { return nil }
        let start = ((preferred % items.count) + items.count) % items.count
        return (0..<items.count).map { (start + $0) % items.count }
            .first { !isArtist(items[$0]) }
    }
}
