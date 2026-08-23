# CLAUDE.md — прототип «Яндекс Плюс»

iOS/SwiftUI дизайн-прототип супераппа «Яндекс Плюс» (кино + книги + музыка + Алиса). Не продовое приложение: моки + бесплатные публичные API. Сиблинг `~/Repos/MusicPlayer` — оттуда берём архитектуру и компоненты.

## Перед любой работой прочитай

0. **[docs/HANDOFF.md](docs/HANDOFF.md)** — состояние проекта и с чего продолжить. Начинай отсюда.
1. [docs/PLAN.md](docs/PLAN.md) — этапы, статусы, очередь открытых вопросов.
2. [docs/DECISIONS.md](docs/DECISIONS.md) — лог решений с «почему». Каждое новое решение (своё или пользователя) фиксируй там сразу.
3. [docs/research/](docs/research/) — снапшот разведки 2026-08-22 (не редактировать): анализ MusicPlayer (app-skeleton, screens, nav-chrome, data-apis, design-kit, bootstrap), спеки из Фигмы (figma-tokens, figma-tabbar, figma-actionbar, figma-screen1, figma-screen2), history.

## Фигма

Файл `0HzFEKtm9oYdkksrDg7U14`, секция «For Claude — Яндекс Плюс» = нода `2004:10700`. MCP-URL ассетов протухают за ~7 дней — экспортировать заново по node ID из research-спек.

## Сборка и верификация

Проект собирается только через Xcode toolchain (Xcode 26.3). Папка репозитория — `plus-proto-app`, Xcode-таргет/схема — `PlusProtoApp` (ASCII без дефисов, чтобы имя Swift-модуля не превращалось в `plus_proto_app`):

```bash
xcodebuild -project PlusProtoApp.xcodeproj -scheme PlusProtoApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug build
```

Запуск: `xcrun simctl install booted <DerivedData>/.../PlusProtoApp.app && xcrun simctl launch booted com.dima.PlusProtoApp`. После каждого визуального изменения — скриншот симулятора (`xcrun simctl io booted screenshot`) и сверка с макетом. Агентские скриншоты симулятора здесь — норма.

## Конвенции

- Общение, коммиты, UI-копия — на русском. Conventional Commits.
- Токены: только переиспользуемые значения в `DesignSystem/Tokens.swift`; одноразовые градиенты/тени живут локально у компонента («токен ради единственного вызова не заводим»).
- Файлы добавляются простым созданием на диске (filesystem-synchronized pbxproj) — проект править не нужно.
- `APIKeys.swift` в гитигноре; без него проект не соберётся — копия в `_secrets/`.
- Живые данные витрины: `-debugMockFeed` — прогон на моках без сети (для сверки с макетом), `-debugFreshFeed` — обойти получасовое окно ротации контента.
- Магические числа анимаций — именованными константами в config-enum рядом с компонентом (стиль MusicPlayer: YMTiming, ShareCardDragConfig).
