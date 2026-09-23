# App icon — source of truth

`icon.png` in this directory is the **master launcher icon** and the single
source of truth for **Open Lock**'s icon.

- Master: `icon.png` (PNG, 1254×1254, ≥512×512 as required). It is a full-bleed
  square: a white padlock centred on a blue field (`#0969F7`).
- **Do not modify or delete the master** unless technically required.

## Generated Android resources (committed)

All Android launcher resources are generated deterministically from this master
and committed under `android/app/src/main/res/`:

| Output | Location | Sizes |
| --- | --- | --- |
| Legacy launcher | `mipmap-{mdpi…xxxhdpi}/ic_launcher.png` | 48 / 72 / 96 / 144 / 192 px |
| Round launcher | `mipmap-{mdpi…xxxhdpi}/ic_launcher_round.png` | circular-masked, same sizes |
| Adaptive foreground | `drawable-{mdpi…xxxhdpi}/ic_launcher_foreground.png` | 108 / 162 / 216 / 324 / 432 px |
| Adaptive background | `values/colors.xml` → `ic_launcher_background` (`#0969F7`) | — |
| Adaptive / round XML | `mipmap-anydpi-v26/ic_launcher.xml`, `ic_launcher_round.xml` | — |
| Monochrome (themed) | `drawable/ic_launcher_monochrome.xml` (white padlock vector) | — |

Regeneration (optional): the `flutter_launcher_icons` block in `pubspec.yaml`
points at this master, so `dart run flutter_launcher_icons` reproduces the
legacy + adaptive foreground/background layers. The round icon and monochrome
layer are hand-maintained; the committed resources above are the source of
truth.

Deterministic raster generation used ImageMagick, e.g.:

```sh
magick icons/icon.png -resize 192x192 -strip \
  android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png
```
