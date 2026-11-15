# MapNameTranslator

Shows the current map's name (zone, continent, city, battleground) translated into the languages you choose, right in the world map.

## Features

- Under the world map title
- Under the minimap
- Under the hovered zone name on the continent map
- Optional tooltip on the map title
- All 11 WoW locales, any subset selectable
- Configure in **Esc → Options → AddOns → MapNameTranslator**, or via `/mnt config`

## Commands

- `/mnt` — toggle on/off
- `/mnt config` — open the options

## Data

Translations are generated from the wago.tools `UiMap` table (build `1.60.1.70938`). To refresh after new zones are added, run `tools/gen_data.py` after updating its `BUILD` constant.

## License

MIT
