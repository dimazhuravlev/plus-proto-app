import SwiftUI
import UIKit
import VariableBlur

// MARK: - Геометрия

/// Числа из `docs/research/figma-moviecard.md` (макет `IKXMroHnoO08WT5W6Rd2bs`,
/// нода `2101:20320`). Холст макета — 393, прототип живёт на 402: по ширине тянется
/// всё, что в макете растягивалось (кавер, полоса меты, колонки оценки, разделители),
/// фиксированные размеры перенесены как есть.
enum MovieLayout {
    // Кавер `I3806:11014;6787:11638`
    /// 393×523.99 — ровно 3:4
    static let coverAspect: CGFloat = 3.0 / 4.0

    // Зеркальное продолжение кавера — макет `2102:15051` (заменил прежнюю полосу
    // «cover bottom blur» 104/88: теперь у картинки есть визуальное продолжение вниз)
    /// Зеркальная копия кадра встык под кавером — **той же высоты, что и кавер**
    /// (правка пользователя 2026-08-25; в макете инстанс 393×300). Одинаковая высота
    /// делает зеркало точной копией кадра: кроп `scaledToFill` совпадает, и шов
    /// сходится по построению.
    static var reflectionHeight: CGFloat { coverHeight }
    /// Полоса затемнения и размытия `cover bottom blur` 393×401: заходит на низ
    /// кавера на 101 (y 423 при шве 524) и накрывает зеркало целиком
    static let reflectionFadeOverlap: CGFloat = 101
    static var reflectionFadeHeight: CGFloat { reflectionFadeOverlap + reflectionHeight }
    /// Пик прогрессив-рампы у низа полосы. Очень большой по прямой просьбе
    /// пользователя (2026-08-25): продолжение должно превращаться в цветовое
    /// пятно задолго до того, как утонет в чёрном. Макетные 28-из-панели (= 14)
    /// оставляли зеркало читаемым.
    static let reflectionBlur: CGFloat = 50
    /// Стоп градиента затемнения: чёрный достигается на этой доле высоты полосы.
    /// В макете 89.9 %; сдвинут раньше — «немного темнее» по просьбе пользователя
    /// (2026-08-25): чем раньше стоп, тем плотнее затемнение по всей полосе.
    static let reflectionGradientEnd: CGFloat = 0.8

    /// Высота кавера — макетные 3:4, и **только** они.
    ///
    /// Раньше она бралась минимумом из 3:4 и того, что оставалось над панелью действий,
    /// чтобы инфо-блок гарантированно помещался на первом экране. Побочно это делало
    /// кадр видео заложником длины лида: у Кинопоиска лид почти всегда длиннее двух
    /// строк, и кавер выходил 443 вместо 536 — пропорция 0.907 вместо 0.75 (замер).
    ///
    /// Теперь наоборот: кадр постоянный, а длинный лид просто опускает всё, что идёт
    /// за ним, ниже. Следствие принято сознательно — при длинном лиде низ инфо-блока
    /// уезжает под градиент панели и до него надо доскроллить.
    static let coverHeight: CGFloat = PlusMetrics.designWidth / coverAspect

    // Шапка `I3806:11014;6787:11641`

    // Инфо-блок `I3806:11014;6787:11640`
    /// Отрицательный gap: инфо наезжает на кавер.
    ///
    /// В макете здесь 40, у нас 80 — правка от 2026-08-23. На кавере теперь чистый
    /// кадр без нанесённого названия, и блоку положено заметно заезжать на него,
    /// а не касаться кромки. Число одно, менять тут же.
    static let infoOverlap: CGFloat = 80
    static let infoLeading: CGFloat = 48
    static let infoTrailing: CGFloat = 16
    static let infoSpacing: CGFloat = 16
    static let infoBottom: CGFloat = 24
    // Прежний `leadInset = 32` («лид уже своего контейнера» из макета) снят —
    // правка пользователя 2026-08-25: правое поле всех текстов аргумента и описания
    // равно общему полю экрана 16, его лиду даёт `infoTrailing`.
    static let metaSpacing: CGFloat = 5
    static let metaDot: CGFloat = 4

    // Пилюля «Смотреть трейлер» из макета удалена решением пользователя 2026-08-25 —
    // вместе с её числами (44/18/22/6/20 и зазором до панели 16).

    // Панель `2101:20595`
    /// Пустая градиентная зона над кнопками
    static let panelLead: CGFloat = 96
    static let panelSide: CGFloat = 24
    static let panelBottom: CGFloat = 24
    static let panelGap: CGFloat = 8
    /// Глубина затемнения под панелью. Ниже таббарных 0.90 и макетных 0.92
    /// сознательно: под панелью фильма едет собственный контент экрана, и он
    /// должен читаться размытым, а не тонуть в черноте.
    static let panelPeak: Double = 0.70
    static let buttonHeight: CGFloat = 56
    static let buttonIconBox: CGFloat = 24
    static let buttonLeading: CGFloat = 22
    static let buttonTrailing: CGFloat = 26
    static let buttonGap: CGFloat = 8
    /// Сколько лента обязана оставить под прибитой панелью
    static var panelClearance: CGFloat { buttonHeight + panelBottom }
    /// Высота затемняющей подложки: чистый градиент над кнопками + сами кнопки + поле
    static var panelHeight: CGFloat { panelLead + buttonHeight + panelBottom }
    /// Блюр начинается от верхней кромки кнопок, а не от верха градиента
    static var panelBlurHeight: CGFloat { buttonHeight + panelBottom }

    // Секции
    /// `header / static` 393×52: padding 16/16/12/16
    static let sectionHeaderTop: CGFloat = 16
    static let sectionHeaderBottom: CGFloat = 12
    static let sectionSide: CGFloat = 16
}

/// Скримы карточки тайтла. Профилей два, и это не небрежность, а два разных места
/// макета: сглаженный на 16 стопов — у панели кнопок и подписей видеокарточек,
/// прямая рампа в два стопа — у верхней шапки. У сглаженного стопы дословные из макета:
/// заменить их линейной интерполяцией значит получить видимый банд.
enum MovieScrim {
    /// Доли альфы от нуля к пику; позиции равномерные, шаг 6.667 %
    private static let profile: [Double] = [
        0, 0.009, 0.036, 0.082, 0.147, 0.232, 0.332, 0.443,
        0.557, 0.668, 0.768, 0.853, 0.918, 0.964, 0.991, 1,
    ]

    /// Прямая рампа: шапка тайтла после тюнинга `2063:10865` идёт именно так —
    /// в дампе заливки ровно два стопа (α 0 → 1) при `opacity` 0.75. Раньше шапка
    /// делила сглаженный профиль с панелью; теперь профили разошлись.
    ///
    /// Оба конца — чёрные, отличаются только альфой: интерполяция от `.clear`
    /// (это чёрный с нулевой альфой у другого цвета) дала бы грязь на светлом кавере.
    static func linear(peak: Double, from start: UnitPoint, to end: UnitPoint) -> LinearGradient {
        LinearGradient(
            colors: [.black.opacity(0), .black.opacity(peak)],
            startPoint: start,
            endPoint: end
        )
    }

    /// `startPoint` — конец с нулевой альфой, `endPoint` — с пиковой
    static func gradient(peak: Double, from start: UnitPoint, to end: UnitPoint) -> LinearGradient {
        LinearGradient(
            stops: profile.enumerated().map { index, share in
                .init(
                    color: .black.opacity(peak * share),
                    location: CGFloat(index) / CGFloat(profile.count - 1)
                )
            },
            startPoint: start,
            endPoint: end
        )
    }
}

// MARK: - Экран

/// Карточка фильма: кавер с зацикленным роликом, инфо-блок с фирменной «ступенькой»
/// слева, закреплённая снизу панель действий и секции под ней.
///
/// Данные живые — `/v1.4/movie/{id}` по id, который витрина положила в `EntityRef`
/// (см. `MovieDetailsStore`). Пока ответ едет и для моковой витрины экран показывает
/// `MovieDetails.placeholder`.
///
/// Навигация у экрана своя (`MovieHeader`), а не общий `EntityNavBar`: кнопки «назад»
/// в макете нет, вместо неё крестик справа, а слева — логотип тайтла.
///
/// Сознательно не делаем (спека §7): индикатор звука трейлера, скелетоны входа,
/// все состояния кнопок кроме дефолтного.
struct MovieScreen: View {
    let entity: EntityRef
    @State private var store = MovieDetailsStore()
    @State private var scrollOffset: CGFloat = 0
    @State private var scrollPosition = ScrollPosition()
    /// Крестик шапки — единственный выход с экрана: кнопки «назад» здесь нет.
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Что показывать прямо сейчас: живые детали, иначе заглушка по названию.
    private var details: MovieDetails {
        store.details ?? .placeholder(title: entity.title, mock: entity.kinopoiskID == nil)
    }

    /// Текст лида — всегда сам аргумент, короткое редакционное описание.
    ///
    /// Раньше при отсутствии логотипа сюда подставлялось название тайтла. Теперь
    /// название показывается на своём месте, текстом в шапке (`MovieHeader`),
    /// и подменять им аргумент незачем: слот аргумента обязан показывать аргумент.
    private var leadText: String {
        details.lead
    }

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    titleBlock
                    // Описание живёт внутри секции видеокарточек, между второй
                    // и третьей, — так оно стоит в макете. Отдельной секцией оно было,
                    // пока карточек не существовало, и показывалось дважды, когда они
                    // появились.
                    //
                    // Секция больше не ждёт данных: содержимое карточек замокировано
                    // (см. `MovieVideoCardMock`), поэтому она есть всегда, а живым
                    // в ней остаётся только описание.
                    MovieVideoSection(
                        paragraphs: details.synopsis,
                        stillURLs: details.cardStills
                    )
                    if !details.cast.isEmpty {
                        MovieCastSection(cast: details.cast)
                    }
                    if !details.rows.isEmpty {
                        MovieDetailsSection(rows: details.rows)
                    }
                    MovieRateSection()
                    if !details.similar.isEmpty {
                        MovieSimilarSection(titles: details.similar)
                    }
                    // Хром приложения на этом экране спрятан, поэтому весь клиренс под
                    // прибитой панелью действий экран добирает сам.
                    Color.clear.frame(height: MovieLayout.panelClearance)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .task { await store.load(entity) }
            .scrollIndicators(.hidden)
            // Экран показан слоем поверх хрома и перекрывает его собой, поэтому
            // поджиматься под него не надо. Инсет приходит по environment из
            // `AppRootView` и доезжает даже в презентацию — снимаем его явно.
            .contentMargins(.bottom, 0, for: .scrollContent)
            // Кавер начинается от физического верха экрана, а не от safe area.
            // Снизу — то же самое: панель прибита к физической кромке, и лента
            // обязана уходить под неё, иначе её клиренс считался бы от безопасной зоны.
            .ignoresSafeArea(edges: [.top, .bottom])
            .scrollPosition($scrollPosition)
            .trackNavBarScroll(into: $scrollOffset)
            #if DEBUG
            // `-debugScrollTo <pt>`: тапнуть и проскроллить экран из шелла нечем,
            // а секции под панелью иначе не сверить с макетом.
            //
            // Прокрутка повторяется, а не делается один раз: на первом кадре лента —
            // это один кавер, прокручивать нечего, и `scrollTo` уходит в пустоту.
            // Секции дорастают по мере ответа `/v1.4/movie/{id}`, а ждать конкретно
            // его нельзя — на моках он не приходит вовсе. Три попытки покрывают оба
            // случая и стоят полторы секунды отладочного запуска.
            //
            // `id:` — чтобы попытки пошли заново, когда детали доехали: приход ответа
            // перестраивает ленту и сбрасывает позицию в ноль, так что прокрутка,
            // сделанная до него, пропадает.
            .task(id: store.details == nil) {
                let offset = UserDefaults.standard.double(forKey: "debugScrollTo")
                guard offset > 0 else { return }
                for _ in 0..<10 {
                    try? await Task.sleep(for: .milliseconds(700))
                    guard !Task.isCancelled else { return }
                    scrollPosition.scrollTo(y: offset)
                }
            }
            #endif

            MovieHeader(
                logo: details.logo,
                title: entity.title,
                // Тот же сигнал, что открывает инфо-блок: детали доехали, состав
                // логотипа известен. Мок и ошибка сети — сразу текст.
                logoResolved: infoReady,
                scrollOffset: headerScrollOffset
            ) {
                headerActions
            }
        }
        .background(Color.black.ignoresSafeArea())
        .overlay(alignment: .bottom) { MovieMainButtons() }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: Резина кавера

    /// Оттяг вниз. Скролл вверх кавер не трогает — он обычным образом уезжает.
    private var pull: CGFloat { max(0, -scrollOffset) }

    /// Сколько «роста» получает кавер. В жизни равно оттягу; в дебаге к нему
    /// добавляется подставной (`-debugMoviePull <pt>`), а компенсация смещения
    /// (`-pull`) остаётся на реальном: подставной оттяг контент вниз не сдвигал,
    /// и компенсировать ему нечего. Паттерн экрана альбома (`-debugAlbumPull`).
    private var growth: CGFloat {
        #if DEBUG
        pull + CGFloat(UserDefaults.standard.double(forKey: "debugMoviePull"))
        #else
        pull
        #endif
    }

    /// Шапке оттяг нужен для роста логотипа, и в дебаге подставной обязан доехать
    /// и до неё — реального жеста из шелла не сделать. Рампам появления сдвиг не
    /// мешает: на оттяге offset и так меньше нуля, доли стоят в нуле.
    private var headerScrollOffset: CGFloat {
        #if DEBUG
        scrollOffset - CGFloat(UserDefaults.standard.double(forKey: "debugMoviePull"))
        #else
        scrollOffset
        #endif
    }

    // MARK: Шапка

    /// Пара «поделиться» / «закрыть» из макета: в `title / header` они прибиты к правому
    /// верхнему углу и по скроллу не меняются — ровно поведение trailing-слота навбара.
    private var headerActions: some View {
        HStack(spacing: PlusMetrics.circleButtonGap) {
            GlassIconButton(icon: "iconShare", accessibilityTitle: "Поделиться")
            GlassIconButton(icon: "iconCross", accessibilityTitle: "Закрыть") { dismiss() }
        }
    }

    // MARK: Кавер и инфо

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: -MovieLayout.infoOverlap) {
            cover
            info
        }
        .padding(.bottom, MovieLayout.infoBottom)
    }

    private var cover: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: MovieLayout.coverHeight)
            // Кадр задаёт распорка, а картинка его заполняет: `aspectRatio` в скролле
            // считает высоту от идеального размера картинки, а не от пропорции макета.
            .overlay {
                MovieTrailerCover(
                    // Живой тайтл ждёт чистый кадр на сером плейсхолдере; постер
                    // достаётся только мокам — у них кадра из API не будет вовсе.
                    poster: entity.kinopoiskID == nil ? entity.artwork : nil,
                    backdrop: details.backdrop,
                    trailer: details.trailer
                )
            }
            .clipped()
            .overlay(alignment: .bottom) { coverExtension }
            // Резина оттяга — на чистых transform'ах, как на экране альбома: слой
            // компенсирует оттяг `offset(y: -pull)` (контент едет вниз, верхняя кромка
            // кадра стоит на месте), а рост даёт `scaleEffect` с якорем `.top` — низ
            // тянется ровно на величину оттяга и остаётся приклеен к инфо-блоку.
            // Полоса `coverExtension` внутри растягиваемого поддерева сознательно: она
            // обязана ехать вместе с низом кадра, снаружи скейла она отстала бы от него
            // на величину роста. Порядок модификаторов обязателен `scaleEffect → offset`:
            // наоборот скейл умножил бы и компенсирующее смещение (DECISIONS, альбом).
            .scaleEffect((MovieLayout.coverHeight + growth) / MovieLayout.coverHeight, anchor: .top)
            .offset(y: -pull)
    }

    /// Нижние 104pt кавера: чёрный градиент под размытием, нарастающим книзу, — стык
    /// с фоном экрана не должен читаться кромкой.
    ///
    /// Размытие именно прогрессивное, а не равномерное: у равномерного полоса сама
    /// становится кромкой — там, где она начинается, резкость обрывается на ровном
    /// месте. Рампа снимает эту границу тем же приёмом, что подложка таббара
    /// (`TabBarUnderlay`), и в ту же сторону — чисто сверху, максимум снизу.
    /// Продолжение кавера вниз — макет `2102:15051` с правками пользователя от
    /// 2026-08-25: под кадром встык стоит его же зеркальная копия той же высоты,
    /// и одна полоса затемнения с прогрессив-рампой накрывает её целиком, залезая
    /// на низ кадра. Картинка получает визуальное «продолжение», которое по мере
    /// спуска размывается и тонет в чёрном.
    ///
    /// Все слои выровнены низом к низу кавера и сдвинуты вниз оффсетами: overlay
    /// не участвует в раскладке, поэтому зеркало просто лежит под инфо-блоком
    /// (он в VStack позже — рисуется поверх), а его низ тонет в чёрном фоне экрана.
    /// Слой живёт до `scaleEffect` резины — на оттяге тянется вместе с кавером.
    private var coverExtension: some View {
        ZStack(alignment: .bottom) {
            reflection
                .offset(y: MovieLayout.reflectionHeight)

            // Затемнение и прогрессив-рампа — **одной полосой одинаковых габаритов**
            // (правка пользователя 2026-08-25): от низа зеркала через всю его высоту
            // и на `reflectionFadeOverlap` на низ верхнего кадра. Рампа одна на всю
            // полосу — отдельного равномерного блюра у зеркала больше нет, максимум
            // радиуса приходится на самый низ, где всё и так тонет в чёрном.
            Group {
                VariableBlurView(
                    maxBlurRadius: MovieLayout.reflectionBlur,
                    direction: .blurredBottomClearTop
                )

                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0), location: 0),
                        .init(color: .black, location: MovieLayout.reflectionGradientEnd),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .frame(height: MovieLayout.reflectionFadeHeight)
            .offset(y: MovieLayout.reflectionHeight)
        }
        .allowsHitTesting(false)
    }

    /// Зеркальная копия кадра. Источник тот же, что у кавера: чистый кадр из API,
    /// моку — его постер. Живому тайтлу до загрузки кадра зеркала нет — полоса
    /// стоит на чёрном, и появление кадра не дёргает: он почти целиком затемнён.
    ///
    /// Отражение чистое (`scaleEffect(y: -1)`), без горизонтального зеркала: у шва
    /// низ кадра должен непрерывно перетекать в свою копию, пока затемнение слабое.
    @ViewBuilder
    private var reflection: some View {
        let source: ArtworkSource? = details.backdrop.map { .remote($0) }
            ?? (entity.kinopoiskID == nil ? entity.artwork : nil)
        if let source {
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: MovieLayout.reflectionHeight)
                .overlay { ArtworkImage(source: source).scaledToFill() }
                .clipped()
                .scaleEffect(y: -1)
        }
    }

    /// Блок лейбла, аргумента и меты готов к показу: детали доехали.
    /// Мок и тайтл не из Кинопоиска показываются сразу — грузить им нечего;
    /// ошибка сети тоже показывает контент (заглушку деталей) — вечный скелетон хуже.
    private var infoReady: Bool {
        store.details != nil || entity.kinopoiskID == nil || store.failure != nil
    }

    /// Лейбл, аргумент и мета появляются **одномоментно**, когда детали доехали, —
    /// до того стоит скелетон (правка пользователя 2026-08-25: раньше заглушка лида
    /// подменялась настоящим текстом и блок дёргался).
    /// Кроссфейд за `MovieInfoMotion.appear`; обе ветки — дефолтный `.opacity`.
    private var info: some View {
        Group {
            if infoReady {
                infoContent
            } else {
                MovieInfoSkeleton()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, MovieLayout.infoLeading)
        .padding(.trailing, MovieLayout.infoTrailing)
        .animation(reduceMotion ? nil : .easeOut(duration: MovieInfoMotion.appear), value: infoReady)
    }

    private var infoContent: some View {
        VStack(alignment: .leading, spacing: MovieLayout.infoSpacing) {
            // В макете здесь «Editor's choice». Редакционных подборок API не отдаёт,
            // поэтому на этом месте самый сильный реальный факт о тайтле — позиция
            // в топ-250 или оценка Кинопоиска. Нет и его — строки просто нет.
            if let accent = details.accent {
                Text(accent)
                    .plusMovieText()
                    .foregroundStyle(Color.plusAccent)
            }

            // В макете лид — это описание, а название несёт логотип тайтла. Если логотипа
            // у тайтла нет, правило макета отдаёт название текстом: у нас оно занимает
            // именно этот слот, а описание целиком остаётся в секции ниже.
            // Не режется: аргумент Кинопоиска — законченная фраза из двух частей
            // («что происходит» + редакционный вердикт), и обрыв убивает вторую.
            // Под его настоящую длину подобран кегль — см. `MovieLeadType`.
            Text(leadText)
                .plusMovieLead()
                .foregroundStyle(Color.fillOne)
                // Контейнер лида — вся колонка инфо-блока, до общего правого поля 16.
                // Без растяжки блок кончался бы там, где кончилась самая длинная
                // строка, и его правый край гулял бы от тайтла к тайтлу.
                .frame(maxWidth: .infinity, alignment: .leading)

            if !details.meta.isEmpty { meta }
        }
    }

    private var meta: some View {
        HStack(spacing: MovieLayout.metaSpacing) {
            ForEach(Array(details.meta.enumerated()), id: \.offset) { index, item in
                if index > 0 {
                    // Fill/Seven — разделитель встречается только здесь, токен не заводим
                    Circle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: MovieLayout.metaDot, height: MovieLayout.metaDot)
                }
                Text(item)
                    .plusMovieText()
                    .foregroundStyle(Color.fillSubtitle)
            }
        }
        .lineLimit(1)
    }

}

// MARK: - Скелетон инфо-блока

enum MovieInfoMotion {
    /// Кроссфейд «скелетон → контент» — 150мс по просьбе пользователя (2026-08-25)
    static let appear: Double = 0.15
}

/// Скелетон на месте лейбла, аргумента, меты и кнопки трейлера — макет `2097:13780`:
/// пять полос аргумента высотой 24 с шагом 32 (ширины 214/264/264/216/214) и две
/// полосы меты высотой 16 (40 и 80, зазор 12). Заливка — `Fill/Nine`, углы прямые —
/// по рендеру макета (тип ноды скруглённый, но радиус нулевой). Полос лейбла и
/// трейлера в макете нет — после загрузки блок подрастает, это сознательно.
private struct MovieInfoSkeleton: View {
    private enum Layout {
        static let leadWidths: [CGFloat] = [214, 264, 264, 216, 214]
        static let leadBarHeight: CGFloat = 24
        static let leadGap: CGFloat = 8
        /// Полосы стоят по центрам строк лида: (32 − 24) / 2. С полем сумма высот —
        /// ровно пять строк лида, стык «скелетон → контент» не прыгает по вертикали.
        static let leadInset: CGFloat = 4
        static let metaWidths: [CGFloat] = [40, 80]
        static let metaBarHeight: CGFloat = 16
        static let metaGap: CGFloat = 12
        /// Та же центровка в строке меты высотой 20
        static let metaInset: CGFloat = 2
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MovieLayout.infoSpacing) {
            VStack(alignment: .leading, spacing: Layout.leadGap) {
                ForEach(Layout.leadWidths.indices, id: \.self) { index in
                    bar(width: Layout.leadWidths[index], height: Layout.leadBarHeight)
                }
            }
            .padding(.vertical, Layout.leadInset)

            HStack(spacing: Layout.metaGap) {
                ForEach(Layout.metaWidths.indices, id: \.self) { index in
                    bar(width: Layout.metaWidths[index], height: Layout.metaBarHeight)
                }
            }
            .padding(.vertical, Layout.metaInset)
        }
        .accessibilityLabel("Загрузка")
    }

    private func bar(width: CGFloat, height: CGFloat) -> some View {
        Rectangle()
            .fill(Color.fillNine)
            .frame(width: width, height: height)
    }
}

// MARK: - Панель действий

/// `2101:20595`: Play с акцентным градиентом, «Позже» и круглая загрузка.
///
/// Панель прибита к нижней кромке экрана: поля 24 по бокам и снизу — макетные.
///
/// Градиент и блюр — **той же формы, что у таббара**: `PlusGradient.bottomUnderlay`
/// и прогрессивный `VariableBlurView`. Кривая одна на обе нижние панели приложения,
/// но глубина затемнения своя: 0.70 против таббарных 0.90 и макетных 0.92 — под
/// панелью фильма едет контент самого экрана, и он должен читаться размытым,
/// а не тонуть в черноте.
///
/// Высоты при этом свои, не таббарные: подложка ровно в панель (96 + 56 + 24),
/// а блюр начинается от верхней кромки кнопок (56 + 24), а не от верха градиента.
///
/// Сплошного чёрного под кнопками больше нет. Он появился, когда под панелью стоял
/// хром приложения и сквозь пик 0.92 читался текст описания; теперь экран показывается
/// слоем поверх хрома, и градиент работает так же, как в макете, — до самого низа.
private struct MovieMainButtons: View {
    var body: some View {
        HStack(spacing: MovieLayout.panelGap) {
            playButton
            watchLaterButton
            downloadButton
        }
        .frame(height: MovieLayout.buttonHeight)
        .padding(.horizontal, MovieLayout.panelSide)
        .padding(.bottom, MovieLayout.panelBottom)
        .background(alignment: .bottom) { scrim }
        // Поле снизу отмеряется от физической кромки экрана, а не от безопасной зоны:
        // в макете оно равно боковому. Одного `ignoresSafeArea` мало — выравнивание
        // оверлея всё равно считается по безопасной зоне родителя, поэтому панель
        // разворачивается на всю высоту и прижимается к низу уже внутри себя.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .ignoresSafeArea(edges: .bottom)
    }

    private var scrim: some View {
        ZStack(alignment: .bottom) {
            VariableBlurView(
                maxBlurRadius: PlusChromeMetrics.underlayBlurRadius,
                direction: .blurredBottomClearTop
            )
            .frame(height: MovieLayout.panelBlurHeight)

            PlusGradient.bottomUnderlay(peak: MovieLayout.panelPeak)
                .frame(height: MovieLayout.panelHeight)
        }
        .allowsHitTesting(false)
    }

    private var playButton: some View {
        Button {} label: {
            label(icon: "iconPlay", title: "Смотреть")
            .frame(maxWidth: .infinity)
            .frame(height: MovieLayout.buttonHeight)
            .background(MoviePlayGradient.fill, in: Capsule(style: .continuous))
        }
        .buttonStyle(PressScaleButtonStyle())
    }

    private var watchLaterButton: some View {
        Button {} label: {
            label(icon: "iconBookmark", title: "Позже")
            .frame(height: MovieLayout.buttonHeight)
            .glassSurface(
                Capsule(style: .continuous),
                blur: PlusMetrics.buttonBlur,
                border: .clear,
                borderWidth: 0
            )
        }
        .buttonStyle(PressScaleButtonStyle())
    }

    private var downloadButton: some View {
        Button {} label: {
            MovieIcon(name: "iconDownload", box: MovieLayout.buttonIconBox)
            .frame(width: MovieLayout.buttonHeight, height: MovieLayout.buttonHeight)
            .glassSurface(Circle(), blur: PlusMetrics.buttonBlur, border: .clear, borderWidth: 0)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel("Скачать")
    }

    private func label(icon: String, title: String) -> some View {
        HStack(spacing: MovieLayout.buttonGap) {
            MovieIcon(name: icon, box: MovieLayout.buttonIconBox)
            Text(title)
                .plusMovieTextBold()
                .foregroundStyle(Color.fillOne)
                .fixedSize()
        }
        .padding(.leading, MovieLayout.buttonLeading)
        .padding(.trailing, MovieLayout.buttonTrailing)
    }
}

/// `Gradients/Yango/Accent` — единственная цветная заливка экрана.
/// CSS из Figma: `linear-gradient(122.13deg, #A332FF 66.8 %, #D633FF 90 %)`.
/// Ручки переведены в unit-space бокса макета 110×56 — так же, как их хранит сама Figma,
/// поэтому при растяжении кнопки градиент скашивается ровно как в макете.
private enum MoviePlayGradient {
    static let fill = LinearGradient(
        stops: [
            .init(color: Color(red: 163 / 255, green: 50 / 255, blue: 255 / 255), location: 0.668),
            .init(color: Color(red: 214 / 255, green: 51 / 255, blue: 255 / 255), location: 0.900),
        ],
        startPoint: UnitPoint(x: 0.027, y: -0.083),
        endPoint: UnitPoint(x: 0.973, y: 1.083)
    )
}

// MARK: - Иконка

/// Иконка экрана в боксе макета. Отдельного размера листа больше нет: ассеты приходят
/// из ДС на едином холсте 16×16 с уже запечёнными полями, поэтому картинка просто
/// растягивается в бокс, а оптические сдвиги (у play лист смещён вправо) живут внутри
/// самого вектора — ровно как в Figma.
struct MovieIcon: View {
    let name: String
    let box: CGFloat

    var body: some View {
        Image(name)
            .renderingMode(.template)
            .resizable()
            .frame(width: box, height: box)
            .foregroundStyle(Color.fillOne)
    }
}
