@main enum HomePromoStartChecks {
    static func main() {
        let kinds = ["artist", "album", "artist", "movie", "book"]
        for preferred in -100...100 {
            let index = HomePromoStartPolicy.index(in: kinds, preferred: preferred) { $0 == "artist" }
            precondition(index != nil && kinds[index!] != "artist")
        }
        precondition(HomePromoStartPolicy.index(in: ["artist"], preferred: 0, isArtist: { $0 == "artist" }) == nil)
        precondition(HomePromoStartPolicy.index(in: [String](), preferred: 1, isArtist: { $0 == "artist" }) == nil)
        print("PASS: first promo is never artist, including wrapped indices and empty/all-artist sets")
    }
}
