import SwiftUI
import UIKit

// MARK: - Геометрия

/// Числа из `docs/research/figma-moviecard.md` (макет `IKXMroHnoO08WT5W6Rd2bs`,
/// нода `2101:20320`). Холст макета — 393, прототип живёт на 402: по ширине тянется
/// всё, что в макете растягивалось (кавер, полоса меты, колонки оценки, разделители),
/// фиксированные размеры перенесены как есть.
enum MovieLayout {
    // Кавер `I3806:11014;6787:11638`
    /// 393×523.99 — ровно 3:4
    static let coverAspect: CGFloat = 3.0 / 4.0
    /// «cover bottom blur» 393×104, прижат к низу кавера
    static let coverFadeHeight: CGFloat = 104
    /// BACKGROUND_BLUR 10 в панели Figma = 5 в единицах проекта (см. GlassSurface)
    static let coverFadeBlur: CGFloat = 5

    /// Высота кавера — макетные 3:4, если инфо-блок под ним успевает закончиться
    /// **над градиентом** панели действий; иначе кавер ужимается ровно настолько,
    /// чтобы он там поместился.
    ///
    /// Расходимся именно с градиентом, а не с рядом кнопок: в макете пилюля «Смотреть
    /// трейлер» яркая и читается целиком, а пик скрима 0.92 съедает её больше чем
    /// наполовину (замер: пик текста падал 255 → 117). Экран прототипа выше макетного,
    /// и лишнюю высоту правильнее отдать каверу до его макетных 3:4, а не задвинуть
    /// инфо-блок под панель.
    static func coverHeight(lead: String) -> CGFloat {
        min(
            PlusMetrics.designWidth / coverAspect,
            panelRowTop - panelLead - infoHeight(lead: lead) + infoOverlap
        )
    }

    // Шапка `I3806:11014;6787:11641`

    // Инфо-блок `I3806:11014;6787:11640`
    /// Отрицательный gap: инфо наезжает на кавер
    static let infoOverlap: CGFloat = 40
    static let infoLeading: CGFloat = 48
    static let infoTrailing: CGFloat = 16
    static let infoSpacing: CGFloat = 16
    static let infoBottom: CGFloat = 24
    /// Лид уже своего контейнера на 32 — в макете это `padding-right` у текста
    static let leadInset: CGFloat = 32
    static let metaSpacing: CGFloat = 5
    static let metaDot: CGFloat = 4

    /// Ширина колонки лида: холст минус «ступенька» 48, поле 16 и внутренний отступ 32.
    static let leadWidth: CGFloat = PlusMetrics.designWidth - infoLeading - infoTrailing - leadInset

    /// Всё, что инфо-блок занимает помимо лида: лейбл 20 + мета 20 + пилюля и три зазора.
    static let infoWithoutLead: CGFloat = 20 + infoSpacing + infoSpacing + 20 + infoSpacing + trailerHeight

    /// Высота инфо-блока под конкретный лид. Лид не режется, поэтому его высота —
    /// не константа: считаем её замером самой строки (`MovieLeadType`), а не вью.
    /// Это не запрещённое чтение собственного размера — обратной связи нет:
    /// высота лида зависит только от текста и фиксированной ширины колонки.
    static func infoHeight(lead: String) -> CGFloat {
        infoWithoutLead + MovieLeadType.height(of: lead)
    }
    /// Зазор «низ трейлера → верх ряда кнопок» из макета (756 → 772)
    static let trailerToPanelGap: CGFloat = 16

    // Пилюля «Смотреть трейлер»
    static let trailerHeight: CGFloat = 44
    static let trailerLeading: CGFloat = 18
    static let trailerTrailing: CGFloat = 22
    static let trailerGap: CGFloat = 6
    static let trailerIconBox: CGFloat = 20

    // Панель `2101:20595`
    /// Пустая градиентная зона над кнопками
    static let panelLead: CGFloat = 96
    static let panelSide: CGFloat = 24
    static let panelBottom: CGFloat = 24
    static let panelGap: CGFloat = 8
    static let panelPeak: Double = 0.92
    static let buttonHeight: CGFloat = 56
    static let buttonIconBox: CGFloat = 24
    static let buttonLeading: CGFloat = 22
    static let buttonTrailing: CGFloat = 26
    static let buttonGap: CGFloat = 8
    /// Сколько лента обязана оставить под панелью сверх хрома приложения
    static var panelClearance: CGFloat { buttonHeight + panelBottom }

    /// Верх ряда кнопок панели от верха экрана. Экран — константа устройства,
    /// а не замер вью: читать размер вью, от которого зависит её же раскладка, запрещено.
    /// Хрома приложения под панелью на этом экране нет, поэтому его высота не вычитается.
    static var panelRowTop: CGFloat {
        UIScreen.main.bounds.height
            - PlusChromeMetrics.bottomSafeArea
            - panelBottom
            - buttonHeight
    }

    // Секции
    /// `header / static` 393×52: padding 16/16/12/16
    static let sectionHeaderTop: CGFloat = 16
    static let sectionHeaderBottom: CGFloat = 12
    static let sectionSide: CGFloat = 16
}

/// Скрим карточки тайтла: 16 сглаженных стопов чёрного. Профиль один на шапку (пик 0.56)
/// и панель кнопок (пик 0.92) — отличается только пиком и направлением. Линейная
/// интерполяция двумя стопами даёт видимый банд, поэтому стопы дословные из макета.
enum MovieScrim {
    /// Доли альфы от нуля к пику; позиции равномерные, шаг 6.667 %
    private static let profile: [Double] = [
        0, 0.009, 0.036, 0.082, 0.147, 0.232, 0.332, 0.443,
        0.557, 0.668, 0.768, 0.853, 0.918, 0.964, 0.991, 1,
    ]

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

    /// Что показывать прямо сейчас: живые детали, иначе заглушка по названию.
    private var details: MovieDetails {
        store.details ?? .placeholder(title: entity.title, mock: entity.kinopoiskID == nil)
    }

    /// Текст лида. Если у тайтла нет логотипа, слот лида по правилу макета занимает
    /// название — описание при этом целиком остаётся в секции ниже.
    private var leadText: String {
        details.logo == nil ? entity.title : details.lead
    }

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    titleBlock
                    if !details.synopsis.isEmpty {
                        MovieSynopsisSection(paragraphs: details.synopsis)
                    }
                    if !details.similar.isEmpty {
                        MovieVideoSection(
                            titles: details.similar,
                            paragraphs: Array(details.synopsis.dropFirst())
                        )
                    }
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
            // Кавер начинается от физического верха экрана, а не от safe area
            .ignoresSafeArea(edges: .top)
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
                scrollOffset: scrollOffset,
                coverHeight: MovieLayout.coverHeight(lead: leadText)
            ) {
                headerActions
            }
        }
        .background(Color.black.ignoresSafeArea())
        .overlay(alignment: .bottom) { MovieMainButtons() }
        .toolbar(.hidden, for: .navigationBar)
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
            .frame(height: MovieLayout.coverHeight(lead: leadText))
            // Кадр задаёт распорка, а картинка его заполняет: `aspectRatio` в скролле
            // считает высоту от идеального размера картинки, а не от пропорции макета.
            .overlay {
                MovieTrailerCover(poster: entity.artwork, trailer: details.trailer)
            }
            .clipped()
            .overlay(alignment: .bottom) { coverFade }
    }

    /// Нижние 104pt кавера: чёрный градиент под лёгким размытием — стык с фоном экрана
    /// не должен читаться кромкой.
    private var coverFade: some View {
        ZStack {
            BackdropBlurView(radius: MovieLayout.coverFadeBlur)
            LinearGradient(
                colors: [.black.opacity(0), .black],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .frame(height: MovieLayout.coverFadeHeight)
        .allowsHitTesting(false)
    }

    private var info: some View {
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
                .padding(.trailing, MovieLayout.leadInset)

            if !details.meta.isEmpty { meta }
            trailerButton
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, MovieLayout.infoLeading)
        .padding(.trailing, MovieLayout.infoTrailing)
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

    private var trailerButton: some View {
        Button {} label: {
            HStack(spacing: MovieLayout.trailerGap) {
                MovieIcon(name: "iconTrailer", box: MovieLayout.trailerIconBox)
                Text("Смотреть трейлер")
                    .plusMovieTextBold()
                    .foregroundStyle(Color.fillOne)
            }
            .padding(.leading, MovieLayout.trailerLeading)
            .padding(.trailing, MovieLayout.trailerTrailing)
            .frame(height: MovieLayout.trailerHeight)
            // Заливка без блюра: у этой пилюли в макете нет backdrop-filter
            .background(Capsule(style: .continuous).fill(Color.buttonsPrimary))
        }
        .buttonStyle(PressScaleButtonStyle())
        // У ролика из API есть своё имя («Джентльмены (2019) — Трейлер дублированный») —
        // на пилюле оно не помещается, но озвучить его VoiceOver стоит.
        .accessibilityLabel(details.trailer?.name ?? "Смотреть трейлер")
    }
}

// MARK: - Панель действий

/// `2101:20595`: Play с акцентным градиентом, «Позже» и круглая загрузка.
///
/// В макете панель прибита к нижней кромке экрана, у нас под ней стоит хром приложения —
/// поэтому кнопки подняты на `contentBottomInset`, а градиент **дотянут до физического
/// низа**: если оборвать его на кромке панели, на ленте появится горизонтальный шов.
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
    }

    private var scrim: some View {
        VStack(spacing: 0) {
            // Набор пика — ровно на макетных 96pt чистого градиента над кнопками.
            MovieScrim.gradient(peak: MovieLayout.panelPeak, from: .top, to: .bottom)
                .frame(height: MovieLayout.panelLead)
            // Ниже кнопок — сплошной чёрный. В макете под панелью экрана нет вовсе,
            // а у нас там хром приложения, и сквозь пик 0.92 в полосе между кнопками
            // и action bar всё ещё читался текст описания. Шов 0.92 → 1 на уже
            // затемнённом фоне неразличим.
            Color.black
        }
        .frame(height: MovieMainButtons.scrimHeight)
        // Оверлей прижат к границе safe area, а градиент обязан уйти под home indicator
        .offset(y: PlusChromeMetrics.bottomSafeArea)
        .allowsHitTesting(false)
    }

    private static var scrimHeight: CGFloat {
        MovieLayout.panelLead + MovieLayout.buttonHeight + MovieLayout.panelBottom
            + PlusChromeMetrics.bottomSafeArea
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
