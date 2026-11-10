import SwiftUI
import UIKit

/// Компактная миниатюра станции для recently. Контур и палитра —
/// из музыкального барабана, а агент рисуется отдельно: масштаб всей большой
/// карточки сделал бы его размером 20 pt и превратил внутренний текст в 5 pt.
struct CompactVibePetal: View {
    let station: VibeStation
    var height: CGFloat = 80
    var fillsContainer = false

    var body: some View {
        let s = height / 80
        return Color.clear.frame(width: height, height: height)

            .overlay(alignment: .topLeading) {
                Group {
                    if fillsContainer, station.photo == nil, let image = RecentlyStationArtwork.image(station.agent) {
                        Image(uiImage: image).resizable().scaledToFit()
                            .frame(width: height, height: height)
                            .shadow(color: station.fill.opacity(0.28), radius: height * 0.09)
                    } else if let photo = station.photo {
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


// Asset canvases include transparent margins. Trim those once, without stretching the figure.
@MainActor private enum RecentlyStationArtwork {
    private static var cache: [String: UIImage] = [:]
    static func image(_ name: String) -> UIImage? {
        if let image = cache[name] { return image }
        guard let source = UIImage(named: name), let cg = source.cgImage else { return nil }
        let w = cg.width, h = cg.height
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        let drawn = pixels.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(data: bytes.baseAddress, width: w, height: h,
                bitsPerComponent: 8, bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard drawn else { return source }
        var left = w, right = 0, top = h, bottom = 0
        for y in 0..<h {
            for x in 0..<w where pixels[(y * w + x) * 4 + 3] > 8 {
                left = min(left, x); right = max(right, x)
                top = min(top, y); bottom = max(bottom, y)
            }
        }
        guard right >= left, bottom >= top,
              let cropped = cg.cropping(to: CGRect(x: left, y: top, width: right - left + 1, height: bottom - top + 1)) else { return source }
        let image = UIImage(cgImage: cropped, scale: source.scale, orientation: source.imageOrientation)
        cache[name] = image
        return image
    }
}
