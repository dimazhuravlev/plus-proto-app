"""TestFlight: раздать последнюю сборку внешней группе (и отправить её на Beta App Review).

Ключ App Store Connect API — локально, вне репозитория:
  ~/.appstoreconnect/plus-proto.env               ASC_ISSUER_ID=…, ASC_KEY_ID=…
  ~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8
JWT подписывается системным openssl (ES256), сторонних пакетов не нужно.

python3 -I scripts/testflight-external.py groups
python3 -I scripts/testflight-external.py distribute [--group <имя>] [--whats-new <текст>] [--build <номер>] [--since-minutes <N>]

`distribute` ждёт, пока Apple обработает сборку (до 30 мин), пишет «Что тестировать» (ru),
добавляет сборку во внешнюю группу и отправляет на Beta App Review (повтор — не ошибка).
"""
import base64, json, os, subprocess, sys, time, urllib.error, urllib.parse, urllib.request
from datetime import datetime

BUNDLE_ID = "com.dima.PlusProtoApp"
API = "https://api.appstoreconnect.apple.com"
HOME = os.path.expanduser("~/.appstoreconnect")


def load_env():
    env = {}
    with open(os.path.join(HOME, "plus-proto.env")) as f:
        for line in f:
            if "=" in line:
                k, v = line.strip().split("=", 1)
                env[k] = v
    return env["ASC_ISSUER_ID"], env["ASC_KEY_ID"]


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def der_to_raw(der: bytes) -> bytes:
    # SEQUENCE { INTEGER r, INTEGER s } → r‖s по 32 байта
    assert der[0] == 0x30
    i = 2 if der[1] < 0x80 else 2 + (der[1] & 0x7F)
    out = b""
    for _ in range(2):
        assert der[i] == 0x02
        n = der[i + 1]
        val = der[i + 2:i + 2 + n].lstrip(b"\x00")
        out += val.rjust(32, b"\x00")
        i += 2 + n
    return out


def token(issuer, key_id):
    now = int(time.time())
    header = b64url(json.dumps({"alg": "ES256", "kid": key_id, "typ": "JWT"}).encode())
    payload = b64url(json.dumps({"iss": issuer, "iat": now, "exp": now + 1100,
                                 "aud": "appstoreconnect-v1"}).encode())
    signing_input = f"{header}.{payload}".encode()
    key_path = os.path.join(HOME, "private_keys", f"AuthKey_{key_id}.p8")
    der = subprocess.run(["openssl", "dgst", "-sha256", "-sign", key_path],
                         input=signing_input, capture_output=True, check=True).stdout
    return f"{header}.{payload}.{b64url(der_to_raw(der))}"


class Client:
    def __init__(self):
        self.issuer, self.key_id = load_env()
        self.jwt, self.born = None, 0

    def call(self, method, path, body=None, ok=(200, 201, 204)):
        if not self.jwt or time.time() - self.born > 900:
            self.jwt, self.born = token(self.issuer, self.key_id), time.time()
        req = urllib.request.Request(API + path, method=method,
                                     data=json.dumps(body).encode() if body is not None else None)
        req.add_header("Authorization", f"Bearer {self.jwt}")
        req.add_header("Content-Type", "application/json")
        try:
            with urllib.request.urlopen(req) as r:
                raw = r.read()
                return r.status, (json.loads(raw) if raw else {})
        except urllib.error.HTTPError as e:
            raw = e.read()
            data = json.loads(raw) if raw else {}
            if e.code in ok:
                return e.code, data
            return e.code, data


def app_id(c):
    q = urllib.parse.urlencode({"filter[bundleId]": BUNDLE_ID})
    status, data = c.call("GET", f"/v1/apps?{q}")
    if status != 200 or not data.get("data"):
        sys.exit(f"приложение {BUNDLE_ID} не найдено: {status} {data}")
    return data["data"][0]["id"]


def groups(c, app):
    status, data = c.call("GET", f"/v1/apps/{app}/betaGroups?limit=50")
    if status != 200:
        sys.exit(f"группы: {status} {data}")
    return [(g["id"], g["attributes"]["name"], g["attributes"].get("isInternalGroup")) for g in data["data"]]


def latest_build(c, app, number=None, since=None):
    """Последняя сборка (или сборка `number`). `since` — сборка должна быть выгружена не
    раньше этой метки (unix-время): только что выгруженная появляется в API не сразу,
    и без этого раздалась бы предыдущая. Нет такой — `None`."""
    q = {"filter[app]": app, "sort": "-uploadedDate", "limit": "1",
         "fields[builds]": "version,processingState,uploadedDate"}
    if number:
        q["filter[version]"] = number
    status, data = c.call("GET", "/v1/builds?" + urllib.parse.urlencode(q))
    if status != 200:
        sys.exit(f"сборки: {status} {data}")
    if not data.get("data"):
        return None
    b = data["data"][0]
    if since is not None:
        uploaded = b["attributes"].get("uploadedDate", "")
        stamp = datetime.fromisoformat(uploaded.replace("Z", "+00:00")).timestamp()
        if stamp < since:
            return None
    return b["id"], b["attributes"]["version"], b["attributes"]["processingState"]


def main():
    args = sys.argv[1:]
    if not args or args[0] not in ("groups", "distribute"):
        sys.exit(__doc__)
    opts = {args[i]: args[i + 1] for i in range(1, len(args) - 1, 2)}
    c = Client()
    app = app_id(c)
    gs = groups(c, app)
    if args[0] == "groups":
        for gid, name, internal in gs:
            print(f"{'внутренняя' if internal else 'внешняя  '}  {name}  ({gid})")
        return

    external = [g for g in gs if not g[2]]
    if "--group" in opts:
        external = [g for g in external if g[1] == opts["--group"]]
    if not external:
        sys.exit("внешних групп не найдено")

    # `--since-minutes N` — ждать сборку, выгруженную за последние N минут (сразу после выгрузки).
    since = time.time() - float(opts["--since-minutes"]) * 60 if "--since-minutes" in opts else None
    deadline = time.time() + 30 * 60
    found = latest_build(c, app, opts.get("--build"), since)
    while found is None:
        if time.time() > deadline:
            sys.exit("свежая сборка так и не появилась в App Store Connect")
        print("сборка ещё не видна в App Store Connect — жду")
        time.sleep(30)
        found = latest_build(c, app, opts.get("--build"), since)
    build, number, state = found
    print(f"сборка {number}: {state}")
    while state != "VALID":
        if state in ("FAILED", "INVALID") or time.time() > deadline:
            sys.exit(f"сборка {number} не готова: {state}")
        time.sleep(30)
        build, number, state = latest_build(c, app, number)
        print(f"сборка {number}: {state}")

    whats_new = opts.get("--whats-new")
    if whats_new:
        status, data = c.call("GET", f"/v1/builds/{build}/betaBuildLocalizations")
        loc = next((l for l in data.get("data", []) if l["attributes"]["locale"].startswith("ru")), None)
        if loc:
            c.call("PATCH", f"/v1/betaBuildLocalizations/{loc['id']}",
                   {"data": {"type": "betaBuildLocalizations", "id": loc["id"],
                             "attributes": {"whatsNew": whats_new}}})
        else:
            c.call("POST", "/v1/betaBuildLocalizations",
                   {"data": {"type": "betaBuildLocalizations",
                             "attributes": {"locale": "ru", "whatsNew": whats_new},
                             "relationships": {"build": {"data": {"type": "builds", "id": build}}}}})
        print("«Что тестировать» записано")

    for gid, name, _ in external:
        status, data = c.call("POST", f"/v1/betaGroups/{gid}/relationships/builds",
                              {"data": [{"type": "builds", "id": build}]})
        print(f"группа «{name}»: {'добавлена' if status in (200, 204) else f'{status} {data}'}")

    status, data = c.call("POST", "/v1/betaAppReviewSubmissions",
                          {"data": {"type": "betaAppReviewSubmissions",
                                    "relationships": {"build": {"data": {"type": "builds", "id": build}}}}})
    if status in (200, 201):
        print("отправлено на Beta App Review")
    else:
        errors = "; ".join(e.get("detail") or e.get("title", "") for e in data.get("errors", []))
        print(f"Beta App Review: {status} {errors}")


if __name__ == "__main__":
    main()
