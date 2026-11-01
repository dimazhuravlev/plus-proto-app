import SwiftUI

/// Настроение Таскалки — точка на поле (экспериментальный UI пустого поиска, задача
/// пользователя 2026-10-31; флаг дебаг-меню `TaskalkaDebug`).
///
/// **Оси.** По вертикали — энергия (сверху «движ», снизу «чилл»), по горизонтали — тон
/// (слева «мрак», справа «свет»): круговая модель эмоций Рассела, переведённая с «что я
/// чувствую» на «чего хочется». Палец не ставит человеку диагноз, а дописывает фразу
/// «Хочется чего-нибудь …» живым оборотом — «под плед», «этакого», «без тормозов»:
/// свобода смыслов как у станций Яндекс Музыки («Мягче некуда: софт-рок», «Трэш-метал,
/// пристегнитесь» — референс пользователя 2026-10-31).
///
/// **Сколько и где.** Пятьдесят четыре, сотами 6 × 9 (`spot`): сперва было 9, потом 17 и 31 —
/// пользователь трижды просил больше, «чтобы чаще менялись» (2026-10-31, 2026-11-01). Соседи —
/// в ~62 pt по ряду и ~65 pt между рядами: слово сменяется за ~30 pt хода пальца. Прежние
/// настроения остались в своих областях карты, новые встали между ними — всё больше темы
/// и занятия («про котиков», «под кофе»), как у станций волны. Под пальцем — ближайшее
/// (`TaskalkaMap`). Кино у тем отбирается по описанию фильма (`keywords`), у «старого
/// доброго» — по году (`maxYear`): жанром их не выразить.
///
/// Подборка — ровно то, что сказано словом («Не врать о контенте»), смеси настроений нет.
/// Непрерывны только цвет и свечение — они плывут за пальцем.
///
/// Цвет — функция места на карте (`TaskalkaColorMap`, просьба пользователя 2026-11-01):
/// у «мрака» почти чёрный, у «света» светлый, сверху тёплые тона, посередине фиолетовые
/// и розовые, внизу синие и мятные. Прежде цвета брались из палитры станций волны и
/// повторялись в разных частях поля.
struct TaskalkaMood: Identifiable, Hashable {
    enum ID: String, CaseIterable {
        case rage, tense, energetic, dance, joyful, festive
        case creepy, bold, chase, inspiring, workout, light
        case war, mysterious, drama, gamble, childhood, summer
        case noir, mafia, twist, adventure, food, heroes
        case witches, space, history, curious, romantic, french
        case neon, lonely, thoughtful, dreamy, tender, sea
        case melancholic, life, music, road, kind, nature
        case winter, oldies, meditate, coffee, weekend, spring
        case latenight, sad, calm, bedtime, cozy, cats
    }

    let id: ID
    /// Центр зоны в долях поля.
    let anchor: CGPoint
    /// Окончание фразы «Хочется чего-нибудь …» — одна строка Headline M.
    let word: String
    /// Название настроения само по себе — для действий VoiceOver.
    let title: String
    /// Что за настроение — голосом Таскалки, на «вы». На экране под фразой её больше нет
    /// (правка пользователя 2026-11-01), её читает VoiceOver вместе со словом.
    let note: String
    /// Жанры Кинопоиска с весами; фильм с жанром из `vetoGenres` не берётся вовсе.
    let genres: [String: Double]
    let vetoGenres: Set<String>
    /// Страны Кинопоиска: непусто — фильм обязан быть оттуда («по-французски»).
    var countries: Set<String> = []
    /// Тема по описанию фильма — регулярное выражение по словам («кот», «повар», «море»):
    /// непусто — фильм обязан его содержать. Темы жанром не выразить, а комедия под
    /// «про еду» была бы враньём о контенте.
    var keywords: String? = nil
    /// Не новее этого года («старого доброго»).
    var maxYear: Int? = nil
    /// Авторы книг — запросом к Google Books по имени, отбор по фамилии (приём
    /// `BooksHomeCatalog`: тематический поиск по-русски — мусор).
    let authors: [TaskalkaAuthor]
    /// Треки — подборка редакции прототипа: исполнитель и название, Deezer находит их
    /// поиском (`TaskalkaCatalog`).
    let tracks: [TaskalkaTrackSpec]

    /// Цвет места на карте (`TaskalkaColorMap`) — не свой у каждого, а функция координат.
    var fill: SIMD3<Double> { TaskalkaColorMap.rgb(at: anchor) }
    /// Слово заголовка — градиент двух близких оттенков цвета места.
    var wordGradient: LinearGradient { TaskalkaColorMap.wordGradient(at: anchor) }
}

struct TaskalkaAuthor: Hashable {
    let query: String
    let surname: String
}

struct TaskalkaTrackSpec: Hashable {
    let artist: String
    let title: String
}

extension TaskalkaMood {
    /// Место в сотах: девять рядов по шесть мест (просьба пользователя 2026-11-01: «6 на 9»).
    /// Чётные ряды сдвинуты на четверть шага влево, нечётные — вправо: соседние ряды
    /// смещены на полшага, у каждого настроения шесть соседей. Шаг — шестая ширины
    /// и девятая высоты: на поле 370×580 это ~62 × 65 pt.
    static func spot(_ row: Int, _ slot: Int) -> CGPoint {
        let shift: CGFloat = row.isMultiple(of: 2) ? 0.25 : 0.75
        return CGPoint(x: (CGFloat(slot) + shift) / 6, y: (CGFloat(row) + 0.5) / 9)
    }

    /// По рядам: сверху вниз, слева направо.
    static let all: [TaskalkaMood] = [
        // MARK: Ряд 0 — самый движ

        TaskalkaMood(
            id: .rage, anchor: spot(0, 0),
            word: "со злостью", title: "Со злостью",
            note: "Выпустить пар и\u{00A0}никого не\u{00A0}покусать",
            genres: ["боевик": 3, "триллер": 1, "криминал": 1],
            vetoGenres: ["мультфильм", "семейный", "мелодрама", "мюзикл", "комедия"],
            authors: [
                TaskalkaAuthor(query: "Энтони Бёрджесс", surname: "Бёрджесс"),
                TaskalkaAuthor(query: "Эдуард Лимонов", surname: "Лимонов"),
                TaskalkaAuthor(query: "Чак Паланик", surname: "Паланик"),
            ],
            tracks: [
                .init(artist: "Rage Against The Machine", title: "Bulls On Parade"),
                .init(artist: "Slipknot", title: "Duality"),
                .init(artist: "System Of A Down", title: "Chop Suey!"),
                .init(artist: "Metallica", title: "Enter Sandman"),
                .init(artist: "Rammstein", title: "Sonne"),
                .init(artist: "KoЯn", title: "Freak On a Leash"),
                .init(artist: "Linkin Park", title: "Faint"),
                .init(artist: "Bring Me The Horizon", title: "Throne"),
                .init(artist: "Lumen", title: "Гореть"),
            ]
        ),

        TaskalkaMood(
            id: .tense, anchor: spot(0, 1),
            word: "до дрожи", title: "До дрожи",
            note: "Сердце в\u{00A0}пятках, басы в\u{00A0}груди",
            genres: ["триллер": 3, "криминал": 2, "детектив": 2, "ужасы": 1, "боевик": 1],
            vetoGenres: ["мультфильм", "семейный", "детский", "мюзикл"],
            authors: [
                TaskalkaAuthor(query: "Борис Акунин", surname: "Акунин"),
                TaskalkaAuthor(query: "Стивен Кинг", surname: "Кинг"),
                TaskalkaAuthor(query: "Артур Конан Дойл", surname: "Дойл"),
            ],
            tracks: [
                .init(artist: "Rammstein", title: "Du hast"),
                .init(artist: "Muse", title: "Hysteria"),
                .init(artist: "Massive Attack", title: "Angel"),
                .init(artist: "Кино", title: "Группа крови"),
                .init(artist: "The Prodigy", title: "Breathe"),
                .init(artist: "Linkin Park", title: "Numb"),
                .init(artist: "Arctic Monkeys", title: "Do I Wanna Know?"),
                .init(artist: "Nine Inch Nails", title: "The Hand That Feeds"),
                .init(artist: "Placebo", title: "Every You Every Me"),
            ]
        ),

        TaskalkaMood(
            id: .energetic, anchor: spot(0, 2),
            word: "на максималках", title: "На максималках",
            note: "Разгон до\u{00A0}сотки за\u{00A0}три трека",
            genres: ["боевик": 3, "приключения": 3, "спорт": 2, "фантастика": 1],
            vetoGenres: ["ужасы", "документальный", "драма"],
            authors: [
                TaskalkaAuthor(query: "Жюль Верн", surname: "Верн"),
                TaskalkaAuthor(query: "Александр Дюма", surname: "Дюма"),
                TaskalkaAuthor(query: "Джек Лондон", surname: "Лондон"),
            ],
            tracks: [
                .init(artist: "Daft Punk", title: "One More Time"),
                .init(artist: "The Killers", title: "Mr. Brightside"),
                .init(artist: "Queen", title: "Don't Stop Me Now"),
                .init(artist: "Survivor", title: "Eye of the Tiger"),
                .init(artist: "The White Stripes", title: "Seven Nation Army"),
                .init(artist: "Звери", title: "Районы-кварталы"),
                .init(artist: "Calvin Harris", title: "Summer"),
                .init(artist: "Би-2", title: "Полковнику никто не пишет"),
                .init(artist: "Avicii", title: "Levels"),
            ]
        ),

        TaskalkaMood(
            id: .dance, anchor: spot(0, 3),
            word: "на танцпол", title: "На танцпол",
            note: "Каблуки стёрты, соседи в\u{00A0}курсе",
            genres: ["мюзикл": 3, "музыка": 3, "комедия": 1],
            vetoGenres: ["ужасы", "военный", "документальный"],
            authors: [
                TaskalkaAuthor(query: "Фрэнсис Скотт Фицджеральд", surname: "Фицджеральд"),
                TaskalkaAuthor(query: "Фредерик Бегбедер", surname: "Бегбедер"),
                TaskalkaAuthor(query: "Ирвин Уэлш", surname: "Уэлш"),
            ],
            tracks: [
                .init(artist: "Daft Punk", title: "Get Lucky"),
                .init(artist: "Dua Lipa", title: "Don't Start Now"),
                .init(artist: "Madonna", title: "Hung Up"),
                .init(artist: "Donna Summer", title: "I Feel Love"),
                .init(artist: "Robyn", title: "Dancing On My Own"),
                .init(artist: "Монеточка", title: "Каждый раз"),
                .init(artist: "Purple Disco Machine", title: "Hypnotized"),
                .init(artist: "Michael Jackson", title: "Billie Jean"),
                .init(artist: "Little Big", title: "Skibidi"),
            ]
        ),

        TaskalkaMood(
            id: .joyful, anchor: spot(0, 4),
            word: "с приколом", title: "С приколом",
            note: "Смех до\u{00A0}икоты, танцы на\u{00A0}столе",
            genres: ["комедия": 3, "мюзикл": 2, "музыка": 1, "приключения": 0.5],
            vetoGenres: ["ужасы", "военный", "триллер", "драма"],
            authors: [
                TaskalkaAuthor(query: "Ильф Петров", surname: "Ильф"),
                TaskalkaAuthor(query: "Михаил Зощенко", surname: "Зощенко"),
                TaskalkaAuthor(query: "Джером К. Джером", surname: "Джером"),
            ],
            tracks: [
                .init(artist: "Pharrell Williams", title: "Happy"),
                .init(artist: "Mark Ronson", title: "Uptown Funk"),
                .init(artist: "ABBA", title: "Dancing Queen"),
                .init(artist: "Dua Lipa", title: "Levitating"),
                .init(artist: "Earth, Wind & Fire", title: "September"),
                .init(artist: "Mumiy Troll", title: "Владивосток 2000"),
                .init(artist: "Katrina & The Waves", title: "Walking On Sunshine"),
                .init(artist: "Иван Дорн", title: "Стыцамен"),
                .init(artist: "Bee Gees", title: "Stayin' Alive"),
            ]
        ),

        TaskalkaMood(
            id: .festive, anchor: spot(0, 5),
            word: "с салютом", title: "С салютом",
            note: "Конфетти, шампанское и\u{00A0}крики «ура»",
            genres: ["комедия": 2, "мюзикл": 1, "семейный": 1],
            vetoGenres: ["ужасы", "военный", "триллер"],
            keywords: #"\b(праздн\w*|свадьб\w*|вечеринк\w*|рождеств\w*|новогодн\w*|юбиле\w*|карнавал\w*)\b"#,
            authors: [
                TaskalkaAuthor(query: "Чарльз Диккенс", surname: "Диккенс"),
                TaskalkaAuthor(query: "О. Генри", surname: "Генри"),
                TaskalkaAuthor(query: "Тэффи", surname: "Тэффи"),
            ],
            tracks: [
                .init(artist: "Kool & The Gang", title: "Celebration"),
                .init(artist: "Queen", title: "We Are The Champions"),
                .init(artist: "Katy Perry", title: "Firework"),
                .init(artist: "Black Eyed Peas", title: "I Gotta Feeling"),
                .init(artist: "Verka Serduchka", title: "Всё будет хорошо"),
                .init(artist: "Bruno Mars", title: "24K Magic"),
                .init(artist: "Wham!", title: "Last Christmas"),
                .init(artist: "Avicii", title: "The Nights"),
                .init(artist: "Mariah Carey", title: "All I Want for Christmas Is You"),
            ]
        ),

        // MARK: Ряд 1 — движ

        TaskalkaMood(
            id: .creepy, anchor: spot(1, 0),
            word: "пострашнее", title: "Пострашнее",
            note: "Свет сегодня не\u{00A0}выключайте",
            genres: ["ужасы": 3, "триллер": 1, "фэнтези": 0.5, "детектив": 0.5],
            vetoGenres: ["мультфильм", "семейный", "мюзикл", "мелодрама", "комедия"],
            authors: [
                TaskalkaAuthor(query: "Говард Лавкрафт", surname: "Лавкрафт"),
                TaskalkaAuthor(query: "Эдгар Аллан По", surname: "Эдгар"),
                TaskalkaAuthor(query: "Брэм Стокер", surname: "Стокер"),
            ],
            tracks: [
                .init(artist: "Bauhaus", title: "Bela Lugosi's Dead"),
                .init(artist: "Michael Jackson", title: "Thriller"),
                .init(artist: "Billie Eilish", title: "bury a friend"),
                .init(artist: "Король и Шут", title: "Кукла колдуна"),
                .init(artist: "Marilyn Manson", title: "The Beautiful People"),
                .init(artist: "Nick Cave & The Bad Seeds", title: "Red Right Hand"),
                .init(artist: "Radiohead", title: "Climbing Up the Walls"),
                .init(artist: "Король и Шут", title: "Лесник"),
                .init(artist: "Chelsea Wolfe", title: "Carrion Flowers"),
            ]
        ),

        TaskalkaMood(
            id: .bold, anchor: spot(1, 1),
            word: "без тормозов", title: "Без тормозов",
            note: "Громко, грубо и\u{00A0}без\u{00A0}извинений",
            genres: ["криминал": 3, "боевик": 2, "комедия": 1],
            vetoGenres: ["мультфильм", "семейный", "мелодрама", "документальный"],
            authors: [
                TaskalkaAuthor(query: "Чак Паланик", surname: "Паланик"),
                TaskalkaAuthor(query: "Венедикт Ерофеев", surname: "Ерофеев"),
                TaskalkaAuthor(query: "Чарльз Буковски", surname: "Буковски"),
            ],
            tracks: [
                .init(artist: "The Clash", title: "London Calling"),
                .init(artist: "Beastie Boys", title: "Sabotage"),
                .init(artist: "Rage Against The Machine", title: "Killing In The Name"),
                .init(artist: "Гражданская оборона", title: "Всё идёт по плану"),
                .init(artist: "Sex Pistols", title: "Anarchy in the U.K."),
                .init(artist: "Ленинград", title: "Экспонат"),
                .init(artist: "Kendrick Lamar", title: "HUMBLE."),
                .init(artist: "M.I.A.", title: "Paper Planes"),
                .init(artist: "Nirvana", title: "Smells Like Teen Spirit"),
            ]
        ),

        TaskalkaMood(
            id: .chase, anchor: spot(1, 2),
            word: "с погоней", title: "С погоней",
            note: "Шины визжат, сюжет не\u{00A0}тормозит",
            genres: ["боевик": 3, "триллер": 2, "приключения": 1, "криминал": 1],
            vetoGenres: ["мультфильм", "семейный", "мелодрама", "документальный"],
            authors: [
                TaskalkaAuthor(query: "Ли Чайлд", surname: "Чайлд"),
                TaskalkaAuthor(query: "Джеймс Роллинс", surname: "Роллинс"),
            ],
            tracks: [
                .init(artist: "Moby", title: "Extreme Ways"),
                .init(artist: "The Prodigy", title: "Firestarter"),
                .init(artist: "The Chemical Brothers", title: "Galvanize"),
                .init(artist: "Junkie XL", title: "Brothers in Arms"),
                .init(artist: "Pendulum", title: "Watercolour"),
                .init(artist: "Daft Punk", title: "Derezzed"),
                .init(artist: "Muse", title: "Knights of Cydonia"),
                .init(artist: "Кино", title: "Последний герой"),
                .init(artist: "Audioslave", title: "Cochise"),
            ]
        ),

        TaskalkaMood(
            id: .inspiring, anchor: spot(1, 3),
            word: "для подвига", title: "Для подвига",
            note: "Свернуть горы. Ну\u{00A0}или встать с\u{00A0}дивана",
            genres: ["биография": 3, "спорт": 3, "драма": 1, "история": 1],
            vetoGenres: ["ужасы", "криминал", "триллер"],
            authors: [
                TaskalkaAuthor(query: "Уолтер Айзексон", surname: "Айзексон"),
                TaskalkaAuthor(query: "Ричард Фейнман", surname: "Фейнман"),
                TaskalkaAuthor(query: "Ричард Бах", surname: "Бах"),
            ],
            tracks: [
                .init(artist: "Coldplay", title: "Viva La Vida"),
                .init(artist: "M83", title: "Midnight City"),
                .init(artist: "Hans Zimmer", title: "Time"),
                .init(artist: "Кино", title: "Звезда по имени Солнце"),
                .init(artist: "U2", title: "Beautiful Day"),
                .init(artist: "Florence + The Machine", title: "Dog Days Are Over"),
                .init(artist: "David Bowie", title: "Starman"),
                .init(artist: "The Verve", title: "Bitter Sweet Symphony"),
                .init(artist: "Imagine Dragons", title: "On Top Of The World"),
            ]
        ),

        TaskalkaMood(
            id: .workout, anchor: spot(1, 4),
            word: "под тренировку", title: "Под тренировку",
            note: "Ещё один подход\u{00A0}— и\u{00A0}хватит. Честно",
            genres: ["спорт": 3, "биография": 1],
            vetoGenres: ["ужасы", "мелодрама", "мультфильм"],
            authors: [
                TaskalkaAuthor(query: "Фил Найт", surname: "Найт"),
                TaskalkaAuthor(query: "Харуки Мураками", surname: "Мураками"),
            ],
            tracks: [
                .init(artist: "Eminem", title: "Till I Collapse"),
                .init(artist: "Kanye West", title: "Stronger"),
                .init(artist: "Imagine Dragons", title: "Believer"),
                .init(artist: "AC/DC", title: "Thunderstruck"),
                .init(artist: "Daft Punk", title: "Harder, Better, Faster, Stronger"),
                .init(artist: "Queen", title: "Another One Bites The Dust"),
                .init(artist: "The Prodigy", title: "Omen"),
                .init(artist: "Eminem", title: "Lose Yourself"),
                .init(artist: "Bill Conti", title: "Gonna Fly Now"),
            ]
        ),

        TaskalkaMood(
            id: .light, anchor: spot(1, 5),
            word: "без драмы", title: "Без драмы",
            note: "Сплошной кайф, ноль заморочек",
            genres: ["комедия": 3, "мелодрама": 1, "семейный": 1, "приключения": 1],
            vetoGenres: ["ужасы", "триллер", "драма", "военный", "криминал"],
            authors: [
                TaskalkaAuthor(query: "Тэффи", surname: "Тэффи"),
                TaskalkaAuthor(query: "О. Генри", surname: "Генри"),
                TaskalkaAuthor(query: "Аркадий Аверченко", surname: "Аверченко"),
            ],
            tracks: [
                .init(artist: "The Beatles", title: "Here Comes The Sun"),
                .init(artist: "Bob Marley & The Wailers", title: "Three Little Birds"),
                .init(artist: "Harry Styles", title: "Watermelon Sugar"),
                .init(artist: "Jason Mraz", title: "I'm Yours"),
                .init(artist: "Леонид Агутин", title: "Хоп хэй лала лэй"),
                .init(artist: "Vampire Weekend", title: "A-Punk"),
                .init(artist: "Phoenix", title: "Lisztomania"),
                .init(artist: "Weezer", title: "Island In The Sun"),
                .init(artist: "Lizzo", title: "Good As Hell"),
            ]
        ),

        // MARK: Ряд 2 — бодро

        TaskalkaMood(
            id: .war, anchor: spot(2, 0),
            word: "про войну", title: "Про войну",
            note: "Тяжело, но\u{00A0}помнить надо",
            genres: ["военный": 3, "история": 1, "драма": 0.5],
            vetoGenres: ["комедия", "мультфильм", "мюзикл", "семейный"],
            authors: [
                TaskalkaAuthor(query: "Борис Васильев", surname: "Васильев"),
                TaskalkaAuthor(query: "Михаил Шолохов", surname: "Шолохов"),
                TaskalkaAuthor(query: "Василь Быков", surname: "Быков"),
            ],
            tracks: [
                .init(artist: "Metallica", title: "One"),
                .init(artist: "The Cranberries", title: "Zombie"),
                .init(artist: "Edwin Starr", title: "War"),
                .init(artist: "Black Sabbath", title: "War Pigs"),
                .init(artist: "Pink Floyd", title: "Goodbye Blue Sky"),
                .init(artist: "Hans Zimmer", title: "Supermarine"),
                .init(artist: "Vladimir Vysotsky", title: "Он не вернулся из боя"),
                .init(artist: "John Williams", title: "Hymn to the Fallen"),
                .init(artist: "Sabaton", title: "The Last Stand"),
            ]
        ),

        TaskalkaMood(
            id: .mysterious, anchor: spot(2, 1),
            word: "с загадкой", title: "С загадкой",
            note: "Туман, шорохи и\u{00A0}подозрительные типы",
            genres: ["детектив": 2, "фантастика": 2, "фэнтези": 2, "ужасы": 1, "триллер": 1],
            vetoGenres: ["комедия", "мюзикл", "спорт"],
            authors: [
                TaskalkaAuthor(query: "Николай Гоголь", surname: "Гоголь"),
                TaskalkaAuthor(query: "Михаил Булгаков", surname: "Булгаков"),
                TaskalkaAuthor(query: "Рэй Брэдбери", surname: "Брэдбери"),
            ],
            tracks: [
                .init(artist: "Portishead", title: "Glory Box"),
                .init(artist: "Massive Attack", title: "Teardrop"),
                .init(artist: "The Cure", title: "A Forest"),
                .init(artist: "Joy Division", title: "Disorder"),
                .init(artist: "Cocteau Twins", title: "Heaven or Las Vegas"),
                .init(artist: "Depeche Mode", title: "Enjoy the Silence"),
                .init(artist: "Molchat Doma", title: "Судно (Борис Рыжий)"),
                .init(artist: "Siouxsie and The Banshees", title: "Spellbound"),
                .init(artist: "Lana Del Rey", title: "Video Games"),
            ]
        ),

        TaskalkaMood(
            id: .drama, anchor: spot(2, 2),
            word: "с драмой", title: "С драмой",
            note: "Страсти кипят, платочки наготове",
            genres: ["драма": 3, "мелодрама": 1, "криминал": 1],
            vetoGenres: ["комедия", "мультфильм", "семейный", "мюзикл"],
            authors: [
                TaskalkaAuthor(query: "Уильям Шекспир", surname: "Шекспир"),
                TaskalkaAuthor(query: "Теодор Драйзер", surname: "Драйзер"),
                TaskalkaAuthor(query: "Джон Стейнбек", surname: "Стейнбек"),
            ],
            tracks: [
                .init(artist: "Queen", title: "Bohemian Rhapsody"),
                .init(artist: "Adele", title: "Rolling in the Deep"),
                .init(artist: "Hozier", title: "Take Me To Church"),
                .init(artist: "Florence + The Machine", title: "Shake It Out"),
                .init(artist: "Земфира", title: "Ромашки"),
                .init(artist: "Ночные Снайперы", title: "31-я весна"),
                .init(artist: "Evanescence", title: "My Immortal"),
                .init(artist: "Sinéad O'Connor", title: "Nothing Compares 2 U"),
                .init(artist: "Imagine Dragons", title: "Demons"),
            ]
        ),

        TaskalkaMood(
            id: .gamble, anchor: spot(2, 3),
            word: "с азартом", title: "С азартом",
            note: "Ставки сделаны, ставок больше нет",
            genres: ["криминал": 1, "спорт": 1, "комедия": 1, "приключения": 1],
            vetoGenres: ["ужасы", "мультфильм"],
            keywords: #"\b(ограблени\w*|казино|покер\w*|ставк\w*|азарт\w*|афер\w*|мошенни\w*|игрок\w*|гонк\w*|пари)\b"#,
            authors: [
                TaskalkaAuthor(query: "Александр Пушкин", surname: "Пушкин"),
                TaskalkaAuthor(query: "Артуро Перес-Реверте", surname: "Реверте"),
                TaskalkaAuthor(query: "Стефан Цвейг", surname: "Цвейг"),
            ],
            tracks: [
                .init(artist: "Frank Sinatra", title: "Luck Be A Lady"),
                .init(artist: "Nancy Sinatra", title: "Bang Bang"),
                .init(artist: "Elvis Presley", title: "Viva Las Vegas"),
                .init(artist: "Lady Gaga", title: "Poker Face"),
                .init(artist: "Arctic Monkeys", title: "R U Mine?"),
                .init(artist: "AC/DC", title: "Shoot To Thrill"),
                .init(artist: "Kenny Rogers", title: "The Gambler"),
                .init(artist: "The Hives", title: "Hate To Say I Told You So"),
                .init(artist: "Muse", title: "Uprising"),
            ]
        ),

        TaskalkaMood(
            id: .childhood, anchor: spot(2, 4),
            word: "из детства", title: "Из детства",
            note: "Как после школы под\u{00A0}мультики",
            genres: ["мультфильм": 3, "семейный": 3, "приключения": 1, "фэнтези": 1],
            vetoGenres: ["ужасы", "триллер", "криминал", "военный"],
            authors: [
                TaskalkaAuthor(query: "Николай Носов", surname: "Носов"),
                TaskalkaAuthor(query: "Эдуард Успенский", surname: "Успенский"),
                TaskalkaAuthor(query: "Кир Булычёв", surname: "Булыч"),
            ],
            tracks: [
                .init(artist: "Backstreet Boys", title: "I Want It That Way"),
                .init(artist: "Руки Вверх", title: "Крошка моя"),
                .init(artist: "Hi-Fi", title: "Седьмой лепесток"),
                .init(artist: "Spice Girls", title: "Wannabe"),
                .init(artist: "Aqua", title: "Barbie Girl"),
                .init(artist: "Smash Mouth", title: "All Star"),
                .init(artist: "Иванушки International", title: "Тучи"),
                .init(artist: "Eiffel 65", title: "Blue (Da Ba Dee)"),
                .init(artist: "Britney Spears", title: "...Baby One More Time"),
            ]
        ),

        TaskalkaMood(
            id: .summer, anchor: spot(2, 5),
            word: "про лето", title: "Про лето",
            note: "Солнце, лёд в\u{00A0}стакане и\u{00A0}никаких дедлайнов",
            genres: ["комедия": 2, "мелодрама": 2, "приключения": 2],
            vetoGenres: ["ужасы", "военный", "триллер", "криминал"],
            keywords: #"\b(лето|летом|летн\w*|каникул\w*|пляж\w*|отпуск\w*|курорт\w*)\b"#,
            authors: [
                TaskalkaAuthor(query: "Джером Сэлинджер", surname: "Сэлинджер"),
                TaskalkaAuthor(query: "Сомерсет Моэм", surname: "Моэм"),
                TaskalkaAuthor(query: "Фазиль Искандер", surname: "Искандер"),
            ],
            tracks: [
                .init(artist: "Mungo Jerry", title: "In the Summertime"),
                .init(artist: "Bananarama", title: "Cruel Summer"),
                .init(artist: "Glass Animals", title: "Heat Waves"),
                .init(artist: "Kygo", title: "Firestone"),
                .init(artist: "DNCE", title: "Cake By The Ocean"),
                .init(artist: "The Beach Boys", title: "Surfin' U.S.A."),
                .init(artist: "Тима Белорусских", title: "Мокрые кроссы"),
                .init(artist: "Luis Fonsi", title: "Despacito"),
                .init(artist: "The Lovin' Spoonful", title: "Summer in the City"),
            ]
        ),

        // MARK: Ряд 3 — активно

        TaskalkaMood(
            id: .noir, anchor: spot(3, 0),
            word: "в стиле нуар", title: "В стиле нуар",
            note: "Дым, дождь и\u{00A0}шляпа набекрень",
            genres: ["детектив": 3, "криминал": 3, "триллер": 1],
            vetoGenres: ["мультфильм", "семейный", "комедия", "мюзикл"],
            authors: [
                TaskalkaAuthor(query: "Джеймс Хэдли Чейз", surname: "Чейз"),
                TaskalkaAuthor(query: "Жорж Сименон", surname: "Сименон"),
                TaskalkaAuthor(query: "Аркадий Вайнер", surname: "Вайнер"),
            ],
            tracks: [
                .init(artist: "Miles Davis", title: "So What"),
                .init(artist: "Nina Simone", title: "Feeling Good"),
                .init(artist: "Portishead", title: "Sour Times"),
                .init(artist: "Chris Isaak", title: "Wicked Game"),
                .init(artist: "Julie London", title: "Cry Me A River"),
                .init(artist: "Tom Waits", title: "Jockey Full of Bourbon"),
                .init(artist: "Massive Attack", title: "Paradise Circus"),
                .init(artist: "Bohren & der Club of Gore", title: "Prowler"),
                .init(artist: "Angelo Badalamenti", title: "Twin Peaks Theme"),
            ]
        ),

        TaskalkaMood(
            id: .mafia, anchor: spot(3, 1),
            word: "про мафию", title: "Про мафию",
            note: "Предложение, от\u{00A0}которого не\u{00A0}отказываются",
            genres: ["криминал": 2, "драма": 1],
            vetoGenres: ["мультфильм", "семейный", "мюзикл"],
            keywords: #"\b(мафи\w*|мафиоз\w*|гангстер\w*|бандит\w*|клан\w*|корлеоне|якудз\w*|наркобарон\w*)\b"#,
            authors: [
                TaskalkaAuthor(query: "Марио Пьюзо", surname: "Пьюзо"),
                TaskalkaAuthor(query: "Роберто Савиано", surname: "Савиано"),
            ],
            tracks: [
                .init(artist: "Nino Rota", title: "Love Theme From"),
                .init(artist: "Dean Martin", title: "That's Amore"),
                .init(artist: "Frank Sinatra", title: "My Way"),
                .init(artist: "Louis Prima", title: "Buona Sera"),
                .init(artist: "Coolio", title: "Gangsta's Paradise"),
                .init(artist: "Ennio Morricone", title: "Deborah's Theme"),
                .init(artist: "The Animals", title: "House Of The Rising Sun"),
                .init(artist: "The Rolling Stones", title: "Gimme Shelter"),
                .init(artist: "Tony Bennett", title: "Rags To Riches"),
            ]
        ),

        TaskalkaMood(
            id: .twist, anchor: spot(3, 2),
            word: "с подвохом", title: "С подвохом",
            note: "Кажется, всё понятно. Кажется",
            genres: ["триллер": 2, "детектив": 2, "фантастика": 1],
            vetoGenres: ["мультфильм", "семейный", "мюзикл", "мелодрама", "комедия"],
            authors: [
                TaskalkaAuthor(query: "Гиллиан Флинн", surname: "Флинн"),
                TaskalkaAuthor(query: "Харлан Кобен", surname: "Кобен"),
                TaskalkaAuthor(query: "Пола Хокинс", surname: "Хокинс"),
            ],
            tracks: [
                .init(artist: "Radiohead", title: "Paranoid Android"),
                .init(artist: "Muse", title: "Psycho"),
                .init(artist: "Billie Eilish", title: "bad guy"),
                .init(artist: "The Beatles", title: "I Am The Walrus"),
                .init(artist: "Tool", title: "Schism"),
                .init(artist: "Twenty One Pilots", title: "Heathens"),
                .init(artist: "Placebo", title: "Running Up That Hill"),
                .init(artist: "Pink Floyd", title: "Brain Damage"),
                .init(artist: "Massive Attack", title: "Inertia Creeps"),
            ]
        ),

        TaskalkaMood(
            id: .adventure, anchor: spot(3, 3),
            word: "с приключениями", title: "С приключениями",
            note: "Карта, компас и\u{00A0}ни\u{00A0}минуты скуки",
            genres: ["приключения": 3, "фэнтези": 1, "боевик": 1],
            vetoGenres: ["ужасы", "военный"],
            authors: [
                TaskalkaAuthor(query: "Роберт Льюис Стивенсон", surname: "Стивенсон"),
                TaskalkaAuthor(query: "Майн Рид", surname: "Рид"),
                TaskalkaAuthor(query: "Фенимор Купер", surname: "Купер"),
            ],
            tracks: [
                .init(artist: "Howard Shore", title: "Concerning Hobbits"),
                .init(artist: "Klaus Badelt", title: "He's a Pirate"),
                .init(artist: "John Williams", title: "Raiders March"),
                .init(artist: "Two Steps From Hell", title: "Heart Of Courage"),
                .init(artist: "Of Monsters and Men", title: "Mountain Sound"),
                .init(artist: "Coldplay", title: "Adventure Of A Lifetime"),
                .init(artist: "Lord Huron", title: "Ends Of The Earth"),
                .init(artist: "Alan Silvestri", title: "Back To The Future"),
                .init(artist: "Mumford & Sons", title: "I Will Wait"),
            ]
        ),

        TaskalkaMood(
            id: .food, anchor: spot(3, 4),
            word: "про еду", title: "Про еду",
            note: "Смотреть на\u{00A0}голодный желудок не\u{00A0}советуем",
            genres: ["комедия": 1, "мелодрама": 1, "документальный": 1, "семейный": 1, "мультфильм": 1],
            vetoGenres: ["ужасы", "военный"],
            keywords: #"\b(повар\w*|ресторан\w*|кухн\w*|кулинар\w*|блюд\w*|еда|еды|едой|пекар\w*|кондитер\w*)\b"#,
            authors: [
                TaskalkaAuthor(query: "Вильям Похлёбкин", surname: "Похл"),
                TaskalkaAuthor(query: "Джоанн Харрис", surname: "Харрис"),
            ],
            tracks: [
                .init(artist: "Harry Belafonte", title: "Banana Boat Song (Day-O)"),
                .init(artist: "The Presidents Of The United States Of America", title: "Peaches"),
                .init(artist: "The Beatles", title: "Savoy Truffle"),
                .init(artist: "Ленинград", title: "В Питере — пить"),
                .init(artist: "Rosemary Clooney", title: "Mambo Italiano"),
                .init(artist: "Gorillaz", title: "Superfast Jellyfish"),
                .init(artist: "Tom Waits", title: "Eggs and Sausage"),
                .init(artist: "The Beach Boys", title: "Vegetables"),
                .init(artist: "Mika", title: "Lollipop"),
            ]
        ),

        TaskalkaMood(
            id: .heroes, anchor: spot(3, 5),
            word: "про супергероев", title: "Про супергероев",
            note: "Плащ не\u{00A0}обязателен, но\u{00A0}желателен",
            genres: ["фантастика": 1, "боевик": 1, "приключения": 1],
            vetoGenres: ["мелодрама"],
            keywords: #"\b(супергер\w*|сверхспособност\w*|суперсил\w*|мстител\w*|бэтмен\w*|супермен\w*|человек-паук\w*|комикс\w*)\b"#,
            authors: [
                TaskalkaAuthor(query: "Нил Гейман", surname: "Гейман"),
                TaskalkaAuthor(query: "Алан Мур", surname: "Мур"),
                TaskalkaAuthor(query: "Стэн Ли", surname: "Стэн"),
            ],
            tracks: [
                .init(artist: "Alan Silvestri", title: "The Avengers"),
                .init(artist: "Danny Elfman", title: "Batman Theme"),
                .init(artist: "Queen", title: "Flash"),
                .init(artist: "Bonnie Tyler", title: "Holding Out For A Hero"),
                .init(artist: "Five for Fighting", title: "Superman (It's Not Easy)"),
                .init(artist: "Coldplay", title: "Something Just Like This"),
                .init(artist: "Nickelback", title: "Hero"),
                .init(artist: "Ludwig Goransson", title: "Wakanda"),
                .init(artist: "Hans Zimmer", title: "Why Do We Fall?"),
            ]
        ),

        // MARK: Ряд 4 — середина

        TaskalkaMood(
            id: .witches, anchor: spot(4, 0),
            word: "про ведьм", title: "Про ведьм",
            note: "Котёл, метла и\u{00A0}немного магии",
            genres: ["фэнтези": 2, "ужасы": 1],
            vetoGenres: ["военный"],
            keywords: #"\b(ведьм\w*|колдун\w*|колдовств\w*|чародей\w*|чародейк\w*|волшебниц\w*|ведьмак\w*)\b"#,
            authors: [
                TaskalkaAuthor(query: "Терри Пратчетт", surname: "Пратчетт"),
                TaskalkaAuthor(query: "Роальд Даль", surname: "Роальд"),
                TaskalkaAuthor(query: "Ширли Джексон", surname: "Джексон"),
            ],
            tracks: [
                .init(artist: "Fleetwood Mac", title: "Rhiannon"),
                .init(artist: "Santana", title: "Black Magic Woman"),
                .init(artist: "Screamin' Jay Hawkins", title: "I Put A Spell On You"),
                .init(artist: "Eagles", title: "Witchy Woman"),
                .init(artist: "Kate Bush", title: "Wuthering Heights"),
                .init(artist: "Florence + The Machine", title: "Seven Devils"),
                .init(artist: "Король и Шут", title: "Ведьма и осёл"),
                .init(artist: "Stevie Nicks", title: "Edge Of Seventeen"),
                .init(artist: "Пикник", title: "Колдун"),
            ]
        ),

        TaskalkaMood(
            id: .space, anchor: spot(4, 1),
            word: "про космос", title: "Про космос",
            note: "Поехали! Невесомость за\u{00A0}наш счёт",
            genres: ["фантастика": 3, "документальный": 1],
            vetoGenres: ["мелодрама", "мюзикл"],
            keywords: #"\b(космос\w*|космич\w*|космонавт\w*|астронавт\w*|планет\w*|галакти\w*|звездол[её]т\w*|марс\w*|орбит\w*|вселенн\w*)\b"#,
            authors: [
                TaskalkaAuthor(query: "Станислав Лем", surname: "Лем"),
                TaskalkaAuthor(query: "Айзек Азимов", surname: "Азимов"),
                TaskalkaAuthor(query: "Стивен Хокинг", surname: "Хокинг"),
            ],
            tracks: [
                .init(artist: "David Bowie", title: "Space Oddity"),
                .init(artist: "Hans Zimmer", title: "Cornfield Chase"),
                .init(artist: "Земляне", title: "Трава у дома"),
                .init(artist: "Elton John", title: "Rocket Man"),
                .init(artist: "M83", title: "Outro"),
                .init(artist: "Pink Floyd", title: "Astronomy Domine"),
                .init(artist: "Jean-Michel Jarre", title: "Oxygène"),
                .init(artist: "Muse", title: "Starlight"),
                .init(artist: "The Police", title: "Walking on the Moon"),
            ]
        ),

        TaskalkaMood(
            id: .history, anchor: spot(4, 2),
            word: "про историю", title: "Про историю",
            note: "Как всё было на\u{00A0}самом деле. Почти",
            genres: ["история": 3, "биография": 2, "военный": 0.5],
            vetoGenres: ["фантастика", "фэнтези", "мультфильм", "ужасы"],
            authors: [
                TaskalkaAuthor(query: "Джаред Даймонд", surname: "Даймонд"),
                TaskalkaAuthor(query: "Лев Гумилёв", surname: "Гумил"),
                TaskalkaAuthor(query: "Мэри Бирд", surname: "Бирд"),
            ],
            tracks: [
                .init(artist: "Hans Zimmer", title: "Now We Are Free"),
                .init(artist: "Ennio Morricone", title: "The Ecstasy Of Gold"),
                .init(artist: "Vangelis", title: "Conquest Of Paradise"),
                .init(artist: "Ramin Djawadi", title: "Main Title"),
                .init(artist: "Dead Can Dance", title: "The Host Of Seraphim"),
                .init(artist: "Wardruna", title: "Helvegen"),
                .init(artist: "Gregorian", title: "Moment Of Peace"),
                .init(artist: "Enigma", title: "Sadeness"),
                .init(artist: "Lisa Gerrard", title: "Now We Are Free"),
            ]
        ),

        TaskalkaMood(
            id: .curious, anchor: spot(4, 3),
            word: "этакого", title: "Этакое",
            note: "Вслепую, но\u{00A0}со\u{00A0}вкусом",
            // Середина поля — без жанрового перекоса: лучшее из разных жанров по кругу.
            genres: [:],
            vetoGenres: [],
            authors: [
                TaskalkaAuthor(query: "Юваль Ной Харари", surname: "Харари"),
                TaskalkaAuthor(query: "Роберт Сапольски", surname: "Сапольски"),
                TaskalkaAuthor(query: "Харуки Мураками", surname: "Мураками"),
            ],
            tracks: [
                .init(artist: "Radiohead", title: "Weird Fishes / Arpeggi"),
                .init(artist: "Gorillaz", title: "Feel Good Inc."),
                .init(artist: "Tame Impala", title: "The Less I Know The Better"),
                .init(artist: "Björk", title: "Hyperballad"),
                .init(artist: "АИГЕЛ", title: "Татарин"),
                .init(artist: "Khruangbin", title: "Time (You and I)"),
                .init(artist: "Stromae", title: "Alors on danse"),
                .init(artist: "Земфира", title: "Хочешь?"),
                .init(artist: "Moderat", title: "A New Error"),
            ]
        ),

        TaskalkaMood(
            id: .romantic, anchor: spot(4, 4),
            word: "про любовь", title: "Про любовь",
            note: "Бабочки в\u{00A0}животе идут в\u{00A0}комплекте",
            genres: ["мелодрама": 3, "комедия": 1, "драма": 0.5],
            vetoGenres: ["ужасы", "боевик", "военный", "мультфильм", "криминал"],
            authors: [
                TaskalkaAuthor(query: "Джейн Остин", surname: "Остин"),
                TaskalkaAuthor(query: "Иван Тургенев", surname: "Тургенев"),
                TaskalkaAuthor(query: "Александр Куприн", surname: "Куприн"),
            ],
            tracks: [
                .init(artist: "Etta James", title: "At Last"),
                .init(artist: "Elvis Presley", title: "Can't Help Falling in Love"),
                .init(artist: "Frank Sinatra", title: "Fly Me To The Moon"),
                .init(artist: "Norah Jones", title: "Come Away With Me"),
                .init(artist: "Ed Sheeran", title: "Perfect"),
                .init(artist: "Sade", title: "By Your Side"),
                .init(artist: "Ёлка", title: "Прованс"),
                .init(artist: "Lana Del Rey", title: "Young and Beautiful"),
                .init(artist: "Mumiy Troll", title: "Невеста?"),
            ]
        ),

        TaskalkaMood(
            id: .french, anchor: spot(4, 5),
            word: "по-французски", title: "По-французски",
            note: "Багет под\u{00A0}мышкой, шансон в\u{00A0}ушах",
            genres: ["мелодрама": 1, "комедия": 1, "драма": 1],
            vetoGenres: ["ужасы"],
            countries: ["Франция"],
            authors: [
                TaskalkaAuthor(query: "Ги де Мопассан", surname: "Мопассан"),
                TaskalkaAuthor(query: "Гюстав Флобер", surname: "Флобер"),
                TaskalkaAuthor(query: "Виктор Гюго", surname: "Гюго"),
            ],
            tracks: [
                .init(artist: "Édith Piaf", title: "La vie en rose"),
                .init(artist: "Joe Dassin", title: "Les Champs-Elysées"),
                .init(artist: "Zaz", title: "Je veux"),
                .init(artist: "Charles Aznavour", title: "La Bohème"),
                .init(artist: "Indila", title: "Dernière danse"),
                .init(artist: "Stromae", title: "Papaoutai"),
                .init(artist: "Christine and the Queens", title: "Christine"),
                .init(artist: "Serge Gainsbourg", title: "La Javanaise"),
                .init(artist: "Françoise Hardy", title: "Tous les garçons et les filles"),
            ]
        ),

        // MARK: Ряд 5 — поспокойнее

        TaskalkaMood(
            id: .neon, anchor: spot(5, 0),
            word: "под неон", title: "Под неон",
            note: "Ночной город, синтезатор и\u{00A0}мокрый асфальт",
            genres: ["фантастика": 2, "криминал": 2, "триллер": 1],
            vetoGenres: ["мультфильм", "семейный", "мюзикл", "мелодрама"],
            authors: [
                TaskalkaAuthor(query: "Уильям Гибсон", surname: "Гибсон"),
                TaskalkaAuthor(query: "Филип Дик", surname: "Дик"),
                TaskalkaAuthor(query: "Виктор Пелевин", surname: "Пелевин"),
            ],
            tracks: [
                .init(artist: "Kavinsky", title: "Nightcall"),
                .init(artist: "The Weeknd", title: "Blinding Lights"),
                .init(artist: "College", title: "A Real Hero"),
                .init(artist: "Vangelis", title: "Blade Runner Blues"),
                .init(artist: "Perturbator", title: "Future Club"),
                .init(artist: "IC3PEAK", title: "Смерти больше нет"),
                .init(artist: "Gesaffelstein", title: "Pursuit"),
                .init(artist: "Chromatics", title: "Shadow"),
                .init(artist: "Carpenter Brut", title: "Turbo Killer"),
            ]
        ),

        TaskalkaMood(
            id: .lonely, anchor: spot(5, 1),
            word: "про одиночество", title: "Про одиночество",
            note: "Наедине с\u{00A0}собой\u{00A0}— и\u{00A0}это нормально",
            genres: ["драма": 2],
            vetoGenres: ["комедия", "мультфильм", "мюзикл", "боевик"],
            keywords: #"\b(одиночеств\w*|одинок\w*|отшельник\w*)\b"#,
            authors: [
                TaskalkaAuthor(query: "Габриэль Гарсиа Маркес", surname: "Маркес"),
                TaskalkaAuthor(query: "Джером Сэлинджер", surname: "Сэлинджер"),
                TaskalkaAuthor(query: "Альбер Камю", surname: "Камю"),
            ],
            tracks: [
                .init(artist: "Green Day", title: "Boulevard Of Broken Dreams"),
                .init(artist: "Radiohead", title: "How To Disappear Completely"),
                .init(artist: "Moby", title: "Why Does My Heart Feel So Bad?"),
                .init(artist: "Billie Eilish", title: "lovely"),
                .init(artist: "Кино", title: "Спокойная ночь"),
                .init(artist: "Lewis Capaldi", title: "Someone You Loved"),
                .init(artist: "Elvis Presley", title: "Are You Lonesome Tonight?"),
                .init(artist: "Кино", title: "Пачка сигарет"),
                .init(artist: "Akon", title: "Lonely"),
            ]
        ),

        TaskalkaMood(
            id: .thoughtful, anchor: spot(5, 2),
            word: "на подумать", title: "На подумать",
            note: "Мозги на\u{00A0}медленном огне",
            genres: ["драма": 2, "фантастика": 2, "документальный": 1],
            vetoGenres: ["комедия", "боевик", "мюзикл", "ужасы"],
            authors: [
                TaskalkaAuthor(query: "Герман Гессе", surname: "Гессе"),
                TaskalkaAuthor(query: "Лев Толстой", surname: "Толстой"),
                TaskalkaAuthor(query: "Марк Аврелий", surname: "Аврелий"),
            ],
            tracks: [
                .init(artist: "Pink Floyd", title: "Wish You Were Here"),
                .init(artist: "Radiohead", title: "Daydreaming"),
                .init(artist: "Johann Johannsson", title: "Flight from the City"),
                .init(artist: "Кино", title: "Кукушка"),
                .init(artist: "Bon Iver", title: "Holocene"),
                .init(artist: "Brian Eno", title: "By This River"),
                .init(artist: "ДДТ", title: "Это всё"),
                .init(artist: "Sufjan Stevens", title: "Mystery of Love"),
                .init(artist: "Agnes Obel", title: "Riverside"),
            ]
        ),

        TaskalkaMood(
            id: .dreamy, anchor: spot(5, 3),
            word: "не от мира сего", title: "Не от мира сего",
            note: "Витать в\u{00A0}облаках\u{00A0}— разрешается",
            genres: ["фэнтези": 3, "мультфильм": 2, "мелодрама": 1, "фантастика": 1],
            vetoGenres: ["ужасы", "криминал", "военный", "триллер"],
            authors: [
                TaskalkaAuthor(query: "Александр Грин", surname: "Грин"),
                TaskalkaAuthor(query: "Антуан де Сент-Экзюпери", surname: "Экзюпери"),
                TaskalkaAuthor(query: "Льюис Кэрролл", surname: "Кэрролл"),
            ],
            tracks: [
                .init(artist: "Beach House", title: "Space Song"),
                .init(artist: "M83", title: "Wait"),
                .init(artist: "Tame Impala", title: "Let It Happen"),
                .init(artist: "Земфира", title: "Небомореоблака"),
                .init(artist: "Air", title: "La femme d'argent"),
                .init(artist: "Washed Out", title: "Amor Fati"),
                .init(artist: "Slowdive", title: "Alison"),
                .init(artist: "Mac DeMarco", title: "Chamber Of Reflection"),
                .init(artist: "Cocteau Twins", title: "Cherry-coloured Funk"),
            ]
        ),

        TaskalkaMood(
            id: .tender, anchor: spot(5, 4),
            word: "понежнее", title: "Понежнее",
            note: "Как обнимашки, только в\u{00A0}наушниках",
            genres: ["мелодрама": 3, "семейный": 1, "драма": 1],
            vetoGenres: ["ужасы", "боевик", "криминал", "военный", "триллер"],
            authors: [
                TaskalkaAuthor(query: "Фредрик Бакман", surname: "Бакман"),
                TaskalkaAuthor(query: "Франсуаза Саган", surname: "Саган"),
                TaskalkaAuthor(query: "Николас Спаркс", surname: "Спаркс"),
            ],
            tracks: [
                .init(artist: "Iron & Wine", title: "Such Great Heights"),
                .init(artist: "Damien Rice", title: "The Blower's Daughter"),
                .init(artist: "Jeff Buckley", title: "Hallelujah"),
                .init(artist: "Сплин", title: "Мое сердце"),
                .init(artist: "Corinne Bailey Rae", title: "Put Your Records On"),
                .init(artist: "Coldplay", title: "Yellow"),
                .init(artist: "Nat King Cole", title: "Unforgettable"),
                .init(artist: "José González", title: "Heartbeats"),
                .init(artist: "Leon Bridges", title: "River"),
            ]
        ),

        TaskalkaMood(
            id: .sea, anchor: spot(5, 5),
            word: "про море", title: "Про море",
            note: "Солёный ветер и\u{00A0}шум прибоя",
            genres: ["приключения": 1, "драма": 1, "семейный": 1, "мультфильм": 1],
            vetoGenres: ["ужасы"],
            keywords: #"\b(мор[еяю]|морск\w*|океан\w*|корабл\w*|пират\w*|моряк\w*|подводн\w*|пляж\w*|остров\w*)\b"#,
            authors: [
                TaskalkaAuthor(query: "Константин Станюкович", surname: "Станюкович"),
                TaskalkaAuthor(query: "Герман Мелвилл", surname: "Мелвилл"),
                TaskalkaAuthor(query: "Жюль Верн", surname: "Верн"),
            ],
            tracks: [
                .init(artist: "Otis Redding", title: "(Sittin' On) The Dock Of The Bay"),
                .init(artist: "Mumiy Troll", title: "Дельфины"),
                .init(artist: "The Beach Boys", title: "Sloop John B"),
                .init(artist: "Bobby Darin", title: "Beyond The Sea"),
                .init(artist: "Christopher Cross", title: "Sailing"),
                .init(artist: "Florence + The Machine", title: "Ship To Wreck"),
                .init(artist: "Cesária Evora", title: "Sodade"),
                .init(artist: "Fleetwood Mac", title: "Albatross"),
                .init(artist: "The Drifters", title: "Under The Boardwalk"),
            ]
        ),

        // MARK: Ряд 6 — медленно

        TaskalkaMood(
            id: .melancholic, anchor: spot(6, 0),
            word: "под дождь", title: "Под дождь",
            note: "Даже если за\u{00A0}окном сухо",
            genres: ["драма": 3, "мелодрама": 1],
            vetoGenres: ["комедия", "боевик", "мультфильм", "семейный", "ужасы"],
            authors: [
                TaskalkaAuthor(query: "Франц Кафка", surname: "Кафка"),
                TaskalkaAuthor(query: "Альбер Камю", surname: "Камю"),
                TaskalkaAuthor(query: "Иван Бунин", surname: "Бунин"),
            ],
            tracks: [
                .init(artist: "Sigur Rós", title: "Hoppípolla"),
                .init(artist: "Portishead", title: "Roads"),
                .init(artist: "Mazzy Star", title: "Fade Into You"),
                .init(artist: "Сплин", title: "Романс"),
                .init(artist: "Radiohead", title: "Exit Music (For A Film)"),
                .init(artist: "Lana Del Rey", title: "Summertime Sadness"),
                .init(artist: "Cigarettes After Sex", title: "Apocalypse"),
                .init(artist: "Наутилус Помпилиус", title: "Я хочу быть с тобой"),
                .init(artist: "The National", title: "About Today"),
            ]
        ),

        TaskalkaMood(
            id: .life, anchor: spot(6, 1),
            word: "про жизнь", title: "Про жизнь",
            note: "Без прикрас, зато честно",
            genres: ["драма": 3, "биография": 2],
            vetoGenres: ["фантастика", "фэнтези", "ужасы", "мультфильм", "боевик"],
            authors: [
                TaskalkaAuthor(query: "Сергей Довлатов", surname: "Довлатов"),
                TaskalkaAuthor(query: "Людмила Улицкая", surname: "Улицкая"),
                TaskalkaAuthor(query: "Дина Рубина", surname: "Рубина"),
            ],
            tracks: [
                .init(artist: "Vladimir Vysotsky", title: "Кони привередливые"),
                .init(artist: "Johnny Cash", title: "Hurt"),
                .init(artist: "Земфира", title: "Жить в твоей голове"),
                .init(artist: "Чайф", title: "Не спеши"),
                .init(artist: "Bob Dylan", title: "Like a Rolling Stone"),
                .init(artist: "Simon & Garfunkel", title: "The Sound of Silence"),
                .init(artist: "ДДТ", title: "Родина"),
                .init(artist: "Fleetwood Mac", title: "Landslide"),
                .init(artist: "Сплин", title: "Орбит без сахара"),
            ]
        ),

        TaskalkaMood(
            id: .music, anchor: spot(6, 2),
            word: "про музыку", title: "Про музыку",
            note: "Про тех, кто сделал музыку",
            genres: ["музыка": 3, "мюзикл": 2, "биография": 1],
            vetoGenres: ["ужасы", "военный"],
            authors: [
                TaskalkaAuthor(query: "Артемий Троицкий", surname: "Троицкий"),
                TaskalkaAuthor(query: "Патти Смит", surname: "Патти"),
                TaskalkaAuthor(query: "Михаил Козырев", surname: "Козырев"),
            ],
            tracks: [
                .init(artist: "ABBA", title: "Thank You For The Music"),
                .init(artist: "Madonna", title: "Music"),
                .init(artist: "Queen", title: "Radio Ga Ga"),
                .init(artist: "The Buggles", title: "Video Killed The Radio Star"),
                .init(artist: "Мираж", title: "Музыка нас связала"),
                .init(artist: "John Miles", title: "Music"),
                .init(artist: "Dire Straits", title: "Sultans Of Swing"),
                .init(artist: "Billy Joel", title: "Piano Man"),
                .init(artist: "KISS", title: "Rock And Roll All Nite"),
            ]
        ),

        TaskalkaMood(
            id: .road, anchor: spot(6, 3),
            word: "в дорогу", title: "В дорогу",
            note: "Окно открыто, навигатор выключен",
            genres: ["приключения": 3, "комедия": 1, "драма": 1],
            vetoGenres: ["ужасы", "военный", "мультфильм"],
            keywords: #"\b(дорог\w*|путешеств\w*|трасс\w*|автостоп\w*|поездк\w*)\b"#,
            authors: [
                TaskalkaAuthor(query: "Джек Керуак", surname: "Керуак"),
                TaskalkaAuthor(query: "Пауло Коэльо", surname: "Коэльо"),
                TaskalkaAuthor(query: "Иван Гончаров", surname: "Гончаров"),
            ],
            tracks: [
                .init(artist: "Tom Petty", title: "Free Fallin'"),
                .init(artist: "Fleetwood Mac", title: "Dreams"),
                .init(artist: "Eagles", title: "Hotel California"),
                .init(artist: "The War On Drugs", title: "Under The Pressure"),
                .init(artist: "Земфира", title: "ариведерчи"),
                .init(artist: "Наутилус Помпилиус", title: "Прогулки по воде"),
                .init(artist: "Bruce Springsteen", title: "Born to Run"),
                .init(artist: "America", title: "A Horse With No Name"),
                .init(artist: "Toto", title: "Africa"),
            ]
        ),

        TaskalkaMood(
            id: .kind, anchor: spot(6, 4),
            word: "доброго", title: "Доброе",
            note: "Чтобы вера в\u{00A0}людей вернулась",
            genres: ["семейный": 2, "комедия": 2, "драма": 1, "мелодрама": 1],
            vetoGenres: ["ужасы", "триллер", "криминал", "военный", "боевик"],
            authors: [
                TaskalkaAuthor(query: "Элинор Портер", surname: "Портер"),
                TaskalkaAuthor(query: "Виктор Драгунский", surname: "Драгунский"),
                TaskalkaAuthor(query: "Фэнни Флэгг", surname: "Флэгг"),
            ],
            tracks: [
                .init(artist: "Israel Kamakawiwo", title: "Over the Rainbow"),
                .init(artist: "The Beatles", title: "All You Need Is Love"),
                .init(artist: "Bill Withers", title: "Lean On Me"),
                .init(artist: "Bobby McFerrin", title: "Don't Worry Be Happy"),
                .init(artist: "Ёлка", title: "Около тебя"),
                .init(artist: "Jack Johnson", title: "Upside Down"),
                .init(artist: "Coldplay", title: "Fix You"),
                .init(artist: "Lenka", title: "Everything At Once"),
                .init(artist: "The Turtles", title: "Happy Together"),
            ]
        ),

        TaskalkaMood(
            id: .nature, anchor: spot(6, 5),
            word: "на природе", title: "На природе",
            note: "Птички поют, вайфай не\u{00A0}ловит",
            genres: ["документальный": 3, "приключения": 1, "семейный": 1],
            vetoGenres: ["ужасы", "криминал", "триллер", "военный"],
            keywords: #"\b(природ\w*|лес|леса|лесу|лесн\w*|животн\w*|тайг\w*|джунгл\w*)\b"#,
            authors: [
                TaskalkaAuthor(query: "Виталий Бианки", surname: "Бианки"),
                TaskalkaAuthor(query: "Эрнест Сетон-Томпсон", surname: "Сетон"),
                TaskalkaAuthor(query: "Генри Дэвид Торо", surname: "Торо"),
            ],
            tracks: [
                .init(artist: "Fleet Foxes", title: "White Winter Hymnal"),
                .init(artist: "Mumford & Sons", title: "The Cave"),
                .init(artist: "Мельница", title: "Ночная кобыла"),
                .init(artist: "Of Monsters and Men", title: "Little Talks"),
                .init(artist: "Nick Drake", title: "Pink Moon"),
                .init(artist: "Novo Amor", title: "Anchor"),
                .init(artist: "John Denver", title: "Take Me Home, Country Roads"),
                .init(artist: "The Lumineers", title: "Ho Hey"),
                .init(artist: "Ludovico Einaudi", title: "Experience"),
            ]
        ),

        // MARK: Ряд 7 — тихо

        TaskalkaMood(
            id: .winter, anchor: spot(7, 0),
            word: "про зиму", title: "Про зиму",
            note: "Снег за\u{00A0}окном, какао в\u{00A0}руках",
            genres: ["семейный": 1, "комедия": 1, "мелодрама": 1, "драма": 1],
            vetoGenres: ["военный"],
            keywords: #"\b(зим[аеуыо]\w*|зимн\w*|снег\w*|снеж\w*|мороз\w*|рождеств\w*|новогодн\w*|льд\w*)\b"#,
            authors: [
                TaskalkaAuthor(query: "Николай Гоголь", surname: "Гоголь"),
                TaskalkaAuthor(query: "Ганс Христиан Андерсен", surname: "Андерсен"),
                TaskalkaAuthor(query: "Джек Лондон", surname: "Лондон"),
            ],
            tracks: [
                .init(artist: "Frank Sinatra", title: "Let It Snow! Let It Snow! Let It Snow!"),
                .init(artist: "Simon & Garfunkel", title: "A Hazy Shade Of Winter"),
                .init(artist: "Max Richter", title: "Winter 1"),
                .init(artist: "Coldplay", title: "Christmas Lights"),
                .init(artist: "Low", title: "Just Like Christmas"),
                .init(artist: "Daughter", title: "Winter"),
                .init(artist: "Иванушки International", title: "Снегири"),
                .init(artist: "Tori Amos", title: "Winter"),
                .init(artist: "Frank Sinatra", title: "The Christmas Waltz"),
            ]
        ),

        TaskalkaMood(
            id: .oldies, anchor: spot(7, 1),
            word: "старого доброго", title: "Старое доброе",
            note: "Классика, которая не\u{00A0}стареет",
            genres: ["комедия": 1, "драма": 1, "мелодрама": 1, "приключения": 1],
            vetoGenres: ["ужасы"],
            maxYear: 1985,
            authors: [
                TaskalkaAuthor(query: "Илья Ильф", surname: "Ильф"),
                TaskalkaAuthor(query: "Михаил Булгаков", surname: "Булгаков"),
                TaskalkaAuthor(query: "Антон Чехов", surname: "Чехов"),
            ],
            tracks: [
                .init(artist: "The Beatles", title: "Yesterday"),
                .init(artist: "Elvis Presley", title: "Love Me Tender"),
                .init(artist: "Муслим Магомаев", title: "Свадьба"),
                .init(artist: "Алла Пугачёва", title: "Миллион алых роз"),
                .init(artist: "Chuck Berry", title: "Johnny B. Goode"),
                .init(artist: "Ray Charles", title: "Hit The Road Jack"),
                .init(artist: "Ella Fitzgerald", title: "Summertime"),
                .init(artist: "Валерий Ободзинский", title: "Восточная песня"),
                .init(artist: "Frank Sinatra", title: "Strangers In The Night"),
            ]
        ),

        TaskalkaMood(
            id: .meditate, anchor: spot(7, 2),
            word: "для медитации", title: "Для медитации",
            note: "Вдох. Выдох. Ничего не\u{00A0}надо",
            genres: ["документальный": 3],
            vetoGenres: ["ужасы", "боевик", "триллер", "криминал", "военный"],
            authors: [
                TaskalkaAuthor(query: "Экхарт Толле", surname: "Толле"),
                TaskalkaAuthor(query: "Тик Нат Хан", surname: "Нат"),
                TaskalkaAuthor(query: "Генри Дэвид Торо", surname: "Торо"),
            ],
            tracks: [
                .init(artist: "Brian Eno", title: "1/1"),
                .init(artist: "Hiroshi Yoshimura", title: "Water Copy"),
                .init(artist: "Jon Hopkins", title: "Immunity"),
                .init(artist: "Hammock", title: "Breathturn"),
                .init(artist: "Brian Eno", title: "Discreet Music"),
                .init(artist: "Ólafur Arnalds", title: "Fyrsta"),
                .init(artist: "Steve Roach", title: "Structures From Silence"),
                .init(artist: "Harold Budd", title: "The Pearl"),
                .init(artist: "Stars Of The Lid", title: "Requiem For Dying Mothers"),
            ]
        ),

        TaskalkaMood(
            id: .coffee, anchor: spot(7, 3),
            word: "под кофе", title: "Под кофе",
            note: "Чашка, плейлист и\u{00A0}никакой спешки",
            genres: ["мелодрама": 1, "комедия": 1, "драма": 1],
            vetoGenres: ["ужасы", "военный", "боевик"],
            keywords: #"\b(кофе\w*|кафе|кофейн\w*|бариста|закусочн\w*)\b"#,
            authors: [
                TaskalkaAuthor(query: "Харуки Мураками", surname: "Мураками"),
                TaskalkaAuthor(query: "Дина Рубина", surname: "Рубина"),
                TaskalkaAuthor(query: "Сергей Довлатов", surname: "Довлатов"),
            ],
            tracks: [
                .init(artist: "Astrud Gilberto", title: "Corcovado"),
                .init(artist: "Diana Krall", title: "The Look Of Love"),
                .init(artist: "Ella Fitzgerald", title: "Black Coffee"),
                .init(artist: "Bob Dylan", title: "One More Cup Of Coffee"),
                .init(artist: "Peggy Lee", title: "Black Coffee"),
                .init(artist: "Madeleine Peyroux", title: "Dance Me To The End Of Love"),
                .init(artist: "Gregory Porter", title: "Liquid Spirit"),
                .init(artist: "Melody Gardot", title: "Baby I'm A Fool"),
                .init(artist: "Jamie Cullum", title: "These Are The Days"),
            ]
        ),

        TaskalkaMood(
            id: .weekend, anchor: spot(7, 4),
            word: "на выходные", title: "На выходные",
            note: "Будильник выключен до\u{00A0}понедельника",
            genres: ["комедия": 2, "приключения": 1, "семейный": 1, "фантастика": 1],
            vetoGenres: ["ужасы", "военный"],
            authors: [
                TaskalkaAuthor(query: "Джоджо Мойес", surname: "Мойес"),
                TaskalkaAuthor(query: "Фредрик Бакман", surname: "Бакман"),
                TaskalkaAuthor(query: "Терри Пратчетт", surname: "Пратчетт"),
            ],
            tracks: [
                .init(artist: "Bruno Mars", title: "The Lazy Song"),
                .init(artist: "Loverboy", title: "Working For The Weekend"),
                .init(artist: "Katy Perry", title: "Last Friday Night (T.G.I.F.)"),
                .init(artist: "The Cure", title: "Friday I'm In Love"),
                .init(artist: "Rebecca Black", title: "Friday"),
                .init(artist: "Calvin Harris", title: "Feel So Close"),
                .init(artist: "MGMT", title: "Electric Feel"),
                .init(artist: "Mac Miller", title: "Weekend"),
                .init(artist: "Bruno Mars", title: "Treasure"),
            ]
        ),

        TaskalkaMood(
            id: .spring, anchor: spot(7, 5),
            word: "про весну", title: "Про весну",
            note: "Всё оживает, и\u{00A0}вы\u{00A0}тоже",
            genres: ["мелодрама": 1, "комедия": 1, "драма": 1],
            vetoGenres: ["ужасы", "военный"],
            keywords: #"\b(весн\w*|весенн\w*|цветени\w*)\b"#,
            authors: [
                TaskalkaAuthor(query: "Иван Тургенев", surname: "Тургенев"),
                TaskalkaAuthor(query: "Иван Бунин", surname: "Бунин"),
                TaskalkaAuthor(query: "Константин Паустовский", surname: "Паустовский"),
            ],
            tracks: [
                .init(artist: "Max Richter", title: "Spring 1"),
                .init(artist: "Vampire Weekend", title: "Harmony Hall"),
                .init(artist: "Kings of Convenience", title: "I'd Rather Dance With You"),
                .init(artist: "Belle and Sebastian", title: "The Boy With The Arab Strap"),
                .init(artist: "Sixpence None The Richer", title: "Kiss Me"),
                .init(artist: "The Cranberries", title: "Dreams"),
                .init(artist: "Simon & Garfunkel", title: "April Come She Will"),
                .init(artist: "ДДТ", title: "Весна"),
                .init(artist: "The Beatles", title: "Good Day Sunshine"),
            ]
        ),

        // MARK: Ряд 8 — самый чилл

        TaskalkaMood(
            id: .latenight, anchor: spot(8, 0),
            word: "на ночь глядя", title: "На ночь глядя",
            note: "Когда все уже спят, а\u{00A0}вам\u{00A0}— нет",
            genres: ["триллер": 1, "драма": 1, "детектив": 1, "ужасы": 1],
            vetoGenres: ["мультфильм", "семейный", "мюзикл"],
            keywords: #"\b(ноч\w*|полноч\w*|ночн\w*)\b"#,
            authors: [
                TaskalkaAuthor(query: "Стивен Кинг", surname: "Кинг"),
                TaskalkaAuthor(query: "Эдгар Аллан По", surname: "Эдгар"),
                TaskalkaAuthor(query: "Нил Гейман", surname: "Гейман"),
            ],
            tracks: [
                .init(artist: "The xx", title: "Intro"),
                .init(artist: "Burial", title: "Archangel"),
                .init(artist: "Beach House", title: "Myth"),
                .init(artist: "Interpol", title: "NYC"),
                .init(artist: "Radiohead", title: "Reckoner"),
                .init(artist: "Angelo Badalamenti", title: "Laura Palmer's Theme"),
                .init(artist: "Chet Faker", title: "Gold"),
                .init(artist: "Cigarettes After Sex", title: "Nothing's Gonna Hurt You Baby"),
                .init(artist: "Agnes Obel", title: "Familiar"),
            ]
        ),

        TaskalkaMood(
            id: .sad, anchor: spot(8, 1),
            word: "до слёз", title: "До слёз",
            note: "Поплакать красиво\u{00A0}— святое",
            genres: ["драма": 3, "военный": 2, "биография": 1],
            vetoGenres: ["комедия", "мультфильм", "семейный", "мюзикл", "боевик"],
            authors: [
                TaskalkaAuthor(query: "Эрих Мария Ремарк", surname: "Ремарк"),
                TaskalkaAuthor(query: "Фёдор Достоевский", surname: "Достоевский"),
                TaskalkaAuthor(query: "Антон Чехов", surname: "Чехов"),
            ],
            tracks: [
                .init(artist: "Adele", title: "Someone Like You"),
                .init(artist: "Radiohead", title: "No Surprises"),
                .init(artist: "Billie Eilish", title: "when the party's over"),
                .init(artist: "Сплин", title: "Выхода нет"),
                .init(artist: "Coldplay", title: "The Scientist"),
                .init(artist: "Земфира", title: "Искала"),
                .init(artist: "Gary Jules", title: "Mad World"),
                .init(artist: "ДДТ", title: "Что такое осень"),
                .init(artist: "Bon Iver", title: "Skinny Love"),
            ]
        ),

        TaskalkaMood(
            id: .calm, anchor: spot(8, 2),
            word: "потише", title: "Потише",
            note: "Пульс 60, уведомления на\u{00A0}беззвучном",
            genres: ["документальный": 3, "биография": 2, "история": 1, "драма": 0.5],
            vetoGenres: ["ужасы", "боевик", "триллер", "криминал"],
            authors: [
                TaskalkaAuthor(query: "Константин Паустовский", surname: "Паустовский"),
                TaskalkaAuthor(query: "Луций Анней Сенека", surname: "Сенека"),
                TaskalkaAuthor(query: "Даниэль Канеман", surname: "Канеман"),
            ],
            tracks: [
                .init(artist: "Ludovico Einaudi", title: "Nuvole Bianche"),
                .init(artist: "Max Richter", title: "On the Nature of Daylight"),
                .init(artist: "Ólafur Arnalds", title: "Saman"),
                .init(artist: "Brian Eno", title: "An Ending (Ascent)"),
                .init(artist: "Nils Frahm", title: "Says"),
                .init(artist: "Yann Tiersen", title: "Comptine d'un autre été"),
                .init(artist: "Bonobo", title: "Kerala"),
                .init(artist: "Hania Rani", title: "Eden"),
                .init(artist: "Tycho", title: "Awake"),
            ]
        ),

        TaskalkaMood(
            id: .bedtime, anchor: spot(8, 3),
            word: "перед сном", title: "Перед сном",
            note: "Глаза слипаются\u{00A0}— и\u{00A0}правильно",
            genres: ["мультфильм": 3, "семейный": 2, "фэнтези": 2],
            vetoGenres: ["ужасы", "триллер", "криминал", "военный", "боевик"],
            authors: [
                TaskalkaAuthor(query: "Ганс Христиан Андерсен", surname: "Андерсен"),
                TaskalkaAuthor(query: "Братья Гримм", surname: "Гримм"),
                TaskalkaAuthor(query: "Шарль Перро", surname: "Перро"),
            ],
            tracks: [
                .init(artist: "Marconi Union", title: "Weightless"),
                .init(artist: "Max Richter", title: "Dream 3"),
                .init(artist: "Ólafur Arnalds", title: "Near Light"),
                .init(artist: "Moby", title: "Porcelain"),
                .init(artist: "Sigur Rós", title: "Samskeyti"),
                .init(artist: "Ludovico Einaudi", title: "Una Mattina"),
                .init(artist: "Nils Frahm", title: "Ambre"),
                .init(artist: "Аида Ведищева", title: "Колыбельная медведицы"),
                .init(artist: "Cigarettes After Sex", title: "Sweet"),
            ]
        ),

        TaskalkaMood(
            id: .cozy, anchor: spot(8, 4),
            word: "под плед", title: "Под плед",
            note: "Чай, носки и\u{00A0}никуда не\u{00A0}надо",
            genres: ["семейный": 3, "мультфильм": 3, "комедия": 1, "фэнтези": 0.5],
            vetoGenres: ["ужасы", "триллер", "криминал", "военный"],
            authors: [
                TaskalkaAuthor(query: "Туве Янссон", surname: "Янссон"),
                TaskalkaAuthor(query: "Марк Твен", surname: "Твен"),
                TaskalkaAuthor(query: "Джеральд Даррелл", surname: "Даррелл"),
            ],
            tracks: [
                .init(artist: "Norah Jones", title: "Don't Know Why"),
                .init(artist: "Jack Johnson", title: "Better Together"),
                .init(artist: "Stan Getz", title: "The Girl from Ipanema"),
                .init(artist: "Louis Armstrong", title: "What a Wonderful World"),
                .init(artist: "Kings of Convenience", title: "Misread"),
                .init(artist: "Chet Baker", title: "I Fall in Love Too Easily"),
                .init(artist: "Vance Joy", title: "Riptide"),
                .init(artist: "Ben Howard", title: "Keep Your Head Up"),
                .init(artist: "Feist", title: "1234"),
            ]
        ),

        TaskalkaMood(
            id: .cats, anchor: spot(8, 5),
            word: "про котиков", title: "Про котиков",
            note: "Мур. Просто мур",
            genres: ["семейный": 1, "комедия": 1, "мультфильм": 1, "драма": 1],
            vetoGenres: ["ужасы"],
            keywords: #"\b(кот|кота|коту|котом|коте|коты|котов|котам|котами|котах|котик\w*|кошк\w*|кошач\w*|кот[её]н\w*)\b"#,
            authors: [
                TaskalkaAuthor(query: "Эрнст Теодор Амадей Гофман", surname: "Гофман"),
                TaskalkaAuthor(query: "Нацумэ Сосэки", surname: "Сосэки"),
                TaskalkaAuthor(query: "Дорис Лессинг", surname: "Лессинг"),
            ],
            tracks: [
                .init(artist: "The Cure", title: "The Lovecats"),
                .init(artist: "Stray Cats", title: "Stray Cat Strut"),
                .init(artist: "Tom Jones", title: "What's New Pussycat?"),
                .init(artist: "Jimmy Smith", title: "The Cat"),
                .init(artist: "Phil Harris", title: "Wants to Be a Cat"),
                .init(artist: "Barbra Streisand", title: "Memory"),
                .init(artist: "Elaine Paige", title: "Memory"),
                .init(artist: "Stray Cats", title: "Rock This Town"),
                .init(artist: "Duke Ellington", title: "Cat Walk"),
            ]
        ),
    ]

    static func with(_ id: ID) -> TaskalkaMood {
        all.first { $0.id == id } ?? center
    }

    /// Середина поля
    static var center: TaskalkaMood {
        all.first { $0.id == .curious } ?? all[0]
    }
}

// MARK: - Карта

/// Чистые функции поля: какое настроение под точкой и какой там цвет. Точка — в долях
/// поля (0…1 по обеим осям), расстояния — в долях **ширины**: поле высокое, и зоны
/// сот обязаны быть круглыми в пунктах, а не вытянутыми вслед за полем. `aspect` —
/// ширина поля к высоте.
enum TaskalkaMap {
    /// Насколько соседнее настроение должно стать ближе текущего, чтобы слово сменилось:
    /// у границы дрожь пальца перебрасывала бы слово и хаптику туда-обратно (~9 pt — зоны теперь в ~62 pt).
    static let hysteresis: CGFloat = 0.025

    private static func distanceSquared(_ point: CGPoint, _ anchor: CGPoint, aspect: CGFloat) -> CGFloat {
        let dx = point.x - anchor.x
        let dy = (point.y - anchor.y) / max(aspect, 0.01)
        return dx * dx + dy * dy
    }

    /// Ближайшее настроение. `current` — то, что уже показано: пока палец у границы зон,
    /// оно держится (`hysteresis`).
    static func mood(at point: CGPoint, current: TaskalkaMood?, aspect: CGFloat) -> TaskalkaMood {
        let nearest = TaskalkaMood.all.min {
            distanceSquared(point, $0.anchor, aspect: aspect) < distanceSquared(point, $1.anchor, aspect: aspect)
        } ?? TaskalkaMood.center
        guard let current, current.id != nearest.id else { return nearest }
        let toNearest = sqrt(distanceSquared(point, nearest.anchor, aspect: aspect))
        let toCurrent = sqrt(distanceSquared(point, current.anchor, aspect: aspect))
        return toNearest + hysteresis < toCurrent ? nearest : current
    }

    /// Цвет поля в точке — непрерывный, по карте цвета (`TaskalkaColorMap`).
    static func color(at point: CGPoint) -> SIMD3<Double> {
        TaskalkaColorMap.rgb(at: point)
    }
}

/// Компоненты цветов палитры — смесь считается в RGB.
enum TaskalkaPalette {
    static func rgb(_ hex: UInt32) -> SIMD3<Double> {
        SIMD3(
            Double((hex >> 16) & 0xFF) / 255,
            Double((hex >> 8) & 0xFF) / 255,
            Double(hex & 0xFF) / 255
        )
    }

    static func color(_ rgb: SIMD3<Double>, opacity: Double = 1) -> Color {
        Color(.sRGB, red: rgb.x, green: rgb.y, blue: rgb.z, opacity: opacity)
    }
}
