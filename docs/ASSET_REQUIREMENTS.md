# Art Requirements

These are production requirements only. Stage 15 does not create final art or audio.

The design viewport is 1152×648. Source files may be larger and are scaled by their UI containers; code must not require exact source dimensions.

## Backgrounds

Recommended source: at least 1920×1080, 16:9, opaque unless a layered composition specifically requires transparency.

First batch:

- Main Menu — night storefront identity and readable center space.
- Convenience Store Normal — main gameplay, room for customer and shelf UI.
- Convenience Store Special Night — narrative variation for the fifth-night mystery.
- Archive — subdued background that keeps long text readable.
- Settings / Generic Interior — neutral reusable presentation background.

## Customer Portraits

Transparent PNG, high-resolution source, portrait composition that can be contained without cropping important features.

Current story characters:

- Black-eyed student
- Overtime worker
- Soaked man
- Woman in a red dress
- Silent old man
- Masked boy
- Lost child
- Insomniac driver
- Nameless guest
- Previous clerk

## Item Icons

Square transparent sources with consistent framing; 512×512 is recommended.

- coffee
- milk
- mint_candy
- black_umbrella
- red_lighter
- bandage
- old_photo
- ticket
- sleep_mask
- tissue
- dark_chocolate
- disposable_camera
- blank_postcard
- battery
- flashlight
- cheap_perfume
- expired_magazine
- lucky_sticker
- rice_ball
- coin

## UI Icons

Prefer SVG or high-resolution transparent PNG. Required IDs:

- lock
- check
- back
- coin
- warning
- combo
- archive
- settings

Icons supplement text; critical actions retain text labels.

## Logo

Transparent background, horizontal composition suitable for the main menu. Provide both “Midnight Wish Mart” and “深夜愿望便利店” treatments or a combined lockup. The text title remains available as a runtime fallback.

## Audio

BGM requirements:

- Main Menu
- Normal Shop
- Special Night
- Night Result

SFX requirements:

- UI Click
- Confirm
- Cancel
- Door Bell
- Cash Register
- Item Select
- Customer Good
- Customer Fail
- Night Complete

Deliver loop points and loudness notes with BGM. Avoid embedding gameplay state in filenames; use the manifest IDs for routing.
