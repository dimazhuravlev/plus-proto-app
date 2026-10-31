// Сводит цифры «Топ-10» ДС (card / poster / top-10 `205:26409`, файл b8maDlvYFFs2vagJxwxc4A)
// в один растр на цифру: та же раскладка, что у слоёв Фигмы (рамка num_N_tall, бокс картинки
// 136×147 с обрезкой, у «10» — две маски). Холст — бокс `top-10` (110×160) с запасом:
// x −18…134, y 4…156 (`ServiceCarouselRank.artOrigin`, `artSize`).
//
// Растры цифр — `get_design_context` нод `N_dark` (6937:57041…57068, шаг 3; у «2» — 8361:12274),
// сохранить как num1.png … num10.png.
//
// xcrun swift scripts/top-rank-compose.swift <папка с numN.png> <куда> 3
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let args = CommandLine.arguments
let src = URL(fileURLWithPath: args[1]), dst = URL(fileURLWithPath: args[2])
let scale = CGFloat(Double(args[3])!)
let canvas = CGRect(x: -18, y: 4, width: 152, height: 152)

func load(_ name: String) -> CGImage {
    let s = CGImageSourceCreateWithURL(src.appendingPathComponent(name) as CFURL, nil)!
    return CGImageSourceCreateImageAtIndex(s, 0, nil)!
}

func context() -> CGContext {
    let ctx = CGContext(data: nil, width: Int(canvas.width * scale), height: Int(canvas.height * scale),
                        bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high
    // Верх-лево, единицы — pt бокса `top-10`
    ctx.translateBy(x: 0, y: canvas.height * scale)
    ctx.scaleBy(x: scale, y: -scale)
    ctx.translateBy(x: -canvas.minX, y: -canvas.minY)
    return ctx
}

func draw(_ ctx: CGContext, _ image: CGImage, in rect: CGRect) {
    ctx.saveGState()
    ctx.translateBy(x: rect.minX, y: rect.maxY)
    ctx.scaleBy(x: 1, y: -1)
    ctx.draw(image, in: CGRect(origin: .zero, size: rect.size))
    ctx.restoreGState()
}

func save(_ ctx: CGContext, _ name: String) {
    let d = CGImageDestinationCreateWithURL(dst.appendingPathComponent(name) as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(d, ctx.makeImage()!, nil)
    CGImageDestinationFinalize(d)
}

// Цифра 1–9: рамка num_N_tall 79.2×158.4 (left, top в боксе), центр картинки 136×147
// сдвинут на (dx, dy) от центра рамки, картинка — доли бокса (left, top, w, h) или во весь бокс.
struct Digit { let numLeft, numTop, dx, dy: CGFloat; let crop: (CGFloat, CGFloat, CGFloat, CGFloat)? }
let digits: [Int: Digit] = [
    1: Digit(numLeft: 15, numTop: 0.48, dx: 0.4, dy: -0.46, crop: nil),
    2: Digit(numLeft: 15.1, numTop: 0.48, dx: -0.1, dy: -0.46, crop: nil),
    3: Digit(numLeft: 15.4, numTop: 0.4752, dx: 0.2, dy: -0.46, crop: (-0.3333, -0.2778, 1.6733, 1.5494)),
    4: Digit(numLeft: 11, numTop: 0, dx: 0.2, dy: 0.02, crop: (-0.3333, -0.2654, 1.6667, 1.5432)),
    5: Digit(numLeft: 13.2, numTop: 0, dx: -0.4, dy: 0.02, crop: (-0.3333, -0.2593, 1.6467, 1.5247)),
    6: Digit(numLeft: 11, numTop: 0, dx: 0.4, dy: 0.02, crop: (-0.3333, -0.2716, 1.6667, 1.5432)),
    7: Digit(numLeft: 14.3, numTop: 0, dx: -0.3, dy: 0.02, crop: (-0.3333, -0.2531, 1.6267, 1.5062)),
    8: Digit(numLeft: 18.7, numTop: 0, dx: -0.1, dy: 0.02, crop: (-0.3333, -0.2716, 1.6667, 1.5432)),
    9: Digit(numLeft: 14.3, numTop: 0, dx: -0.1, dy: 0.02, crop: (-0.3333, -0.2716, 1.6667, 1.5432)),
]

for (n, d) in digits {
    let ctx = context()
    let box = CGRect(x: d.numLeft + 39.6 + d.dx - 68, y: d.numTop + 79.2 + d.dy - 73.5, width: 136, height: 147)
    ctx.clip(to: box)
    let rect = d.crop.map { c in
        CGRect(x: box.minX + c.0 * box.width, y: box.minY + c.1 * box.height, width: c.2 * box.width, height: c.3 * box.height)
    } ?? box
    draw(ctx, load("num\(n).png"), in: rect)
    save(ctx, "topRank\(n).png")
}

// «10»: рамка num_10_tall в (4.4, 0); две копии одного растра, каждая под своей маской.
do {
    let ctx = context()
    let image = load("num10.png")
    let num = CGPoint(x: 4.4, y: 0)
    let parts: [(div: CGRect, mask: CGPoint, points: [CGPoint])] = [
        (CGRect(x: num.x - 15.11, y: num.y + 4.82, width: 134.843, height: 145.799), CGPoint(x: 2.107, y: 2.528),
         [CGPoint(x: 61.9434, y: 0), CGPoint(x: 32.4466, y: 145.377), CGPoint(x: 0, y: 145.377), CGPoint(x: 0, y: 0)]),
        (CGRect(x: num.x - 16.01, y: num.y + 7.83, width: 135.172, height: 146.155), CGPoint(x: 33.792, y: -2.112),
         [CGPoint(x: 29.9913, y: 0), CGPoint(x: 0, y: 147), CGPoint(x: 83.2154, y: 147), CGPoint(x: 110.25, y: 0)]),
    ]
    for part in parts {
        ctx.saveGState()
        ctx.clip(to: part.div)
        let path = CGMutablePath()
        path.addLines(between: part.points.map { CGPoint(x: part.div.minX + part.mask.x + $0.x, y: part.div.minY + part.mask.y + $0.y) })
        path.closeSubpath()
        ctx.addPath(path)
        ctx.clip()
        let div = part.div
        draw(ctx, image, in: CGRect(x: div.minX - 0.2703 * div.width, y: div.minY - 0.1272 * div.height,
                                    width: 1.4563 * div.width, height: 1.3468 * div.height))
        ctx.restoreGState()
    }
    save(ctx, "topRank10.png")
}
