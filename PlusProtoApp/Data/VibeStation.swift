import SwiftUI

struct VibeStation: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    /// Иконка агента — ассет; у станции исполнителя вместо неё фото (`photo`).
    let agent: String
    /// Цвет капли и её светлой кромки — хексами макета: `Color` считается при обращении,
    /// в пространстве палитры (`PlusColorSpace`), и переключается вместе с ней.
    let fillHex: UInt32
    let rimHex: UInt32
    /// Фото исполнителя кругом — у станции исполнителя (в макете у Cream soda фото
    /// группы; в экспорт SVG оно не попало, берём фото Deezer, id 5535442).
    var photo: URL? = nil
    /// Preserve bundled portraits as well as remote photos when entering Recently.
    var artistArtwork: ArtworkSource? = nil

    var artwork: ArtworkSource {
        artistArtwork ?? photo.map { .remote($0, fallback: nil) } ?? .asset(agent)
    }

    var hasArtistArtwork: Bool { artistArtwork != nil || photo != nil }

    /// Пять лепестков макета, слева направо. Капсулу «В стиле: The Mars Volta» не
    /// добавляем (правка пользователя 2026-10-09).
    static let all: [VibeStation] = [
        VibeStation(id: "testosterone", title: "Укол тестостерона", agent: "vibeAgentElectronicsPink",
                    fillHex: 0xE7338F, rimHex: 0xF4A4CD),
        VibeStation(id: "cream-soda", title: "Cream soda", agent: "",
                    fillHex: 0x5C8E9B, rimHex: 0x99F2FF,
                    photo: URL(string: "https://cdn-images.dzcdn.net/images/artist/e41bf19f0bd5fbe74298b1981a21cd77/250x250-000000-80-0-0.jpg")),
        VibeStation(id: "garage", title: "Спальничный гэридж", agent: "vibeStationPopIndigo",
                    fillHex: 0xF02A4F, rimHex: 0xF8A0B0),
        VibeStation(id: "night-minimal", title: "Ночной минимал", agent: "vibeAgentElectronicsBlue",
                    fillHex: 0x426DF5, rimHex: 0x9EB4FA),
        VibeStation(id: "testosterone-altrock", title: "Укол тестостерона", agent: "vibeAgentAltrock",
                    fillHex: 0x4F6C9B, rimHex: 0xBBC8DD),
    ]

    /// Стартовая — по центру макета
    static let startIndex = 2

    var fill: Color { Color(hex: fillHex) }
    var rim: Color { Color(hex: rimHex) }
}

extension VibeStation {
    private enum CodingKeys: String, CodingKey {
        case id, title, agent, fillHex, rimHex, photo, artistArtwork
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let id = try values.decode(String.self, forKey: .id)
        let oldAgent = try values.decode(String.self, forKey: .agent)
        let retiredShape = oldAgent == "vibeAgentPop" || oldAgent == "vibeStationPopCarmine"
        self.init(id: id, title: try values.decode(String.self, forKey: .title),
                  agent: retiredShape ? "vibeStationPopIndigo" : oldAgent,
                  fillHex: try values.decode(UInt32.self, forKey: .fillHex),
                  rimHex: try values.decode(UInt32.self, forKey: .rimHex),
                  photo: try values.decodeIfPresent(URL.self, forKey: .photo),
                  artistArtwork: try values.decodeIfPresent(ArtworkSource.self, forKey: .artistArtwork))
        // Repair the old snapshot that dropped Musia's bundled portrait. History
        // keeps the artist the user actually played, even though new cards use others.
        if artistArtwork == nil, photo == nil, id == "artist-wave-173022587" {
            artistArtwork = .asset("promoHQMusiaArtist")
        }
    }
}
