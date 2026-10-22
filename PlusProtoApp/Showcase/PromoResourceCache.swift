import Foundation

/// Keeps active carousel resources strongly retained. Only retired resources may
/// be evicted: dropping a visible raster would require changing the view's identity
/// to restart its loader and could leave the card blank between updates.
struct PromoResourceCache<Key: Hashable, Value> {
    private struct Entry {
        let value: Value
        let cost: Int
        let sequence: UInt64
    }
    private var entries: [Key: Entry] = [:]
    private var pinned: Set<Key> = []
    private var sequence: UInt64 = 0
    let countLimit: Int
    let costLimit: Int

    init(countLimit: Int, costLimit: Int) {
        self.countLimit = countLimit
        self.costLimit = costLimit
    }

    subscript(key: Key) -> Value? { entries[key]?.value }

    mutating func retain(_ keys: Set<Key>) {
        pinned = keys
        trim()
    }

    mutating func insert(_ value: Value, for key: Key, cost: Int) {
        sequence &+= 1
        entries[key] = Entry(value: value, cost: max(0, cost), sequence: sequence)
        trim()
    }

    private mutating func trim() {
        var cost = entries.values.reduce(0) { $0 + $1.cost }
        let retired = entries.filter { !pinned.contains($0.key) }
            .sorted { $0.value.sequence < $1.value.sequence }
        for (key, entry) in retired {
            guard entries.count > countLimit || cost > costLimit else { break }
            entries[key] = nil
            cost -= entry.cost
        }
    }
}
