# Project Instructions

## Communication Style

- When talking with the user, avoid unnecessarily technical or specialized
  language. Prefer clear, everyday Chinese that is easy to understand.
- When a technical term is needed for accuracy, briefly explain what it means
  in plain language the first time it appears.
- Keep exact commands, file paths, code names, and error messages unchanged
  when changing them would make the answer inaccurate.

## Asset Sourcing

- When the project needs new assets, first search the [Ninja Adventure Asset Pack](https://pixel-boy.itch.io/ninja-adventure-asset-pack) and reuse a suitable asset from it whenever possible.
- Avoid creating new assets when the asset pack already contains something suitable.
- Create a new asset only when the asset pack has no suitable option or its available assets cannot meet the project's technical or visual requirements.
- Follow the asset pack's license and attribution requirements when importing or distributing its assets.

## Project Asset Baseline

Unless a deliberate exception is documented in the owning script or source
record, all new game art and HUD work must use this baseline:

```text
Game logical viewport: 960x540
HUD authoring space:   960x540
World art:             Ninja Adventure at its original source dimensions
HUD item icons:        16x16 design pixels, or an explicitly documented family
UI panels:             Kenney Pixel UI Pack nine-slice resources
Font:                  Fusion Pixel Simplified Chinese font
Texture filtering:     nearest-neighbor
Scaling:               integer multiples only
Color:                 one documented palette per interface family
```

- The viewport and HUD authoring space are the same coordinate system. Do not
  introduce a hidden 320x180 HUD coordinate layer or a second runtime HUD scale.
- Keep world sprites at their source pixel density unless the whole asset family
  is intentionally migrated together.
- Use one consistent icon family in each HUD row. A different size or family
  requires a source record explaining the visual and technical reason.
- Store the palette decision beside the relevant UI source record. New colors
  must be added to that palette deliberately rather than chosen per widget.
- The baseline does not override licensing: every imported asset still needs a
  verified source URL, license, and redistribution decision.

## Pixel UI and HUD Standards

These rules apply to the exploration HUD, inventory windows, dialogs, buttons,
resource icons, fonts, and any future pixel-art interface work.

### Coordinate and Display Model

- Keep the game's canonical logical viewport and HUD authoring space at
  `960x540`. HUD layout values are written directly in this space.
- Keep the existing Godot stretch configuration: `canvas_items`, `aspect = keep`,
  and integer scale. `canvas_items` is Godot's 2D CanvasItem stretch mode; it
  scales the Control/Node2D canvas to the window and is not a widget library.
- Fullscreen means changing the output window mode, not increasing the HUD
  authoring resolution. Do not replace the 960x540 HUD space with 1920x1080
  coordinates just to fill a monitor.
- The intended path is `960x540 HUD design and logical viewport ->
  integer-scaled output`. Do not add a HUD root scale or per-control scale.
- Do not mix design-space coordinates with logical-viewport or desktop-pixel
  coordinates in the same layout function. Use named constants for design-space
  positions and sizes; never hard-code `1920`, `1080`, or a monitor size in HUD
  layout code.
- Preserve the aspect ratio. Do not use non-uniform horizontal or vertical
  stretching to remove letterboxing.

### Pixel Grid and Scaling

- Every HUD position, size, padding, border margin, and icon destination must be
  an integer in the 960x540 logical grid.
- HUD and child Controls must use `scale = Vector2.ONE` unless a documented
  animation temporarily requires otherwise. The only normal runtime stretch is
  Godot's viewport-to-window integer scaling.
- Avoid fractional `position`, `size`, `pivot_offset`, and `scale` values. If a
  container produces fractional geometry, round the final geometry to the
  design grid before drawing.
- Use a 3-pixel alignment rhythm for major HUD spacing and borders when it fits
  the component. This preserves the chunky pixel feel without introducing a
  second runtime design coordinate system.
- Pixel art is allowed to become larger on a high-resolution monitor. It must
  not be redrawn at a larger logical resolution merely to make it smaller on
  screen.
- Test at the native logical view and at the configured fullscreen output. A
  screenshot taken for pixel inspection should be captured at `960x540` and
  enlarged with nearest-neighbor scaling when a larger review image is needed.

### Fonts and Text

- HUD text must use an explicitly imported pixel font. Do not use
  `ThemeDB.fallback_font` for final HUD labels.
- The current approved default is the Simplified Chinese Fusion Pixel font in
  `assets/fonts/fusion_pixel/`. Keep its OFL license file with the font.
- Choose a fixed pixel size and use the same font resource for labels, buttons,
  counters, tooltips, and modal text. Do not compensate for a wrong font by
  applying a second scale to individual labels.
- Understand the rendering pipeline: a TTF/OTF stores glyph outlines; Godot
  rasterizes those outlines into screen pixels at the requested size. A bitmap
  font stores pre-drawn pixel cells. Either can be sharp, but only when the
  chosen size and placement land on the pixel grid.
- For pixel HUD fonts, set antialiasing to `NONE`, disable hinting where the
  importer exposes it, and disable subpixel positioning. Keep text positions
  and baselines on integer design pixels.
- A bitmap font is not automatically blurry. It becomes blurry when it is
  filtered, placed between pixels, or scaled by a non-integer factor. If a
  bitmap font has a native 10px face, scale that face by an integer factor or
  choose another supplied size; never stretch it by an arbitrary percentage.
- Verify Chinese strings, Latin strings, numbers, punctuation, and mixed-width
  strings. No label may clip, overlap an icon, or change the height of its
  parent panel when the text changes.

### Texture Filtering and Icons

- Treat PNG sprite sheets and individual PNG sprites as bitmaps: fixed grids of
  colored pixels, not resolution-independent vector art.
- Use nearest-neighbor filtering for all pixel HUD textures. Nearest filtering
  copies the closest source pixel when an image is enlarged, preserving hard
  color blocks. Linear filtering blends neighboring pixels and is prohibited for
  pixel HUD art because it creates soft edges and halos.
- Keep the project default texture filter at nearest and explicitly set
  `CanvasItem.TEXTURE_FILTER_NEAREST` on HUD `TextureRect`, `Sprite2D`, and
  other image-bearing controls when their inheritance is not obvious.
- Do not mix icon families, source resolutions, outlines, or palette treatments
  in one component row without documenting the reason. Prefer a complete icon
  sheet over hand-drawn Unicode symbols or emoji.
- Render a source icon at its native logical size or at an integer multiple. If
  an icon must be recolored, preserve its silhouette and source pixel grid.

### Panels, Buttons, and Nine-Slice

- Use the imported Kenney Pixel UI Pack resources under
  `assets/art/open_ui/kenney_pixel_ui/` for standard panel, button, disabled,
  and progress-meter surfaces. Keep the source and license record in
  `assets/art/open_ui/SOURCES.md`.
- Use a real `NinePatchRect` or `StyleBoxTexture` for stretchable panels. A
  nine-slice divides a texture into four fixed corners, four one-axis edges,
  and a stretchable center, so ornate corners and border thickness survive
  resizing.
- Set texture margins from the source sprite's actual border pixels. Do not use
  content padding as a substitute for texture margins, and do not scale the
  whole panel texture when a nine-slice is required.
- Every interactive button must provide and visually test normal, hover,
  pressed, disabled, and focus states. Icon buttons must have a tooltip or an
  adjacent accessible label when the symbol is not universally recognizable.
- Keep a component's state colors, border thickness, corner shape, font, and
  icon treatment consistent across the HUD. Do not give every button a separate
  hand-written `StyleBoxFlat` when an imported Theme resource can express the
  same system.

### Theme and Asset Licensing

- Prefer reusable open resources over one-off hand-drawn replacements, but
  verify the license before importing anything. Record source URL, license,
  intended use, and attribution requirements in `assets/art/open_ui/SOURCES.md`.
- Current UI sources are Kenney Pixel UI Pack (CC0), 16x16 Assorted RPG Icons
  (CC0), and Fusion Pixel Font (SIL OFL 1.1). Do not remove their license files.
- Continue to follow the Ninja Adventure asset-pack rule above for world and
  item art. If a UI asset also exists in that pack and matches the required
  style, prefer the cohesive existing project asset.
- Do not copy paid, proprietary, or “free sample” packs into the project as if
  they were open source. A runtime dependency must be redistributable under a
  license compatible with the game.

### Implementation Boundaries

- Keep layout constants grouped near the top of the owning UI script and name
  them in 960x540 logical-viewport units. Do not scatter magic numbers through
  refresh or signal handlers.
- Keep visual construction in Theme/style helpers and keep gameplay state in
  `GameManager`, resource systems, and world scripts. HUD refresh functions
  consume state; they must not invent alternate resource or progression rules.
- Use `TextureRect`/`TextureButton`/`NinePatchRect`/Theme resources for visual
  assets. Use custom drawing only when no suitable reusable asset exists and
  document why.
- Do not introduce a second UI framework or web UI runtime into the Godot
  game. External references may guide design, but shipped UI must be native
  Godot resources and controls.

### Acceptance Checks

- Run the HUD layout and icon regression scripts after any HUD, font, theme, or
  display-setting change. They must pass with zero failures.
- Inspect a `960x540` capture at 1:1 for crisp glyphs, even borders, integer
  icon sizes, and no overlap. Then inspect the configured fullscreen output for
  the same composition and aspect ratio.
- Test at least these states: normal gameplay, paused menu, backpack open,
  storage/fish processing window open, shortcut help open, and log panel open.
- Check long Simplified Chinese labels and changing resource quantities. Text
  must remain inside its parent, and a changed value must not resize or shift
  neighboring controls unexpectedly.
- Any deliberate deviation from these rules must include a short reason in the
  owning script or the relevant asset source record.
