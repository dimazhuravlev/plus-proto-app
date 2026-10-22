import SwiftUI

/// Умная загрузка — включена ли и закрыт ли её баннер (задача пользователя 2026-10-21).
/// Одна на приложение: баннер стоит первым в «Скачанном» «Моего» и в шапке «Скачанных
/// треков», и закрывают его, и переключают — разом в обоих местах. Лежит на диске.
/// Саму загрузку прототип не делает — это состояние баннера.
@MainActor
@Observable
final class SmartDownloads {
    static let shared = SmartDownloads()

    private(set) var isOn: Bool {
        didSet { UserDefaults.standard.set(isOn, forKey: Self.onKey) }
    }

    private(set) var isBannerDismissed: Bool {
        didSet { UserDefaults.standard.set(isBannerDismissed, forKey: Self.dismissedKey) }
    }

    private static let onKey = "smartDownloadsOn"
    private static let dismissedKey = "smartDownloadsBannerDismissed"

    private init() {
        #if DEBUG
        // `-debugResetCollection 1` — баннер снова на месте и включён, как на первом запуске.
        if UserDefaults.standard.bool(forKey: "debugResetCollection") {
            UserDefaults.standard.removeObject(forKey: Self.onKey)
            UserDefaults.standard.removeObject(forKey: Self.dismissedKey)
        }
        #endif
        // По умолчанию — включена: первое состояние макета (`19836:173541`).
        isOn = UserDefaults.standard.object(forKey: Self.onKey) as? Bool ?? true
        isBannerDismissed = UserDefaults.standard.bool(forKey: Self.dismissedKey)
    }

    func toggle() {
        withAnimation(SmartDownloadsMotion.swap) { isOn.toggle() }
    }

    /// ✕ — баннер гаснет, его место схлопывается, блоки ниже поднимаются.
    func dismissBanner() {
        withAnimation(SmartDownloadsMotion.dismiss) { isBannerDismissed = true }
    }
}

enum SmartDownloadsMotion {
    /// Смена состояния: тексты — через блюр, высота баннера доезжает той же кривой
    static let swap: Animation = .easeInOut(duration: 0.3)
    /// Закрытие: гаснет и схлопывается
    static let dismiss: Animation = .easeInOut(duration: 0.3)
}

/// Баннер умной загрузки — `smart downloads banner` (`19836:173541` — включена,
/// `19836:173542` — выключена) в наших стилях: Headline M и Text M ДС, токены палитры,
/// белая `PlusButton` M, ✕ — plain S. Подложка Fill/Nine с бордером внутрь, r 18, поля 24;
/// у включённой за иконкой фиолетовое свечение. Кнопка переключает состояния, ✕ закрывает
/// баннер насовсем (`SmartDownloads`).
struct SmartDownloadsBanner: View {
    /// ✕ — только в «Скачанном» «Моего»; на экране «Скачанных треков» баннер постоянный,
    /// скрыть его оттуда нельзя (правка пользователя 2026-10-22).
    var isDismissible = true

    private var smart: SmartDownloads { .shared }

    private enum Layout {
        static let padding: CGFloat = 24
        static let radius: CGFloat = 18
        static let contentGap: CGFloat = 12
        static let titlesGap: CGFloat = 8
        static let iconToTitle: CGFloat = 12
        static let icon: CGFloat = 24
        /// Свечение — круг 56 по центру, верх на 6.34, фиолетовый 30 % с блюром 48 Фигмы
        static let glow: CGFloat = 56
        static let glowTop: CGFloat = 6.34
        static let glowOpacity: Double = 0.3
        static let glowBlur: CGFloat = 24
        /// ✕ — глиф 16 на 11.34 от верхней и правой кромок
        static let closeInset: CGFloat = 11.34
    }

    private var title: String {
        smart.isOn ? "Автоскачивание включено" : "Автоскачивание выключено"
    }

    /// Подпись одна на оба состояния (тексты пользователя 2026-10-22).
    private var message: String {
        "Можно слушать Мою волну и любимые треки без сети"
    }

    private var action: String {
        smart.isOn ? "Настроить" : "Включить"
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Layout.radius, style: .continuous)
        let isOn = smart.isOn
        VStack(spacing: Layout.contentGap) {
            VStack(spacing: Layout.titlesGap) {
                VStack(spacing: Layout.iconToTitle) {
                    Image("iconDownload")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: Layout.icon, height: Layout.icon)
                        .foregroundStyle(isOn ? Color.accentPrimary : Color.fillSeven)
                    Text(title)
                        .plusHeadline(.m)
                        .foregroundStyle(Color.fillOne)
                        .multilineTextAlignment(.center)
                        .id(title)
                        .transition(.blurReplace)
                }
                Text(message)
                    .plusText(.textM, .medium)
                    .foregroundStyle(Color.fillSubtitle)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .id(message)
                    .transition(.blurReplace)
            }
            .frame(maxWidth: .infinity)

            PlusButton(action, type: .white, size: .m) { smart.toggle() }
        }
        .padding(Layout.padding)
        .background(alignment: .top) {
            Circle()
                .fill(Color.accentPrimary)
                .frame(width: Layout.glow, height: Layout.glow)
                .blur(radius: Layout.glowBlur)
                .opacity(isOn ? Layout.glowOpacity : 0)
                .padding(.top, Layout.glowTop)
                .allowsHitTesting(false)
        }
        .background(Color.fillNine)
        .clipShape(shape)
        .overlay { shape.strokeBorder(Color.fillNine, lineWidth: PlusMetrics.hairline) }
        .overlay(alignment: .topTrailing) {
            if isDismissible { closeButton }
        }
    }

    /// ✕ — plain S: круг 32 под отрицательным отступом, в раскладке — глиф 16.
    private var closeButton: some View {
        let size = PlusButtonSize.s
        let inset = (size.height - size.iconBox) / 2
        return PlusButton(type: .plain, size: size, accessibilityTitle: "Закрыть") {
            smart.dismissBanner()
        } icon: {
            Image("iconCross")
                .renderingMode(.template)
                .resizable()
                .frame(width: size.iconBox, height: size.iconBox)
                .foregroundStyle(Color.fillSeven)
        }
        .padding(-inset)
        .padding(.top, Layout.closeInset)
        .padding(.trailing, Layout.closeInset)
    }
}
