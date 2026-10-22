import Foundation

@main struct PromoResourceCacheChecks {
    static func main() {
        var cache = PromoResourceCache<Int, String>(countLimit: 2, costLimit: 20)
        cache.retain([1, 2])
        cache.insert("visible A", for: 1, cost: 8)
        cache.insert("visible B", for: 2, cost: 8)
        cache.insert("retired", for: 3, cost: 8)
        assert(cache[1] == "visible A" && cache[2] == "visible B")
        assert(cache[3] == nil)

        // A visible resource remains available even above the soft memory budget.
        cache.insert("large active", for: 1, cost: 30)
        assert(cache[1] == "large active" && cache[2] == "visible B")
        cache.retain([2])
        assert(cache[1] == nil && cache[2] == "visible B")

        cache.retain([4, 5])
        cache.insert("next A", for: 4, cost: 8)
        cache.insert("next B", for: 5, cost: 8)
        assert(cache[2] == nil && cache[4] == "next A" && cache[5] == "next B")
        cache.retain([])
        cache.insert("new", for: 6, cost: 8)
        assert(cache[4] == nil && cache[5] == "next B" && cache[6] == "new")

        // An active set may exceed the count budget until its keys retire.
        var countCache = PromoResourceCache<Int, String>(countLimit: 1, costLimit: 100)
        countCache.retain([1, 2])
        countCache.insert("active A", for: 1, cost: 1)
        countCache.insert("active B", for: 2, cost: 1)
        assert(countCache[1] == "active A" && countCache[2] == "active B")
        countCache.retain([2])
        assert(countCache[1] == nil && countCache[2] == "active B")
        print("PASS: count/cost limits, active pinning, replacement cost, retirement")
    }
}
