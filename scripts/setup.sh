#!/usr/bin/env bash
# Первая установка прототипа: ключи на место, зависимости, контрольная сборка.
# Запускать из любого места — скрипт сам перейдёт в корень репозитория:
#
#     ./scripts/setup.sh
#
# Идемпотентный: существующий APIKeys.swift не перезаписывает никогда.
set -euo pipefail

cd "$(dirname "$0")/.."
KEYS="PlusProtoApp/APIKeys.swift"
SIM="${PLUS_SIM:-iPhone 17 Pro}"

echo "▸ Проверяю инструменты"
if ! xcodebuild -version >/dev/null 2>&1; then
    echo "  ✗ xcodebuild не отвечает. Поставь Xcode из App Store, открой его один раз" >&2
    echo "    (он допоставит компоненты) и выполни: sudo xcode-select -s /Applications/Xcode.app" >&2
    exit 1
fi
xcodebuild -version | sed 's/^/  /'
# Деплой-таргет проекта — iOS 26.0, то есть нужен Xcode 26.x с его симуляторами.
case "$(xcodebuild -version | head -1)" in
    *"Xcode 26"*) ;;
    *) echo "  ⚠️  Проект рассчитан на Xcode 26.x (iOS 26 SDK) — на более старом сборка упадёт" ;;
esac

echo "▸ Ключи внешних API"
if [ -f "$KEYS" ]; then
    echo "  • $KEYS уже есть — не трогаю"
else
    cp APIKeys.example.swift "$KEYS"
    echo "  • создал $KEYS из шаблона (пустые ключи: витрина пойдёт на моках)"
fi
if grep -q '"[^"]\{8,\}"' "$KEYS"; then
    echo "  • ключ Кинопоиска вписан — витрина будет на живых данных"
else
    echo "  • ключей нет. Прототип запустится на моках; за живыми данными — README, раздел «Ключи»"
fi

echo "▸ Собираю (первый раз дольше: тянется зависимость VariableBlur)"
if xcodebuild -project PlusProtoApp.xcodeproj -scheme PlusProtoApp \
    -destination "platform=iOS Simulator,name=$SIM" -configuration Debug build \
    >/tmp/plus-setup-build.log 2>&1; then
    echo "  ✓ BUILD SUCCEEDED"
else
    echo "  ✗ сборка упала. Последние строки лога (весь — /tmp/plus-setup-build.log):" >&2
    grep -E 'error:|xcodebuild: error' /tmp/plus-setup-build.log | head -10 >&2 || tail -20 /tmp/plus-setup-build.log >&2
    echo "    Симулятор «$SIM» не найден? Передай свой: PLUS_SIM='iPhone 17' ./scripts/setup.sh" >&2
    exit 1
fi

cat <<'DONE'

Готово. Дальше:
  1. open PlusProtoApp.xcodeproj
  2. сверху выбери схему PlusProtoApp и симулятор iPhone 17 Pro
  3. Cmd+R

Если Xcode ругается на команду разработчика (Signing & Capabilities, team Z55ZV5538M) —
поставь свою или очисти поле: для симулятора подпись не нужна.
Что дальше читать — README.md и CLAUDE.md.
DONE
