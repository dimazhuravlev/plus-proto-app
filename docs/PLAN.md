# План: прототип «Яндекс Плюс» (суперапп)

Статус: **в реализации, этапы 0–4 закрыты, Этап 5 следующий**. Решения фиксируются в [DECISIONS.md](DECISIONS.md).
Обновлён: 2026-08-22.

## Что это

Партизанская копия-прототип мобильного приложения «Яндекс Плюс» на iOS/SwiftUI для проектирования UX и тестирования нового дизайна. Данные замоканы + бесплатные публичные API (кино/книги/музыка). Архитектурная база — сосед `~/Repos/MusicPlayer`.

Фигма: файл `0HzFEKtm9oYdkksrDg7U14`, секция «For Claude — Яндекс Плюс» (`2004:10700`):
- 2 экрана-витрины: «Тебе нравится…» (`2004:10701`) и «Полчаса в такси» (`2004:10785`)
- Компоненты: таббар (`2004:9169`), action bar 4 состояния (`2001:111005`), search с 3 плейсхолдерами (`2001:110986`), кнопка-стекляшка 40pt (`11:9189`)

Полные спеки — в [research/](research/). Grill-интервью 2026-08-22 закрыло 12 блоков — ответы в DECISIONS.md.

## Ключевые факты из разведки

- **Развёртывание проверено**: pbxproj objectVersion 77 (filesystem-synchronized), Xcode 26.3, iPhone 17 Pro.
- **Палитра**: white-with-opacity + `#D88DFC` + `#141414B2`. Токены: [research/figma-tokens.md](research/figma-tokens.md).
- **Шрифты**: YS Display/Text Medium+Bold — runtime через `FontManager`.
- **Рецепт стекла**: fill white 10% + stroke white 8% 0.66pt + backdrop-blur 35/20 (пилюли/кнопки). Тайл таба — **без блюра**.
- **Ambilight**: blur 28 (CSS σ), opacity 0.3–0.7, общий поворот.
- **Переиспользование MusicPlayer**: MiniPlayerV2, LoopingVideoPlayer, DeezerService, CachedAsyncImage, VariableBlur (подключён, под скрим таббара не ставим).

## Этапы

Каждый этап: `xcodebuild` → симулятор → скриншот → сверка с Фигмой → DECISIONS.md.

### Этап 0 — Развёртывание ✅ (2026-08-22)
Скаффолд, шрифты YS, Tokens, KinopoiskService, видео, APIKeys, BUILD SUCCEEDED.

### Этап 1 — Дизайн-система и атомы ✅ (2026-08-22)
`GlassSurface`, `GlassIconButton`, `GradientText`, `PlusProgressBar`, `AmbilightArtwork`, `AtomsCatalogScreen`. **31 imageset** (10 глифов табов Active/Inactive + остальные). BUILD SUCCEEDED.

### Этап 2 — Каркас приложения ✅ (2026-08-22)
`App/` + `State/` + `Chrome/` + `Screens/`. 5 NavigationStack, хром в ZStack, `@Observable` env-объекты, `contentMargins` 130pt. BUILD SUCCEEDED.

### Этап 3 — Таббар ✅ (2026-08-22)
`TabBarView` по `figma-tabbar.md`. Тайминг 0,26s, пресс-стейт, pulse PNG, глифы PNG Active/Inactive с запечённым emboss. Сверка с `2004:9169` — попиксельно. BUILD SUCCEEDED.

### Этап 4 — Action bar ✅ (2026-08-22)
`ActionBarView` по `figma-actionbar.md`: persistent HStack, 4 режима (search/music/movie/book), морф 0,32s `.smooth`, MiniPlayerPill (обложка 48 + вращение 18°/s + `MiniPlayerProgressFill`), чипы кино/книги rot 4°, тикер плейсхолдеров + троеточие, `isSearchFocused` + `KeyboardObserver` поднимает хром, DEBUG `-debugActionBar` / `-debugSearchFocus`. BUILD SUCCEEDED; simctl-скриншоты 4 режимов + keyboard layout в `/tmp/plus-actionbar-screenshots/`.

### Этап 5 — Витрина 1: персональная лента ⏸ pending
Спека `figma-screen1.md`: 7 карточек, нерегулярные гэпы, динамический фон, каскад, орб «Моя Волна», continue watching (видео), continue reading. Удалить `AtomsCatalogScreen` из `ShowcaseScreen`.

### Этап 6 — Витрина 2: «Полчаса в такси» ⏸ pending
Спека `figma-screen2.md`: то же представление в другом состоянии (заголовок, блоки, фон). Переиспользование карточек Этапа 5.

### Этап 7 — Данные ⏸ pending

| Домен | Источник | Ключ | Статус |
|---|---|---|---|
| Музыка | Deezer (перенос `DeezerService`) | нет | не перенесён |
| Кино | kinopoisk.dev | ✅ `APIKeys.kinopoisk` | сервис готов |
| Кино: видео | `_assets/videos/` → `Videos/` | — | ✅ забандлено |
| Книги: обложки | Google covers CDN | нет | — |
| Книги: мета | Google Books API | ✅ `APIKeys.googleBooks` | сервис не написан |
| Книги: текст | ru.wikisource | нет | сервис не написан |

Написать: `BooksService`, `WikisourceService`, `BookModels`, `BookCatalog` (20–30 книг). Перенести Deezer. Включить `CurationCache`.

### Этап 8 — Полировка ⏸ pending
Хаптики (`research/nav-chrome.md` §11), каскад карточек, parallax, Instruments (Animation Hitches), grain орба.

## Процесс работы

- **Handoff для агента без контекста**: [HANDOFF.md](HANDOFF.md) — актуализировать после каждой сессии.
- **Верификация**: xcodebuild → simctl install/launch → screenshot. DEBUG: `-debugTab <tab>`.
- **Параллельные агенты**: один xcodebuild; Assets.xcassets — зона экспорта.

## Открытые вопросы

**Закрыто grill-интервью и реализацией:**
- Концепция, табы, шрифты, iOS 26, action bar логика, витрина, данные, стартовый таб «Плюс»
- Google Books ключ — ✅ 2026-08-22
- Тайминг таба 0,26s — ✅
- Пресс-стейт табов — ✅
- Пустой музплеер → только search — ✅

**Осталось по ходу (не блокеры):**
- Каденция ротации плейсхолдера поиска
- Каталог книг 20–30 — какие произведения
- Тайминг морфа action bar
- A/B единиц блюра (CSS σ vs SwiftUI)
- Хаптики — сверка на устройстве
- Тап «продолжить чтение» → ридер
