# Разведка MusicPlayer: навбар внутренних экранов + инерция вращения обложки

Снапшот 2026-08-23. Источник — `~/Repos/MusicPlayer` (сиблинг-проект того же автора).
Файл только для чтения при переносе; MusicPlayer в ходе разведки не менялся.

Все пути абсолютные, номера строк — на момент снапшота.

---

# Часть 1. Верхний навбар внутренних экранов

## 1.1. Где что лежит

| Что | Файл | Строки |
|---|---|---|
| `ScrollOffsetPreferenceKey` | `/Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Features/NavBar.swift` | 5–10 |
| `ScrollOffsetModifier` | там же | 12–31 |
| **`NavBar`** — сам компонент | там же | 33–172 |
| `BackButton` | там же | 174–191 |
| `SearchButton` | там же | 193–214 |
| `SkipButton` | там же | 216–240 |
| `View.trackScrollOffset(in:offset:)` | там же | 243–247 |

**Важно не перепутать.** В MusicPlayer два разных навбара:

- `NavBar` (`Features/NavBar.swift`) — **это наш кандидат**: back + обложка + тайтл, появляющиеся по скроллу. Используется на Album / Artist / Playlist / AlbumSkeletonScreen / Wizard.
- `TopNavBar` (`Features/TopNavBar.swift`, 7–159) — главная навигация с текстовыми табами («For You / Trends / Spiritual»), точкой-индикатором и аватаркой. Не то, что нужно, но его подложку `TopNavBarBackground` (строки 164–204) стоит посмотреть: там другой рецепт фона — постоянный градиент + **два** VariableBlur (4 и 14) без завязки на скролл.

## 1.2. Полный исходник `NavBar.swift`

```swift
import SwiftUI
import VariableBlur

// MARK: - Scroll Position Tracking
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ScrollOffsetModifier: ViewModifier {
    let coordinateSpace: String
    @Binding var offset: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .preference(
                            key: ScrollOffsetPreferenceKey.self,
                            value: -geometry.frame(in: .named(coordinateSpace)).minY
                        )
                }
            )
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                offset = value
            }
    }
}

struct NavBar: View {
    @Environment(\.dismiss) private var dismiss

    let showBackButton: Bool
    let showSearchButton: Bool
    let showSkipButton: Bool
    let showBackground: Bool
    let onSearchTap: (() -> Void)?
    let onSkipTap: (() -> Void)?
    let onDebugTap: (() -> Void)?
    let onYasminaTap: (() -> Void)?
    let contentName: String?
    let contentImageName: String?
    var contentImageURL: URL? = nil
    var roundedCover: Bool = false
    let scrollOffset: CGFloat

    init(
        showBackButton: Bool = true,
        showSearchButton: Bool = true,
        showSkipButton: Bool = false,
        showBackground: Bool = true,
        onSearchTap: (() -> Void)? = nil,
        onSkipTap: (() -> Void)? = nil,
        onDebugTap: (() -> Void)? = nil,
        onYasminaTap: (() -> Void)? = nil,
        contentName: String? = nil,
        contentImageName: String? = nil,
        contentImageURL: URL? = nil,
        roundedCover: Bool = false,
        scrollOffset: CGFloat = 0
    ) {
        self.showBackButton = showBackButton
        self.showSearchButton = showSearchButton
        self.showSkipButton = showSkipButton
        self.showBackground = showBackground
        self.onSearchTap = onSearchTap
        self.onSkipTap = onSkipTap
        self.onDebugTap = onDebugTap
        self.onYasminaTap = onYasminaTap
        self.contentName = contentName
        self.contentImageName = contentImageName
        self.contentImageURL = contentImageURL
        self.roundedCover = roundedCover
        self.scrollOffset = scrollOffset
    }

    // MARK: - Computed Properties
    private var contentVisibility: Double {
        // Content appears smoothly when scroll position reaches 360
        return scrollOffset >= 360 ? 1.0 : 0.0
    }

    private var backgroundOpacity: Double {
        // Background fades in from 200pt scroll offset over 80pt
        return min(1.0, Double(max(0, scrollOffset - 200) / 80))
    }

    var body: some View {
        HStack {
            BackButton()

            // Left-aligned content with image and title
            if let contentName = contentName, let contentImageName = contentImageName {
                HStack(spacing: 6) {
                    CachedAsyncImage(url: contentImageURL, assetName: contentImageName)
                        .frame(width: 40, height: 40)
                        .clipShape(roundedCover ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: 6)))
                        .overlay(
                            (roundedCover ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: 6)))
                                .stroke(Color.white.opacity(0.08), lineWidth: 0.66)
                        )

                    Text(contentName)
                        .font(.Headline4)
                        .foregroundColor(.fill1)
                        .lineLimit(1)
                }
                .opacity(contentVisibility)
                .animation(.easeInOut(duration: 0.4), value: scrollOffset)
            }

            Spacer()

            if showSearchButton {
                SearchButton(onTap: onSearchTap)
            } else if showSkipButton {
                HStack(spacing: 8) {
                    if let onYasminaTap {
                        SkipButton(title: "Yasmina", onTap: onYasminaTap)
                    }
                    if let onDebugTap {
                        SkipButton(title: "Debug", onTap: onDebugTap)
                    }
                    SkipButton(onTap: onSkipTap)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 0)
        .padding(.bottom, 8)
        .background {
            if showBackground {
                ZStack {
                    VariableBlurView(maxBlurRadius: 16, direction: .blurredTopClearBottom)
                        .frame(height: 105)
                        .ignoresSafeArea()

                    // Dark gradient overlay for better contrast
                    LinearGradient(
                        gradient: Gradient(stops: [
                            Gradient.Stop(color: .black.opacity(0), location: 0.00),
                            Gradient.Stop(color: .black.opacity(0.07), location: 0.11),
                            Gradient.Stop(color: .black.opacity(0.13), location: 0.21),
                            Gradient.Stop(color: .black.opacity(0.18), location: 0.28),
                            Gradient.Stop(color: .black.opacity(0.24), location: 0.34),
                            Gradient.Stop(color: .black.opacity(0.29), location: 0.39),
                            Gradient.Stop(color: .black.opacity(0.34), location: 0.44),
                            Gradient.Stop(color: .black.opacity(0.39), location: 0.48),
                            Gradient.Stop(color: .black.opacity(0.44), location: 0.51),
                            Gradient.Stop(color: .black.opacity(0.49), location: 0.55),
                            Gradient.Stop(color: .black.opacity(0.53), location: 0.59),
                            Gradient.Stop(color: .black.opacity(0.58), location: 0.65),
                            Gradient.Stop(color: .black.opacity(0.63), location: 0.71),
                            Gradient.Stop(color: .black.opacity(0.69), location: 0.79),
                            Gradient.Stop(color: .black.opacity(0.74), location: 0.88),
                            Gradient.Stop(color: .black.opacity(0.8), location: 1.00),
                            ],),
                        startPoint: .bottom,
                        endPoint: .top
                    )
                    .frame(height: 120)
                    .ignoresSafeArea()
                }
                .opacity(backgroundOpacity)
                .animation(.easeOut(duration: 0.2), value: scrollOffset)
            }
        }
    }
}

struct BackButton: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button(action: { dismiss() }) {
            Image(systemName: "chevron.left")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.fill1)
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 100)
                    .stroke(Color.white.opacity(0.1), lineWidth: 0.66)
                )
                .clipShape(Circle())
        }
    }
}

struct SearchButton: View {
    let onTap: (() -> Void)?

    init(onTap: (() -> Void)? = nil) {
        self.onTap = onTap
    }

    var body: some View {
        Button(action: { onTap?() }) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.fill1)
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 100)
                    .stroke(Color.white.opacity(0.1), lineWidth: 0.66)
                )
                .clipShape(Circle())
        }
    }
}

struct SkipButton: View {
    let title: String
    let onTap: (() -> Void)?

    init(title: String = "Skip", onTap: (() -> Void)? = nil) {
        self.title = title
        self.onTap = onTap
    }

    var body: some View {
        Button(action: { onTap?() }) {
            Text(title)
                .font(.Text1)
                .foregroundColor(.fill1)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial.opacity(0.5))
                .overlay(
                    Capsule()
                    .stroke(Color.white.opacity(0.1), lineWidth: 0.66)
                )
                .clipShape(Capsule())
        }
    }
}

// MARK: - View Extension
extension View {
    func trackScrollOffset(in coordinateSpace: String, offset: Binding<CGFloat>) -> some View {
        self.modifier(ScrollOffsetModifier(coordinateSpace: coordinateSpace, offset: offset))
    }
}
```

## 1.3. Зависимости

### `Color.fill1`
`/Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Colors.swift:5`

```swift
extension Color {
    static let fill1 = Color.white           // :5
    static let fill5 = Color.white.opacity(0.6)   // :7
    static let subtitle = Color.white.opacity(0.5) // :8
    static let accent = Color(red: 0.64, green: 0.2, blue: 1.0) // :9
}
```

У нас соответствие: `.fill1` → `Color.fillOne`, `.subtitle` → `Color.fillSubtitle`, `white.opacity(0.08)` → `Color.fillNine`, `white.opacity(0.1)` → `Color.buttonsPrimary` (`PlusProtoApp/DesignSystem/Tokens.swift:9–33`).

### Шрифты `.Headline4`, `.Text1`
`/Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Fonts/CustomFonts.swift:10–21`

```swift
static var Headline1: Font { Font.custom("YangoGroupHeadlineAR-ExtraBold", size: 48) }
static var Headline2: Font { Font.custom("YangoGroupHeadlineAR-ExtraBold", size: 40) }
static var Headline3: Font { Font.custom("YangoGroupHeadlineAR-ExtraBold", size: 32) }
static var Headline4: Font { Font.custom("YangoGroupHeadlineAR-ExtraBold", size: 28) }  // ← тайтл навбара
static var Headline5: Font { Font.custom("YangoGroupHeadlineAR-ExtraBold", size: 24) }
static var Title1: Font { Font.custom("YangoText-Medium", size: 24) }
static var Title2: Font { Font.custom("YangoText-Medium", size: 18) }
static var Text1: Font { Font.custom("YangoText-Medium", size: 15) }  // ← SkipButton
static var Text2: Font { Font.custom("YangoText-Medium", size: 13) }
static var Text3: Font { Font.custom("YangoText-Medium", size: 11) }
```

**Внимание при переносе:** `Headline4` — это 28pt ExtraBold-хедлайн. В навбаре высотой 48pt он занимает почти всю высоту. Для «Плюса» это, скорее всего, слишком крупно — макет надо сверять отдельно, не копировать 28pt вслепую.

### `CachedAsyncImage`
`/Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Features/CachedAsyncImage.swift:4–40` — вью с двумя источниками: URL (через `ImageLoader` + `NSCache` на 200 объектов / 100 МБ, файл 44–100) и fallback на bundled asset по имени. Плейсхолдер — `Rectangle().fill(Color.white.opacity(0.08))`.

У нас эквивалент уже есть: `ArtworkImage` / `ResolvedArtwork` в `/Users/dimazhuravlev/Repos/plus-proto-app/PlusProtoApp/DesignSystem/ArtworkImage.swift` (плейсхолдер — `Color.buttonsPrimary`). Переносить `CachedAsyncImage` не нужно.

### `AnyShape`
Собственного определения в MusicPlayer нет — это системный `SwiftUI.AnyShape` (iOS 16+). Используется, чтобы одним `clipShape` переключаться между `Circle()` (артист) и `RoundedRectangle(cornerRadius: 6)` (альбом/плейлист).

### `VariableBlurView`
Локальный SPM-пакет `/Users/dimazhuravlev/Repos/MusicPlayer/VariableBlur/Sources/VariableBlur/VariableBlur.swift` (107 строк).

Суть: `UIVisualEffectView` со стилем `.regular`, у которого backdrop-слою через рантайм-подмену ставится приватный `CAFilter` типа `"variableBlur"`. Радиус в каждом пикселе задаётся альфой градиентной маски (`CIFilter.linearGradient`, 100×100), поэтому блюр плавно сходит на нет по вертикали.

```swift
public enum VariableBlurDirection {
    case blurredTopClearBottom
    case blurredBottomClearTop
}

public struct VariableBlurView: UIViewRepresentable {
    public var maxBlurRadius: CGFloat = 20
    public var direction: VariableBlurDirection = .blurredTopClearBottom
    /// Небольшое отрицательное значение стартует блюр не с нуля — иногда выглядит лучше.
    public var startOffset: CGFloat = 0
    // makeUIView → VariableBlurUIView(maxBlurRadius:direction:startOffset:)
}
```

Ключевые строки `VariableBlurUIView`:
- `:49–56` — достаём приватный класс `CAFilter`, создаём `filterWithType: "variableBlur"`;
- `:62–64` — `inputRadius`, `inputMaskImage`, `inputNormalizeEdges = true`;
- `:68–71` — заменяем стандартные фильтры backdrop-слоя на единственный variableBlur;
- `:74–76` — гасим тонирующие подслои, иначе будет видна жёсткая граница;
- `:83–87` — в `didMoveToWindow` ставим `scale` = `displayScale`, иначе пикселизация на нерасплывшемся крае;
- `:93–105` — генерация маски: линейный градиент чёрный→прозрачный, для `blurredBottomClearTop` точки инвертируются.

**У нас в проекте этого нет.** В `/Users/dimazhuravlev/Repos/plus-proto-app/PlusProtoApp/DesignSystem/GlassSurface.swift:79–118` живёт `BackdropBlurView` — тот же приём подмены `CAFilter`, но с **однородным** `gaussianBlur` и управляемым `inputRadius`, без маски. Чтобы получить прогрессивный блюр под навбаром, нужно либо (а) допилить `BackdropBlurView` до маски (добавить ветку `variableBlur` + генерацию `inputMaskImage`), либо (б) обойтись `.mask(LinearGradient(...))` поверх обычного блюра — дешевле и без нового приватного API. См. `docs/DECISIONS.md` про приоритет производительности.

### `.ultraThinMaterial.opacity(0.5)`
Фон круглых кнопок back/search — системный материал, приглушённый до 0.5. У нас аналог — `.glassCircle()` (`GlassSurface.swift:55–57`: `Circle`, blur 20, бордер white 6%).

## 1.4. Геометрия и типографика

| Параметр | Значение | Где |
|---|---|---|
| Горизонтальные поля бара | **12pt** | `NavBar.swift:131` |
| Верхний padding | 0 (бар лежит под safe area) | `:132` |
| Нижний padding | **8pt** | `:133` |
| Высота контента бара | **48pt** (кнопка 40 + 8 нижнего) | производная |
| Кнопка back | **40×40**, круг | `:182, :188` |
| Иконка back | SF Symbol `chevron.left`, `.system(size: 16, weight: .semibold)`, `.fill1` | `:179–181` |
| Бордер кнопки | white 10%, **0.66pt** | `:186` |
| Фон кнопки | `.ultraThinMaterial.opacity(0.5)` | `:183` |
| Кнопка search | ровно та же геометрия, глиф `magnifyingglass` | `:202–211` |
| Обложка в навбаре | **40×40** | `:99` |
| Радиус обложки | **6pt** (`roundedCover: true` → `Circle()`) | `:100` |
| Бордер обложки | white **8%**, 0.66pt | `:103` |
| Зазор обложка↔тайтл | **6pt** | `:97` |
| Тайтл | `.Headline4` = YangoGroupHeadlineAR-ExtraBold **28pt**, `.fill1`, `lineLimit(1)` | `:107–109` |
| Зазор back↔блок обложки | дефолтный `HStack` spacing (**8pt**) — явно не задан | `:92` |
| SkipButton | `.Text1` 15pt, padding 16×12, `Capsule`, бордер white 10% × 0.66 | `:227–237` |
| Высота VariableBlur фона | **105pt** | `:138` |
| Максимальный радиус блюра | **16** | `:137` |
| Высота градиента фона | **120pt** | `:164` |
| Градиент фона | 16 стопов, снизу вверх, `black 0.8` вверху → `black 0` внизу | `:143–163` |

## 1.5. Реакция на скролл

### Откуда берётся offset

Механика двухступенчатая:

1. Экран объявляет `@State private var scrollOffset: CGFloat = 0` (`Album.swift:11`, `Artist.swift:13`, `Playlist.swift:10`, `AlbumSkeletonScreen.swift:9`).
2. Первым элементом внутри `ScrollView` кладётся невидимый датчик высотой 1pt:
   ```swift
   Color.clear
       .frame(height: 1)
       .trackScrollOffset(in: "scroll", offset: $scrollOffset)   // Album.swift:60–62
   ```
3. `ScrollView` помечен `.coordinateSpace(name: "scroll")` (`Album.swift:106`) и `.ignoresSafeArea(.container, edges: .top)` (`:107`) — контент начинается от физического верха экрана, поэтому `offset == 0` соответствует нескролленному состоянию.
4. `ScrollOffsetModifier` (`NavBar.swift:12–31`) вешает на датчик `GeometryReader` в `.background`, публикует `-geometry.frame(in: .named("scroll")).minY` через `PreferenceKey` и в `onPreferenceChange` пишет значение в биндинг.

Итого `scrollOffset` = сколько пунктов контента ушло вверх, положительное при скролле вниз, отрицательное при оттяжке.

### Порог появления тайтла+обложки

```swift
private var contentVisibility: Double {
    return scrollOffset >= 360 ? 1.0 : 0.0     // NavBar.swift:81–84
}
```

Это **бинарный** переключатель, а не рампа. Плавность даёт не формула, а модификатор:

```swift
.opacity(contentVisibility)
.animation(.easeInOut(duration: 0.4), value: scrollOffset)   // :111–112
```

То есть: как только скролл переваливает 360pt, `opacity` скачком меняет цель 0→1, а `.animation` разводит это в кроссфейд `easeInOut` длительностью **0.4s**. Ни `offset`, ни `scale`, ни `blur` у тайтла нет — только прозрачность.

Порог 360 подобран под шапку альбома: `AlbumHeader` имеет `.padding(.top, 120)` (`Album.swift:321`), обложка 280×280 (`:242`), то есть нижний край обложки — на 400pt. Тайтл проявляется примерно тогда, когда обложка почти целиком ушла под навбар.

**Слабое место:** `value: scrollOffset` вместо `value: contentVisibility`. Транзакция пересоздаётся на каждом кадре скролла, хотя цель меняется один раз. Работает, но это анимация «на дребезжащем ключе» — при переносе ставить `value: contentVisibility` (или сразу `Bool`).

### Порог появления фона

```swift
private var backgroundOpacity: Double {
    return min(1.0, Double(max(0, scrollOffset - 200) / 80))   // NavBar.swift:86–89
}
```

Линейная рампа: **0 до 200pt → 1.0 на 280pt**, ширина растворения 80pt. Фон, таким образом, приезжает заметно раньше тайтла (200 против 360) — сначала подложка, потом текст.

```swift
.opacity(backgroundOpacity)
.animation(.easeOut(duration: 0.2), value: scrollOffset)   // :167–168
```

`.easeOut(0.2)` поверх уже непрерывной рампы работает как сглаживающий лаг ~0.2s — фон чуть отстаёт от пальца, что скрывает дискретность preference-обновлений.

Гаснет/проявляется **весь блок целиком**: и VariableBlur, и градиент внутри одного `ZStack` с общей `.opacity`.

### Сводная шкала

```
offset:  0 ──────────── 200 ──── 280 ──────── 360 ────────►
фон:     прозрачный   старт   полный        (держится)
тайтл:   скрыт                              появление, 0.4s easeInOut
```

## 1.6. Как встроен в экран

Ни `toolbar`, ни `safeAreaInset` — навбар кладётся **оверлеем в `ZStack`** через `VStack { NavBar(...); Spacer() }`.

`Album.swift:25–50`:

```swift
var body: some View {
    ZStack {
        backgroundView          // Color.black.ignoresSafeArea()
        contentView             // ScrollView

        // Fixed top navbar that stays in place during navigation
        VStack {
            NavBar(
                showBackButton: true,
                showSearchButton: true,
                onSearchTap: {},
                contentName: displayAlbumTitle,
                contentImageName: albumImageName,
                contentImageURL: albumImageURL,
                scrollOffset: scrollOffset
            )
            Spacer()
        }
    }
    #if os(iOS)
    .navigationBarHidden(true)
    #endif
    .onAppear { showcaseNavState.isShowingDetail = true }
    .onDisappear { showcaseNavState.isShowingDetail = false }
}
```

Существенные детали:

- **`.navigationBarHidden(true)`** — системный бар выключен, экраны пушатся в `NavigationStack` (`MusicApp.swift:188`, `:242`) через `.navigationDestination` (`ShowcaseFeedView.swift:68–74`).
- Навбар **не** уходит под safe area — `VStack` его прижимает к верхней safe-area границе. Под статус-бар лезет только фон: у `VariableBlurView` и градиента внутри `.background { }` стоит `.ignoresSafeArea()`, а собственные высоты 105/120 больше 48pt самого бара, поэтому подложка выпирает вверх и накрывает статус-бар.
- Скролл-контент, наоборот, идёт под навбар: `.ignoresSafeArea(.container, edges: .top)` на `ScrollView` (`Album.swift:107`), компенсируется `.padding(.top, 120)` у шапки (`:321`).
- `.onAppear/.onDisappear` дёргают `showcaseNavState.isShowingDetail` — глобальный флаг «мы на внутреннем экране», по нему прячется нижний бар витрины.

Точно так же навбар встроен в:
- `/Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Screens/Artist.swift:24–36` — плюс `roundedCover: true` (круглая аватарка артиста);
- `/Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Screens/Playlist.swift:27–37` — без `contentImageURL`, только asset;
- `/Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Features/AlbumSkeletonScreen.swift:61–70` — `contentName: nil, contentImageName: nil`, то есть только back+search;
- `/Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Screens/Wizard.swift:50–70` — единственный случай с `showBackground: false`, `showSkipButton: true`, `scrollOffset: 0` (навбар статичный, внутри `VStack`, а не `ZStack`).

## 1.7. Что делает back

`BackButton` (`NavBar.swift:174–191`) держит **собственный** `@Environment(\.dismiss)` и вызывает `dismiss()` — то есть просто снимает верхний экран `NavigationStack`. Никакой кастомной анимации, хаптики или колбэка. Кнопка не параметризуется вообще: ни экшена, ни заголовка на вход.

## 1.8. Дефекты, которые не стоит переносить

1. **`showBackButton` — мёртвый параметр.** `BackButton()` рендерится безусловно (`:93`), флаг нигде не проверяется. Все вызывающие передают `true`, поэтому баг не всплыл.
2. **`@Environment(\.dismiss)` в самом `NavBar` (`:34`) не используется** — дублирует то, что есть в `BackButton`.
3. **Обложка+тайтл требуют оба поля.** Условие `if let contentName, let contentImageName` (`:96`) — при `contentImageName == nil` тайтл не покажется даже при заданном `contentName`. Для «Плюса», где сущность может быть без обложки, лучше развязать.
4. **`.animation(..., value: scrollOffset)`** вместо `value:` от производного состояния (см. 1.5).
5. **`PreferenceKey` + `onPreferenceChange`** пишет `@State` экрана на каждом кадре скролла → тело экрана переоценивается каждый кадр. У нас deployment target **iOS 26** (`PlusProtoApp.xcodeproj/project.pbxproj:285`), поэтому доступен `.onScrollGeometryChange(for:of:action:)` (iOS 18+) — он дешевле и не требует ни coordinate space, ни датчика-распорки:
   ```swift
   .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y + $0.contentInsets.top } action: { _, new in
       scrollOffset = new
   }
   ```
   А для чистой визуальной реакции без `@State` вообще — `.visualEffect { content, proxy in ... }`.
6. **Пороги 200/360 — абсолютные пункты**, завязанные на конкретную шапку альбома. При переносе считать от реальной высоты шапки (`headerHeight - navBarHeight`), иначе на экране книги/фильма с другой шапкой всё разъедется.

---

# Часть 2. Инерция вращения обложки мини-плеера

## 2.1. Три разные реализации — важно не перепутать

| Компонент | Файл | Скорость | Инерция |
|---|---|---|---|
| `MiniPlayerV2` | `Features/MiniPlayerV2.swift:34–49` | 18°/с | **нет**, скорость постоянная |
| `MiniPlayer` (v1) | `Features/MiniPlayer.swift:47–65` | 40°/с | торможение — да, разгон — **мгновенный** (осознанно) |
| `RotatingCoverDemo` | `Features/RotatingCoverDemo.swift:10–50` | 60°/с | **симметричная**: и разгон, и торможение |

Мы в `plus-proto-app` скопировали именно `MiniPlayerV2` — самый простой из трёх, у которого инерции нет вовсе. Инерция живёт в `MiniPlayer.swift` и `RotatingCoverDemo.swift`.

Перекрёстная проверка: `grep -rn "currentSpeed\|targetSpeed"` по всему MusicPlayer даёт только эти два файла (третье совпадение — `lerp` в `Yasmina/Components/SpeakerStage.swift:53`, к вращению отношения не имеет).

## 2.2. `RotatingCoverDemo` — эталонная демка инерции

`/Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Features/RotatingCoverDemo.swift`, файл целиком (66 строк):

```swift
import SwiftUI

/// Демо-компонент: круглый кавер с инерционным вращением при старте и остановке.
///
/// Механика инерции:
/// Каждый кадр текущая скорость (`currentSpeed`) приближается к целевой на 4%
/// от оставшейся разницы — это классический lerp (экспоненциальное сглаживание).
/// Работает одинаково для разгона (isPlaying = true → target = 60°/с)
/// и торможения (isPlaying = false → target = 0°/с).
struct RotatingCoverDemo: View {                        // :10

    @Binding var isPlaying: Bool                        // :12

    /// Имя asset'а обложки
    let coverImage: String                              // :15

    @State private var rotation: Double = 0             // :17
    @State private var lastUpdateTime: Date = Date()    // :18
    @State private var currentSpeed: Double = 0         // :19

    /// Конечная скорость вращения, градусов в секунду
    private let targetSpeed: Double = 60                // :22

    /// Коэффициент lerp — доля сближения с целевой скоростью за один кадр.
    /// Увеличить (напр. 0.08) → быстрее разгон/торможение.
    /// Уменьшить (напр. 0.02) → медленнее, более «тяжёлый» маховик.
    private let lerpFactor: Double = 0.04               // :27

    var body: some View {
        TimelineView(.animation) { timeline in          // :30
            Image(coverImage)
                .resizable()
                .scaledToFill()
                .frame(width: 56, height: 56)
                .clipShape(Circle())
                .rotationEffect(.degrees(rotation))     // :36
                .onChange(of: timeline.date) { _, newTime in   // :37
                    let delta = newTime.timeIntervalSince(lastUpdateTime)
                    lastUpdateTime = newTime

                    // Плавно тянемся к целевой скорости (0 или targetSpeed)
                    let target = isPlaying ? targetSpeed : 0     // :42
                    currentSpeed += (target - currentSpeed) * lerpFactor   // :43

                    rotation += currentSpeed * delta             // :45
                    rotation = rotation.truncatingRemainder(dividingBy: 360)  // :46
                }
        }
    }
}
```

## 2.3. `MiniPlayer` (v1) — асимметричный вариант

`/Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Features/MiniPlayer.swift`, ядро вращения (строки 9–18 и 47–65):

```swift
@State private var rotation: Double = 0                 // :9
@State private var lastUpdateTime: Date = Date()        // :10
@State private var currentSpeed: Double = 0             // :11
@State private var previousIsPlaying: Bool = false      // :13
private let targetSpeed: Double = 40 // degrees per second   // :18

// ...
.onChange(of: timeline.date) { _, newTime in            // :47
    let delta = newTime.timeIntervalSince(lastUpdateTime)

    // Manual interpolation for smooth acceleration/deceleration
    let target = isPlaying ? targetSpeed : 0            // :51
    currentSpeed += (target - currentSpeed) * 0.04      // :52

    rotation += currentSpeed * delta                    // :54
    rotation = rotation.truncatingRemainder(dividingBy: 360)   // :55
    lastUpdateTime = newTime

    // On play start: jump to full speed immediately so rotation is visible right away.
    // Smooth lerp is kept for deceleration (spin-down) when pausing.
    if isPlaying && !previousIsPlaying {                // :60
        currentSpeed = targetSpeed                      // :61
        playStartHaptic()                               // :62
    }
    previousIsPlaying = isPlaying                       // :64
}
```

**Это важнейший вывод части 2.** Автор сначала сделал симметричный lerp (как в демке), а потом сознательно откатил разгон в мгновенный: комментарий `:58–59` прямым текстом говорит, что плавный разгон не читается («so rotation is visible right away»), и инерция оставлена только на торможение. При скорости 40°/с (оборот за 9 с) плавный старт действительно почти невидим — а у нас скорость ещё вдвое ниже, 18°/с.

Обвязка вращения в `MiniPlayer` (не относится к инерции, но контекст): вокруг обложки — кольцо прогресса (`:28–45`, `stroke(white 0.1, lineWidth: 2)` + `trim(from:0,to:progress)` белым, оба повёрнуты на −90°), обложка 56×56 внутри рамки 68×68, кроссфейд обложки при смене трека (`:66–77`), press-скейл 0.95 (`:79–80`), CoreHaptics-паттерн `hapticContinuous` intensity 0.40 / sharpness 0.30 / duration 0.50 на старте (`:125–151`).

## 2.4. `MiniPlayerV2` — то, что скопировано у нас (инерции нет)

`/Users/dimazhuravlev/Repos/MusicPlayer/MusicPlayer/Features/MiniPlayerV2.swift:8–16, 34–49`:

```swift
@State private var coverRotation: Double = 0            // :8
@State private var lastTimelineDate: Date = Date()      // :9
private let coverDegreesPerSecond: Double = 18          // :11
private let barHeight: CGFloat = 56                     // :13
private let cornerRadius: CGFloat = 100                 // :15
private let coverSize: CGFloat = 48                     // :16

TimelineView(.animation) { timeline in                  // :34
    CachedAsyncImage(url: track.albumCoverURL, assetName: track.albumCover)
        .frame(width: coverSize, height: coverSize)
        .clipShape(Circle())
        .rotationEffect(.degrees(coverRotation))        // :38
        .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 0.66))
        .onChange(of: timeline.date) { _, newTime in    // :43
            let delta = newTime.timeIntervalSince(lastTimelineDate)
            coverRotation += coverDegreesPerSecond * delta   // :45
            coverRotation = coverRotation.truncatingRemainder(dividingBy: 360)
            lastTimelineDate = newTime
        }
}
```

Заметь: здесь нет даже проверки `isPlaying` — обложка крутится всегда.

## 2.5. Механика и константы — разбор

Механика **не** пружина и **не** SwiftUI-анимация с кривой. Это ручной численный интегратор в `onChange(of: timeline.date)`:

```
скорость:   v ← v + (target − v)·k        // экспоненциальное сглаживание (lerp), покадрово
угол:       θ ← θ + v·Δt                  // явный метод Эйлера
нормализация: θ ← θ mod 360
```

| Константа | `RotatingCoverDemo` | `MiniPlayer` v1 | `MiniPlayerV2` |
|---|---|---|---|
| Целевая скорость `targetSpeed` | 60 °/с | 40 °/с | 18 °/с (константа скорости, не цель) |
| Коэффициент lerp `k` | 0.04 | 0.04 (литерал) | — |
| Кривая разгона | экспонента | **мгновенно** (`v = target`) | мгновенно |
| Кривая торможения | экспонента | экспонента | мгновенно |
| Диаметр обложки | 56 | 56 (рамка 68) | 48 |
| Источник тика | `TimelineView(.animation)` | `TimelineView(.animation)` | `TimelineView(.animation)` |

### Что такое `k = 0.04` во времени

Покадровый lerp — это дискретная экспонента: разница `(target − v)` умножается на `(1 − k)` каждый кадр. За `n` кадров: `(1 − k)ⁿ`. Приравняв к `e^(−t/τ)` при `n = t/Δt`, получаем постоянную времени

```
τ = −Δt / ln(1 − k)
```

При `k = 0.04`: `ln(0.96) = −0.040822`, значит

- **60 Гц:** `τ = (1/60)/0.040822 ≈ 0.408 с`
- **120 Гц (ProMotion):** `τ = (1/120)/0.040822 ≈ 0.204 с`

**Это баг механики, а не фича:** одна и та же константа даёт вдвое более резкое торможение на ProMotion. Автор подбирал 0.04 на каком-то одном устройстве. Наша реализация от этого должна быть свободна по построению.

Практические следствия для `RotatingCoverDemo` (60°/с): выбег после паузы = `v₀·τ` = 12.2° на 120 Гц и 24.5° на 60 Гц. То есть на iPhone Pro обложка «докатывается» на треть меньше, чем на не-ProMotion.

### Как хранится угол и почему не теряется при паузе

Угол хранится в `@State rotation` и **накапливается**: `rotation += v·Δt`. При паузе `v` уходит в 0, но `rotation` остаётся тем значением, до которого докрутилось — новое накопление продолжится с него. То есть непрерывность обеспечена самим фактом накопления.

Цена: `@State` пишется **на каждом кадре внутри тела `TimelineView`**. Это ровно тот приём, который у нас запрещён (`docs/DECISIONS.md`, запись от 2026-08-22 про вращение обложки и про белый экран при 100% CPU).

Второй скрытый дефект накопительной схемы: `lastUpdateTime` инициализирован `Date()` в момент создания вью. Если вью пролежала в дереве без тиков (скрытая вкладка, приложение в фоне), первый же `delta` окажется огромным и обложка прыгнет на произвольный угол.

---

# Чего не хватает нашей реализации

## 3.1. Что у нас сейчас

`/Users/dimazhuravlev/Repos/plus-proto-app/PlusProtoApp/Chrome/ActionBarView.swift:621–649`
(файл активно правится — номера строк дрейфуют, искать по `struct CoverSpin`):

```swift
/// Угол обложки — чистая функция от времени, а не накапливаемое состояние.
/// Запись `@State` из `onChange(of: timeline.date)` (так сделано в MusicPlayer)
/// замыкает цикл перерисовки и вешает экран — этот приём сюда не переносим.
private struct CoverSpin {
    /// Угол на момент старта текущей фазы
    var base: Double = 0
    /// Начало фазы вращения; nil — обложка стоит
    var anchor: Date?

    var isSpinning: Bool { anchor != nil }

    func degrees(at date: Date) -> Double {
        guard let anchor else { return base }
        let elapsed = date.timeIntervalSince(anchor)
        return (base + elapsed * ActionBarMotion.coverDegreesPerSecond)
            .truncatingRemainder(dividingBy: 360)
    }

    /// Идемпотентно: повторный вызов с тем же состоянием угол не двигает.
    mutating func set(spinning: Bool, at date: Date = .now) {
        guard spinning != isSpinning else { return }
        if spinning {
            anchor = date
        } else {
            base = degrees(at: date)
            anchor = nil
        }
    }
}
```

Применение — `ActionBarView.swift:694–715` (`private var cover`): когда `spin.isSpinning`, обложка заворачивается в `TimelineView(.animation)` и угол берётся из чистой функции; когда стоит — `TimelineView` вообще выкидывается из дерева и остаётся статический `rotationEffect(.degrees(spin.base))`. Флаг переключается из `.onChange(of: isPlaying)` и один раз в `.task`. Константа — `ActionBarMotion.coverDegreesPerSecond = 18` (`ActionBarView.swift:18`).

Свойства, которые обязаны сохраниться:
1. **Угол — чистая функция от `timeline.date`.** Ни одной записи `@State` за кадр.
2. **`@State` пишется только на смене фазы** (play↔pause), то есть 1–2 раза за взаимодействие.
3. **Когда обложка стоит, `TimelineView` исчезает из дерева** — нулевой расход в покое.

## 3.2. Дефицит

Скорость — константа `ω = 18 °/с`, переключаемая ступенькой. На старте обложка мгновенно набирает полную угловую скорость, на паузе мгновенно замирает. Физически это выглядит как «щелчок»: у диска нет массы.

## 3.3. Предлагаемая математика — экспоненциальный разгон/торможение с аналитическим интегралом

Модель: скорость релаксирует к цели с постоянной времени `τ`.

```
Дифур:      ω′(t) = (ω_T − ω(t)) / τ
Скорость:   ω(t) = ω_T + (ω₀ − ω_T)·e^(−t/τ)
Угол:       θ(t) = θ₀ + ω_T·t + (ω₀ − ω_T)·τ·(1 − e^(−t/τ))
```

Проверка: `dθ/dt = ω_T + (ω₀−ω_T)·e^(−t/τ) = ω(t)` ✓; при `t = 0` → `θ = θ₀`, `ω = ω₀` ✓.

Здесь `t = date.timeIntervalSince(anchor)`, а `θ₀`, `ω₀`, `ω_T`, `τ` — снапшот, снимаемый **один раз** в момент смены фазы. Угол остаётся чистой функцией от `date` — ровно как сейчас, просто формула из линейной становится «линейная + затухающая экспонента».

Это та же физика, что у покадрового lerp MusicPlayer, но записанная в замкнутом виде: нет ни накопления, ни зависимости от частоты кадров.

### Непрерывность на переключении

В момент `t*` (нажали play/pause) снимаем **и угол, и скорость**:

```
θ₀′ = θ(t*)      // старая формула
ω₀′ = ω(t*)      // старая формула
ω_T′ = playing ? ω_max : 0
τ′   = playing ? τ_start : τ_stop
anchor′ = t*
```

Так как обе величины переносятся, стык C¹-гладкий: ни скачка угла, ни излома скорости. Play/pause можно дёргать сколь угодно часто посреди разгона — формула одна и та же, ветвлений «разгон/торможение» нет вообще.

### Когда выключать `TimelineView`

Экспонента до нуля не доходит, поэтому вводим порог `ε` (°/с) и считаем дату успокоения **заранее**, в момент постановки на паузу:

```
t_settle = τ_stop · ln(ω₀ / ε)
settleDate = anchor + t_settle
```

`isSpinning` становится: `ω_T > 0 || date < settleDate`. Финальный угол известен аналитически (предел при `t → ∞`):

```
θ_∞ = θ₀ + ω₀·τ_stop      // при ω_T = 0
```

Расхождение между `θ(t_settle)` и `θ_∞` равно `ε·τ_stop` — при `ε = 1 °/с` и `τ_stop = 0.75` это 0.75°, невидимо. Значит на успокоении можно честно записать `base = θ_∞`, `anchor = nil` и вернуться к нынешнему статическому рендеру.

Практически это один `@State`-апдейт через `t_settle` секунд после паузы. Организуется либо `.task(id: phaseID) { try? await Task.sleep(until: settleDate); spin.settle() }`, либо (проще и без таймера) — оставить `isSpinning` вычисляемым от `timeline.date` и позволить `TimelineView` самому обнулиться на следующем внешнем апдейте. Первый вариант детерминированнее.

### Стартовые константы

| Константа | Значение | Обоснование |
|---|---|---|
| `ω_max` | 18 °/с | как сейчас, `ActionBarMotion.coverDegreesPerSecond` |
| `τ_start` | **0.28 с** | 95 % скорости за `3τ ≈ 0.84 с`; «недобор» угла против мгновенного старта = `ω·τ = 5.0°` |
| `τ_stop` | **0.75 с** | выбег `ω·τ = 13.5°`; до `ε` — `0.75·ln(18) ≈ 2.2 с` |
| `ε` | **1.0 °/с** | порог успокоения |

Асимметрия `τ_stop > τ_start` намеренная: подхватывает быстро, докатывается долго — так читается «маховик». Это же решение (только в крайней форме, `τ_start = 0`) принял автор MusicPlayer в `MiniPlayer.swift:58–61`.

**Риск, который надо проверить на записи.** При 18 °/с полный оборот занимает 20 секунд. Разгон на 5° и выбег на 13.5° — это 1.4 % и 3.75 % оборота. Есть шанс, что инерция окажется физически честной, но глазом неразличимой — ровно то, на что жаловался автор MusicPlayer при 40 °/с. Проверять записью `xcrun simctl io booted recordVideo` с покадровым разбором; если не читается — либо поднимать `ω_max` до 30–40 °/с, либо задирать `τ_stop` до 1.5–2.0 с (выбег 27–36°).

### Альтернатива: smoothstep с конечной длительностью

Если нужна гарантированно конечная фаза (точный момент выключения `TimelineView` без порога `ε`), берём smoothstep-рампу скорости. `u = t/D`, `s(u) = 3u² − 2u³`, `∫₀ᵘ s = u³ − u⁴/2`.

**Разгон** (`t ≤ D`):
```
ω(t) = ω_max · s(u)
θ(t) = θ₀ + ω_max·D·(u³ − u⁴/2)
```
при `t > D`: `θ(t) = θ₀ + 0.5·ω_max·D + ω_max·(t − D)`.

**Торможение** (`t ≤ D`):
```
ω(t) = ω₀ · (1 − s(u))
θ(t) = θ₀ + ω₀·D·(u − u³ + u⁴/2)
```
при `t ≥ D`: угол замирает на `θ₀ + 0.5·ω₀·D`.

Стартовые значения: `D_start = 0.6 с` (недобор `0.5·18·0.6 = 5.4°`), `D_stop = 1.6 с` (выбег `14.4°`).

Плюс: фаза кончается ровно в `anchor + D`, никаких эпсилонов, скорость на обоих концах точно 0 или точно `ω_max`.
Минус: если play/pause дёрнуть **посреди** рампы, для гладкого стыка нужно решать `s(u₀) = ω_текущая/ω_max` и перепараметризовывать `u`, иначе получишь излом скорости или рестарт с нулевой производной. У экспоненциального варианта этой проблемы нет вовсе.

**Рекомендация: экспонента (3.3).** Причина — `spin.set(spinning:)` дёргается из `.onChange(of: isPlaying)`, а флаг меняют кнопка плеера, карточка витрины и debug-прогон (`ActionBarView.swift:707–709`), то есть быстрые перещёлкивания посреди рампы — штатный сценарий.

### Форма кода (схема, не финал)

```swift
private struct CoverSpin {
    var base: Double = 0            // θ₀ — угол на старте фазы
    var speed: Double = 0           // ω₀ — скорость на старте фазы
    var target: Double = 0          // ω_T — цель фазы
    var tau: Double = 1             // τ текущей фазы
    var anchor: Date = .distantPast

    private func elapsed(_ date: Date) -> Double {
        max(0, date.timeIntervalSince(anchor))
    }

    func degrees(at date: Date) -> Double {
        let t = elapsed(date)
        let decay = exp(-t / tau)
        return (base + target * t + (speed - target) * tau * (1 - decay))
            .truncatingRemainder(dividingBy: 360)
    }

    func velocity(at date: Date) -> Double {
        target + (speed - target) * exp(-elapsed(date) / tau)
    }

    /// true, пока движение видимо: цель ненулевая либо остаточная скорость выше ε.
    func isAnimating(at date: Date) -> Bool {
        target > 0 || velocity(at: date) > CoverSpinConfig.settleEpsilon
    }

    mutating func set(spinning: Bool, at date: Date = .now) {
        guard spinning != (target > 0) else { return }
        base = degrees(at: date)
        speed = velocity(at: date)
        target = spinning ? CoverSpinConfig.maxDegreesPerSecond : 0
        tau = spinning ? CoverSpinConfig.tauStart : CoverSpinConfig.tauStop
        anchor = date
    }
}

/// Магические числа инерции — именованными константами рядом с компонентом
/// (стиль MusicPlayer: YMTiming, ShareCardDragConfig).
private enum CoverSpinConfig {
    static let maxDegreesPerSecond: Double = 18
    static let tauStart: Double = 0.28
    static let tauStop: Double = 0.75
    static let settleEpsilon: Double = 1.0
}
```

Что меняется на стороне вью (`ActionBarView.swift`, `private var cover`): условие `if spin.isSpinning` надо заменить на что-то, что умеет дожить до `settleDate`. Самое дешёвое — держать `TimelineView` в дереве, пока `spin.target > 0 || spin.settleDate > .now`, и один раз после `settleDate` записать `spin.freeze()` (то есть `base = θ_∞; speed = 0; anchor = .distantPast`). Это ровно один дополнительный `@State`-апдейт на паузу — запрет из `docs/DECISIONS.md` не нарушается.

### Сводка отличий от MusicPlayer

| | MusicPlayer (`RotatingCoverDemo` / `MiniPlayer`) | Предлагаемое для `CoverSpin` |
|---|---|---|
| Где считается | покадрово в `onChange(of: timeline.date)` | чистая функция `degrees(at:)` |
| Запись `@State` | каждый кадр (3 переменные) | 2 раза на взаимодействие |
| Зависимость от Hz | **есть**, τ ×2 между 60 и 120 Гц | нет, τ в секундах |
| Разгон | v1 — мгновенно; демка — экспонента | экспонента, `τ_start = 0.28` |
| Торможение | экспонента, `k = 0.04` | экспонента, `τ_stop = 0.75` |
| Конец фазы | не определён, тик идёт вечно | `settleDate`, `TimelineView` выкидывается |
| Прыжок после фона | есть (`lastUpdateTime` протухает) | нет, угол считается от `anchor` |
| Скорость | 60 / 40 °/с | 18 °/с (наша, проверить читаемость) |
