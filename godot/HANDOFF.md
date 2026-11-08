# Handoff: where the Godot port stands

Branch `godot-port`. Godot 4.7, Compatibility renderer.

## Working

- **Engine** (`engine/*.gd`) is a bit-exact port of the browser engine (`../engine/*.js`).
  `tools/parity.sh` diffs 25 seeded runs + fuzz between the two
  (needs `GODOT=/path/to/godot`). Last result: 13,830 identical trace lines.
- **Chunks remember their source card** (`from`) and cards record `holes` where
  words were cut. Both engines; rules unchanged.
- **Paper-world card renderer** (mockup quality): `ui/pub.gd`, `ui/pub_card.gd`,
  `ui/pub_chunk.gd`, shaders `pub_paper`, `pub_photo`, `desk`.
  Six publications: Newspaper, Comics, Pulp Horror, Zine, Instruction Manual, Almanac.
  Pasted slips keep their source's paper and type, and are stuck on the
  destination's way (glue, tape, red thread, staples, bolts, photo corners).
- **Mockups**: `tests/pub_mockup.tscn` renders `docs/paper-world.png`
  (six cards, then the same six with words swapped by the real Edits tools):

  ```
  xvfb-run -a godot --path godot --rendering-driver opengl3 res://tests/pub_mockup.tscn -- out.png
  ```

  Run `godot --headless --path godot --import` first after adding new class_names.

## Next (from the latest feedback)

1. **Card art: drop the illustrated scenes for now.** Use abstract art in the
   earlier style (the cut-paper shapes of `ui/illo.gd`'s paper toolkit), and keep
   cards "cardy and papery with colours on the background": a coloured paper
   ground per publication, not full-bleed pictures. `PubCard` has `full_art`
   (default true) and the older framed-picture layout (`full_art = false`).
2. Screens are not built: `game/main.gd` still references the old UI and won't
   run. Needed: title, map, combat, reward, workshop + tutorial, end.
3. Design still open:
   - the publication ring and pair synergies/counters (see chat; not in data yet)
   - what swapping a card's art does
   - the Manual's "Build" keyword and ×2/×6 multipliers

## Older UI kept for reference

`ui/card_view.gd` + `ui/chunk_view.gd` (candy-stripe cards), `tests/mockup.tscn`.
