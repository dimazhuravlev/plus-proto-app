# План: прототип «Яндекс Плюс» (суперапп)

Статус: **черновик, до grill-интервью**. Решения фиксируются в [DECISIONS.md](DECISIONS.md).
Обновлён: 2026-08-22.

## Что это

Партизанская копия-прототип мобильного приложения «Яндекс Плюс» на iOS/SwiftUI для проектирования UX и тестирования нового дизайна. Данные замоканы + бесплатные публичные API (кино/книги/музыка). Архитектурная база — сосед по репозиторию `~/Repos/MusicPlayer` (тот же подход: UI-прототип без бэкенда, ручная навигация, фиксированный хром в ZStack, эффект-кит).

Фигма: файл `0HzFEKtm9oYdkksrDg7U14`, секция «For Claude — Яндекс Плюс» (`2004:10700`):
- 2 экрана-витрины: персональная лента «Тебе нравится…» (`2004:10701`) и контекстная «Полчаса в такси» (`2004:10785`)
- Компоненты: таббар 5 сервисов (`2004:9169`), сет иконок (`2004:9170`), action bar 4 состояния (`2001:111005`), search с 3 плейсхолдерами (`2001:110986`), кнопка-стекляшка 40pt (`11:9189`)

Полные спеки — в [research/](research/): figma-tokens, figma-tabbar, figma-actionbar, figma-screen1, figma-screen2; анализ MusicPlayer — app-skeleton, screens, nav-chrome, data-apis, design-kit, bootstrap; история — history.

## Ключевые факты из разведки

- **Развёртывание проверено на этой машине**: копия `project.pbxproj` (objectVersion 77, filesystem-synchronized — файлы добавляются простым созданием на диске) + sed-переименование → BUILD SUCCEEDED. Рецепт: [research/bootstrap.md](research/bootstrap.md). Xcode 26.3, симулятор iPhone 17 Pro (iOS 26.0) уже загружен.
- **Вся палитра Фигмы** — white-with-opacity + 2 хекса: акцент `Plus/Solid One #D88DFC`, `#141414B2` (navbar blur). Радиусы/отступы — raw. Токен-таблица: [research/figma-tokens.md](research/figma-tokens.md).
- **Шрифты Фигмы**: YS Display Bold, YS Text Medium, Yandex Sans Text Medium — в MusicPlayer их НЕТ (там Yango Text/Yango Headline). Нужно решение (grill).
- **Рецепт «стекла»**: fill white 10% + stroke white 8% 0.66pt + backdrop-blur 35 (пилюли r32) / 20 (кнопки 40pt) / 14 (тайлы иконок r14).
- **Рецепт ambilight**: копия обложки за карточкой, blur 28, opacity 0.3–0.7, общий поворот −9.5°…+5° (знак чередуется по ленте).
- **Готовые переиспользуемые куски MusicPlayer** (карта: research/app-skeleton, nav-chrome, design-kit): каркас AppTab+ZStack-хром, MiniPlayerV2 (почти 1:1 = свёрнутый мини-плеер экшнбара), BottomBarV2 (скалярная хореография хрома), CachedAsyncImage + averageColorPair (цвета для ambilight), OfflineGlowBackground (блоб-глоу), VariableBlur, гиро-параллакс, тосты, ShareOverlay/OverflowMenu, DeezerService (актор с троттлингом), CurationCache (мёртвый код, но нужен для квот новых API).
- **Истории обсуждения «Яндекс Плюс» в CCD-сессиях нет** (проверено; MusicPlayer строился вне Claude Code). Контекст восстанавливаем через grill.

## Этапы

Каждый этап заканчивается: `xcodebuild` зелёный → установка на симулятор → скриншот → сверка с Фигмой. Решения по ходу — в DECISIONS.md.

### Этап 0 — Развёртывание проекта ✅ ГОТОВО (2026-08-22)
1. ✅ Скаффолд по рецепту bootstrap.md: таргет `PlusProtoApp`, bundle `com.dima.PlusProtoApp`, display name «Яндекс Плюс», iOS 26.0, ATS allow-all, entitlements network.client, VariableBlur SPM с пином.
2. ✅ Шрифты YS Display/Text Medium+Bold в бандле, `FontManager` (runtime-регистрация), `DesignSystem/Typography.swift` с точной компенсацией line-height из макета.
3. ✅ `DesignSystem/Tokens.swift`: цвета, радиусы, метрики, 16-стоповый градиент подложки таббара, градиенты глифов табов.
4. ✅ Каркас: `AppTab` на 5 сервисов, дефолтный таб «Плюс», заглушки сервисных табов.
5. ✅ `.gitignore` (APIKeys.swift, _secrets), клипы `_assets/videos` → `PlusProtoApp/Videos`.
6. ✅ Верификация: **BUILD SUCCEEDED**, установлено и запущено на iPhone 17 Pro, скриншот снят, шрифт YS отрисовывается.

Осталось: `git init` + первый коммит; `.claude/settings.json`.

### Этап 1 — Дизайн-система и атомы
1. `DesignSystem/Tokens.swift`: цвета (fill1/6/9/10, subtitle, buttonsPrimary/Secondary, plusAccent #D88DFC), радиусы (14/32/12/8/4), типографика.
2. `GlassSurface` ViewModifier (стекло-рецепт), `GlassIconButton` 40pt (компонент 11:9189: сердце/крестик), `LikeDismissPair` (gap 6).
3. `GradientText` (горизонтальный градиент-заливка текста), `PlusProgressBar` (капсула h6, трек white10, филл #D88DFC).
4. `AmbilightArtwork(image:size:corner:rotation:glowOpacity:borderWidth:)` — единый рецепт карточек.
5. Экспорт ассетов из Фигмы по node ID (иконки табов ×10, pulse glow, search/love/pause/X/heart, мок-обложки, изометрическая книга флэт-PNG, орб «Моя Волна»).
6. Витрина-каталог атомов (debug-экран) для визуальной сверки.

### Этап 2 — Каркас приложения
1. `AppRootView` + env-объекты (по образцу MusicApp.swift): `AppTab` enum на 5 сервисов (Плюс/Музыка/Кинопоиск/Книги/Алиса), NavigationStack на таб, фиксированный хром поверх.
2. Стейты: `ActionBarState` (mode: search/music/book/movie + payload), `FeedState`, `GyroManager`.
3. Заглушки экранов сервисов.

### Этап 3 — Таббар
По спеке figma-tabbar.md: ряд 5×(60×62), тайл 40×40 r14, glow-«pulse» активного (Ellipse+RadialGradient #AC5387→#4C31BE, blur 28, crossfade + сдвиг 7→11), лейблы 11/14, подложка — 16-стоповый градиент 210pt (+ VariableBlur?). Анимации активации, хаптика, поведение — по grill.

### Этап 4 — Action bar
По спеке figma-actionbar.md: единый HStack с анимируемыми ширинами (284↔60↔flex), стекло константно, скрытые слои opacity 0 (как в Фигме — под морф), тикер плейсхолдеров (шаг 42pt), чипы книга 44×60 r4 / кино 88×54 r8 rot 4°, прогресс. Триггеры состояний, тайминги морфа — по grill.

### Этап 5 — Витрина 1: персональная лента
По спеке figma-screen1.md: `FeedItem` enum + ScrollView с per-card оффсетами (нерегулярные гэпы 20–66, наезды, bleed за края — не клипать!), фон-коллаж blur 100/40%, хедер с врезками-чипами (ZStack поверх текста), 7 карточек: movie, album, isometric book, my vibe (орб), continue reading (глас-блок с выдержкой текста + прогресс), continue watching (видеофрейм + Rate 4 эмодзи). Лайк/дисмисс-поведение, анимации появления — по grill.

### Этап 6 — Витрина 2: контекстная «Полчаса в такси»
Переиспользование карточек Этапа 5 с параметрами (rotation/glowOpacity/bleed), тёплый фон от контента, двухцветный заголовок (белое предложение + тонированный вопрос), action bar в состоянии movie player.

### Этап 7 — Данные

Источники утверждены и проверены запросами (детали и лимиты — в DECISIONS.md):

| Домен | Источник | Ключ | Что даёт |
|---|---|---|---|
| Музыка | Deezer (перенос `DeezerService`) | нет | мета, обложки 1000×1000, превью-MP3 30с |
| Кино: мета/постеры | **kinopoisk.dev** (`api.poiskkino.dev`) | есть (`X-API-KEY`) | русские названия и `shortDescription`, постеры Яндекс-CDN до `orig`, backdrop 1344×756, logo PNG, 302 подборки |
| Кино: видео | забандленные клипы `_assets/videos/` | — | 3 клипа, 3,58 МБ, faststart |
| Книги: обложки | Google covers CDN | нет | 1600×2476 (`fife=w1600`) |
| Книги: мета | Google Books API | нужен | русские названия/авторы/аннотации (`langRestrict=ru`) |
| Книги: текст | ru.wikisource | нет | настоящий русский текст глав |

Архитектура: актор-сервис на домен по шаблону `DeezerService` (URLCache + скользящее окно троттлинга + generic `fetch<T: Decodable>`), курируемые каталоги-константы по образцу `DeezerMusicScope`, двойная модель «ассет + URL» (как `Track`).

**`CurationCache` (версионированный диск-кэш) включить с первого дня** — у Кинопоиска всего 200 запросов/сутки, у Google Books ~1000. Проверять остаток: `GET /v1.5/token`.

### Этап 8 — Полировка
Хаптики (карта в research/nav-chrome.md §11), появление карточек, гиро-параллакс, runtime-ambilight от averageColorPair, grain, звуки — по grill-решениям.

## Процесс работы (оркестрация)

- **Писатели кода** — субагенты (Workflow/Agent) на модели **Opus 5** (`model: "opus"`), effort ниже максимального для механического написания по готовой спеке; ревью/верификация — сессионная модель. На этапах 3–6 компоненты пишутся параллельными агентами в worktree-изоляции, у каждого на входе — соответствующий research/*.md + DECISIONS.md; после — сборка, ревью-агент, визуальная сверка скриншотом.
- **Контекст между итерациями**: этот PLAN.md (актуализировать статусы этапов), DECISIONS.md (каждое решение с "почему"), research/ (не редактировать — снапшот разведки).
- **Верификация**: `xcodebuild -project <Name>.xcodeproj -scheme <Name> -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build` → `xcrun simctl install booted … && xcrun simctl launch booted com.dima.<Name>` → скриншот. Симулятор-скриншоты агентом — норма для этого проекта (в отличие от рабочего logist-courier-app).

## Открытые вопросы (очередь grill)

Grill-интервью 2026-08-22 закрыло 12 блоков — все ответы в [DECISIONS.md](DECISIONS.md). Закрыто: концепция и состав табов, имя проекта, шрифты, iOS-таргет, переключение и активное состояние табов, вся логика action bar (состояния, морф, клавиатура, тикер), состав и поведение ленты, «Моя Волна», видео в карточке, фон витрины, живость ленты и требование 120 fps, все источники данных, стартовый таб, природа двух экранов витрины.

Осталось решить по ходу реализации (не блокеры):
- Хаптики: взять карту из MusicPlayer (research/nav-chrome.md §11) и сверить на устройстве.
- Тайминги морфа action bar и кроссфейда таббара — подобрать на симуляторе, зафиксировать в config-enum.
- Каденция смены плейсхолдера поиска (интервал ротации).
- Тап по карточке «продолжить чтение» → ридер (экрана пока нет).
- Курируемый каталог книг: какие 20–30 произведений.
- Нужен ключ Google Books (пользователь получает; всё остальное уже работает).
