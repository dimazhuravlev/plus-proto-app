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
    /// Хронометраж в секундах — длина таймлайна киноплеера. `nil` — API его не отдал.
    let runtime: TimeInterval?
    /// Вторая строка шапки киноплеера: «2019 • криминал». Пусто — шапка в одну строку.
    let playerSubtitle: String?
    /// Абзацы полного описания, уже нарезанные под макет.
    let synopsis: [String]
    let rows: [MovieDetailRow]
    let cast: [MovieCastMember]
    /// Съёмочная группа — та же карусель, что и актёры, но серой строкой у неё
    /// специальность человека, а не его герой.
    let crew: [MovieCastMember]
    let similar: [MovieSimilarTitle]
    let trailer: MovieTrailer?
    /// Горизонтальный кадр тайтла — фон верхнего блока, пока не поехало видео.
    let backdrop: URL?
    /// Кадры под видеокарточки — те же сцены тайтла, но **другие**, чем в шапке.
    /// Пустой массив или короче четырёх — карточкам без кадра остаётся ролик.
    let cardStills: [URL]
}

/// Карточка персоны в карусели: имя и серая строка под ним.
struct MovieCastMember: Identifiable {
    let id: Int
    let name: String
    /// Что стоит под именем: у актёра — его герой, у съёмочной группы — специальность.
    ///
    /// У актёров эта строка чаще всего пустая: героя API отдаёт полем `description`,
    /// а в списочном роуте, которым набирается запас витрины, его нет ни у одной
    /// персоны (замер 2026-08-29 по 17 827 персонам пула). Выдумывать роль нельзя —
    /// карточка остаётся с одним именем.
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

    /// Сколько персон доезжает до экрана. Не приватные: по этим же числам `MoviePool`
    /// обрезает запись перед записью на диск — хранить состав, который карточка
    /// никогда не покажет, незачем.
    static let castLimit = 12
    static let directorLimit = 2

    /// Сколько похожих тайтлов показывает секция — ровно три ряда сетки 3×N
    /// (решение пользователя 2026-08-29; потолок был снят 2026-08-25 и вернулся
    /// тем же числом). На диске похожие по-прежнему лежат все: режется показ,
    /// а не запись — вес их записи терпимый, главную тяжесть давали персоны.
    static let similarLimit = 9

    /// Кого показывает «Съёмочная группа» и в каком порядке. Специальность здесь своя,
    /// а не из ответа API: `profession` приходит во множественном числе и без «ё»
    /// («режиссеры»), а под именем человека нужна его роль — «Режиссёр».
    ///
    /// Актёров тут нет — у них своя карусель. Актёров дубляжа (`voiceover`) нет тоже:
    /// это не съёмочная группа, а озвучка, и по числу (медиана 18 на тайтл против
    /// одного оператора) они вытеснили бы собой всех остальных.
    static let crewProfessions: [(en: String, ru: String)] = [
        ("director", "Режиссёр"),
        ("writer", "Сценарист"),
        ("operator", "Оператор"),
        ("composer", "Композитор"),
        ("producer", "Продюсер"),
        ("design", "Художник"),
        ("editor", "Монтажёр"),
    ]

    /// Потолки съёмочной группы: сколько человек на специальность и сколько всего.
    /// Продюсеров и художников у тайтла бывает под десяток (медиана по пулу — 4),
    /// и без потолка на специальность они заняли бы карусель целиком.
    static let crewPerProfessionLimit = 3
    static let crewLimit = 12

    /// - Parameter stills: горизонтальные кадры тайтла из `/v1.4/image`. Пустой массив —
    ///   кадров у тайтла нет, кавер возьмёт `backdrop`, как раньше.
    init(movie: KinopoiskMovie, stills: [KinopoiskStill] = []) {
        id = movie.id
        title = movie.displayTitle
        logo = movie.logo?.logoURL(width: Self.logoPixelWidth)
        accent = Self.accent(movie)
        lead = Self.lead(movie)
        meta = Self.meta(movie)
        runtime = movie.movieLength.flatMap { $0 > 0 ? TimeInterval($0 * 60) : nil }
        playerSubtitle = Self.playerSubtitle(movie)
        synopsis = Self.synopsis(movie)
        rows = Self.rows(movie)
        cast = Self.cast(movie)
        crew = Self.crew(movie)
        similar = Self.similar(movie)
        trailer = Self.trailer(movie)
        // Кадр вместо `backdrop`: это сцена из фильма, а не одна официальная картинка
        // на весь тайтл. Кропается он так же (кавер портретный, кадр 16:9), но приходит
        // крупнее: `huge` — единственный большой пресет, который берут кадры, и кадр
        // 6000×4000 приезжает по нему как 1920×1280 против 1344×756 у `backdrop`.
        //
        // Кадра может не быть вовсе — тогда всё работает как раньше, через `backdrop`.
        backdrop = stills.first?.url(size: .huge)
            ?? movie.backdrop?.url(size: .frame)
            ?? movie.poster?.url(size: .medium)
        // Видеокарточкам — **остальные** кадры, начиная со второго: первый уже стоит
        // в шапке, и повторять его четырьмя этажами ниже значит показать одну сцену
        // пять раз. Кадров может не хватить — тогда карточек столько, сколько кадров:
        // без своего кадра карточка не показывается (правка 2026-08-25, раньше брала
        // первый кадр забандленного ролика).
        cardStills = stills.dropFirst().compactMap { $0.url(size: .huge) }
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

    /// Шапка плеера узкая — колонка 375pt по центру верхней полосы, поэтому из меты
    /// туда едут только год и жанр: остальное на первом экране фильма уже прочитано.
    /// Разделитель тот же, что в мете карточки.
    private static func playerSubtitle(_ movie: KinopoiskMovie) -> String? {
        let items = [movie.year.map { "\($0)" }, movie.genres?.first?.name].compactMap { $0 }
        return items.isEmpty ? nil : items.joined(separator: " • ")
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

    private static func crew(_ movie: KinopoiskMovie) -> [MovieCastMember] {
        crewSelection(movie.persons ?? []).enumerated().map { index, picked in
            MovieCastMember(
                id: picked.person.id ?? -(index + 1),
                name: picked.person.displayName ?? "",
                role: picked.role,
                photo: picked.person.photoURL
            )
        }
    }

    /// Кто попадёт в «Съёмочную группу» и с какой подписью — по порядку специальностей.
    ///
    /// Общая с `MoviePool`: пул обрезает запись до того же набора, и без единого правила
    /// на диск попадали бы одни персоны, а на экран просились другие. Функция
    /// идемпотентна — прогон по уже обрезанной записи даёт тот же список.
    ///
    /// Один человек часто числится сразу в нескольких профессиях (в пуле 17 827 строк
    /// состава на 12 446 разных людей), поэтому берём его один раз — по самой старшей
    /// из них: две одинаковые карточки подряд с разными подписями читаются ошибкой.
    static func crewSelection(_ persons: [KinopoiskPerson]) -> [(person: KinopoiskPerson, role: String)] {
        var taken = Set<Int>()
        var result: [(person: KinopoiskPerson, role: String)] = []

        for profession in crewProfessions {
            var inProfession = 0
            for person in persons where person.enProfession == profession.en {
                guard result.count < crewLimit else { return result }
                guard inProfession < crewPerProfessionLimit else { break }
                guard let name = person.displayName, !name.isEmpty else { continue }
                // Персона без id — её нечем отличить от другой такой же, дублей
                // среди безымянных для карусели не набирается.
                if let id = person.id, !taken.insert(id).inserted { continue }
                inProfession += 1
                result.append((person, profession.ru))
            }
        }
        return result
    }

    private static func similar(_ movie: KinopoiskMovie) -> [MovieSimilarTitle] {
        let titles = (movie.similarMovies ?? []).compactMap { item -> MovieSimilarTitle? in
            let title = item.displayTitle
            guard !title.isEmpty else { return nil }
            return MovieSimilarTitle(
                id: item.id,
                title: title,
                year: item.year.map { "\($0)" },
                poster: item.poster?.url(size: .small)
            )
        }
        // Потолок считается после отсева безымянных: иначе выброшенный тайтл
        // забирал бы с собой место в секции.
        return Array(titles.prefix(similarLimit))
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
            // Те же моковые факты, что в мете: живому тайтлу до ответа API
            // хронометраж не выдумываем — плеер возьмёт длительность из макета.
            runtime: mock ? 118 * 60 : nil,
            playerSubtitle: mock ? "2024 • драма" : nil,
            synopsis: mock ? Self.mockSynopsis : [],
            rows: mock ? Self.mockRows : [],
            cast: [],
            crew: [],
            similar: [],
            trailer: nil,
            backdrop: nil,
            cardStills: []
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

    /// Точка в конце фразы: в макете её нет ни у аргумента, ни у абзацев описания.
    /// Восклицательный и вопросительный знаки — часть интонации, их оставляем.
    var withoutTrailingPeriod: String {
        var trimmed = trimmingCharacters(in: .whitespaces)
        while trimmed.hasSuffix(".") {
            trimmed.removeLast()
        }
        return trimmed
    }
}

extension String {
    /// Режет сплошной текст на абзацы по границам предложений, набирая примерно
    /// `targetLength` символов на абзац. Предложение не разрывается: макет ставит
    /// абзацы в шахматном порядке, и обрыв на полуслове там читается опечаткой.
    ///
    /// Не приватный: тем же способом читалка (`BookTextStore`) режет аннотацию книги,
    /// которую Google отдаёт одной строкой.
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
