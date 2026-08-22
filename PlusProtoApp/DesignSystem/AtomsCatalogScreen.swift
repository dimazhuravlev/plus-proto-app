import SwiftUI
import UIKit

/// Debug-каталог атомов дизайн-системы: каждый атом в характерных состояниях, с подписями.
/// Нужен для сверки со скриншотами макета — в продуктовую навигацию не входит.
struct AtomsCatalogScreen: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 40) {
                    Text("Атомы")
                        .plusHeadline()
                        .gradientFill(from: .fillOne, to: .white.opacity(0.6))

                    glassSection
                    buttonsSection
                    gradientTextSection
                    progressSection
                    ambilightSection
                }
                .padding(.horizontal, PlusMetrics.screenMargin)
                .padding(.vertical, 32)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Стекло

    private var glassSection: some View {
        CatalogSection("GlassSurface") {
            CatalogRow("Пилюля r32, blur 35 · круг 40, blur 20 · тайл r14, без блюра") {
                VStack(alignment: .leading, spacing: 12) {
                    Color.clear
                        .frame(width: 284, height: PlusMetrics.actionBarHeight)
                        .glassPill()

                    HStack(spacing: 12) {
                        Color.clear
                            .frame(width: PlusMetrics.circleButton, height: PlusMetrics.circleButton)
                            .glassCircle()
                        Color.clear
                            .frame(width: PlusMetrics.tabIconTile, height: PlusMetrics.tabIconTile)
                            .glassIconTile()
                        Color.clear
                            .frame(width: PlusMetrics.tabIconTile, height: PlusMetrics.tabIconTile)
                            .glassIconTile(border: .white.opacity(0.06), borderWidth: 0.733)
                    }
                }
            }

            CatalogRow("То же поверх картинки: у пилюли и круга виден backdrop-blur, тайл плоский") {
                ZStack {
                    CatalogMock.artwork("mockMoviePoster")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 300, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: PlusRadius.card, style: .continuous))

                    HStack(spacing: 12) {
                        Color.clear
                            .frame(width: 140, height: PlusMetrics.actionBarHeight)
                            .glassPill()
                        Color.clear
                            .frame(width: PlusMetrics.circleButton, height: PlusMetrics.circleButton)
                            .glassCircle()
                        Color.clear
                            .frame(width: PlusMetrics.tabIconTile, height: PlusMetrics.tabIconTile)
                            .glassIconTile()
                    }
                }
                .frame(width: 300, height: 120)
            }
        }
    }

    // MARK: - Кнопки

    private var buttonsSection: some View {
        CatalogSection("GlassIconButton") {
            CatalogRow("Одиночные 40×40, бокс глифа 20×20 — глиф в натуральную величину") {
                HStack(spacing: 20) {
                    GlassIconButton(icon: "iconHeart", accessibilityTitle: "Нравится")
                    GlassIconButton(icon: "iconClose", accessibilityTitle: "Скрыть")
                    GlassIconButton(icon: "iconSearch", accessibilityTitle: "Поиск")
                }
            }

            CatalogRow("LikeDismissPair, зазор 6 — нажми, проверь пресс-стейт") {
                LikeDismissPair()
            }
        }
    }

    // MARK: - Градиентный текст

    private var gradientTextSection: some View {
        CatalogSection("GradientText") {
            CatalogRow("Заголовок экрана 32/36: white → white 60%") {
                GradientText("Тебе нравится", from: .fillOne, to: .white.opacity(0.6))
                    .plusHeadline()
            }

            CatalogRow("Подпись к фильму 15/18: #A7CAC6 → white") {
                GradientText(
                    "Обыкновенный уборщик ищет красоту в каждом мгновении",
                    from: Color(red: 0xA7 / 255, green: 0xCA / 255, blue: 0xC6 / 255),
                    to: .fillOne
                )
                .plusTextM()
                .frame(width: 183, alignment: .leading)
            }

            CatalogRow("Подпись к книге 15/18: white → #BCEBFB, выключка вправо") {
                GradientText(
                    "Что пришло на смену капитализму и как это изменило мир?",
                    from: .fillOne,
                    to: Color(red: 0xBC / 255, green: 0xEB / 255, blue: 0xFB / 255)
                )
                .plusTextM()
                .multilineTextAlignment(.trailing)
                .frame(width: 192, alignment: .trailing)
            }

            CatalogRow("Подзаголовок «Моей Волны»: white → white 70%, поверх opacity 0.6") {
                GradientText("Атмосферный постпанк, когда внутри пасмурно", from: .fillOne, to: .white.opacity(0.7))
                    .plusTextM()
                    .opacity(0.6)
                    .frame(width: 124, alignment: .leading)
            }
        }
    }

    // MARK: - Прогресс

    private var progressSection: some View {
        CatalogSection("PlusProgressBar") {
            CatalogRow("Ширина 108 (карточка чтения): 0% · 36% · 100%") {
                VStack(alignment: .leading, spacing: 12) {
                    PlusProgressBar(progress: 0).frame(width: 108)
                    PlusProgressBar(progress: 0.3545).frame(width: 108)
                    PlusProgressBar(progress: 1).frame(width: 108)
                }
            }

            CatalogRow("Ширина 261 (карточка просмотра): 81,5%") {
                PlusProgressBar(progress: 0.815).frame(width: 261)
            }
        }
    }

    // MARK: - Ambilight

    private var ambilightSection: some View {
        CatalogSection("AmbilightArtwork") {
            CatalogRow("Кино: 180×270, r12, −3°, glow 0.7, бордер 1") {
                AmbilightArtwork(
                    image: CatalogMock.artwork("mockMoviePoster"),
                    size: CGSize(width: 180, height: 270),
                    rotation: .degrees(-3),
                    glowOpacity: 0.7
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            }

            CatalogRow("Альбом: 180×180, r12, +2°, glow 0.7, бордер 1") {
                AmbilightArtwork(
                    image: CatalogMock.artwork("mockAlbumCover"),
                    size: CGSize(width: 180, height: 180),
                    rotation: .degrees(2),
                    glowOpacity: 0.7
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            }

            CatalogRow("Лестница glow: 0.7 · 0.5 · 0.3 (кино / видео / книга)") {
                HStack(spacing: 32) {
                    ForEach([0.7, 0.5, 0.3], id: \.self) { opacity in
                        AmbilightArtwork(
                            image: CatalogMock.artwork("mockAlbumCover"),
                            size: CGSize(width: 72, height: 72),
                            rotation: .degrees(-3),
                            glowOpacity: opacity
                        )
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            }

            CatalogRow("Без поворота, бордер 0.66 (видеокадр)") {
                AmbilightArtwork(
                    image: CatalogMock.artwork("mockVideoStill"),
                    size: CGSize(width: 277, height: 156),
                    glowOpacity: 0.5,
                    borderWidth: PlusMetrics.hairline
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            }
        }
    }
}

// MARK: - Каркас каталога

private struct CatalogSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text(title)
                .plusTitleL()
                .foregroundStyle(Color.fillOne)
            content
        }
    }
}

private struct CatalogRow<Content: View>: View {
    let caption: String
    @ViewBuilder let content: Content

    init(_ caption: String, @ViewBuilder content: () -> Content) {
        self.caption = caption
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(caption)
                .plusTextS()
                .foregroundStyle(Color.fillSubtitle)
            content
        }
    }
}

/// Ассеты экспортирует параллельный агент. Пока их нет — подставляем сгенерированный градиент,
/// иначе геометрию ambilight и работу блюра на скриншоте не проверить.
private enum CatalogMock {
    static func artwork(_ name: String) -> Image {
        if UIImage(named: name) != nil { return Image(name) }
        return placeholder
    }

    private static let placeholder: Image = {
        let size = CGSize(width: 300, height: 450)
        let ui = UIGraphicsImageRenderer(size: size).image { context in
            let colors = [
                UIColor(red: 0.42, green: 0.66, blue: 0.62, alpha: 1).cgColor,
                UIColor(red: 0.24, green: 0.16, blue: 0.36, alpha: 1).cgColor,
            ]
            guard let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors as CFArray,
                locations: [0, 1]
            ) else { return }
            context.cgContext.drawLinearGradient(
                gradient,
                start: .zero,
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )
        }
        return Image(uiImage: ui)
    }()
}
