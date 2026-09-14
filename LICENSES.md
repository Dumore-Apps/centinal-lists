# Licences & attributions

The compiled rule sets (`blockerSet1.json` … `blockerSet4.json`) in this repository
are a **derivative work** of the filter lists below and are distributed under the
**GNU General Public License v3.0** (GPL-3.0). The full GPL-3.0 text is at
<https://www.gnu.org/licenses/gpl-3.0.txt>.

## Sources compiled into the rule sets

| Source | Upstream licence | Elected for this artifact |
|---|---|---|
| [EasyList](https://easylist.to/) | dual GPL-3.0 / CC BY-SA 3.0 | GPL-3.0 |
| [EasyPrivacy](https://easylist.to/) | dual GPL-3.0 / CC BY-SA 3.0 | GPL-3.0 |
| [Fanboy's Annoyances](https://secure.fanboy.co.nz/) | dual GPL-3.0 / CC BY-SA 3.0 | GPL-3.0 |
| [IndianList](https://easylist.to/) | dual GPL-3.0 / CC BY-SA 3.0 | GPL-3.0 |
| [uBlock filters (uAssets)](https://github.com/uBlockOrigin/uAssets) | GPL-3.0 | GPL-3.0 |
| [AdGuard Base filter](https://github.com/AdguardTeam/AdguardFilters) | GPL-3.0 | GPL-3.0 |

Each source's surviving rule count is recorded in `manifest.json` → `sources[]`.

## Build tool

[AdGuard SafariConverterLib](https://github.com/AdguardTeam/SafariConverterLib) —
GPL-3.0. Used only at build time by `blockgen` to convert Adblock-Plus syntax to
Safari content-blocker JSON. Not shipped in any application binary.
