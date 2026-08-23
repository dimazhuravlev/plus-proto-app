#if DEBUG
import SwiftUI

// MARK: - ВРЕМЕННО. Удалить целиком вместе с вызовом в `MovieScreen`.
//
// Секция показывает **сырой** ответ `/v1.4/movie/{id}` — все поля, которые Кинопоиск
// знает о тайтле, с их именами из API. Нужна, чтобы решить, что из этого имеет смысл
// показывать в карточке; в продуктовой ленте ей места нет.
//
// Данные тянутся **мимо пула**: пул сужен через `selectFields` до того, что рисует
// карточка, а здесь нужно как раз то, чего в нём нет (сборы, премьеры, факты, где
// смотреть, сети, сезоны). Это стоит одного запроса на тайтл из суточных двухсот,
// поэтому ответ кладётся на диск и повторные открытия того же фильма бесплатны.

/// Одна строка дампа: путь поля в ответе API и его значение.
private struct RawField: Identifiable {
    let path: String
    let value: String

    var id: String { path }

    /// Поле из набора `KinopoiskService.movieFields`, то есть уже лежит в запасе
    /// и доступно карточке без сети. Остальным нужен отдельный запрос.
    var isInPool: Bool {
        let root = path.prefix { $0 != "." && $0 != "[" }
        return KinopoiskService.movieFields.contains(String(root))
    }
}

/// Одна картинка галереи: что показать, откуда она в API и что про неё известно.
struct RawGraphic: Identifiable {
    /// Уменьшенная копия для показа: тянуть десятки `orig` ради превью незачем.
    let preview: URL
    /// Полный адрес — то, что реально лежит в поле.
    let full: URL
    /// Путь в ответе или ручка, откуда картинка взялась.
    let path: String
    /// Что это: размер, имя персоны, название ролика.
    let note: String

    var id: String { path + full.absoluteString }
}

struct RawGraphicGroup: Identifiable {
    let title: String
    /// Ручка или поле — подпись под заголовком группы.
    let origin: String
    let items: [RawGraphic]

    var id: String { title }
}

@MainActor
@Observable
private final class MovieRawFieldsStore {
    private(set) var fields: [RawField] = []
    private(set) var graphics: [RawGraphicGroup] = []
    /// Сколько картинок у тайтла всего по данным ручки — обычно больше, чем показано.
    private(set) var imagesTotal = 0
    private(set) var byteCount = 0
    private(set) var isLoading = false
    private(set) var failure: String?
    /// Ответ приехал с диска, квота не потрачена.
    private(set) var fromDisk = false

    private var requested: Int?

    /// Сколько картинок просим у `/v1.4/image` за проход. 250 — потолок выдачи.
    private static let imagesLimit = 250
    /// Сколько картинок одного типа показываем: постеров бывает под две сотни,
    /// и для «что вообще есть» хватает первого десятка.
    private static let perTypeLimit = 12

    func load(id: Int) async {
        guard requested != id else { return }
        requested = id
        fields = []
        graphics = []
        failure = nil

        if let cached = Self.readFromDisk(id: id, suffix: "") {
            fromDisk = true
            // Тайтл мог быть сохранён до того, как секция научилась тянуть картинки, —
            // тогда за ними всё-таки идём, иначе галерея останется без них навсегда.
            var images = Self.readFromDisk(id: id, suffix: "-images")
            if images == nil {
                isLoading = true
                images = await Self.loadImages(id: id)
                isLoading = false
                if let images {
                    fromDisk = false
                    Self.writeToDisk(images, id: id, suffix: "-images")
                }
            }
            apply(cached, imagesData: images, id: id)
            return
        }

        isLoading = true
        defer { isLoading = false }
        do {
            let data = try await KinopoiskService.shared.rawMovieJSON(id: id)
            fromDisk = false
            Self.writeToDisk(data, id: id, suffix: "")
            // Вторая ручка — вся графика тайтла. Падение здесь не должно ронять дамп
            // полей, поэтому ошибка глотается: галерея просто останется без этой группы.
            let images = await Self.loadImages(id: id)
            if let images { Self.writeToDisk(images, id: id, suffix: "-images") }
            apply(data, imagesData: images, id: id)
        } catch {
            failure = error.localizedDescription
        }
    }

    /// Картинки тайтла: проход с начала алфавита типов и, если в один заход всё
    /// не поместилось, ещё один с конца. Возвращается склейка в виде `{"docs": …}`.
    private static func loadImages(id: Int) async -> Data? {
        guard
            let head = try? await KinopoiskService.shared.rawImagesJSON(movieID: id, limit: imagesLimit, ascending: true),
            let headObject = try? JSONSerialization.jsonObject(with: head) as? [String: Any]
        else { return nil }

        var docs = headObject["docs"] as? [[String: Any]] ?? []
        let total = headObject["total"] as? Int ?? docs.count
        if total > docs.count,
           let tail = try? await KinopoiskService.shared.rawImagesJSON(movieID: id, limit: imagesLimit, ascending: false),
           let tailObject = try? JSONSerialization.jsonObject(with: tail) as? [String: Any] {
            docs += tailObject["docs"] as? [[String: Any]] ?? []
        }
        return try? JSONSerialization.data(withJSONObject: ["docs": docs, "total": total])
    }

    private func apply(_ data: Data, imagesData: Data?, id: Int) {
        byteCount = data.count
        guard let object = try? JSONSerialization.jsonObject(with: data) else {
            failure = "ответ не разобрался в JSON"
            return
        }
        var rows: [RawField] = []
        Self.flatten(object, prefix: "", into: &rows)
        fields = rows

        let movie = object as? [String: Any] ?? [:]
        let imagesObject = (try? imagesData.flatMap { try JSONSerialization.jsonObject(with: $0) }) as? [String: Any]
        let images = imagesObject?["docs"] as? [[String: Any]] ?? []
        imagesTotal = imagesObject?["total"] as? Int ?? images.count
        graphics = Self.collectGraphics(movie: movie, images: images)
    }

    // MARK: - Графика

    /// Собирает всю графику тайтла: три картинки самого фильма, кадры роликов,
    /// фото персон, постеры похожих и сиквелов, логотипы платформ — и отдельно
    /// всё, что отдаёт ручка `/v1.4/image`.
    private static func collectGraphics(movie: [String: Any], images: [[String: Any]]) -> [RawGraphicGroup] {
        var groups: [RawGraphicGroup] = []

        var own: [RawGraphic] = []
        for key in ["poster", "backdrop"] {
            guard let image = movie[key] as? [String: Any] else { continue }
            guard let full = url(image["url"]) else { continue }
            own.append(RawGraphic(
                preview: url(image["previewUrl"]) ?? full,
                full: full,
                path: "\(key).url",
                note: sizeSuffix(full)
            ))
        }
        // Логотип лежит на tmdb, а этот хост здесь не резолвится — ведём через прокси,
        // как это делает карточка (см. `TMDBImageProxy`).
        if let logo = movie["logo"] as? [String: Any], let full = url(logo["url"]) {
            own.append(RawGraphic(
                preview: TMDBImageProxy.rewrite(full, width: 400) ?? full,
                full: full,
                path: "logo.url",
                note: "PNG с альфой, через прокси"
            ))
        }
        if !own.isEmpty {
            groups.append(RawGraphicGroup(title: "Картинки тайтла", origin: "/v1.4/movie/{id}", items: own))
        }

        // Ролики: смотреть можно только кадр — `url` ведёт на страницу-эмбед плеера,
        // и подписанный поток внутри неё закрыт для сторонних клиентов.
        let videos = movie["videos"] as? [String: Any] ?? [:]
        var stills: [RawGraphic] = []
        for kind in ["trailers", "teasers"] {
            for (index, item) in ((videos[kind] as? [[String: Any]]) ?? []).enumerated() {
                guard let preview = url(item["preview_url"]) else { continue }
                stills.append(RawGraphic(
                    preview: preview,
                    full: preview,
                    path: "videos.\(kind)[\(index)].preview_url",
                    note: (item["name"] as? String) ?? kind
                ))
            }
        }
        if !stills.isEmpty {
            groups.append(RawGraphicGroup(
                title: "Кадры роликов",
                origin: "videos.trailers[].preview_url · сам ролик — эмбед-страница, поток закрыт",
                items: stills
            ))
        }

        var people: [RawGraphic] = []
        for (index, person) in ((movie["persons"] as? [[String: Any]]) ?? []).enumerated() {
            guard let photo = url(person["photo"]) else { continue }
            people.append(RawGraphic(
                preview: photo,
                full: photo,
                path: "persons[\(index)].photo",
                note: [(person["name"] as? String), (person["profession"] as? String)]
                    .compactMap { $0 }.joined(separator: " · ")
            ))
        }
        if !people.isEmpty {
            groups.append(RawGraphicGroup(title: "Фото персон", origin: "/v1.4/movie/{id} → persons[]", items: people))
        }

        for key in ["similarMovies", "sequelsAndPrequels"] {
            var posters: [RawGraphic] = []
            for (index, item) in ((movie[key] as? [[String: Any]]) ?? []).enumerated() {
                guard let poster = item["poster"] as? [String: Any], let full = url(poster["url"]) else { continue }
                posters.append(RawGraphic(
                    preview: url(poster["previewUrl"]) ?? full,
                    full: full,
                    path: "\(key)[\(index)].poster.url",
                    note: (item["name"] as? String) ?? (item["alternativeName"] as? String) ?? ""
                ))
            }
            guard !posters.isEmpty else { continue }
            groups.append(RawGraphicGroup(
                title: key == "similarMovies" ? "Похожие" : "Сиквелы и приквелы",
                origin: "\(key)[].poster",
                items: posters
            ))
        }

        var platforms: [RawGraphic] = []
        for (index, item) in (((movie["watchability"] as? [String: Any])?["items"] as? [[String: Any]]) ?? []).enumerated() {
            guard let logo = item["logo"] as? [String: Any], let full = url(logo["url"]) else { continue }
            platforms.append(RawGraphic(
                preview: full,
                full: full,
                path: "watchability.items[\(index)].logo.url",
                note: (item["name"] as? String) ?? ""
            ))
        }
        if !platforms.isEmpty {
            groups.append(RawGraphicGroup(title: "Логотипы платформ", origin: "watchability.items[].logo", items: platforms))
        }

        // Ручка картинок: у неё свои типы — poster, backdrop, cover, screenshot,
        // frame, still, — и у каждой известны размеры.
        let byType = Dictionary(grouping: images) { ($0["type"] as? String) ?? "без типа" }
        for type in byType.keys.sorted() {
            let ofType = byType[type] ?? []
            let items = ofType.prefix(perTypeLimit).compactMap { item -> RawGraphic? in
                guard let full = url(item["url"]) else { return nil }
                let width = item["width"] as? Int ?? 0
                let height = item["height"] as? Int ?? 0
                return RawGraphic(
                    preview: url(item["previewUrl"]) ?? full,
                    full: full,
                    path: "type=\(type)",
                    note: width > 0 ? "\(width)×\(height)" : sizeSuffix(full)
                )
            }
            guard !items.isEmpty else { continue }
            groups.append(RawGraphicGroup(
                title: ofType.count > items.count
                    ? "image: \(type) — показаны \(items.count) из \(ofType.count)"
                    : "image: \(type) (\(items.count))",
                origin: "/v1.4/image?movieId=&type=\(type)",
                items: items
            ))
        }

        return groups
    }

    private static func url(_ value: Any?) -> URL? {
        guard let string = value as? String, !string.isEmpty else { return nil }
        return URL(string: string)
    }

    /// Размер у Яндекс-CDN — последний сегмент пути (`…/1344x756`, `…/orig`).
    private static func sizeSuffix(_ url: URL) -> String {
        url.lastPathComponent
    }

    // MARK: - Разбор

    /// Разворачивает ответ в плоский список «путь → значение».
    ///
    /// Массивы объектов режутся: у `persons` бывает под сотню элементов, а для решения
    /// «показывать или нет» хватает первых трёх и счётчика остальных.
    private static func flatten(_ value: Any, prefix: String, into rows: inout [RawField]) {
        switch value {
        case let dictionary as [String: Any]:
            for key in dictionary.keys.sorted() {
                let path = prefix.isEmpty ? key : "\(prefix).\(key)"
                flatten(dictionary[key] as Any, prefix: path, into: &rows)
            }

        case let array as [Any]:
            guard !array.isEmpty else {
                rows.append(RawField(path: prefix, value: "[] пусто"))
                return
            }
            // Массив простых значений (`lists`, `facts` строками) читается одной строкой.
            if array.allSatisfy({ !($0 is [String: Any]) && !($0 is [Any]) }) {
                let joined = array.map { scalar($0) }.joined(separator: ", ")
                rows.append(RawField(path: "\(prefix) (\(array.count))", value: clip(joined)))
                return
            }
            rows.append(RawField(path: "\(prefix) (\(array.count))", value: "список объектов"))
            for (index, element) in array.prefix(previewCount).enumerated() {
                flatten(element, prefix: "\(prefix)[\(index)]", into: &rows)
            }
            if array.count > previewCount {
                rows.append(RawField(path: "\(prefix)[…]", value: "ещё \(array.count - previewCount)"))
            }

        default:
            rows.append(RawField(path: prefix, value: clip(scalar(value))))
        }
    }

    /// Сколько элементов массива разворачиваем целиком.
    private static let previewCount = 3
    /// Длинные описания в дампе не нужны целиком — важно, что поле есть и какое оно.
    private static let valueLimit = 240

    private static func scalar(_ value: Any) -> String {
        switch value {
        case is NSNull:
            return "null"
        case let number as NSNumber:
            // `as Bool` здесь ловил бы и числа: `JSONSerialization` отдаёт всё числовое
            // одним `NSNumber`, и `typeNumber: 1` печатался как `true`. Настоящий буль
            // отличается только типом CoreFoundation.
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return number.boolValue ? "true" : "false"
            }
            return number.stringValue
        case let string as String:
            return string
        default:
            return String(describing: value)
        }
    }

    private static func clip(_ text: String) -> String {
        let flat = text.replacingOccurrences(of: "\n", with: " ")
        guard flat.count > valueLimit else { return flat }
        return String(flat.prefix(valueLimit)) + "…"
    }

    // MARK: - Диск

    /// Сырые ответы лежат отдельной папкой: удалить временную секцию — удалить и её.
    private static func fileURL(id: Int, suffix: String) -> URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let folder = caches.appendingPathComponent("movie-raw", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("\(id)\(suffix).json")
    }

    private static func readFromDisk(id: Int, suffix: String) -> Data? {
        try? Data(contentsOf: fileURL(id: id, suffix: suffix))
    }

    private static func writeToDisk(_ data: Data, id: Int, suffix: String) {
        try? data.write(to: fileURL(id: id, suffix: suffix), options: .atomic)
    }
}

// MARK: - Секция

struct MovieRawFieldsSection: View {
    let movieID: Int

    @State private var store = MovieRawFieldsStore()

    private enum Layout {
        static let rowSpacing: CGFloat = 10
        static let pathSize: CGFloat = 10
        static let valueSize: CGFloat = 12
        /// Бокс превью. Пропорции у картинок разные — от постера 2:3 до логотипа-полоски,
        /// поэтому каждая вписывается в общий бокс, а не заполняет его.
        static let tileWidth: CGFloat = 132
        static let tileHeight: CGFloat = 172
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            MovieSectionHeader(title: "Вся графика")
            caption
                .padding(.horizontal, MovieLayout.sectionSide)
                .padding(.bottom, 12)
            gallery
            MovieSectionHeader(title: "Все поля API")

            if let failure = store.failure {
                Text(failure)
                    .font(.system(size: Layout.valueSize, design: .monospaced))
                    .foregroundStyle(Color.fillSubtitle)
                    .padding(.horizontal, MovieLayout.sectionSide)
            }

            VStack(alignment: .leading, spacing: Layout.rowSpacing) {
                ForEach(store.fields) { field in
                    row(field)
                }
            }
            .padding(.horizontal, MovieLayout.sectionSide)

            neighbours
                .padding(.horizontal, MovieLayout.sectionSide)
                .padding(.top, 24)
                // Клиренс экрана рассчитан на секции макета; у дампа последняя строка
                // без этого запаса упирается в панель действий.
                .padding(.bottom, 40)
        }
        .task(id: movieID) { await store.load(id: movieID) }
    }

    /// Подпись секции: откуда данные, сколько их и потрачен ли на них запрос.
    private var caption: some View {
        VStack(alignment: .leading, spacing: 2) {
            // `verbatim`: обычная интерполяция форматирует id по локали, с пробелами
            // между разрядами, — из «7932118» получалось «7 932 118».
            Text(verbatim: "GET /v1.4/movie/\(movieID) + /v1.4/image?movieId=\(movieID)")
            if store.isLoading {
                Text("тянем ответы…")
            } else if !store.fields.isEmpty {
                let pictures = store.graphics.reduce(0) { $0 + $1.items.count }
                Text("\(store.fields.count) строк · \(pictures) картинок в галерее · у тайтла их \(store.imagesTotal) · \(store.fromDisk ? "всё с диска, без запросов" : "свежие запросы")")
                Text("• — поле уже лежит в запасе витрины (selectFields)")
            }
        }
        .font(.system(size: Layout.pathSize, design: .monospaced))
        .foregroundStyle(Color.fillSubtitle)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Галерея: по ряду на источник графики. Ряды горизонтальные и ленивые — у ручки
    /// `/v1.4/image` бывает под сотню картинок, и тянуть их все разом незачем.
    private var gallery: some View {
        VStack(alignment: .leading, spacing: 18) {
            if store.graphics.isEmpty, !store.isLoading {
                Text("графики у тайтла нет")
                    .font(.system(size: Layout.valueSize, design: .monospaced))
                    .foregroundStyle(Color.fillSubtitle)
                    .padding(.horizontal, MovieLayout.sectionSide)
            }
            ForEach(store.graphics) { group in
                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(group.title)
                            .foregroundStyle(Color.fillOne)
                        Text(group.origin)
                            .foregroundStyle(Color.fillSix)
                    }
                    .font(.system(size: Layout.pathSize, design: .monospaced))
                    .padding(.horizontal, MovieLayout.sectionSide)

                    ScrollView(.horizontal) {
                        LazyHStack(alignment: .top, spacing: 8) {
                            ForEach(group.items) { item in
                                tile(item)
                            }
                        }
                    }
                    // Поле секции задаётся полями скролла, а не паддингом стека:
                    // с паддингом ряд открывался уже прокрученным на половину плитки.
                    .contentMargins(.horizontal, MovieLayout.sectionSide, for: .scrollContent)
                    .scrollIndicators(.hidden)
                }
            }
        }
        .padding(.bottom, 24)
    }

    private func tile(_ item: RawGraphic) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ArtworkImage(source: .remote(item.preview))
                .aspectRatio(contentMode: .fit)
                .frame(width: Layout.tileWidth, height: Layout.tileHeight)
                .background(Color.fillTen)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text(item.path)
                .foregroundStyle(Color.fillSix)
            Text(item.note)
                .foregroundStyle(Color.fillOne)
                .lineLimit(2)
        }
        .font(.system(size: Layout.pathSize, design: .monospaced))
        .frame(width: Layout.tileWidth, alignment: .leading)
    }

    /// Что ещё Кинопоиск знает об этом тайтле, но отдаёт отдельными ручками. Здесь
    /// только справка: каждая из них — свой запрос из суточной квоты, и дёргать их
    /// на открытии карточки ради дампа незачем.
    private var neighbours: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Есть ещё по этому тайтлу — отдельными запросами:")
                .foregroundStyle(Color.fillSubtitle)
            ForEach(Self.neighbourRoutes, id: \.route) { item in
                VStack(alignment: .leading, spacing: 1) {
                    Text(verbatim: "\(item.route)?movieId=\(movieID)")
                        .foregroundStyle(Color.fillSix)
                    Text(item.what)
                        .foregroundStyle(Color.fillOne)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .font(.system(size: Layout.pathSize, design: .monospaced))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static let neighbourRoutes: [(route: String, what: String)] = [
        ("/v1.4/season", "сезоны и эпизоды: номер, дата выхода, описание, кадр эпизода"),
        ("/v1.4/review", "рецензии зрителей: текст, автор, тип (позитивная/нейтральная/негативная)"),
        ("/v1.4/movie/awards", "награды и номинации: премия, год, победа или нет"),
    ]

    private func row(_ field: RawField) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(field.isInPool ? "• \(field.path)" : field.path)
                .font(.system(size: Layout.pathSize, design: .monospaced))
                .foregroundStyle(Color.fillSix)
            Text(field.value)
                .font(.system(size: Layout.valueSize, design: .monospaced))
                .foregroundStyle(Color.fillOne)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
#endif
