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
/// **Сколько и где.** Тридцать одно, сотами: семь рядов по 4 и 5 мест вперемешку (`spot`).
/// Сперва было 9 (3×3), потом 17 — пользователь дважды просил больше, «чтобы чаще менялись»
/// (2026-10-31). Соседи — в 74 pt по ряду и 83 pt между рядами: слово сменяется за ~40 pt
/// хода пальца в любую сторону. Плотнее — зона уже пальца, и лежащий палец перебрасывал бы
/// слово туда-обратно. Соты, а не сетка: у каждого настроения шесть соседей, а не четыре.
/// Прежние семнадцать остались в своих областях карты, четырнадцать новых встали между
/// ними — уже не только настроения, но и темы и занятия («про космос», «в дорогу»), как
/// у станций волны. Под пальцем — ближайшее настроение (`TaskalkaMap`).
///
/// Подборка — ровно то, что сказано словом («Не врать о контенте»), смеси настроений нет.
/// Непрерывны только цвет и свечение — они плывут за пальцем.
///
/// Цвета — палитра «Моя волна 2026» (`VibePromoStation.palette`): поле красится так же,
/// как станции волны. Янтарь «для подвига» и «в дорогу» — мандарин палитры, сдвинутый
/// к жёлтому приёмом `PromoStationTint` (жёлтого в палитре нет). Цветов меньше, чем
/// настроений: повторяются только у несоседей.
struct TaskalkaMood: Identifiable, Hashable {
    enum ID: String, CaseIterable {
        case tense, energetic, dance, joyful
        case creepy, bold, chase, inspiring, light
        case mysterious, drama, childhood, summer
        case noir, space, curious, romantic, french
        case neon, thoughtful, dreamy, tender
        case melancholic, life, road, kind, nature
        case sad, calm, bedtime, cozy
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
    /// Цвет капли станции волны и её светлая кромка — кромкой пишется слово на тёмном.
    let fill: UInt32
    let rim: UInt32
    /// Жанры Кинопоиска с весами; фильм с жанром из `vetoGenres` не берётся вовсе.
    let genres: [String: Double]
    let vetoGenres: Set<String>
    /// Страны Кинопоиска: непусто — фильм обязан быть оттуда («по-французски»).
    var countries: Set<String> = []
    /// Авторы книг — запросом к Google Books по имени, отбор по фамилии (приём
    /// `BooksHomeCatalog`: тематический поиск по-русски — мусор).
    let authors: [TaskalkaAuthor]
    /// Треки — подборка редакции прототипа: исполнитель и название, Deezer находит их
    /// поиском (`TaskalkaCatalog`).
    let tracks: [TaskalkaTrackSpec]

    var fillColor: Color { Color(hex: fill) }
    var rimColor: Color { Color(hex: rim) }
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
    /// Место в сотах: ряд 0…6 сверху вниз; в чётных рядах четыре места (⅕…⅘ ширины),
    /// в нечётных — пять, сдвинутые на полшага (⅒…⁹⁄₁₀). Шаг по ряду — пятая ширины,
    /// между рядами — седьмая высоты: на поле 370×580 это 74 и 83 pt, соты почти правильные.
    static func spot(_ row: Int, _ slot: Int) -> CGPoint {
        let x = row.isMultiple(of: 2) ? 0.2 * CGFloat(slot + 1) : 0.1 + 0.2 * CGFloat(slot)
        return CGPoint(x: x, y: (CGFloat(row) + 0.5) / 7)
    }

    /// По рядам: сверху вниз, слева направо.
    static let all: [TaskalkaMood] = [
        // MARK: Ряд 0 — самый движ

        TaskalkaMood(
            id: .tense, anchor: spot(0, 0),
            word: "до дрожи", title: "До дрожи",
            note: "Сердце в\u{00A0}пятках, басы в\u{00A0}груди",
            fill: 0xF5002E, rim: 0xFF99AC,
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
            id: .energetic, anchor: spot(0, 1),
            word: "на максималках", title: "На максималках",
            note: "Разгон до\u{00A0}сотки за\u{00A0}три трека",
            fill: 0xF53700, rim: 0xFFB099,
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
            id: .dance, anchor: spot(0, 2),
            word: "на танцпол", title: "На танцпол",
            note: "Каблуки стёрты, соседи в\u{00A0}курсе",
            fill: 0xDB1A7D, rim: 0xF4A4CD,
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
            id: .joyful, anchor: spot(0, 3),
            word: "с приколом", title: "С приколом",
            note: "Смех до\u{00A0}икоты, танцы на\u{00A0}столе",
            fill: 0xF56E00, rim: 0xFFC799,
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

        // MARK: Ряд 1 — движ потише

        TaskalkaMood(
            id: .creepy, anchor: spot(1, 0),
            word: "пострашнее", title: "Пострашнее",
            note: "Свет сегодня не\u{00A0}выключайте",
            fill: 0xBB1ADB, rim: 0xE7A4F4,
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
            fill: 0xF5007C, rim: 0xFF99CD,
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
            fill: 0xF5002E, rim: 0xFF99AC,
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
            fill: 0xF59700, rim: 0xFFDA99,
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
            id: .light, anchor: spot(1, 4),
            word: "без драмы", title: "Без драмы",
            note: "Сплошной кайф, ноль заморочек",
            fill: 0x00C789, rim: 0x00C789,
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
            id: .mysterious, anchor: spot(2, 0),
            word: "с загадкой", title: "С загадкой",
            note: "Туман, шорохи и\u{00A0}подозрительные типы",
            fill: 0x7C35C0, rim: 0xCDAFE9,
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
            id: .drama, anchor: spot(2, 1),
            word: "с драмой", title: "С драмой",
            note: "Страсти кипят, платочки наготове",
            fill: 0xDB1A7D, rim: 0xF4A4CD,
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
            id: .childhood, anchor: spot(2, 2),
            word: "из детства", title: "Из детства",
            note: "Как после школы под\u{00A0}мультики",
            fill: 0x34C03E, rim: 0xAFE9B3,
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
            id: .summer, anchor: spot(2, 3),
            word: "про лето", title: "Про лето",
            note: "Солнце, лёд в\u{00A0}стакане и\u{00A0}никаких дедлайнов",
            fill: 0xF56E00, rim: 0xFFC799,
            genres: ["комедия": 2, "мелодрама": 2, "приключения": 2],
            vetoGenres: ["ужасы", "военный", "триллер", "криминал"],
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

        // MARK: Ряд 3 — середина

        TaskalkaMood(
            id: .noir, anchor: spot(3, 0),
            word: "в стиле нуар", title: "В стиле нуар",
            note: "Дым, дождь и\u{00A0}шляпа набекрень",
            fill: 0x4F6C9B, rim: 0xBBC8DD,
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
            id: .space, anchor: spot(3, 1),
            word: "про космос", title: "Про космос",
            note: "Поехали! Невесомость за\u{00A0}наш счёт",
            fill: 0x160CE8, rim: 0xA29EFA,
            genres: ["фантастика": 3, "документальный": 1],
            vetoGenres: ["мелодрама", "мюзикл"],
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
            id: .curious, anchor: spot(3, 2),
            word: "этакого", title: "Этакое",
            note: "Вслепую, но\u{00A0}со\u{00A0}вкусом",
            fill: 0x5C8E9B, rim: 0xBFD4D9,
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
            id: .romantic, anchor: spot(3, 3),
            word: "про любовь", title: "Про любовь",
            note: "Бабочки в\u{00A0}животе идут в\u{00A0}комплекте",
            fill: 0xDB1A7D, rim: 0xF4A4CD,
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
            id: .french, anchor: spot(3, 4),
            word: "по-французски", title: "По-французски",
            note: "Багет под\u{00A0}мышкой, шансон в\u{00A0}ушах",
            fill: 0xBB1ADB, rim: 0xE7A4F4,
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

        // MARK: Ряд 4 — поспокойнее

        TaskalkaMood(
            id: .neon, anchor: spot(4, 0),
            word: "под неон", title: "Под неон",
            note: "Ночной город, синтезатор и\u{00A0}мокрый асфальт",
            fill: 0xF5007C, rim: 0xFF99CD,
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
            id: .thoughtful, anchor: spot(4, 1),
            word: "на подумать", title: "На подумать",
            note: "Мозги на\u{00A0}медленном огне",
            fill: 0x4F6C9B, rim: 0xBBC8DD,
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
            id: .dreamy, anchor: spot(4, 2),
            word: "не от мира сего", title: "Не от мира сего",
            note: "Витать в\u{00A0}облаках\u{00A0}— разрешается",
            fill: 0x00C7A6, rim: 0x00C7A6,
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
            id: .tender, anchor: spot(4, 3),
            word: "понежнее", title: "Понежнее",
            note: "Как обнимашки, только в\u{00A0}наушниках",
            fill: 0x5035C0, rim: 0xBAAFE9,
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

        // MARK: Ряд 5 — почти чилл

        TaskalkaMood(
            id: .melancholic, anchor: spot(5, 0),
            word: "под дождь", title: "Под дождь",
            note: "Даже если за\u{00A0}окном сухо",
            fill: 0x160CE8, rim: 0xA29EFA,
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
            id: .life, anchor: spot(5, 1),
            word: "про жизнь", title: "Про жизнь",
            note: "Без прикрас, зато честно",
            fill: 0x5C8E9B, rim: 0xBFD4D9,
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
            id: .road, anchor: spot(5, 2),
            word: "в дорогу", title: "В дорогу",
            note: "Окно открыто, навигатор выключен",
            fill: 0xF59700, rim: 0xFFDA99,
            genres: ["приключения": 3, "комедия": 1, "драма": 1],
            vetoGenres: ["ужасы", "военный", "мультфильм"],
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
            id: .kind, anchor: spot(5, 3),
            word: "доброго", title: "Доброе",
            note: "Чтобы вера в\u{00A0}людей вернулась",
            fill: 0xF53700, rim: 0xFFB099,
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
            id: .nature, anchor: spot(5, 4),
            word: "на природе", title: "На природе",
            note: "Птички поют, вайфай не\u{00A0}ловит",
            fill: 0x00C789, rim: 0x00C789,
            genres: ["документальный": 3, "приключения": 1, "семейный": 1],
            vetoGenres: ["ужасы", "криминал", "триллер", "военный"],
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

        // MARK: Ряд 6 — самый чилл

        TaskalkaMood(
            id: .sad, anchor: spot(6, 0),
            word: "до слёз", title: "До слёз",
            note: "Поплакать красиво\u{00A0}— святое",
            fill: 0x0C41E8, rim: 0x9EB4FA,
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
            id: .calm, anchor: spot(6, 1),
            word: "потише", title: "Потише",
            note: "Пульс 60, уведомления на\u{00A0}беззвучном",
            fill: 0x00B2CC, rim: 0x00B2CC,
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
            id: .bedtime, anchor: spot(6, 2),
            word: "перед сном", title: "Перед сном",
            note: "Глаза слипаются\u{00A0}— и\u{00A0}правильно",
            fill: 0x7C35C0, rim: 0xCDAFE9,
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
            id: .cozy, anchor: spot(6, 3),
            word: "под плед", title: "Под плед",
            note: "Чай, носки и\u{00A0}никуда не\u{00A0}надо",
            fill: 0x34C03E, rim: 0xAFE9B3,
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
    /// у границы дрожь пальца перебрасывала бы слово и хаптику туда-обратно (~12 pt).
    static let hysteresis: CGFloat = 0.035

    /// Ширина цветового пятна настроения: на середине между соседями по ряду цвета
    /// смешаны поровну, у центра зоны соседей почти не видно.
    private static let colorSpread: Double = 0.1

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

    /// Цвет поля в точке: гауссова смесь цветов настроений.
    static func color(at point: CGPoint, aspect: CGFloat) -> SIMD3<Double> {
        var sum = SIMD3<Double>(0, 0, 0)
        var total = 0.0
        for mood in TaskalkaMood.all {
            let weight = exp(-Double(distanceSquared(point, mood.anchor, aspect: aspect)) / (colorSpread * colorSpread))
            sum += TaskalkaPalette.rgb(mood.fill) * weight
            total += weight
        }
        return total > 0 ? sum / total : TaskalkaPalette.rgb(TaskalkaMood.center.fill)
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
