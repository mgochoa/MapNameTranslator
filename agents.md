# MapNameTranslator — agent guide

## What this is

A **WoW Forever** (private server) addon that shows the current map's name
(zone / continent / city / battleground) translated into the languages the
player chooses — under the world-map title, in the minimap, and under the
hovered zone on the continent map.

## Layout

- `MapNameTranslator/` — the addon (this is what ships).
  - `MapNameTranslator.toc` — `## Interface: 16001`; loads `Data.lua` then `Core.lua`.
  - `Data.lua` — **generated**, do not hand-edit. `ns.Data = { [uiMapID] = { enUS=…, esES=…, … } }`, 60 maps.
  - `Core.lua` — all logic.
- `tools/gen_data.py` — regenerates `Data.lua` from wago.tools (stdlib only).
- `.pkgmeta`, `README.md`, `LICENSE`, `CHANGELOG.md`, `logo.svg` — packaging/metadata; **not** shipped.

## Regenerating `Data.lua`

Run `tools/gen_data.py`. There is no working `python3` on PATH (Windows Store
stub); run it in the eval Python kernel (`%load "tools/gen_data.py"`) or with
`py`. Update its `BUILD` constant when Forever adds zones (newest `wowf` build
from `https://wago.tools/api/builds`).

## Key facts & invariants

- Client interface `16001`, build `1.60.1.70938`. UiMap has 60 rows; `Type`:
  `1`=World, `2`=Continent, `3`=Zone, `6`=Battleground. **Battlegrounds are
  Type 6** — keep them in `KEEP_TYPES` (the four: Alterac Valley, Warsong
  Gulch, Arathi Basin, Darkspear Islands).
- Map title font string: global `WorldMapFrameTitleText` (also
  `WorldMapFrame.BorderFrame.TitleText`).
- Hovered-zone name inside the map: the area label, found via
  `WorldMapFrame.dataProviders` → `provider.Label.Name`.
- `C_Map.GetBestMapForUnit("player")` can **crash the client** in rare spots
  (documented by Ellesmere) — always guard with `pcall`.
- Reference addons (installed in the WoW folder, read-only):
  `EllesmereUIForeverEssentials/EllesmereUIForeverEssentials_ZoneLevels.lua`,
  `Leatrix_Plus/Leatrix_Plus.lua`.

## Deploy

Copy the three addon files into:

`C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\MapNameTranslator\`

## Verify

- No Lua interpreter here; syntax-check with `bunx luaparse <file>` (Lua 5.1).
- In-game is the only end-to-end check (the addon cannot run outside the client).

## Packaging (CurseForge)

`.pkgmeta` sets `package-as: MapNameTranslator`; ship only that folder.
`MapNameTranslator.zip` is a generated artifact — do **not** commit it.
