# Передача работы: прототип «Яндекс Плюс»

Документ самодостаточный — рассчитан на агента без контекста предыдущей сессии.
Обновлён: 2026-08-22. Если расходится с кодом — верь коду и обнови этот файл.

---

## 1. Что это за проект

iOS/SwiftUI **дизайн-прототип супераппа «Яндекс Плюс»** — партизанская копия, не продовое приложение. Пользователь (Дима Журавлёв, продуктовый дизайнер в Яндексе) проектирует в нём опыт взаимодействия и тестирует новый дизайн. Данные — моки + бесплатные публичные API.

**Репозиторий**: `/Users/dimazhuravlev/Repos/plus-proto-app`
**Xcode-таргет/схема**: `PlusProtoApp`, bundle `com.dima.PlusProtoApp`, iOS 26.0, Swift 5.

**Концепция** (со слов пользователя): суперапп объединяет развлекательные сервисы — Яндекс Музыка, Кинопоиск, Книги, Алиса. У каждого свой таб. **Внутренние разделы сервисов НЕ проектируем** — переход по табу ведёт на пустую заглушку. **Фокус — на архитектуре, навигации и главном экране «Плюс»**: кросс-сервисной витрине, объединяющей все сервисы в единое целое.

**Сиблинг-проект `/Users/dimazhuravlev/Repos/MusicPlayer`** — источник архитектуры и готовых компонентов. Это предыдущий прототип того же пользователя (музыкальный стриминг). Переиспользуй оттуда всё, что подходит.

---

## 2. Обязательное чтение перед работой

По порядку:

1. **`CLAUDE.md`** (корень репо) — конвенции проекта.
2. **`docs/DECISIONS.md`** — лог всех принятых решений с обоснованиями. **Главный документ.** Каждое новое решение (своё или пользователя) записывай туда сразу, с датой и «почему».
3. **`docs/PLAN.md`** — 9 этапов со статусами и таблица источников данных.
4. **`docs/research/`** — снапшот разведки от 2026-08-22, **не редактировать**:
   - `figma-tabbar.md`, `figma-actionbar.md`, `figma-screen1.md`, `figma-screen2.md`, `figma-tokens.md` — попиксельные спеки из макета с node ID
   - `app-skeleton.md`, `screens.md`, `nav-chrome.md`, `design-kit.md`, `data-apis.md`, `bootstrap.md` — разбор MusicPlayer с путями и номерами строк
   - `history.md` — контекст о пользователе и его рабочих привычках

---

## 3. Три правила, нарушение которых обесценит работу

1. **Пиксель в пиксель с Фигмой.** Типографика, отступы, цвета, градиенты, бордеры — точными значениями из макета, не «примерно». Числа брать из `docs/research/figma-*.md` или перепроверять в Фигме. После каждого компонента — скриншот симулятора и сверка с рендером ноды.

2. **120 fps на скролле витрины — приоритет №1.** Скролл должен быть идеально плавным, без фризов. `LazyVStack`, растеризация тяжёлых blur-слоёв, ambilight считать один раз, видео играть только у видимых карточек. Любой эффект, роняющий фреймрейт, — резать или запекать.

3. **Квота Кинопоиска — 200 запросов в сутки.** Не жечь её отладочными запросами. Проверка остатка: `GET /v1.5/token` (сам не тратится). Дисковый кэш обязателен.

---

## 4. Что уже сделано

### Этап 0 — развёртывание ✅ (2026-08-22)
Проект создан копированием `project.pbxproj` из MusicPlayer + sed-переименование. **pbxproj в формате filesystem-synchronized (objectVersion 77)** — списков файлов внутри нет, поэтому **новые .swift-файлы добавляются простым созданием на диске, проект править не нужно.**

Готово и собирается:
- `PlusProtoApp/PlusProtoAppApp.swift` — точка входа
- `PlusProtoApp/Fonts/FontManager.swift` — runtime-регистрация 4 шрифтов YS
- `PlusProtoApp/DesignSystem/Typography.swift`, `Tokens.swift`
- `PlusProtoApp/Services/KinopoiskService.swift` + `Data/KinopoiskModels.swift`
- Шрифты в `PlusProtoApp/Fonts/`, клипы в `PlusProtoApp/Videos/`
- `PlusProtoApp/APIKeys.swift` — **в гитигноре**, дубликат в `_secrets/APIKeys.swift`

**BUILD SUCCEEDED** на iPhone 17 Pro, шрифт YS отрисовывается.

### Этап 1 — атомы дизайн-системы ✅ (2026-08-22)
Файлы в `PlusProtoApp/DesignSystem/`:
- `GlassSurface.swift` — `.glassPill` / `.glassCircle` / `.glassIconTile`
- `GlassIconButton.swift` — 40×40, `LikeDismissPair`, `PressScaleButtonStyle`
- `GradientText.swift`
- `PlusProgressBar.swift`
- `AmbilightArtwork.swift`
- `AtomsCatalogScreen.swift` — debug-каталог (вставлен в `ShowcaseScreen` под `// ATOMS-CATALOG`, удалить на Этапе 5)

### Этап 2 — каркас ✅ (2026-08-22)
Структура:
- `App/` — `AppTab.swift`, `AppRootView.swift`
- `State/` — `AppNavigationState`, `ActionBarState` (`@Observable`)
- `Chrome/` — `BottomChrome.swift` (+ `PlusChromeMetrics`, `KeyboardObserver`), `TabBarView.swift`, `ActionBarView.swift`
- `Screens/` — `ShowcaseScreen` (заглушка), `ServiceStubScreen`

5 `NavigationStack` с независимыми путями, хром в ZStack вне стеков, `contentMargins(.bottom, 130, for: .scrollContent)`. Env-объекты из корня: `AppNavigationState`, `ActionBarState`, `KeyboardObserver`.

### Этап 3 — таббар ✅ (2026-08-22)
`TabBarView` наполнен по `figma-tabbar.md`: 5×(60×62), тайл 40×40 r14, кроссфейд глифов (PNG Active/Inactive с emboss), pulse PNG, лейблы 11/14, скрим 210pt. Тайминг активации **0,26s `.smooth`**, пресс-стейт `PressScaleButtonStyle` (scale 0.92). Сверка с нодой `2004:9169` — попиксельно.

### Этап 4 — action bar ✅ (2026-08-22)
`ActionBarView` по `figma-actionbar.md` — **полная реализация**, не заглушка:

- **Persistent HStack** (две зоны, gap 8, поля 24, h 60): ширины и opacity анимируются на живых вью; скрытые слои остаются в дереве с opacity 0 — никаких if/else-подмен.
- **4 режима** (`ActionBarMode`): search / music / movie / book. Режим определяется последним потреблённым контентом, не активным табом.
- **Морф 0,32s `.smooth`** (`ActionBarMotion.morph`) на ширины и opacity; прогресс плеера — отдельно `.easeOut(0.12)`.
- **SearchPill**: иконка 24, padding H 18, плейсхолдер YS Display Semibold 20/26; режим icon-only 60×60 в music; flex в book/movie/focused.
- **Тикер плейсхолдера**: три фразы, шаг 42pt за 0,45s, интервал 4s; троеточие 1→2→3 каждые 500ms.
- **MiniPlayerPill**: обложка 48×48, вращение 18°/s при `isMusicPlaying`, подписи 13/16, ♥/⏸, `MiniPlayerProgressFill` (white 6%).
- **Чипы**: book 44×60 r4 + cover 36×52; movie 88×54 r8 + frame 80×46; rot 4°; book без clip (AABB 48×63).
- **Пустое состояние музыки**: только search на всю ширину, круг 60 не показывается.
- **Клавиатура**: тап по search → `isSearchFocused`; `KeyboardObserver` поднимает хром; таббар opacity 0; search flex, mini-player сжимается в 60×60.
- **Sticky payload'ы** в `ActionBarState`: `music`/`movie`/`book` не сбрасываются при смене режима (морф до конца анимации).
- **DEBUG-пресеты** (см. §7): `-debugActionBar search|music|movie|book`, `-debugSearchFocus`. `AtomsCatalogScreen` скрывается при `-debugActionBar` для чистых скриншотов.

**BUILD SUCCEEDED.** Скриншоты 4 режимов + keyboard layout: `/tmp/plus-actionbar-screenshots/` (`actionbar-{search,music,movie,book,keyboard}.png`). При глюке simctl (белый кадр ~67 КБ) — `terminate` + fresh `install`/`launch`. Софт-клавиатура в headless simctl обычно не видна; layout с `-debugSearchFocus` (таббар скрыт, бар поднят) снят, полный кадр с клавиатурой — только в интерактивном Simulator (I/O → Keyboard).

### Ассеты ✅ (2026-08-22)
**31 imageset** в `PlusProtoApp/Assets.xcassets/` (+ `AppIcon`, `AccentColor`):

| Группа | Имена |
|---|---|
| Глифы табов (PNG @3x, original, градиент + emboss запечены) | `tabGlyphPlusActive`/`Inactive`, `tabGlyphMusic*`, `tabGlyphKinopoisk*`, `tabGlyphBooks*`, `tabGlyphAlisa*` |
| Свечение | `tabPulseGlow` |
| Иконки UI (SVG template) | `iconSearch`, `iconHeart`, `iconClose`, `iconPause` |
| Орб «Моя Волна» | `vibeGlyph`, `vibeColorEllipse`, `mockVibeNoise` |
| Моки контента | `mockAlbumCover`, `mockMoviePoster`, `mockPlayerCover`, `mockAvatar`, `mockLogoYura`, `mockBgCollage`, `mockBookIsometric`, `mockBookMini`, `mockChipBook`, `mockChipBookCover`, `mockChipMovieStill`, `mockChipPoster`, `mockVideoStill` |

**Пайплайн экспорта** (см. DECISIONS.md §«Пайплайн ассетов»): брать **`rawImages` ноды**, не `download_assets` PNG (это скриншот ноды с фоном и хромом). Ресемпл LANCZOS под @3x, апскейл запрещён. Монохромные векторы — template-рендеринг. Свечения — предрендеренные PNG @3x. Глифы табов — **два PNG на таб** (Active/Inactive), не template-SVG.

### APIKeys ✅
Локально в `PlusProtoApp/APIKeys.swift` (gitignore):
- `kinopoisk` — kinopoisk.dev, заголовок `X-API-KEY`
- `googleBooks` — ключ получен **2026-08-22**, квота ~1000/сутки

Без `APIKeys.swift` проект не соберётся — скопировать из `_secrets/`.

### Книжный сервис — отложен до Этапа 7
`BooksService`, `WikisourceService`, `BookModels`, `BookCatalog` **отсутствуют** (решение 2026-08-22). Ключ Google Books уже есть; сервисы пишутся вместе с подключением данных на Этапе 7.

---

## 5. Что делать дальше

**Текущий фокус: Этап 5 — витрина «Плюс»** (`docs/research/figma-screen1.md`).

### Что делать на Этапе 5
1. Заменить заглушку `ShowcaseScreen` на ленту из **7 карточек** по макету `2004:10701`.
2. Нерегулярные гэпы 20–66pt, наезды карточек, контент не клипать.
3. Динамический фон от обложки первого блока (blur 100, opacity 0.4, scale ×2).
4. Каскадное появление + лёгкий scroll-параллакс слоёв.
5. Орб «Моя Волна» — живой (glyph + noise + color ellipse).
6. Карточка «продолжить смотреть» — `LoopingVideoPlayer`, muted, только в viewport.
7. Карточка «продолжить чтение» — мок-текст / Wikitext позже.
8. **Удалить** `AtomsCatalogScreen` из `ShowcaseScreen` (блок `// ATOMS-CATALOG`).

### После Этапа 5
- **Этап 6** — второе состояние витрины (`figma-screen2.md`).
- **Этап 7** — данные (Deezer, Kinopoisk, Google Books + Викитека, `BookCatalog`).
- **Этап 8** — полировка (хаптики, тайминги, Instruments).

### Follow-up по action bar (не блокирует Этап 5)
- Покадровая верификация тайминга морфа 0,32s (simctl record).
- Каденция плейсholдера 4s — подтвердить с пользователем.
- Полный keyboard-скрин с софт-клавиатурой — интерактивный Simulator (headless layout уже снят).
- Подключить Deezer-превью → живой прогресс/вращение обложки (Этап 7).

---

## 6. API: что проверено и как этим пользоваться

### Кино — kinopoisk.dev ✅ работает
- База: **`https://api.poiskkino.dev`**
- Заголовок `X-API-KEY`, ключ в `APIKeys.kinopoisk`
- **Квота 200/сутки**, сброс в 21:00 UTC; 5 запросов/сек
- Сервис готов: `KinopoiskService.shared`
- Подпись фильма в макете — поле **`shortDescription`**
- Постеры: Яндекс-CDN. Рабочие: `300x450`, `600x900`, `1920x1080`, `x1000`, `orig`

### Книги — три источника (сервисы на Этапе 7)
- **Обложки** → Google covers CDN, **без ключа**: `books.google.com/books/publisher/content?id={id}&printsec=frontcover&img=1&zoom=1&fife=w1600`
- **Метаданные** → Google Books API, ключ в `APIKeys.googleBooks` (~1000/сутки), `langRestrict=ru`
- **Текст** → `ru.wikisource.org/w/api.php?action=parse&page={путь}&prop=text&format=json&formatversion=2`, без ключа, нужен User-Agent
- **Курируемый каталог 20–30 книг** — состав ещё не выбран (`BookCatalog`)

### Видео — забандленные клипы
`PlusProtoApp/Videos/{fallen-angels,yura,movie-short}.mp4` — H.264, 1080×30, без звука, 3,58 МБ суммарно.

### Исключено
TMDB (DNS → 127.0.0.1), iTunes Search для кино, Gutendex, Open Library как основной источник обложек.

---

## 7. Сборка и верификация

```bash
cd /Users/dimazhuravlev/Repos/plus-proto-app
xcodebuild -project PlusProtoApp.xcodeproj -scheme PlusProtoApp \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug build
```

Запуск и скриншот:
```bash
APP=$(ls -d ~/Library/Developer/Xcode/DerivedData/PlusProtoApp-*/Build/Products/Debug-iphonesimulator/PlusProtoApp.app | head -1)
xcrun simctl install booted "$APP" && xcrun simctl launch booted com.dima.PlusProtoApp
sleep 3 && xcrun simctl io booted screenshot /tmp/plus.png
```

DEBUG-аргументы запуска (парсятся в `PlusProtoAppApp.parseDebugLaunchArguments` → UserDefaults):
```bash
# Стартовый таб (plus|music|kinopoisk|books|alisa)
xcrun simctl launch booted com.dima.PlusProtoApp -debugTab plus

# Режим action bar (search|music|movie|book) — мок-payload'ы из ActionBarState.debug*
xcrun simctl launch booted com.dima.PlusProtoApp -debugTab plus -debugActionBar music

# Фокус поиска + клавиатура (задержка 0,8s в ActionBarView.onAppear)
xcrun simctl launch booted com.dima.PlusProtoApp -debugTab plus -debugActionBar search -debugSearchFocus
```

Скриншоты action bar (terminate между режимами для чистого старта):
```bash
xcrun simctl terminate booted com.dima.PlusProtoApp
xcrun simctl launch booted com.dima.PlusProtoApp -debugTab plus -debugActionBar search
sleep 5 && xcrun simctl io booted screenshot /tmp/plus-actionbar-search.png
```

**Параллельные агенты**: `xcodebuild` — только одному одновременно (конфликт DerivedData). `Assets.xcassets/` — зона экспорта, не править параллельно.

Окружение: Xcode 26.3, симулятор iPhone 17 Pro (iOS 26.0).

---

## 8. Конвенции

- Общение, коммиты, UI-копия — **на русском**. Conventional Commits.
- **Токены**: только переиспользуемые значения в `DesignSystem/Tokens.swift`; одноразовые градиенты/тени — локально у компонента.
- **Магические числа анимаций** — именованными константами в config-enum рядом с компонентом (`ActionBarMotion`, `TabBarMotion` и т.п.).
- `APIKeys.swift` в гитигноре — без него проект не соберётся.

---

## 9. Открытые вопросы

**Закрыто (не спрашивать повторно):**
- Ключ Google Books — ✅ получен 2026-08-22, в `APIKeys.googleBooks`
- Пустое состояние музплеера — ✅ только поиск, без круга 60
- Тайминг активации таба — ✅ 0,26s `.smooth`
- Пресс-стейт табов — ✅ `PressScaleButtonStyle`
- Action bar 4 режима + морф — ✅ Этап 4 закрыт 2026-08-22

**Осталось решить по ходу (не блокеры):**
- Каденция смены плейсхолдера поиска (интервал ротации фраз — старт 4s)
- Состав курируемого каталога книг (20–30 произведений)
- Тайминг морфа action bar 0,32s — покадровая верификация записью simctl
- A/B: единицы блюра (CSS-сигма vs панель Figma vs SwiftUI `.blur`) — см. DECISIONS.md
- Хаптики — карта в `research/nav-chrome.md` §11, сверить на устройстве
- Тап по «продолжить чтение» → ридер (экрана пока нет)

**Как спрашивать**: формат «вопрос + рекомендация», по одному за раз.

---

## 10. Критические факты для продолжения

- **Блюры в коде — CSS-единицы (гауссова σ)**, не значения панели Figma (там σ×2). Менять все константы разом. SwiftUI `.blur(radius:)` может отличаться — нужен A/B на симуляторе.
- **Тайл таба 40×40 — без backdrop-blur**, только заливка white 10% + hairline. `glassIconTile()` без блюра.
- **Морф action bar** — один persistent HStack, скрытые слои с opacity 0, **никаких if/else-подмен** и пересозданий вью.
- **120 fps** — `LazyVStack`, `drawingGroup()` на тяжёлых blur-слоях, ambilight запекается один раз. **Не переносить** `ScrollOffsetPreferenceKey` из MusicPlayer — перерисовывает хром каждый кадр.
- **Env-объекты `@Observable`**, не `ObservableObject` — тик прогресса не инвалидирует витрину/таббар.
- **Payload'ы action bar sticky** — уходящий элемент рисуется до конца анимации морфа.
- **`GeometryReader` только в background** action bar для замера ширины — корневой GeometryReader раздувает ZStack до белого кадра.
- **DEBUG**: `-debugTab`, `-debugActionBar`, `-debugSearchFocus` — simctl launch без тапов.
- **Параллельные агенты**: один `xcodebuild`; `Assets.xcassets/` — не трогать одновременно.
