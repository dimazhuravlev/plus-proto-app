import SwiftUI

/// Компактная миниатюра станции для recently. Контур и палитра —
/// из музыкального барабана, а агент рисуется отдельно: масштаб всей большой
/// карточки сделал бы его размером 20 pt и превратил внутренний текст в 5 pt.
struct CompactVibePetal: View {
    let station: VibeStation
    var height: CGFloat = 80

    var body: some View {
        let s = height / 80
        return Color.clear.frame(width: height, height: height)

            .overlay(alignment: .topLeading) {
                Group {
                    if let photo = station.photo {
                        Color.clear.frame(width: 72 * s, height: 72 * s)
                            .overlay { ArtworkImage(source: .remote(photo)).scaledToFill() }
                            .clipShape(Circle())
                    } else if station.agent == "vibeAgentPop" {
                        Image("vibeAgentPop").resizable().frame(width: 78.4615 * s, height: 78.4615 * s)
                    } else {
                        Image(station.agent).resizable().scaledToFit().frame(width: 72 * s, height: 72 * s)
                    }
                }
                .position(x: height / 2, y: height / 2)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

}
