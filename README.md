# centinal-lists

Public filter-list distribution for **Centinal** (the ad/tracker blocker for Safari,
iOS/iPadOS/macOS). This repo compiles six open, GPL-3.0 community filter lists into
four Safari content-blocker rule sets and publishes them, so the app can update its
blocking **over the air** — no App Store round-trip.

## What's served (via GitHub Pages)

| File | What it is |
|---|---|
| `manifest.json` | Schema-v2 index: each set's URL, `bytes`, `sha256`, plus a `sources[]` provenance list with per-source rule counts + licences. |
| `blockerSet1.json` … `blockerSet4.json` | The compiled Safari content-blocker rules (each ≤ 1.5 MB, the iOS OOM ceiling). |

The Centinal app fetches `manifest.json`, and downloads only the sets whose `sha256`
changed. It validates every download against `bytes` + `sha256` + the content-blocker
JSON schema before installing, so this repo is a plain static origin with no server
logic and no secrets required to run.

## Sources (all GPL-3.0 — see the compiled artifact's licence below)

EasyList, EasyPrivacy, Fanboy's Annoyances and IndianList are dual GPL-3.0 / CC BY-SA
3.0; we **elect the GPL-3.0 branch** of each. uBlock filters and AdGuard Base are
GPL-3.0. Every source is credited with its live rule count in `manifest.json`.

## Licence

The **compiled rule sets** (`blockerSet*.json`) are **GPL-3.0**, being a derivative of
the GPL-3.0 sources above. They are published here openly, which satisfies copyleft.
The `blockgen` converter uses AdGuard's SafariConverterLib (GPL-3.0) at build time
only. See `LICENSES.md` for the per-source attributions.

## How it updates

`.github/workflows/refresh.yml` runs `refresh.sh` daily (and on demand). `refresh.sh`
downloads the six lists, converts them with `blockgen` (SafariConverterLib), byte-
greedy bin-packs them into the four sets, and writes `manifest.json`. If the upstream
lists are unchanged since the last run it exits without bumping the version, so only
real changes are ever published.

Run it locally with: `bash refresh.sh` (needs Xcode / Swift + Python 3).
