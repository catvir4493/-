# Asset Pipeline

## Purpose

The presentation asset layer keeps textures, audio, and fonts separate from gameplay data and state. Gameplay systems continue to use IDs such as `coffee` or `placeholder_student`; only `AssetRegistry` resolves those IDs to Godot resources.

The pipeline is intentionally small:

```text
presentation_assets.json → AssetRegistry → ResourceLoader → cache/fallback → UI or AudioManager
```

It does not manage money, inventory, customer progress, chapters, saves, downloads, patches, DLC, or mods.

## Folder Structure

```text
assets/
  art/
    backgrounds/
      shop/
      story/
      menu/
    customers/
      portraits/
    items/
      icons/
    ui/
      icons/
      logos/
      decorations/
    placeholders/
  fonts/
  audio/
    bgm/
    sfx/
      ui/
      shop/
      customer/
      ambience/
```

Gameplay JSON remains under `data/`; scripts remain under `scripts/`.

## Naming Convention

Use lowercase English `snake_case` filenames. Do not use spaces, Chinese filenames, or temporary names such as `image1.png` and `final_final_2.png`.

Examples:

- `bg_shop_night_01.png`
- `portrait_student_01.png`
- `item_coffee.png`
- `ui_coin.svg`
- `logo_main.png`
- `bgm_main_menu.ogg`
- `sfx_ui_click.wav`

## Manifest

The manifest is `res://data/presentation_assets.json` with independent `manifest_version = 1`. Categories are:

- `backgrounds`
- `portraits`
- `item_icons`
- `ui_icons`
- `logos`
- `fonts`
- `bgm`
- `sfx`

Each category maps a stable asset ID to an object containing a `path`. Non-empty paths must use `res://`. Empty paths are allowed for planned audio or font resources and return a safe null value.

## Adding an Item Icon

1. Place the file at a stable path, for example `assets/art/items/icons/item_coffee.png`.
2. Change only the `coffee.path` entry in `presentation_assets.json`.
3. Run `asset_validation.gd`.

No change is needed in `ItemCard.gd`, `ShopScene.gd`, or `InventorySystem.gd`.

## Adding a Customer Portrait

The resolution chain is:

```text
customer_profiles.json portrait_id
→ presentation_assets.json portraits entry
→ AssetRegistry.get_texture("portraits", portrait_id)
→ CustomerHeader
```

Keep `portrait_id` stable. Never derive filenames from the localized customer name.

## Adding a Background

Add a `backgrounds` manifest entry and call `ScreenBackground.set_background(asset_id)`. Background controls fill the viewport, ignore mouse input, and use keep-aspect-covered rendering.

## Adding BGM

Place an imported audio file under `assets/audio/bgm/`, set the matching `bgm` manifest path, then call:

```gdscript
AudioManager.play_bgm_by_id("main_menu", 0.3)
```

The existing stream-based API remains available.

## Adding SFX

Place the file in the appropriate `assets/audio/sfx/` subfolder, update the `sfx` manifest entry, then call:

```gdscript
AudioManager.play_sfx_by_id("ui_click")
```

Missing audio is ignored safely and warnings are deduplicated per asset during one run.

## Adding Fonts

Add a path under the `fonts` category. `UIThemeManager.apply_font_assets(theme)` can apply `font_ui_default` to a supplied Theme. Until a font is assigned, Godot's default font remains active.

## Placeholder Policy

Stage 15 includes five deliberately generic SVG placeholders: background, portrait, item, UI icon, and logo. Multiple IDs may point to the same placeholder file. If the manifest is missing, corrupt, references a missing path, or contains a wrong resource type, `AssetRegistry` warns once and texture consumers receive an internal generated fallback instead of null.

Audio and fonts have no fabricated media fallback. Missing streams/fonts return null safely, so the current default font and silent audio behavior continue.

## Texture Stretch and Import

- Background: keep aspect covered.
- Portrait: keep aspect contained/centered.
- Item and UI icon: keep aspect centered.
- Logo: keep aspect contained/centered.

The final visual style is not locked. If the project chooses pixel art, configure the relevant imports for pixel-appropriate filtering. If it chooses hand-drawn art, use linear filtering. Do not force a global filter before that choice is made.

## Asset Validation

Run:

```powershell
Godot --headless --path . --script res://tests/asset_validation.gd
```

The validator checks JSON shape, categories, paths, resource types, all 20 item IDs, all profile portrait IDs, and required background/UI IDs.

## Replacing Placeholder Assets

Replacing presentation assets should normally require only placing a file and changing its manifest path. Gameplay logic and save data must not contain texture, audio, font, manifest, or cache metadata.
