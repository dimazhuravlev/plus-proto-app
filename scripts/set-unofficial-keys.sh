#!/usr/bin/env bash
# Ключи Kinopoisk API Unofficial (запас поиска фильмов, `KinopoiskUnofficialService`)
# — во все копии APIKeys.swift: основная папка, _secrets и worktree'ы в .claude/worktrees.
# Ключи спрашивает скрытым вводом и на экран не выводит, затем проверяет каждый у сервиса.
#
#     ./scripts/set-unofficial-keys.sh
#
# Повторный запуск заменяет ключи. Пустой ввод на первом ключе — выход без изменений.
# Свои файлы для проверки скрипта — аргументами: ./scripts/set-unofficial-keys.sh a.swift b.swift
set -euo pipefail

cd "$(dirname "$0")/.."
# Корень основной папки — и из worktree: общий .git лежит в ней.
MAIN="$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")"

if [[ $# -gt 0 ]]; then
    TARGETS=("$@")
else
    TARGETS=("$MAIN/PlusProtoApp/APIKeys.swift" "$MAIN/_secrets/APIKeys.swift")
    for f in "$MAIN"/.claude/worktrees/*/PlusProtoApp/APIKeys.swift; do
        [[ -f "$f" ]] && TARGETS+=("$f")
    done
fi

valid() { [[ "$1" =~ ^[A-Za-z0-9-]{8,}$ ]]; }

read -r -s -p "Ключ 1 (ввод скрыт): " KEY1; echo
if [[ -z "$KEY1" ]]; then
    echo "Пусто — ничего не меняю."
    exit 0
fi
valid "$KEY1" || { echo "  ✗ Ключ 1 не похож на ключ: только латиница, цифры и дефис" >&2; exit 1; }
read -r -s -p "Ключ 2 (Enter — без второго): " KEY2; echo
if [[ -n "$KEY2" ]]; then
    valid "$KEY2" || { echo "  ✗ Ключ 2 не похож на ключ: только латиница, цифры и дефис" >&2; exit 1; }
fi

echo "▸ Вписываю в APIKeys.swift"
# Ключи — через окружение, а не аргументами: аргументы видны в списке процессов.
K1="$KEY1" K2="$KEY2" python3 -I - "${TARGETS[@]}" <<'PY'
import os, re, sys

keys = [k for k in (os.environ["K1"], os.environ.get("K2", "")) if k]
body = "".join(f'        "{k}",\n' for k in keys)
field = (
    "\n    /// kinopoiskapiunofficial.tech — запас поиска фильмов, когда у kinopoisk.dev кончилась\n"
    "    /// квота на всех ключах (`KinopoiskUnofficialService`).\n"
    "    static let kinopoiskUnofficial: [String] = [\n" + body + "    ]\n"
)
pattern = re.compile(r"(static let kinopoiskUnofficial: \[String\] = \[\n).*?(\n?    \])", re.S)

for path in sys.argv[1:]:
    try:
        source = open(path).read()
    except FileNotFoundError:
        print(f"  – нет файла: {path}")
        continue
    if "kinopoiskUnofficial" in source:
        updated, count = pattern.subn(lambda m: m.group(1) + body.rstrip("\n") + "\n    ]", source, count=1)
        if count == 0:
            print(f"  ✗ не разобрал поле kinopoiskUnofficial, поправь руками: {path}")
            continue
    else:
        head, brace, _ = source.rpartition("}")
        if not brace:
            print(f"  ✗ не нашёл конец enum APIKeys: {path}")
            continue
        updated = head.rstrip("\n") + "\n" + field + "}\n"
    open(path, "w").write(updated)
    print(f"  ✓ {path}")
PY

echo "▸ Проверяю ключи у сервиса"
n=0
for key in "$KEY1" "$KEY2"; do
    [[ -z "$key" ]] && continue
    n=$((n + 1))
    response="$(curl -s -m 15 -w '\n%{http_code}' -H "X-API-KEY: $key" \
        "https://kinopoiskapiunofficial.tech/api/v1/api_keys/$key" || true)"
    code="${response##*$'\n'}"
    json="${response%$'\n'*}"
    if [[ "$code" == "200" ]]; then
        # Python 3.9 из Xcode: без f-строк с кавычками внутри — `format`.
        printf '%s' "$json" | N="$n" python3 -I -c '
import json, os, sys
d = json.load(sys.stdin)
daily = d.get("dailyQuota") or {}
total = (d.get("totalQuota") or {}).get("value")
print("  ✓ ключ {}: сегодня {} из {} запросов, всего — {}, тариф {}".format(
    os.environ["N"], daily.get("used", "?"), daily.get("value", "?"),
    "без лимита" if total == -1 else total, d.get("accountType", "?")))
' 2>/dev/null || echo "  ✓ ключ $n принят (HTTP 200)"
    else
        echo "  ✗ ключ $n: сервис ответил HTTP $code — проверь, что ключ скопирован целиком"
    fi
done

echo
echo "Готово. Пересобери приложение в Xcode — ключи вшиваются при сборке."
