import SwiftUI
import UIKit

/// Цветная тень под кавером карточек промо «Главной» — фильм, книга, исполнитель, альбом;
/// станция без тени (правка пользователя 2026-10-13, макета нет: ось y — из правки,
/// размытие и плотность — подобраны).
///
/// Тень повторяет форму кавера, сдвинута вниз и размыта, цвет — средний цвет картинки,
/// притушенный в темноту (`ArtworkLoader.shadowColor`). На кадре скролла она стоит
/// ровно битмап: размытая белая форма рисуется один раз в растр на форму и размер,
/// растр красится в цвет айтема (template) и лежит позади кавера. `.shadow` на карточке
/// считал бы размытие заново на каждом кадре наклона и масштаба.
enum PromoCoverShadowConfig {
    /// Непрозрачность тени. Тень темнее фона витрины (размытый кавер под затемнением 0.35,
    /// `ShowcasePromoBackdropStyle.dim`): в плотной части ≈ 0.3 яркости среднего тона против
    /// ≈ 0.65 у фона (правка пользователя 2026-10-13; было 0.6 и яркость 0.55 — сливалась с фоном).
    static let opacity: Double = 0.85
    /// Сдвиг вниз и радиус размытия — на 402, умножаются на `ShowcasePromoLayout.scale`.
    /// Радиус — в единицах `.blur(radius:)`, как у прочих блюров кода.
    static let offsetY: CGFloat = 4
    static let blur: CGFloat = 10
    /// Поле растра вокруг формы — в радиусах размытия: за тремя хвост гауссианы
    /// меньше четверти процента и в 8-битной альфе его уже нет.
    static let fieldInBlurs: CGFloat = 3
    /// Растр в 1 пиксель на пункт: размытие с радиусом 10 стирает детали мельче ~5 пунктов,
    /// и растр, растянутый на экранный масштаб, неотличим от полного, а памяти — в девять раз меньше.
    static let rasterScale: CGFloat = 1

    @MainActor
    static var offset: CGFloat { offsetY * ShowcasePromoLayout.scale }
    @MainActor
    static var blurRadius: CGFloat { blur * ShowcasePromoLayout.scale }
}

/// Форма кавера, под которым лежит тень. Размеры — в пунктах, уже умноженные на масштаб
/// промо; они же ключ кэша растра.
enum PromoCoverShadowForm: Hashable {
    case rounded(width: CGFloat, height: CGFloat, radius: CGFloat)
    case circle(diameter: CGFloat)
    /// Книга целиком, как она лежит: обложка и выступающий за ней блок страниц.
    case book(coverWidth: CGFloat, coverHeight: CGFloat, coverRadius: CGFloat, pagesInset: CGFloat, pagesRadius: CGFloat)

    /// Кадр, к которому прикладывается тень, — кадр кавера (у книги — кадр `BookFigure`).
    var size: CGSize {
        switch self {
        case .rounded(let width, let height, _): CGSize(width: width, height: height)
        case .circle(let diameter): CGSize(width: diameter, height: diameter)
        case .book(let coverWidth, let coverHeight, _, let inset, _):
            CGSize(width: coverWidth + inset, height: coverHeight + inset)
        }
    }

    /// Холст растра: форма и поле под размытие, целым числом пунктов — растр ложится
    /// на пиксельную сетку без пересэмплирования.
    @MainActor
    var canvas: CGSize {
        let field = (PromoCoverShadowConfig.blurRadius * PromoCoverShadowConfig.fieldInBlurs).rounded(.up)
        return CGSize(
            width: (size.width + 2 * field).rounded(.up),
            height: (size.height + 2 * field).rounded(.up)
        )
    }

    /// Отступ формы от левого верхнего угла холста.
    @MainActor
    var inset: CGSize {
        CGSize(width: (canvas.width - size.width) / 2, height: (canvas.height - size.height) / 2)
    }

    /// Белый силуэт формы в её кадре.
    @MainActor @ViewBuilder
    var silhouette: some View {
        switch self {
        case .rounded(let width, let height, let radius):
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .frame(width: width, height: height)
        case .circle(let diameter):
            Circle()
                .frame(width: diameter, height: diameter)
        case .book(let coverWidth, let coverHeight, let coverRadius, let inset, let pagesRadius):
            // Подложка страниц и обложка поверх — без скоса корешка и сгиба: под размытием
            // 10 они не видны.
            ZStack(alignment: .topLeading) {
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: pagesRadius,
                    topTrailingRadius: pagesRadius,
                    style: .continuous
                )
                .frame(width: coverWidth + inset, height: coverHeight + inset)
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: coverRadius,
                    topTrailingRadius: coverRadius,
                    style: .continuous
                )
                .frame(width: coverWidth, height: coverHeight)
                .padding(.top, inset)
            }
            .frame(width: coverWidth + inset, height: coverHeight + inset, alignment: .topLeading)
        }
    }
}

/// Откуда тень берёт цвет и какой формы она.
struct PromoCoverShadowSpec {
    let source: ArtworkSource
    let form: PromoCoverShadowForm
}

extension ShowcaseBlock {
    /// Кавер карточки промо, под которым лежит тень. Размеры и радиусы — те же, что
    /// у кавера в `PromoCardFace`. `nil` — тени нет (станция, «продолжить»).
    @MainActor
    var promoShadow: PromoCoverShadowSpec? {
        typealias Layout = ShowcasePromoLayout
        switch self {
        case .movie(let movie):
            return PromoCoverShadowSpec(
                source: movie.poster,
                form: .rounded(width: Layout.poster.width, height: Layout.poster.height, radius: Layout.posterRadius)
            )
        case .album(let album):
            return PromoCoverShadowSpec(
                source: album.cover,
                form: .rounded(width: Layout.album, height: Layout.album, radius: Layout.albumRadius)
            )
        case .book(let book):
            let figure = Layout.book
            return PromoCoverShadowSpec(
                source: book.cover,
                form: .book(
                    coverWidth: figure.coverWidth,
                    coverHeight: figure.geometry.coverHeight,
                    coverRadius: figure.geometry.coverRadius,
                    pagesInset: figure.geometry.pagesInset,
                    pagesRadius: figure.geometry.pagesRadius
                )
            )
        case .artist(let artist):
            return PromoCoverShadowSpec(source: artist.picture, form: .circle(diameter: Layout.album))
        case .vibe, .reading, .watching:
            return nil
        }
    }
}

extension View {
    /// Тень под кавером айтема промо — позади, не меняя раскладку карточки. Вешается
    /// до `showcaseSwappable()`: тень гаснет вместе с карточкой.
    func promoCoverShadow(_ item: ShowcaseBlock) -> some View {
        background(alignment: .topLeading) {
            PromoCoverShadowView(item: item)
        }
    }
}

enum PromoCoverShadow {
    /// Растры форм и цвета обложек среди айтемов — заранее: под заставкой (`AppRootView`),
    /// а не на первом кадре показа. Цвет считается только у обложек, уже лежащих в памяти.
    @MainActor
    static func prewarm(_ blocks: [ShowcaseBlock]) {
        for block in blocks {
            guard let shadow = block.promoShadow else { continue }
            _ = PromoCoverShadowRaster.image(for: shadow.form)
            _ = ArtworkLoader.shared.shadowColor(for: shadow.source)
        }
    }
}

/// Растры теней — на форму и размер: у промо их четыре (постер, квадрат альбома, книга, круг),
/// и все слоты ряда делят одни и те же битмапы.
@MainActor
private enum PromoCoverShadowRaster {
    private static var images: [PromoCoverShadowForm: UIImage] = [:]

    static func image(for form: PromoCoverShadowForm) -> UIImage? {
        if let hit = images[form] { return hit }
        let canvas = form.canvas
        // Блюр рисует за пределы кадра формы, поэтому внешний кадр — холст с полем.
        let renderer = ImageRenderer(content:
            form.silhouette
                .foregroundStyle(.white)
                .blur(radius: PromoCoverShadowConfig.blurRadius)
                .frame(width: canvas.width, height: canvas.height)
        )
        renderer.scale = PromoCoverShadowConfig.rasterScale
        guard let image = renderer.uiImage else { return nil }
        // Растр готов к показу сразу, а не на первой отрисовке.
        let prepared = image.preparingForDisplay() ?? image
        images[form] = prepared
        return prepared
    }
}

/// Сама тень: растр формы, покрашенный в цвет кавера. Цвет известен на первом кадре, если
/// картинка уже в памяти (из кэша, моковый ассет), — тогда тень есть сразу. Иначе её нет,
/// пока нет картинки (скелетон), и она проявляется вместе с кавером (`PlusSkeleton.appear`).
private struct PromoCoverShadowView: View {
    let shadow: PromoCoverShadowSpec?
    /// Цвет берётся из памяти **синхронно, в `init`** — как картинка в `ResolvedArtwork`:
    /// иначе тень моргала бы на каждом монтировании слота.
    @State private var color: Color?

    @MainActor
    init(item: ShowcaseBlock) {
        let shadow = item.promoShadow
        self.shadow = shadow
        _color = State(initialValue: shadow.flatMap { ArtworkLoader.shared.shadowColor(for: $0.source) })
    }

    var body: some View {
        if let shadow {
            Color.clear
                .frame(width: shadow.form.size.width, height: shadow.form.size.height)
                .overlay(alignment: .topLeading) {
                    if let color, let raster = PromoCoverShadowRaster.image(for: shadow.form) {
                        let canvas = shadow.form.canvas
                        let inset = shadow.form.inset
                        Image(uiImage: raster)
                            .renderingMode(.template)
                            .resizable()
                            .frame(width: canvas.width, height: canvas.height)
                            .foregroundStyle(color)
                            .opacity(PromoCoverShadowConfig.opacity)
                            .offset(x: -inset.width, y: -inset.height + PromoCoverShadowConfig.offset)
                            .transition(.opacity)
                    }
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .task(id: shadow.source) { await resolve(shadow.source) }
        }
    }

    /// Цвет, которого не было на первом кадре: обложка приехала позже — ждём её и проявляем
    /// тень той же анимацией, что и саму картинку.
    private func resolve(_ source: ArtworkSource) async {
        let loader = ArtworkLoader.shared
        if let known = loader.shadowColor(for: source) {
            if color != known { color = known }
            return
        }
        if color != nil { color = nil }
        guard
            let url = source.remoteURL,
            let image = await loader.image(for: url),
            let tone = loader.shadowColor(for: url, image: image)
        else { return }
        withAnimation(PlusSkeleton.appear) { color = tone }
    }
}
