import SwiftUI
import UIKit

// MARK: - Заглушки данных

/// Карточку тайтла макет кормит полями, которых в `EntityRef` пока нет: год, жанр,
/// хронометраж, возрастной рейтинг, описание, дорожки. **Это временная заглушка** —
/// как только модель сущности расширится (или экран пойдёт в `KinopoiskService`
/// за деталями), всё отсюда должно уехать в данные.
///
/// Значения намеренно нейтральные: подставлять под живой тайтл выдуманные факты —
/// та же ложь о контенте, из-за которой в блоке «продолжить смотреть» отказались
/// от мокового логотипа (DECISIONS 2026-08-23).
private enum MovieStub {
    static let editorial = "Выбор редакции"
    /// Мета-строка макета: «2025 · comedy · 2 seasons · Egypt · 15+»
    static let meta = ["2024", "драма", "1 ч 58 мин", "16+"]

    /// Абзацы описания — в макете их 1–3, до ~150 символов каждый
    static let synopsis = [
        "Герой возвращается в город, из которого однажды сбежал, и застаёт его совсем другим.",
        "Дальше — история про то, что прошлое не отпускает, пока с ним не поговоришь начистоту.",
    ]

    /// Строки блока «Детали»: лейбл, значение, приглушённое уточнение
    static let details: [MovieDetailRow] = [
        // Лейбл держится в колонке 104pt: «Аудиодорожки» в неё не влезает и переносится
        MovieDetailRow(label: "Аудио", value: "Русский", note: "стерео"),
        MovieDetailRow(label: "Субтитры", value: "Русские", note: nil),
        MovieDetailRow(label: "Качество", value: "4K", note: "HDR"),
        MovieDetailRow(label: "Возраст", value: "16+", note: nil),
    ]
}

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

    /// Высота кавера. В макете это ровно 3:4 (536 на нашей ширине), но там под экраном
    /// нет хрома приложения: action bar и таббар съедают 164pt снизу, и на 3:4 инфо-блок
    /// уезжает под панель действий. Поэтому берём минимум из макетной пропорции и того,
    /// что остаётся над панелью при сохранённом зазоре «трейлер → кнопки» из макета.
    /// На 402×874 выходит 487 — кавер 1:1.21 вместо 1:1.33, остальные отношения макета целы.
    static var coverHeight: CGFloat {
        min(
            PlusMetrics.designWidth / coverAspect,
            panelRowTop - trailerToPanelGap - infoHeight + infoOverlap
        )
    }

    // Шапка `I3806:11014;6787:11641`
    static let headerScrimHeight: CGFloat = 240
    static let headerScrimPeak: Double = 0.56

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

    /// Высота инфо-блока с однострочным лидом: 20 + 35.2 + 20 + 44 и три зазора по 16.
    /// Лид на две строки инфо-блок удлинит — хвост уедет под панель, это допущение.
    static let infoHeight: CGFloat = 20 + infoSpacing + 35.2 + infoSpacing + 20 + infoSpacing + trailerHeight
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
    static var panelRowTop: CGFloat {
        UIScreen.main.bounds.height
            - PlusChromeMetrics.bottomSafeArea
            - PlusChromeMetrics.contentBottomInset
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

/// Пороги появления навбара. Считаются от высоты кавера на ширине макета прототипа —
/// это константа, а не замер вью: читать собственный размер здесь запрещено (DECISIONS).
enum MovieScreenMotion {
    /// Верх лида: кавер − наезд + лейбл (20) + зазор
    static var leadTop: CGFloat {
        MovieLayout.coverHeight - MovieLayout.infoOverlap + 20 + MovieLayout.infoSpacing
    }
    /// Нижняя кромка кнопок навбара: вырез iPhone 17 Pro + круг 40
    static let navBarBottom: CGFloat = 62 + EntityNavBarGeometry.controlSize

    /// Подложка навбара приезжает, пока уезжает градиент шапки; название — только когда
    /// лид уйдёт под бар, иначе название экрана какое-то время видно дважды.
    static var navBar: EntityNavBarThresholds {
        EntityNavBarThresholds(
            backgroundStart: 200,
            backgroundRamp: 120,
            titleStart: leadTop - navBarBottom,
            titleRamp: 60
        )
    }
}

// MARK: - Экран

/// Карточка фильма. Одно состояние — загруженный тайтл со статичным кавером:
/// кавер со скримом (высота — см. `MovieLayout.coverHeight`), инфо-блок с фирменной
/// «ступенькой» слева, закреплённая снизу панель действий и несколько секций под ней.
///
/// Сознательно не делаем (спека §7): трейлер-видео и индикатор звука, скелетоны входа,
/// все состояния кнопок кроме дефолтного, схлопывание шапки 240 → 166 при скролле
/// (вместо него по скроллу проявляется общий `EntityNavBar`).
struct MovieScreen: View {
    let entity: EntityRef
    @State private var scrollOffset: CGFloat = 0
    @State private var scrollPosition = ScrollPosition()

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    titleBlock
                    MovieSynopsisSection(paragraphs: MovieStub.synopsis)
                    MovieDetailsSection(rows: MovieStub.details)
                    MovieRateSection()
                    // Панель действий висит поверх ленты, а хром приложения поджимает
                    // её сам (`contentMargins` из AppRootView) — распоркой добираем
                    // только высоту самой панели.
                    Color.clear.frame(height: MovieLayout.panelClearance)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
            // Кавер начинается от физического верха экрана, а не от safe area
            .ignoresSafeArea(edges: .top)
            .scrollPosition($scrollPosition)
            .trackNavBarScroll(into: $scrollOffset)
            #if DEBUG
            // `-debugScrollTo <pt>`: тапнуть и проскроллить экран из шелла нечем,
            // а секции под панелью иначе не сверить с макетом.
            .task {
                let offset = UserDefaults.standard.double(forKey: "debugScrollTo")
                guard offset > 0 else { return }
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled else { return }
                scrollPosition.scrollTo(y: offset)
            }
            #endif

            EntityNavBar(
                title: entity.title,
                artwork: entity.artwork,
                scrollOffset: scrollOffset,
                thresholds: MovieScreenMotion.navBar
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
            GlassIconButton(icon: "iconMovieShare", accessibilityTitle: "Поделиться")
            GlassIconButton(icon: "iconMovieClose", accessibilityTitle: "Закрыть")
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
            .overlay { ArtworkImage(source: entity.artwork).scaledToFill() }
            .clipped()
            .overlay(alignment: .bottom) { coverFade }
            .overlay(alignment: .top) { headerScrim }
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

    private var headerScrim: some View {
        MovieScrim.gradient(peak: MovieLayout.headerScrimPeak, from: .bottom, to: .top)
            .frame(height: MovieLayout.headerScrimHeight)
            .allowsHitTesting(false)
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: MovieLayout.infoSpacing) {
            Text(MovieStub.editorial)
                .plusMovieText()
                .foregroundStyle(Color.plusAccent)

            // В макете здесь лид-описание, а название несёт логотип тайтла. Логотипов
            // у нас нет (правило самого макета: «если лого нет — текстовое название»),
            // поэтому в лид уходит название — единственное живое поле сущности.
            Text(entity.title)
                .plusMovieLead()
                .foregroundStyle(Color.fillOne)
                .padding(.trailing, MovieLayout.leadInset)

            meta
            trailerButton
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, MovieLayout.infoLeading)
        .padding(.trailing, MovieLayout.infoTrailing)
    }

    private var meta: some View {
        HStack(spacing: MovieLayout.metaSpacing) {
            ForEach(Array(MovieStub.meta.enumerated()), id: \.offset) { index, item in
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
    }

    private var trailerButton: some View {
        Button {} label: {
            HStack(spacing: MovieLayout.trailerGap) {
                MovieIcon(
                    name: "iconMovieTrailer",
                    box: MovieLayout.trailerIconBox,
                    leaf: CGSize(width: 13.333, height: 17.5)
                )
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
        .padding(.bottom, MovieLayout.panelBottom + PlusChromeMetrics.contentBottomInset)
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
            + PlusChromeMetrics.contentBottomInset + PlusChromeMetrics.bottomSafeArea
    }

    private var playButton: some View {
        Button {} label: {
            label(
                icon: "iconMoviePlay",
                leaf: CGSize(width: 14.5, height: 21),
                // В боксе 24 глиф сдвинут вправо: inset 7 слева против 2.5 справа
                leafOffset: CGPoint(x: 7, y: 1.5),
                title: "Смотреть"
            )
            .frame(maxWidth: .infinity)
            .frame(height: MovieLayout.buttonHeight)
            .background(MoviePlayGradient.fill, in: Capsule(style: .continuous))
        }
        .buttonStyle(PressScaleButtonStyle())
    }

    private var watchLaterButton: some View {
        Button {} label: {
            label(
                icon: "iconMovieWatchLater",
                leaf: CGSize(width: 17, height: 22.5),
                leafOffset: CGPoint(x: 5, y: 0),
                title: "Позже"
            )
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
            MovieIcon(
                name: "iconMovieDownload",
                box: MovieLayout.buttonIconBox,
                leaf: CGSize(width: 18, height: 21)
            )
            .frame(width: MovieLayout.buttonHeight, height: MovieLayout.buttonHeight)
            .glassSurface(Circle(), blur: PlusMetrics.buttonBlur, border: .clear, borderWidth: 0)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel("Скачать")
    }

    private func label(
        icon: String,
        leaf: CGSize,
        leafOffset: CGPoint,
        title: String
    ) -> some View {
        HStack(spacing: MovieLayout.buttonGap) {
            MovieIcon(
                name: icon,
                box: MovieLayout.buttonIconBox,
                leaf: leaf,
                leafOffset: leafOffset
            )
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

/// Глиф в боксе макета: у иконок карточки тайтла лист не совпадает с боксом и не всегда
/// в нём центрован (у play inset слева 7 против 2.5 справа — оптическая компенсация).
/// Поэтому бокс и лист задаются раздельно, как в Figma.
struct MovieIcon: View {
    let name: String
    let box: CGFloat
    let leaf: CGSize
    /// Левый верхний угол листа внутри бокса. `nil` — лист по центру.
    var leafOffset: CGPoint?

    var body: some View {
        Color.clear
            .frame(width: box, height: box)
            .overlay(alignment: leafOffset == nil ? .center : .topLeading) {
                Image(name)
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: leaf.width, height: leaf.height)
                    .foregroundStyle(Color.fillOne)
                    .offset(x: leafOffset?.x ?? 0, y: leafOffset?.y ?? 0)
            }
    }
}
