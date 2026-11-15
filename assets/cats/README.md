# Cat layer art — status

The cat renderer in `lib/cat_avatar.dart` currently draws every layer in
code (`CustomPainter`). Each layer paints in a canonical transparent space
and composites bottom-to-top, so a layer can be replaced by a transparent
PNG without touching the others. This folder is reserved for that art.

## Canonical spaces

- Head layers: **120×120** logical units, transparent background.
- Body layers (full `CatCharacter`): **240×310** logical units.
- Accessories stay in `assets/generated/` as today (256 px sprites).

## Layer order (head)

| # | Layer kind | Contents | Files needed |
|---|------------|----------|--------------|
| 1 | `ears` | Ear silhouettes for each ear variant, fur-filled with ink outline and pink inner ear. Variants: `normal` (two), `left` (left only — Tzuki), `folded`, `tufted`. | `ears_normal.png`, `ears_left.png`, `ears_folded.png`, `ears_tufted.png` — or one sheet `ears_sheet.png` with 4 cells. |
| 2 | `base` | Head silhouette filled with fur + ink outline. Should be authored as a neutral mid-grey so it can be tinted per fur colour, or shipped per fur colour. | `head_base.png` (tintable) or `head_base_<fur>.png` × 6. |
| 3 | `pattern` | Coat markings per pattern, clipped to head + ears. Patterns: `solid` (empty), `tabby`, `bicolour`, `calico`, `colourpoint`. Markings must read on both light and dark furs (use the marking-colour rule: light fur → dark marks, dark fur → light marks). | `pattern_tabby.png`, `pattern_bicolour.png`, `pattern_calico.png`, `pattern_colourpoint.png`. |
| 4 | `muzzle` | Cream muzzle patch, pink nose, mouth strokes. Fixed for every cat. | `muzzle.png`. |
| 5 | `eyes` | Eye whites/irises/pupils/highlights. Iris colour is a parameter; either ship per eye colour or author white+dark and tint the iris. | `eyes_<colour>.png` × 4 (green, blue, gold, copper) or a tintable `eyes.png`. |

## Body layers (240×310)

| Layer kind | Contents | Files needed |
|------------|----------|--------------|
| `base` | Tail, torso, legs, cream belly/paws, fur fill + ink outline. | `body_base.png` (tintable) or per fur colour. |
| `pattern` | Body markings: tabby side stripes, bicolour chest bib, calico patches, colourpoint tail/paws. | `body_pattern_tabby.png`, `body_pattern_bicolour.png`, `body_pattern_calico.png`, `body_pattern_colourpoint.png`. |

## Accessories

Already shipped as individual sprites in `assets/generated/`:
`acc_pirate_bandana.png`, `acc_witch_hat.png`, `acc_pink_bow.png`,
`acc_ninja_headband.png`. They render on top of every other layer.

## Style reference

Match the flat cartoon style of the reference sheets in `assets/`
(`sprites_*.png.jpg`): bold `ink` (#51312d) outlines, soft pastel fills,
big friendly eyes. Layers must keep alpha where the cat is not, so any
combination of fur × pattern × eyes × ears composites cleanly.

Until this art exists the code-drawn layers above are the source of truth;
swap them for PNGs behind the same `CatLayer` contract without changing
screens or tests.
