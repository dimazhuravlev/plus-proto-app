import SwiftUI
import VariableBlur

// MARK: - Движение

/// Константы появления навбара по скроллу. Стиль проекта — числа именами рядом
/// с компонентом (`ActionBarMotion`, `ShowcaseMotion`).
enum EntityNavBarMotion {
    /// Offset, с которого начинает проявляться подложка. Дефолт рассчитан на шапку
    /// с обложкой ~280pt: подложка приезжает заметно раньше названия — сперва фон,
    /// потом текст (порядок из MusicPlayer, там 200 против 360).
    static let backgroundStart: CGFloat = 120
    static let backgroundRamp: CGFloat = 80
    /// Название и обложка проявляются, когда шапка почти скрылась под баром.
    static let titleStart: CGFloat = 220
    static let titleRamp: CGFloat = 90

    /// На сколько блок сущности приподнимается, пока проявляется. Чистый сдвиг
    /// без opacity читался бы как подмена, а 8pt хватает, чтобы движение было
    /// направленным и не спорило с самим скроллом.
    static let entityRise: CGFloat = 8

    /// Множитель затемнения подложки. Градиент таббара в пике даёт чёрный 0.90 —
    /// это уже сплошная плашка, а под баром контент должен угадываться.
    /// Глобального `TopScrim` поверх бара больше нет (2026-10-03): подложка — единственный
    /// слой затемнения и блюра у экранов со своим навбаром.
    static let backdropTint: Double = 0.8
}

/// Пороги появления — параметр компонента, а не константа: они зависят от высоты
/// шапки конкретного экрана (постер фильма выше обложки альбома), и зашитые в
/// компонент абсолютные пункты разъехались бы на первом же новом экране.
/// Это ровно тот дефект оригинала, который переносить не надо.
struct EntityNavBarThresholds: Equatable {
    /// Сколько пунктов контента должно уйти вверх, прежде чем подложка начнёт проявляться
    var backgroundStart: CGFloat = EntityNavBarMotion.backgroundStart
    /// За сколько пунктов подложка доезжает до полной непрозрачности
    var backgroundRamp: CGFloat = EntityNavBarMotion.backgroundRamp
    var titleStart: CGFloat = EntityNavBarMotion.titleStart
    var titleRamp: CGFloat = EntityNavBarMotion.titleRamp

    static let `default` = EntityNavBarThresholds()

    /// Экран без скролла (заглушка, статичная карточка): и подложка, и название
    /// стоят на месте. Нулевая длина рампы означает «постоянное значение»:
    /// при offset 0 обе доли уже равны 1.
    static let pinned = EntityNavBarThresholds(
        backgroundStart: 0,
        backgroundRamp: 0,
        titleStart: 0,
        titleRamp: 0
    )
}

// MARK: - Геометрия

/// Размеры бара. Не `private`: экрану сущности нужен `barHeight`, чтобы отодвинуть
/// от него свою шапку.
enum EntityNavBarGeometry {
    /// Кнопка и обложка — 40pt, как все круглые кнопки проекта
    static let controlSize = PlusMetrics.circleButton
    /// Отступ до контента под баром
    static let bottomPadding: CGFloat = 8
    /// Полная высота бара под safe area
    static var barHeight: CGFloat { controlSize + bottomPadding }

    /// Боковые поля навбара внутренних экранов — 16 (правка пользователя 2026-08-25;
    /// было `screenMargin` 24 в линию с action bar — теперь навбар живёт общим полем
    /// контента, как шапка карточки тайтла).
    static let horizontalPadding: CGFloat = 16
    /// Зазор кнопка ↔ обложка сущности — 8, правило пользователя 2026-10-03.
    /// Было 12: казалось, что круг кнопки и угол прямоугольной обложки при 8pt
    /// зрительно слипаются. Тем же зазором отделены друг от друга и остальные
    /// элементы строки — блок сущности и слот действий справа.
    static let backToEntityGap: CGFloat = 8
    /// Зазор обложка ↔ название — как в мини-плеере action bar
    static let coverTitleGap: CGFloat = 8
    /// Скругление прямоугольной обложки: тот же радиус, что у чипа кино в баре
    static let coverCornerRadius = PlusRadius.movieChip

    /// Высота подложки, отмеряется вверх от нижней кромки бара: safe area с
    /// Dynamic Island (62) + бар (48) + запас на устройства с более высоким вырезом.
    static let backdropHeight: CGFloat = 120
    /// Максимальный радиус прогрессивного блюра у верхней кромки подложки
    static let backdropBlurRadius: CGFloat = 16
}

// MARK: - Компонент

/// Верхний навбар внутренних экранов: «назад» слева, следом обложка сущности с её
/// названием, справа — слот под действия. Портирован из `NavBar` MusicPlayer.
///
/// Появление привязано к скроллу экрана: подложка и блок сущности проявляются
/// **рампой от offset**, то есть чистой функцией без `.animation`. В оригинале
/// порог был бинарным (`offset >= 360 ? 1 : 0`), а плавность давала
/// `.animation(_:value: scrollOffset)` — транзакция пересоздавалась на каждом
/// кадре скролла ради перехода, случающегося один раз.
struct EntityNavBar<Trailing: View>: View {
    @Environment(\.dismiss) private var dismiss

    /// Название сущности. На экране без сущности — название раздела.
    let title: String
    /// Обложка. `nil` — «пустой» вариант: только кнопка и название.
    var artwork: ArtworkSource? = nil
    /// Круг для альбома и исполнителя, скруглённый прямоугольник для фильма и книги
    var isArtworkCircular: Bool = false
    /// Сколько пунктов контента ушло вверх. Экран отдаёт через `trackNavBarScroll`.
    var scrollOffset: CGFloat = 0
    var thresholds: EntityNavBarThresholds = .default
    /// `nil` — снять верхний экран стека
    var onBack: (() -> Void)? = nil
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: EntityNavBarGeometry.backToEntityGap) {
            backButton
            entity
            Spacer(minLength: 0)
            trailing()
        }
        .frame(height: EntityNavBarGeometry.controlSize)
        .padding(.horizontal, EntityNavBarGeometry.horizontalPadding)
        .padding(.bottom, EntityNavBarGeometry.bottomPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Подложка выше бара и прижата к его низу — так она накрывает статус-бар,
        // не заставляя бар лезть под safe area. Размер бара при этом ни на что
        // не влияет: высота подложки — константа, а не замер (запрет из DECISIONS).
        .background(alignment: .bottom) { backdrop }
    }

    // MARK: Слои

    /// Шеврон — `icon / dropleft` из ДС «🦄 Графика» (нода сета `19:6461`).
    /// Раньше здесь стоял системный `chevron.left`: своего ассета не было.
    ///
    /// Кнопка — тот же `GlassIconButton`, что у крестика и сердца: круг 40, бокс глифа 20,
    /// стекло и пресс-стейт совпадали и раньше, просто были переписаны здесь заново.
    private var backButton: some View {
        GlassIconButton(icon: "iconDropleft", accessibilityTitle: "Назад") {
            if let onBack { onBack() } else { dismiss() }
        }
    }

    private var entity: some View {
        HStack(spacing: EntityNavBarGeometry.coverTitleGap) {
            // Ветвление статическое: наличие обложки задано экраном и по скроллу
            // не переключается, поэтому идентичность анимируемого поддерева цела.
            if let artwork {
                cover(artwork)
            }

            Text(title)
                .plusHeadline(.s)
                .foregroundStyle(Color.fillOne)
                .lineLimit(1)
        }
        .opacity(entityProgress)
        .offset(y: CGFloat(1 - entityProgress) * EntityNavBarMotion.entityRise)
    }

    private func cover(_ source: ArtworkSource) -> some View {
        let shape: AnyShape = isArtworkCircular
            ? AnyShape(Circle())
            : AnyShape(
                RoundedRectangle(
                    cornerRadius: EntityNavBarGeometry.coverCornerRadius,
                    style: .continuous
                )
            )

        return ArtworkImage(source: source)
            .scaledToFill()
            .frame(width: EntityNavBarGeometry.controlSize, height: EntityNavBarGeometry.controlSize)
            .clipShape(shape)
            .overlay { shape.stroke(Color.fillNine, lineWidth: PlusMetrics.hairline) }
    }

    private var backdrop: some View {
        ZStack(alignment: .top) {
            VariableBlurView(
                maxBlurRadius: EntityNavBarGeometry.backdropBlurRadius,
                direction: .blurredTopClearBottom
            )

            // Тот же 16-стоповый сглаженный чёрный, что под таббаром: двух стопов
            // на 120pt мало — на градиенте виден банд, ради этого стопы и заведены.
            // Переворачиваем по вертикали, потому что у него зашит startPoint .bottom.
            PlusGradient.tabBarUnderlay
                .scaleEffect(y: -1)
                .opacity(EntityNavBarMotion.backdropTint)
        }
        .frame(height: EntityNavBarGeometry.backdropHeight)
        .opacity(backgroundProgress)
        .allowsHitTesting(false)
    }

    // MARK: Рампы

    private var backgroundProgress: Double {
        EntityNavBar.ramp(scrollOffset, start: thresholds.backgroundStart, length: thresholds.backgroundRamp)
    }

    private var entityProgress: Double {
        EntityNavBar.ramp(scrollOffset, start: thresholds.titleStart, length: thresholds.titleRamp)
    }

    /// Плавная доля 0→1 как чистая функция от offset. Smoothstep, а не линейка:
    /// у линейной рампы на обоих концах излом, и старт проявления читается щелчком.
    private static func ramp(_ offset: CGFloat, start: CGFloat, length: CGFloat) -> Double {
        // Нулевая длина — «постоянное значение» (вариант `.pinned`), а не деление на ноль.
        guard length > 0 else { return offset >= start ? 1 : 0 }
        let u = Double(min(max((offset - start) / length, 0), 1))
        return u * u * (3 - 2 * u)
    }
}

extension EntityNavBar where Trailing == EmptyView {
    init(
        title: String,
        artwork: ArtworkSource? = nil,
        isArtworkCircular: Bool = false,
        scrollOffset: CGFloat = 0,
        thresholds: EntityNavBarThresholds = .default,
        onBack: (() -> Void)? = nil
    ) {
        self.init(
            title: title,
            artwork: artwork,
            isArtworkCircular: isArtworkCircular,
            scrollOffset: scrollOffset,
            thresholds: thresholds,
            onBack: onBack
        ) {
            EmptyView()
        }
    }
}

// MARK: - Скролл

extension View {
    /// Отдаёт навбару, сколько пунктов контента ушло вверх. Вешается на сам `ScrollView`.
    ///
    /// `onScrollGeometryChange` вместо связки `PreferenceKey` + датчик-распорка из
    /// MusicPlayer: датчику нужен собственный проход раскладки на каждом кадре, а
    /// геометрия скролла и так посчитана. Значение сравнивается системой, поэтому
    /// `@State` пишется только когда offset реально изменился.
    func trackNavBarScroll(into offset: Binding<CGFloat>) -> some View {
        onScrollGeometryChange(for: CGFloat.self) { geometry in
            // Плюс верхний inset: у нескролленного вью contentOffset.y отрицательный
            // на высоту инсета, а рампам нужен ноль в покое.
            geometry.contentOffset.y + geometry.contentInsets.top
        } action: { _, new in
            offset.wrappedValue = new
        }
    }
}
