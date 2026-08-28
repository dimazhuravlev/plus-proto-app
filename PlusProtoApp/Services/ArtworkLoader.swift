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
        guard let image = await image(for: url), let cg = image.cgImage else { return nil }

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

        return Color(hue: hue, saturation: min(saturation * 0.9, 0.35), brightness: 0.86)
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
