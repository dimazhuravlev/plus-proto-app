import Foundation

// MARK: - Модель экрана

/// Готовые к показу данные карточки тайтла: всё уже отформатировано, вьюхе
/// остаётся только разложить строки по макету.
///
/// Отдельно от `KinopoiskMovie`, потому что у карточки своя логика «что показать»:
/// половина полей API опциональна, и решение «жанра нет — строку не рисуем»
/// принимается один раз здесь, а не в каждом блоке экрана.
///
/// **Ничего не выдумываем.** Если факта в API нет, строка просто исчезает: подставлять
/// под живой тайтл правдоподобные аудиодорожки и качество — та же ложь о контенте,
/// из-за которой в блоке «продолжить смотреть» отказались от мокового логотипа
/// (DECISIONS 2026-08-23).
struct MovieDetails {
    let id: Int
    let title: String
    /// PNG-логотип тайтла. `nil` — рисуем название текстом (правило самого макета).
    let logo: URL?
    /// Акцентная строка над лидом. В макете здесь «Editor's choice» — у нас реальный
    /// факт из API: позиция в топ-250 или оценка Кинопоиска.
    let accent: String?
    /// Крупный лид под логотипом — редакционное однострочное описание Кинопоиска.
    let lead: String
    /// «2019 · криминал · 1 ч 53 мин · Великобритания · 18+»
    let meta: [String]
    /// Абзацы полного описания, уже нарезанные под макет.
    let synopsis: [String]
    let rows: [MovieDetailRow]
    let cast: [MovieCastMember]
    let similar: [MovieSimilarTitle]
    let trailer: MovieTrailer?
    /// Горизонтальный кадр тайтла — фон верхнего блока, пока не поехало видео.
    let backdrop: URL?
}

struct MovieCastMember: Identifiable {
    let id: Int
    let name: String
    /// Роль в этом тайтле; у части персон API её не знает.
    let role: String?
    let photo: URL?
}

struct MovieSimilarTitle: Identifiable {
    let id: Int
    let title: String
    let year: String?
    let poster: URL?
}

/// Ролик тайтла. `stream` почти всегда `nil`: Кинопоиск отдаёт не файл, а страницу
/// своего плеера, и подписанный поток внутри неё закрыт для сторонних клиентов
/// (см. `KinopoiskVideo`). Поэтому у ролика полезны имя и кадр, а движущуюся картинку
/// верхнего блока даёт забандленный клип — см. `MovieTrailerCover`.
struct MovieTrailer {
    let name: String
    let poster: URL?
    let stream: URL?
}

// MARK: - Сборка из ответа API

extension MovieDetails {
    /// Ширина логотипа в пикселях: макетные 188pt на ×3.
    private static let logoPixelWidth = 564

    /// Сколько персон и похожих тайтлов доезжает до экрана. Не приватные: по этим же
    /// числам `MoviePool` обрезает запись перед записью на диск — хранить состав,
    /// который карточка никогда не покажет, незачем.
    static let castLimit = 12
    static let directorLimit = 2
    static let similarLimit = 9

    init(movie: KinopoiskMovie) {
        id = movie.id
        title = movie.displayTitle
        logo = movie.logo?.logoURL(width: Self.logoPixelWidth)
        accent = Self.accent(movie)
        lead = Self.lead(movie)
        meta = Self.meta(movie)
        synopsis = Self.synopsis(movie)
        rows = Self.rows(movie)
        cast = Self.cast(movie)
        similar = Self.similar(movie)
        trailer = Self.trailer(movie)
        backdrop = movie.backdrop?.url(size: .frame) ?? movie.poster?.url(size: .medium)
    }

    /// Место акцентной строки макета занимает самый сильный реальный факт о тайтле.
    private static func accent(_ movie: KinopoiskMovie) -> String? {
        if let place = movie.top250, place > 0 {
            return "№\(place) в топ-250 Кинопоиска"
        }
        if let kp = movie.rating?.kp, kp > 0 {
            return "Кинопоиск \(kp.ratingText)"
        }
        return nil
    }

    /// Лид: редакционная строка Кинопоиска, иначе первое предложение описания,
    /// иначе слоган. Совсем пусто — название, как было до живых данных.
    private static func lead(_ movie: KinopoiskMovie) -> String {
        if let short = movie.shortDescription?.flattened, !short.isEmpty {
            return short.withoutTrailingPeriod
        }
        if let sentence = movie.description?.flattened.firstSentence, !sentence.isEmpty {
            return sentence.withoutTrailingPeriod
        }
        if let slogan = movie.slogan?.flattened, !slogan.isEmpty {
            return slogan.withoutTrailingPeriod
        }
        return movie.displayTitle
    }

    private static func meta(_ movie: KinopoiskMovie) -> [String] {
        var items: [String] = []
        if let year = movie.year { items.append("\(year)") }
        if let genre = movie.genres?.first?.name { items.append(genre) }
        if let length = movie.movieLength?.durationText { items.append(length) }
        if let country = movie.countries?.first?.name { items.append(country) }
        if let age = movie.ageRating { items.append("\(age)+") }
        return items
    }

    /// Абзацы описания. У Кинопоиска это сплошной текст — режем по границам
    /// предложений примерно по 150 символов.
    ///
    /// Отдаём **все** абзацы, а не первые три: раньше лишние просто выбрасывались,
    /// и описание обрывалось на полуслове без всякого признака, что оно продолжается.
    /// Сколько показать и где поставить многоточие, решает вью — она же умеет
    /// раскрыть текст целиком по нажатию.
    private static func synopsis(_ movie: KinopoiskMovie) -> [String] {
        guard let full = movie.description?.flattened, !full.isEmpty else { return [] }
        return full.paragraphs(targetLength: 150).map(\.withoutTrailingPeriod)
    }

    private static func rows(_ movie: KinopoiskMovie) -> [MovieDetailRow] {
        var rows: [MovieDetailRow] = []

        // Оригинальное название показываем, только если оно и правда другое.
        if let original = movie.alternativeName, !original.isEmpty, original != movie.name {
            rows.append(MovieDetailRow(label: "Оригинал", value: original, note: nil))
        }
        if let year = movie.year {
            rows.append(MovieDetailRow(
                label: "Год",
                value: "\(year)",
                note: movie.isSeries == true ? "сериал" : nil
            ))
        }
        if let genres = movie.genres?.map(\.name).prefix(3), !genres.isEmpty {
            rows.append(MovieDetailRow(label: "Жанр", value: genres.joined(separator: ", "), note: nil))
        }
        if let countries = movie.countries?.map(\.name).prefix(2), !countries.isEmpty {
            rows.append(MovieDetailRow(label: "Страна", value: countries.joined(separator: ", "), note: nil))
        }
        let directors = movie.persons?
            .filter { $0.enProfession == "director" }
            .compactMap(\.displayName)
            .prefix(directorLimit) ?? []
        if !directors.isEmpty {
            rows.append(MovieDetailRow(label: "Режиссёр", value: directors.joined(separator: ", "), note: nil))
        }
        if let length = movie.movieLength?.durationText {
            rows.append(MovieDetailRow(label: "Длительность", value: length, note: nil))
        }
        if let kp = movie.rating?.kp, kp > 0 {
            rows.append(MovieDetailRow(
                label: "Оценка",
                value: kp.ratingText,
                note: movie.votes?.kp.map { Int($0).votesText }
            ))
        }
        if let age = movie.ageRating {
            rows.append(MovieDetailRow(
                label: "Возраст",
                value: "\(age)+",
                // MPAA приходит строчными («r», «pg13») — в интерфейсе он заглавный.
                note: movie.ratingMpaa.map { $0.uppercased() }
            ))
        }
        return rows
    }

    private static func cast(_ movie: KinopoiskMovie) -> [MovieCastMember] {
        let actors = movie.persons?.filter { $0.enProfession == "actor" } ?? []
        return actors.prefix(castLimit).enumerated().compactMap { index, person in
            guard let name = person.displayName, !name.isEmpty else { return nil }
            return MovieCastMember(
                // У эпизодических персон `id` бывает пустым, а список обязан быть
                // стабильно идентифицируемым — падаем на позицию в списке.
                id: person.id ?? -(index + 1),
                name: name,
                role: person.description?.flattened,
                photo: person.photoURL
            )
        }
    }

    private static func similar(_ movie: KinopoiskMovie) -> [MovieSimilarTitle] {
        (movie.similarMovies ?? []).prefix(similarLimit).compactMap { item in
            let title = item.displayTitle
            guard !title.isEmpty else { return nil }
            return MovieSimilarTitle(
                id: item.id,
                title: title,
                year: item.year.map { "\($0)" },
                poster: item.poster?.url(size: .small)
            )
        }
    }

    private static func trailer(_ movie: KinopoiskMovie) -> MovieTrailer? {
        let videos = (movie.videos?.trailers ?? []) + (movie.videos?.teasers ?? [])
        // Ролик со своим кадром предпочтительнее: им закрывается верхний блок,
        // пока видео не поехало.
        guard let video = videos.first(where: { $0.previewImageURL != nil }) ?? videos.first else { return nil }
        return MovieTrailer(
            name: video.name ?? "Трейлер",
            poster: video.previewImageURL,
            stream: video.directStreamURL
        )
    }
}

// MARK: - Пока живых данных нет

extension MovieDetails {
    /// Карточка до ответа API и для сущностей не из Кинопоиска.
    ///
    /// `mock: true` — витрина собрана на моках (`-debugMockFeed`), у её тайтлов нет id
    /// Кинопоиска и не будет никогда. Там заглушечные факты уместны: врать не о чем,
    /// сам тайтл выдуман, а экран нужен для сверки вёрстки с макетом.
    ///
    /// `mock: false` — живой тайтл, детали ещё едут. Показываем **только название**:
    /// подставлять под настоящий фильм правдоподобные жанр и хронометраж — та же ложь
    /// о контенте, из-за которой в блоке «продолжить смотреть» отказались от мокового
    /// логотипа (DECISIONS 2026-08-23).
    static func placeholder(title: String, mock: Bool) -> MovieDetails {
        MovieDetails(
            id: 0,
            title: title,
            logo: nil,
            accent: mock ? "Выбор редакции" : nil,
            lead: title,
            meta: mock ? ["2024", "драма", "1 ч 58 мин", "16+"] : [],
            synopsis: mock ? Self.mockSynopsis : [],
            rows: mock ? Self.mockRows : [],
            cast: [],
            similar: [],
            trailer: nil,
            backdrop: nil
        )
    }

    /// Абзацы описания — в макете их 1–3, до ~150 символов каждый
    private static let mockSynopsis = [
        "Герой возвращается в город, из которого однажды сбежал, и застаёт его совсем другим.",
        "Дальше — история про то, что прошлое не отпускает, пока с ним не поговоришь начистоту.",
    ]

    private static let mockRows: [MovieDetailRow] = [
        MovieDetailRow(label: "Год", value: "2024", note: nil),
        MovieDetailRow(label: "Жанр", value: "драма", note: nil),
        MovieDetailRow(label: "Длительность", value: "1 ч 58 мин", note: nil),
        MovieDetailRow(label: "Возраст", value: "16+", note: nil),
    ]
}

// MARK: - Форматирование

private extension Int {
    /// «127» → «2 ч 7 мин», «58» → «58 мин»
    var durationText: String? {
        guard self > 0 else { return nil }
        let hours = self / 60
        let minutes = self % 60
        if hours == 0 { return "\(minutes) мин" }
        if minutes == 0 { return "\(hours) ч" }
        return "\(hours) ч \(minutes) мин"
    }

    /// «107232 оценки». Русские числительные: 1 оценка / 2 оценки / 5 оценок.
    var votesText: String {
        let thousands = self / 1000
        let head = thousands >= 10 ? "\(thousands) тыс." : "\(self)"
        let tail = thousands >= 10 ? self / 1000 : self
        let lastTwo = tail % 100
        let last = tail % 10
        let word: String
        if (11...14).contains(lastTwo) {
            word = "оценок"
        } else if last == 1 {
            word = "оценка"
        } else if (2...4).contains(last) {
            word = "оценки"
        } else {
            word = "оценок"
        }
        return "\(head) \(word)"
    }
}

private extension Double {
    /// «8.556» → «8,6». Дробная часть — одна цифра, разделитель русский.
    var ratingText: String {
        String(format: "%.1f", self).replacingOccurrences(of: ".", with: ",")
    }
}

private extension String {
    /// Схлопывает переносы и повторные пробелы: описания API приходят с вёрсткой,
    /// а в макете это сплошной текст.
    var flattened: String {
        replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var firstSentence: String {
        guard let stop = firstIndex(where: { ".!?".contains($0) }) else { return self }
        return String(self[...stop])
    }

    /// Режет сплошной текст на абзацы по границам предложений, набирая примерно
    /// `targetLength` символов на абзац. Предложение не разрывается: макет ставит
    /// абзацы в шахматном порядке, и обрыв на полуслове там читается опечаткой.
    /// Точка в конце фразы: в макете её нет ни у аргумента, ни у абзацев описания.
    /// Восклицательный и вопросительный знаки — часть интонации, их оставляем.
    var withoutTrailingPeriod: String {
        var trimmed = trimmingCharacters(in: .whitespaces)
        while trimmed.hasSuffix(".") {
            trimmed.removeLast()
        }
        return trimmed
    }

    func paragraphs(targetLength: Int) -> [String] {
        var sentences: [String] = []
        var current = ""
        for character in self {
            current.append(character)
            if ".!?".contains(character) {
                sentences.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            }
        }
        let tail = current.trimmingCharacters(in: .whitespaces)
        if !tail.isEmpty { sentences.append(tail) }

        var result: [String] = []
        var buffer = ""
        for sentence in sentences {
            if buffer.isEmpty {
                buffer = sentence
            } else if buffer.count + 1 + sentence.count <= targetLength {
                buffer += " " + sentence
            } else {
                result.append(buffer)
                buffer = sentence
            }
        }
        if !buffer.isEmpty { result.append(buffer) }
        return result
    }
}
