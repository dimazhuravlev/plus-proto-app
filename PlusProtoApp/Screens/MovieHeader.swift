import SwiftUI
import VariableBlur

/// Геометрия шапки карточки тайтла — `figma-moviecard.md` §2.2 и §5.1.
///
/// Это **своя** навигация экрана, а не общий `EntityNavBar`: кнопки «назад» здесь нет
/// вовсе, вместо неё крестик справа. В макете (`title / header`) слот слева занимает
/// логотип тайтла, а пара «поделиться»/«закрыть» прибита к правому верхнему углу
/// и по скроллу не меняется — это прямо оговорено в спеке для всех прокрученных кадров.
enum MovieHeaderLayout {
    /// Высота градиента: основное состояние → компактное. Тюнинг `2063:10865`
    /// и `2063:10893` — оттуда же пик, профиль и радиус блюра ниже.
    static let gradientMain: CGFloat = 200
    static let gradientCompact: CGFloat = 150
    /// Пик альфы шапки — это `opacity` самой заливки (у панели кнопок свой, 0.92)
    static let scrimPeak: Double = 0.75
    /// Логотип в компактном состоянии — 60 %: бокс 88 → 52.8 в обоих кадрах тюнинга
    static let logoCompactScale: CGFloat = 0.6
    /// Ход скролла, за который шапка схлопывается целиком. В макете это «плавно
    /// переходим при свайпе», числом не задано: 120 подобрано так, чтобы уменьшение
    /// читалось сразу с началом скролла. Тюнинг высот его не трогает.
    static let compactRamp: CGFloat = 120
    /// Кнопки: верх 63 (высота статус-бара), правый край 377 = 393 − 16
    static let actionsTop: CGFloat = 63
    static let actionsTrailing: CGFloat = 16
    /// Название текстом вместо логотипа — `2063:11230`: YS Display Bold 28/32,
    /// бокс `inset 63/144/113/20`, то есть ширина 229 и две строки по 32.
    static let titleSize: CGFloat = 28
    static let titleLineHeight: CGFloat = 32
    static let titleWidth: CGFloat = 229
    static let titleLines = 2
    /// Полоса размытия **короче полосы градиента** и живёт своей высотой. Затемнение
    /// остаётся макетным (200/150), размытие кончается выше — эти две вещи здесь
    /// сознательно разной высоты.
    static let blurMain: CGFloat = 176
    static let blurCompact: CGFloat = 132

    /// Размытие идёт **двумя слоями** разной высоты — приём тот же, что у верхнего
    /// скрима ленты (`PlusChromeMetrics.topScrimBlurSoft/Strong`).
    ///
    /// Считать надо не по высоте полосы, а по тому, где радиус проходит **порог
    /// заметности**. Глаз ловит размытие текста примерно с 1pt, а у линейной рампы
    /// радиус равен единице на высоте `H·(1 − 1/R)`: у прежней одиночной рампы
    /// 10/200 это 180pt — то есть размывать она начинала почти у самого низа шапки
    /// и дальше нарастала круто, отчего граница и читалась строкой.
    ///
    /// Здесь порог вынесен к низу логотипа и подход к нему сделан пологим: тихий
    /// слой 6/176 даёт единицу на 147pt (низ бокса логотипа — 63 + 88 = 151)
    /// и растёт по 0.034pt на пункт. Сильный слой включается только с 97pt
    /// и доводит пик на верхней кромке до √(6² + 8²) = 10 — той же десятки, что была.
    ///
    /// Это пик рампы, а не равномерный радиус: с `BACKGROUND_BLUR 10` из панели
    /// Figma (= 5 равномерных) напрямую не сравнивается.
    static let blurSoftRadius: CGFloat = 6
    static let blurStrongRadius: CGFloat = 8
    /// Сильный слой кончается раньше тихого — на этом и держится плавность хвоста.
    static let blurStrongShare: CGFloat = 0.55
}

/// Шапка карточки тайтла: градиент, логотип слева, действия справа.
///
/// Слой **прибит к верху экрана** и не скроллится — уезжает под него только контент.
/// Раньше градиент лежал внутри кавера и уезжал вместе с ним, а сверху по скроллу
/// проявлялся общий навбар; в макете это один и тот же слой, просто меняющий размеры.
struct MovieHeader<Actions: View>: View {
    let logo: URL?
    let title: String
    /// Сколько уже прокручено. Приходит снаружи: читать свой размер и позицию вью,
    /// от которых зависит её же раскладка, в проекте запрещено (DECISIONS).
    let scrollOffset: CGFloat
    @ViewBuilder var actions: () -> Actions

    var body: some View {
        ZStack(alignment: .top) {
            backdrop

            HStack(alignment: .top, spacing: 0) {
                logoView
                Spacer(minLength: 0)
                actions()
            }
            .padding(.top, MovieHeaderLayout.actionsTop)
            .padding(.leading, MovieLogoLayout.leading)
            .padding(.trailing, MovieHeaderLayout.actionsTrailing)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .ignoresSafeArea(edges: .top)
    }

    // MARK: Слои

    /// Размытие **нарастает к верху**, вслед за самим градиентом, и живёт всегда —
    /// в обоих кадрах тюнинга оно стоит на шапке, а не появляется по скроллу.
    ///
    /// Равномерное здесь не годится: полоса шапки сама становится кромкой — там, где
    /// она кончается, резкость обрывается на ровном месте посреди кавера. Рампа снимает
    /// эту границу тем же приёмом и в ту же сторону, что верхний скрим ленты
    /// (`TopScrim`), зеркально полосе под кавером.
    ///
    /// Слоёв размытия два и они разной высоты — так хвост рампы растянут и строки,
    /// на которой резкость возвращается, не видно. Оба короче полосы градиента,
    /// поэтому стек выровнен по верху: затемнение доходит до низа шапки, размытие —
    /// только до логотипа.
    ///
    /// Порядок слоёв: размытие **под** градиентом, а не над, — размывать нужно кавер,
    /// а не собственную затемняющую заливку.
    private var backdrop: some View {
        ZStack(alignment: .top) {
            VariableBlurView(
                maxBlurRadius: MovieHeaderLayout.blurSoftRadius,
                direction: .blurredTopClearBottom
            )
            .frame(height: blurHeight)

            VariableBlurView(
                maxBlurRadius: MovieHeaderLayout.blurStrongRadius,
                direction: .blurredTopClearBottom
            )
            .frame(height: blurHeight * MovieHeaderLayout.blurStrongShare)

            MovieScrim.linear(peak: MovieHeaderLayout.scrimPeak, from: .bottom, to: .top)
                .frame(height: gradientHeight)
        }
        .frame(height: gradientHeight, alignment: .top)
        .allowsHitTesting(false)
    }

    /// Логотип, а если его нет — название текстом на том же месте (`2063:11183`).
    ///
    /// Ужимается он к **верхне-левому** углу. В обоих кадрах тюнинга его бокс
    /// стоит в одной точке (20, 63), а сторона падает 88 → 52.8 — значит на месте
    /// остаётся верхняя кромка, а не нижняя, как было раньше. Сверено замером по
    /// рендеру макета: левый край краски 21 в обоих состояниях, верхний 67 → 65
    /// (те же 4pt прозрачного поля в PNG, умноженные на 0.6), нижний 150 → 115.
    ///
    /// Масштаб, а не пересчёт бокса, — чтобы соседние элементы не дёргались
    /// раскладкой на каждом кадре скролла.
    @ViewBuilder
    private var logoView: some View {
        Group {
            if let logo {
                MovieTitleLogo(url: logo, title: title)
            } else {
                titleText
            }
        }
        .scaleEffect(logoScale, anchor: .topLeading)
    }

    /// Название на месте логотипа: то же выравнивание, то же положение и тот же
    /// масштаб по скроллу — отличается только тем, что это текст.
    ///
    /// Правило макета «text big до 28 символов, text small свыше» воспроизведено
    /// не дискретной парой стилей, а сжатием: мастер `title / logo` лежит
    /// в подключённой библиотеке и кегль «text small» оттуда не читается, а
    /// придумывать число в проекте, который сверяется с макетом попиксельно, нельзя.
    /// `minimumScaleFactor` даёт то же поведение — длинное название становится
    /// мельче, — и остаётся честным: он подгоняет, а не выдаёт выдуманный кегль.
    private var titleText: some View {
        Text(title)
            .plusMovieHeaderTitle()
            .foregroundStyle(Color.fillOne)
            .lineLimit(MovieHeaderLayout.titleLines)
            .minimumScaleFactor(0.7)
            .frame(
                width: MovieHeaderLayout.titleWidth,
                height: MovieHeaderLayout.titleLineHeight * CGFloat(MovieHeaderLayout.titleLines),
                alignment: .topLeading
            )
    }

    // MARK: Прогресс

    /// 0 — основное состояние, 1 — компактное.
    private var compact: CGFloat {
        min(1, max(0, scrollOffset / MovieHeaderLayout.compactRamp))
    }

    private var gradientHeight: CGFloat {
        MovieHeaderLayout.gradientMain
            + (MovieHeaderLayout.gradientCompact - MovieHeaderLayout.gradientMain) * compact
    }

    private var logoScale: CGFloat {
        1 + (MovieHeaderLayout.logoCompactScale - 1) * compact
    }

    /// Полоса размытия ужимается вместе с шапкой, но по своим числам: она короче
    /// полосы градиента и кончается примерно у низа логотипа.
    private var blurHeight: CGFloat {
        MovieHeaderLayout.blurMain
            + (MovieHeaderLayout.blurCompact - MovieHeaderLayout.blurMain) * compact
    }
}
