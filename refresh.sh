#!/usr/bin/env bash
set -euo pipefail
# centinal-lists — daily refresh. Downloads the 6 GPL-3.0 community lists, converts
# each to Safari content-blocker JSON (blockgen → SafariConverterLib), merges +
# dedupes + byte-greedy bin-packs across FOUR ~1.5 MB sets, and writes:
#   blockerSet1.json … blockerSet4.json   (served by GitHub Pages, fetched by the app)
#   manifest.json                          (schema v2: per-set bytes+sha256 + sources[])
# The app validates every download against manifest.bytes/sha256 before installing,
# so this repo is a plain static origin — no server logic, no secrets required to run.
#
# SKIP-IF-UNCHANGED: if the concatenated upstream inputs hash the same as last run,
# exit 0 WITHOUT bumping `version`, so a no-change day triggers no client downloads.
#
# This mirrors the app repo's dev/scripts/refresh_lists.sh (single source of truth for
# the compile logic — keep them in sync); it differs only in OUTPUT paths (repo root)
# and the skip-if-unchanged guard.

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"
mkdir -p FilterLists
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT

PER_FILE_CAP=1500000
# id|category|licence|sub-budget|url|display-name   (ORDER = dedup + pack precedence)
SOURCES=(
  "easylist|ads|GPL-3.0|1700000|https://easylist.to/easylist/easylist.txt|EasyList"
  "easyprivacy|privacy|GPL-3.0|1400000|https://easylist.to/easylist/easyprivacy.txt|EasyPrivacy"
  "fanboy-annoyance|annoyances|GPL-3.0|1200000|https://secure.fanboy.co.nz/fanboy-annoyance.txt|Fanboy's Annoyances"
  "indianlist|regional|GPL-3.0|900000|https://easylist-downloads.adblockplus.org/indianlist.txt|IndianList"
  "ublock-filters|ads|GPL-3.0|1100000|https://ublockorigin.github.io/uAssets/filters/filters.txt|uBlock filters"
  "adguard-base|ads|GPL-3.0|1400000|https://filters.adtidy.org/extension/safari/filters/2.txt|AdGuard Base"
)

for spec in "${SOURCES[@]}"; do
  IFS='|' read -r id category license budget url name <<< "$spec"
  echo "Downloading ${name}…"
  curl -sL "$url" -o "FilterLists/${id}.txt"
done

# Skip-if-unchanged: hash all inputs; compare to the stored fingerprint.
FINGERPRINT="$(cat FilterLists/*.txt | shasum -a 256 | cut -d' ' -f1)"
if [ -f ".inputs.sha256" ] && [ "$(cat .inputs.sha256)" = "$FINGERPRINT" ]; then
  echo "Upstream lists unchanged since last run — nothing to publish."
  exit 0
fi

for spec in "${SOURCES[@]}"; do
  IFS='|' read -r id category license budget url name <<< "$spec"
  echo "Converting ${name} (byte-budgeted to ${budget})…"
  swift run -c release blockgen "FilterLists/${id}.txt" "${WORK}/${id}.json" "${budget}"
done

echo "Merging + byte-greedy packing…"
PER_FILE_CAP="${PER_FILE_CAP}" WORK="${WORK}" ROOT="${ROOT}" \
SOURCES_SPEC="$(printf '%s\n' "${SOURCES[@]}")" python3 - <<'PY'
import json, os, hashlib, time
BIN_COUNT = 4
cap = int(os.environ["PER_FILE_CAP"]); work = os.environ["WORK"]; root = os.environ["ROOT"]
specs = [l.split("|") for l in os.environ["SOURCES_SPEC"].splitlines() if l]
sources = []
for id, category, license, budget, url, name in specs:
    p = os.path.join(work, f"{id}.json")
    sources.append((id, category, license, url, name, json.load(open(p)) if os.path.exists(p) else []))
def canon(r): return json.dumps(r, sort_keys=True, separators=(",", ":"))
seen, merged = {}, []
for id, *_r, rules in [(s[0], s[1], s[2], s[3], s[4], s[5]) for s in sources]:
    for r in rules:
        k = canon(r)
        if k not in seen: seen[k] = id; merged.append(r)
blocks  = [r for r in merged if r["action"]["type"] != "ignore-previous-rules"]
excepts = [r for r in merged if r["action"]["type"] == "ignore-previous-rules"]
def rb(r): return len(json.dumps(r, separators=(",", ":")).encode())
def enc(rs): return json.dumps(rs, separators=(",", ":")).encode()
eb = sum(rb(r) for r in excepts); block_budget = cap - 2 - eb - len(excepts)
if block_budget < 0: raise SystemExit("exceptions exceed cap")
bins = [[] for _ in range(BIN_COUNT)]; used = [0]*BIN_COUNT; dropped = 0
for rule in blocks:
    c = rb(rule)
    if c > block_budget: dropped += 1; continue
    placed = False
    for b in range(BIN_COUNT):
        added = c + (0 if not bins[b] else 1)
        if used[b] + added <= block_budget:
            bins[b].append(rule); used[b] += added; placed = True; break
    if not placed: dropped += 1
ordered = [bins[i] + excepts for i in range(BIN_COUNT) if bins[i]]
while len(ordered) < BIN_COUNT: ordered.append(list(excepts))
set_files = []
for n, rules in enumerate(ordered, 1):
    data = enc(rules); open(os.path.join(root, f"blockerSet{n}.json"), "wb").write(data)
    set_files.append(data)
shipped = set()
for rules in ordered:
    for r in rules: shipped.add(canon(r))
surv = {s[0]: 0 for s in sources}
for k, origin in seen.items():
    if k in shipped: surv[origin] = surv.get(origin, 0) + 1
PAGES = "https://dumore-apps.github.io/centinal-lists"
names = ["Block Set 1 (Ads — EasyList lead)","Block Set 2 (Trackers — EasyPrivacy lead)",
         "Block Set 3 (Annoyances — Fanboy lead)","Block Set 4 (AdGuard + regional lead)"]
lists = [{"id": f"block-set-{i+1}", "name": names[i], "url": f"{PAGES}/blockerSet{i+1}.json",
          "ruleCount": len(json.loads(d)), "bytes": len(d), "sha256": hashlib.sha256(d).hexdigest()}
         for i, d in enumerate(set_files)]
srcs = [{"id": s[0], "name": s[4], "category": s[1], "license": s[2],
         "ruleCount": surv.get(s[0], 0), "url": s[3]} for s in sources]
mpath = os.path.join(root, "manifest.json")
prev = 1
try: prev = json.load(open(mpath)).get("version", 1)
except Exception: pass
manifest = {"schemaVersion": 2, "version": prev + 1, "updatedEpoch": int(time.time()),
            "lists": lists, "sources": srcs}
json.dump(manifest, open(mpath, "w"), indent=2); open(mpath, "a").write("\n")
print(f"  {sum(x['ruleCount'] for x in lists)} rules, manifest version {manifest['version']}"
      + (f", {dropped} dropped" if dropped else ""))
for s in sources: print(f"    {s[4]:24s} {surv.get(s[0],0):>7d}")
PY

for n in 1 2 3 4; do
  b=$(wc -c < "blockerSet${n}.json" | tr -d ' ')
  [ "$b" -le "$PER_FILE_CAP" ] || { echo "ERROR: blockerSet${n}.json ${b} > cap" >&2; exit 1; }
done
echo "$FINGERPRINT" > .inputs.sha256
echo "Done. Published blockerSet1..4.json + manifest.json."
