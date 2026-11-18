import Foundation

/// Artist identities and portraits resolved from the seed albums in Deezer (2026-11-18).
/// Local assets keep the home reserve complete before network loading.
enum PromoAlbumArtists {
    struct Artist { let id: Int; let picture: ArtworkSource }
    static let byAlbumID: [String: Artist] = [
        "dz-101618": Artist(id: 569, picture: .asset("promoAlbumArtist569")), // The Strokes
        "dz-102619": Artist(id: 381, picture: .asset("promoAlbumArtist381")), // The Cure
        "dz-105352": Artist(id: 652, picture: .asset("promoAlbumArtist652")), // Pixies
        "dz-106054": Artist(id: 1041, picture: .asset("promoAlbumArtist1041")), // Cocteau Twins
        "dz-106308": Artist(id: 108420982, picture: .asset("promoAlbumArtist108420982")), // Разные исполнители
        "dz-106700": Artist(id: 1676, picture: .asset("promoAlbumArtist1676")), // Pavement
        "dz-109301": Artist(id: 1069, picture: .asset("promoAlbumArtist1069")), // Portishead
        "dz-224401": Artist(id: 2021, picture: .asset("promoAlbumArtist2021")), // Slowdive
        "dz-230048": Artist(id: 1211, picture: .asset("promoAlbumArtist1211")), // The Mars Volta
        "dz-300592": Artist(id: 642, picture: .asset("promoAlbumArtist642")), // LCD Soundsystem
        "dz-301773": Artist(id: 612, picture: .asset("promoAlbumArtist612")), // Massive Attack
        "dz-319814": Artist(id: 1306, picture: .asset("promoAlbumArtist1306")), // Mazzy Star
        "dz-340889": Artist(id: 181, picture: .asset("promoAlbumArtist181")), // Talking Heads
        "dz-467267": Artist(id: 1297, picture: .asset("promoAlbumArtist1297")), // The Smiths
        "dz-662259": Artist(id: 1177, picture: .asset("promoAlbumArtist1177")), // Queens of the Stone Age
        "dz-1261474": Artist(id: 1297, picture: .asset("promoAlbumArtist1297")), // The Smiths
        "dz-1262014": Artist(id: 415, picture: .asset("promoAlbumArtist415")), // Nirvana
        "dz-2795271": Artist(id: 1098, picture: .asset("promoAlbumArtist1098")), // Boards of Canada
        "dz-2948621": Artist(id: 1294, picture: .asset("promoAlbumArtist1294")), // The Field Mice
        "dz-6237061": Artist(id: 169, picture: .asset("promoAlbumArtist169")), // Fleetwood Mac
        "dz-6709163": Artist(id: 545, picture: .asset("promoAlbumArtist545")), // Depeche Mode
        "dz-6899610": Artist(id: 1182, picture: .asset("promoAlbumArtist1182")), // Arctic Monkeys
        "dz-10709540": Artist(id: 134790, picture: .asset("promoAlbumArtist134790")), // Tame Impala
        "dz-10843530": Artist(id: 1302, picture: .asset("promoAlbumArtist1302")), // Sonic Youth
        "dz-11093204": Artist(id: 75055, picture: .asset("promoAlbumArtist75055")), // Beach House
        "dz-13995194": Artist(id: 2016, picture: .asset("promoAlbumArtist2016")), // New Order
        "dz-13995252": Artist(id: 1725, picture: .asset("promoAlbumArtist1725")), // Ramones
        "dz-14879699": Artist(id: 399, picture: .asset("promoAlbumArtist399")), // Radiohead
        "dz-14880659": Artist(id: 399, picture: .asset("promoAlbumArtist399")), // Radiohead
        "dz-54718352": Artist(id: 4505880, picture: .asset("promoAlbumArtist4505880")), // Кино
        "dz-56889262": Artist(id: 997, picture: .asset("promoAlbumArtist997")), // David Bowie
        "dz-70487632": Artist(id: 1559, picture: .asset("promoAlbumArtist1559")), // The Velvet Underground
        "dz-95104172": Artist(id: 4628187, picture: .asset("promoAlbumArtist4628187")), // Bosnian Rainbows
        "dz-123870262": Artist(id: 73228892, picture: .asset("promoAlbumArtist73228892")), // Molchat Doma
        "dz-160648172": Artist(id: 1249, picture: .asset("promoAlbumArtist1249")), // Joy Division
        "dz-212636922": Artist(id: 2465, picture: .asset("promoAlbumArtist2465")), // my bloody valentine
        "dz-310447807": Artist(id: 2873, picture: .asset("promoAlbumArtist2873")), // Fugazi
        "dz-413452427": Artist(id: 1049, picture: .asset("promoAlbumArtist1049")), // Kate Bush
        "dz-420206277": Artist(id: 1868, picture: .asset("promoAlbumArtist1868")), // At the Drive-In
        "dz-447073745": Artist(id: 5143097, picture: .asset("promoAlbumArtist5143097")), // The Smile
        "dz-597350882": Artist(id: 1462230, picture: .asset("promoAlbumArtist1462230")), // Charli xcx
    ]
}
