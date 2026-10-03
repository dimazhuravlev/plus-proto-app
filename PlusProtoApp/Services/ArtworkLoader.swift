import CoreImage
import SwiftUI
import UIKit

/// Загрузка и кэш обложек. Приём из `CachedAsyncImage` MusicPlayer: два слоя кэша —
/// декодированные `UIImage` в `NSCache` и сырые ответы в `URLCache` сессии.
///
/// `AsyncImage` сюда не годится по двум причинам: он не отдаёт готовый `UIImage`
/// (а `AmbilightArtwork` запекает из картинки ещё и ореол), и на каждом появлении вью
/// начинает загрузку заново — на скролле витрины это перезапрос на каждый кадр въезда.
@MainActor
final class ArtworkLoader {
    static let shared = ArtworkLoader()

    private let cache: NSCache<NSURL, UIImage> = {
        let cache = NSCache<NSURL, UIImage>()
        cache.countLimit = 200
        cache.totalCostLimit = 100 * 1024 * 1024
        return cache
    }()

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(
            memoryCapacity: 50 * 1024 * 1024,
            diskCapacity: 200 * 1024 * 1024,
            diskPath: "artwork_cache"
        )
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.timeoutIntervalForRequest = 20
        return URLSession(configuration: config)
    }()

    /// Идущие загрузки: два блока витрины могут просить одну обложку (плеер и карточка),
    /// и без дедупликации это два запроса вместо одного.
    private var inflight: [URL: Task<UIImage?, Never>] = [:]

    private init() {}

    /// Синхронный ответ из памяти — им закрывается первый кадр без мигания плейсхолдером.
    func cached(_ url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func image(for url: URL) async -> UIImage? {
        if let hit = cached(url) { return hit }
        if let running = inflight[url] { return await running.value }

        let task = Task<UIImage?, Never> { [session] in
            guard
                let (data, _) = try? await session.data(from: url),
                let image = UIImage(data: data)
            else { return nil }
            return image
        }
        inflight[url] = task
        let image = await task.value
        inflight[url] = nil
        if let image {
            cache.setObject(image, forKey: url as NSURL, cost: image.cost)
        }
        return image
    }

    /// Прогрев без ожидания: витрина заказывает обложки блоков, пока пользователь
    /// смотрит на первый экран.
    func preload(_ sources: [ArtworkSource]) {
        for case .remote(let url, _) in sources where cached(url) == nil {
            Task { _ = await image(for: url) }
        }
    }

    /// Прогрев **с ожиданием** — им сплэш держит запуск, пока картинки первого
    /// экрана не окажутся в памяти. Без него витрина открывается и дозагружает
    /// обложки на глазах: `preload` возвращается мгновенно и ничего не обещает.
    ///
    /// Все разом, а не по очереди: обложек первого экрана меньше десятка,
    /// а последовательная загрузка сложила бы их задержки в секунды ожидания.
    func prewarm(_ sources: [ArtworkSource]) async {
        let pending = Set(sources.compactMap { source -> URL? in
            guard case .remote(let url, _) = source, cached(url) == nil else { return nil }
            return url
        })
        guard !pending.isEmpty else { return }

        await withTaskGroup(of: Void.self) { group in
            for url in pending {
                group.addTask { @MainActor in _ = await self.image(for: url) }
            }
        }
    }

    /// Цвет, в который уводится градиент подписи рядом с картинкой (figma-screen1 §1).
    /// В макете он снят с постера пипеткой — для живого контента снимаем сами.
    ///
    /// Считается по верхней половине: у постеров низ занят титрами и логотипами,
    /// среднее по всей картинке уходит в грязно-серый. Результат выводится в светлый
    /// пастельный тон — подпись лежит на чёрном, и тёмный акцент на нём не читается.
    func accent(for url: URL) async -> Color? {
        guard let image = await image(for: url), let tone = Self.averageTone(of: image) else { return nil }
        return Color(hue: tone.hue, saturation: min(tone.saturation * 0.9, 0.35), brightness: 0.86)
    }

    /// Цвет свечения за обложкой на экране книги (`2427:26464`). В макете там чистый
    /// красный — под обложку Atomic Heart с красными деталями; живым книгам берём
    /// оттенок их собственной обложки.
    ///
    /// Не среднее, как у `accent`, а самый «громкий» оттенок: гистограмма тонов
    /// с весом насыщенность × яркость по уменьшенной копии. Среднее у обложек уходит
    /// в серое — у той же Atomic Heart верх серо-золотой, и свечение вышло бы серым,
    /// а глаз считывает обложку по красному. Насыщенный — свечение лежит на чёрном
    /// с прозрачностью 0.4, и пастель в нём растворилась бы. У серой обложки ярких
    /// тонов нет — свечение нейтральное, а не случайно красное (оттенок ноль).
    func glow(for source: ArtworkSource) async -> Color? {
        let image: UIImage?
        if let url = source.remoteURL {
            image = await self.image(for: url)
        } else {
            image = source.fallbackAsset.flatMap { UIImage(named: $0) }
        }
        guard let cg = image?.cgImage else { return nil }
        guard let hue = Self.vividHue(of: cg) else { return Color(white: Self.glowNeutralWhite) }
        return Color(hue: hue, saturation: Self.glowSaturation, brightness: 1)
    }

    private static let glowSaturation: CGFloat = 0.9
    private static let glowNeutralWhite: CGFloat = 0.6
    /// Сетка уменьшенной копии и число корзин гистограммы: больше не нужно —
    /// ищется доминирующий тон, а не детали.
    private static let vividSample = (width: 24, height: 36)
    private static let vividBins = 24
    /// Пиксель серее этого (разброс каналов) в гистограмму не идёт.
    private static let vividMinChroma: CGFloat = 0.12
    /// Сколько веса должен набрать лучший тон, в долях от числа пикселей, —
    /// иначе ярких мест на обложке нет и свечение нейтральное.
    private static let vividMinShare: CGFloat = 0.03

    /// Самый «громкий» оттенок картинки, 0…1, или `nil`, если она серая.
    private static func vividHue(of cg: CGImage) -> CGFloat? {
        let (width, height) = vividSample
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.interpolationQuality = .medium
            context.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }

        var bins = [CGFloat](repeating: 0, count: vividBins)
        for offset in stride(from: 0, to: pixels.count, by: 4) {
            let red = CGFloat(pixels[offset]) / 255
            let green = CGFloat(pixels[offset + 1]) / 255
            let blue = CGFloat(pixels[offset + 2]) / 255
            let maxChannel = max(red, green, blue)
            let chroma = maxChannel - min(red, green, blue)
            guard chroma >= vividMinChroma else { continue }

            var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
            UIColor(red: red, green: green, blue: blue, alpha: 1)
                .getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
            bins[min(vividBins - 1, Int(hue * CGFloat(vividBins)))] += saturation * brightness
        }

        guard let best = bins.indices.max(by: { bins[$0] < bins[$1] }),
              bins[best] >= CGFloat(width * height) * vividMinShare
        else { return nil }
        return (CGFloat(best) + 0.5) / CGFloat(vividBins)
    }

    /// Средний тон верхней половины картинки.
    private static func averageTone(of image: UIImage) -> (hue: CGFloat, saturation: CGFloat, brightness: CGFloat)? {
        guard let cg = image.cgImage else { return nil }

        let extent = CGRect(x: 0, y: 0, width: cg.width, height: cg.height / 2)
        let input = CIImage(cgImage: cg).cropped(to: extent)
        guard
            let filter = CIFilter(name: "CIAreaAverage", parameters: [
                kCIInputImageKey: input,
                kCIInputExtentKey: CIVector(cgRect: extent)
            ]),
            let output = filter.outputImage
        else { return nil }

        var pixel = [UInt8](repeating: 0, count: 4)
        Self.ciContext.render(
            output,
            toBitmap: &pixel,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        UIColor(
            red: CGFloat(pixel[0]) / 255,
            green: CGFloat(pixel[1]) / 255,
            blue: CGFloat(pixel[2]) / 255,
            alpha: 1
        ).getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        return (hue, saturation, brightness)
    }

    /// Один контекст на приложение: создание `CIContext` тянет за собой инициализацию
    /// Metal-пайплайна и на каждый вызов стоит десятки миллисекунд.
    private static let ciContext = CIContext(options: [.workingColorSpace: NSNull()])
}

private extension UIImage {
    /// Цена в `NSCache` — байты растра, а не размер файла: JPEG 200 КБ разворачивается
    /// в 12 МБ и лимит по файлам не защищает от переполнения памяти.
    var cost: Int {
        guard let cg = cgImage else { return 1 }
        return cg.bytesPerRow * cg.height
    }
}
