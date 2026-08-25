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
    /// Логотип в компактном состоянии. В кадрах тюнинга 60 % (бокс 88 → 52.8),
    /// у нас 70 % (правка пользователя 2026-08-25) — мельче логотип терялся.
    static let logoCompactScale: CGFloat = 0.7
    /// Ход скролла, за который шапка схлопывается целиком. В макете это «плавно
    /// переходим при свайпе», числом не задано: 120 подобрано так, чтобы уменьшение
    /// читалось сразу с началом скролла. Тюнинг высот его не трогает.
    static let compactRamp: CGFloat = 120
    /// Ход уменьшения логотипа — вдвое длиннее общего (правка пользователя
    /// 2026-08-25): шапка уже схлопнулась, а логотип ещё плавно доезжает.
    /// Градиент, блюр и его проявление остаются на общем ходе.
    static let logoCompactRamp: CGFloat = compactRamp * 2
    /// Кнопки: верх 63 (высота статус-бара), правый край 377 = 393 − 16
    static let actionsTop: CGFloat = 63
    static let actionsTrailing: CGFloat = 16
    /// Название текстом вместо логотипа — `2063:11230`: YS Display Bold,
    /// бокс `inset 63/144/113/20`, то есть ширина 229 и две строки.
    static let titleWidth: CGFloat = 229
    static let titleLines = 2

    /// Кегль текстового логотипа — ступенями от длины названия (правка 2026-08-25):
    /// макетные 28/32 рассчитаны на среднюю длину, а короткое слово («Дюна», «Лейла»)
    /// в них теряется — настоящие логотипы коротких тайтлов всегда крупные.
    ///
    /// Границы подобраны по колонке 229: кегль каждой ступени держит название
    /// её верхней границы в двух строках без ужатия. Интерлиньяж везде кегль + 4 —
    /// пропорция макетной пары 28/32.
    static let titleSteps: [(maxLength: Int, size: CGFloat, lineHeight: CGFloat)] = [
        (8, 44, 48),
        (14, 36, 40),
        (22, 28, 32),
        (Int.max, 24, 28),
    ]

    /// Ступень по длине названия. Последняя ловит всё (`Int.max`) — `!` безопасен.
    static func titleStep(for title: String) -> (maxLength: Int, size: CGFloat, lineHeight: CGFloat) {
        titleSteps.first { title.count <= $0.maxLength }!
    }

    /// Рост логотипа на оттяге экрана: кавер под ним тянется, и логотип подрастает
    /// следом — мягко, а не пункт-в-пункт. Делитель даёт ~6 % на обычном оттяге
    /// (120pt); кап держит рост «немного» даже на самом длинном рывке.
    static let logoPullRamp: CGFloat = 2000
    static let logoPullMaxScale: CGFloat = 1.12
    /// Полоса размытия **короче полосы градиента** и живёт своей высотой. Затемнение
    /// остаётся макетным (200/150), размытие кончается выше — эти две вещи здесь
    /// сознательно разной высоты.
    ///
    /// Числа — тюнинг от 2026-08-25 (было 176/132): раз блюр проявляется по скроллу,
    /// полоса нужна там, где он виден целиком, — у компактной шапки, — и там она
    /// теперь 110. Основное состояние держит ту же дельту 44, что и раньше:
    /// скорость, с которой полоса ужимается при схлопывании, не менялась.
    static let blurMain: CGFloat = 154
    static let blurCompact: CGFloat = 110

    /// Размытие идёт **двумя слоями** разной высоты — приём тот же, что у верхнего
    /// скрима ленты (`PlusChromeMetrics.topScrimBlurSoft/Strong`).
    ///
    /// Считать надо не по высоте полосы, а по тому, где радиус проходит **порог
    /// заметности**. Глаз ловит размытие текста примерно с 1pt, а у линейной рампы
    /// радиус равен единице на высоте `H·(1 − 1/R)`: у прежней одиночной рампы
    /// 10/200 это 180pt — то есть размывать она начинала почти у самого низа шапки
    /// и дальше нарастала круто, отчего граница и читалась строкой.
    ///
    /// Тихий слой 6 даёт единицу на 5/6 высоты полосы (в компактном состоянии — 92pt)
    /// и подходит к ней полого. Сильный слой включается с 0.55 высоты и доводит пик
    /// на верхней кромке до √(6² + 6²) ≈ 8.5 — тюнинг от 2026-08-25, было
    /// √(6² + 8²) = 10. Прежняя привязка порога к низу бокса логотипа снята вместе
    /// с постоянным блюром: в покое блюра нет вовсе (см. `backdrop`), и якорить его
    /// к статичной шапке больше не по чему.
    ///
    /// Это пик рампы, а не равномерный радиус: с `BACKGROUND_BLUR 10` из панели
    /// Figma (= 5 равномерных) напрямую не сравнивается.
    static let blurSoftRadius: CGFloat = 6
    static let blurStrongRadius: CGFloat = 6
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

    /// Размытие **нарастает к верху**, вслед за самим градиентом, но живёт не всегда:
    /// в покое кавер стоит чистым, только под затемнением, а блюр проявляется по мере
    /// скролла (правка от 2026-08-25 — в кадрах тюнинга он стоял на шапке постоянно).
    /// В покое размывать нечего — под шапкой чистый кадр, и блюр только мылил его;
    /// нужен он, когда под шапку начинает уезжать контент.
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
            Group {
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
            }
            .opacity(blurProgress)

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
    /// Кегль — ступенью от длины названия (`MovieHeaderLayout.titleSteps`): это
    /// то самое правило макета «text big / text small», только ступеней четыре
    /// и числа свои. `minimumScaleFactor` остаётся страховкой внутри ступени —
    /// название из длинных слов может не влезть в две строки и на её кегле.
    private var titleText: some View {
        let step = MovieHeaderLayout.titleStep(for: title)
        return Text(title)
            .plusMovieHeaderTitle(size: step.size, lineHeight: step.lineHeight)
            .foregroundStyle(Color.fillOne)
            .lineLimit(MovieHeaderLayout.titleLines)
            .minimumScaleFactor(0.7)
            .frame(
                width: MovieHeaderLayout.titleWidth,
                height: step.lineHeight * CGFloat(MovieHeaderLayout.titleLines),
                alignment: .topLeading
            )
    }

    // MARK: Прогресс

    /// 0 — основное состояние, 1 — компактное.
    private var compact: CGFloat {
        min(1, max(0, scrollOffset / MovieHeaderLayout.compactRamp))
    }

    /// Доля уменьшения логотипа — своя, вдвое медленнее `compact`.
    private var logoCompact: CGFloat {
        min(1, max(0, scrollOffset / MovieHeaderLayout.logoCompactRamp))
    }

    /// Оттяг вниз: отрицательный offset. Пока он есть, обе компактные доли стоят
    /// в нуле — ходы логотипа не пересекаются.
    private var pull: CGFloat { max(0, -scrollOffset) }

    private var gradientHeight: CGFloat {
        MovieHeaderLayout.gradientMain
            + (MovieHeaderLayout.gradientCompact - MovieHeaderLayout.gradientMain) * compact
    }

    /// Схлопывание по скроллу × рост на оттяге. Перемножение честно, потому что
    /// ходы взаимоисключающие: при оттяге компактная доля — единица, при скролле
    /// вверх единицей становится рост. Якорь у обоих один — `.topLeading`.
    private var logoScale: CGFloat {
        let compactScale = 1 + (MovieHeaderLayout.logoCompactScale - 1) * logoCompact
        let pullScale = min(MovieHeaderLayout.logoPullMaxScale, 1 + pull / MovieHeaderLayout.logoPullRamp)
        return compactScale * pullScale
    }

    /// Полоса размытия ужимается вместе с шапкой, но по своим числам: она короче
    /// полосы градиента и кончается примерно у низа логотипа.
    private var blurHeight: CGFloat {
        MovieHeaderLayout.blurMain
            + (MovieHeaderLayout.blurCompact - MovieHeaderLayout.blurMain) * compact
    }

    /// Доля проявления блюра: 0 в покое, 1 у компактной шапки. Ход тот же, что у
    /// схлопывания (`compactRamp`) — блюр приезжает вместе с компактным состоянием,
    /// отдельного порога у него нет. Но не сама линейка `compact`, а smoothstep от неё:
    /// у линейной рампы на концах излом, и старт проявления читался бы щелчком —
    /// та же причина, что у рамп `EntityNavBar`. Высотам и масштабу излом не страшен:
    /// они едут вместе со скроллом, а не появляются из нуля.
    private var blurProgress: Double {
        let u = Double(compact)
        return u * u * (3 - 2 * u)
    }
}
