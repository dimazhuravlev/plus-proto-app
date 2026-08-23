import SwiftUI

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
    /// Блюр шапки в компактном состоянии. Число в **CSS-единицах**, как `ambilightBlur`:
    /// в панели Figma радиус вдвое больше (`BACKGROUND_BLUR 10` = `backdrop-blur 5px`).
    static let blurRadius: CGFloat = 5
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
    /// Высота кавера — чтобы понять, есть ли ещё что размывать под шапкой.
    let coverHeight: CGFloat
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

    private var backdrop: some View {
        ZStack {
            // Размытие под градиентом, а не над: размывать нужно кавер, а не собственную
            // затемняющую заливку.
            BackdropBlurView(radius: blur)
            MovieScrim.linear(peak: MovieHeaderLayout.scrimPeak, from: .bottom, to: .top)
        }
        .frame(height: gradientHeight)
        .allowsHitTesting(false)
    }

    /// Ужимается логотип к **верхне-левому** углу. В обоих кадрах тюнинга его бокс
    /// стоит в одной точке (20, 63), а сторона падает 88 → 52.8 — значит на месте
    /// остаётся верхняя кромка, а не нижняя, как было раньше. Сверено замером по
    /// рендеру макета: левый край краски 21 в обоих состояниях, верхний 67 → 65
    /// (те же 4pt прозрачного поля в PNG, умноженные на 0.6), нижний 150 → 115.
    ///
    /// Масштаб, а не пересчёт бокса, — чтобы соседние элементы не дёргались
    /// раскладкой на каждом кадре скролла.
    @ViewBuilder
    private var logoView: some View {
        if let logo {
            MovieTitleLogo(url: logo, title: title)
                .scaleEffect(logoScale, anchor: .topLeading)
        }
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

    /// Блюр включается вместе со схлопыванием и гаснет по мере ухода кавера — ровно
    /// как описано в спеке («10 → 0 по мере ухода кавера»). Когда кавера под шапкой
    /// уже нет, размывать нечего: там сплошной чёрный фон экрана.
    private var blur: CGFloat {
        let remaining = coverHeight - scrollOffset
        let fade = min(1, max(0, remaining / MovieHeaderLayout.gradientMain))
        return MovieHeaderLayout.blurRadius * compact * fade
    }
}
