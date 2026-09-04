# Open UI sources

## Kenney Pixel UI Pack

- Source: https://kenney.nl/assets/pixel-ui-pack
- Mirror: https://opengameart.org/content/pixel-ui-pack-750-assets
- License: CC0 1.0 (see `kenney_pixel_ui/License.txt`)
- Imported use: nine-slice card, button, disabled-state, and progress-meter textures.
- The 48px source tiles use a 2px transparent/edge border; `PixelUITheme`
  keeps that source margin for every `StyleBoxTexture`.

## 16x16 Assorted RPG Icons (archived source)

- Source: https://opengameart.org/content/16x16-assorted-rpg-icons
- License: CC0 1.0
- The archive is retained for provenance, but is no longer imported by the
  runtime. HUD resources and inventory slots use the cohesive Ninja Adventure
  icon family documented below.

## Fusion Pixel Font

- Source: https://github.com/TakWolf/fusion-pixel-font
- License: SIL Open Font License 1.1 (see `fonts/fusion_pixel/OFL.txt`)
- Imported use: the HUD's default font, including Simplified Chinese labels.

## HUD visual baseline

- Logical authoring space: 960x540, with no HUD root scale or secondary 320x180
  coordinate layer.
- Icon family: Ninja Adventure 16px source sprites for every resource, tool,
  landmark, and inventory row. Destinations are 16px or 32px integer multiples
  and use nearest-neighbor filtering.
- Palette: dark teal panels (`#101b1d`, `#18282a`), sage borders/text
  (`#78968a`, `#b6c6b5`), ember accent (`#f2ca72`, `#e58b6a`) and water/safe
  status (`#7eb8b8`, `#9dc77c`). This palette is implemented in
  `scripts/pixel_ui_theme.gd` and is shared by every HUD state.
