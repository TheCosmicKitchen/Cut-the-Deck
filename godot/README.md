# Cut the Deck: Godot 4.7

The Godot version of Cut the Deck. The rules are a line-by-line GDScript port of
the web prototype's engine (`../engine/`), checked against it trace for trace.

Open `godot/project.godot` in Godot 4.7. It uses the Compatibility renderer, so it
runs on older GPUs and can export to the web.

| Folder | What's in it |
|---|---|
| `engine/` | Rules as static functions over plain Dictionaries: `rng`, `grammar`, `edits`, `combat`, `run`, `fuzz`, and `db` (loads `data/`). No nodes. |
| `data/` | Copies of `../data/*.json`. Edit the originals; `tools/parity.sh` copies them over. |
| `ui/` | The look: `look.gd` (palette, fonts, candy frames), `card_view.gd`, `chunk_view.gd`, `px.gd` (pixel sprites for card pictures). |
| `shaders/` | `candy` (striped frames), `pill` (chunks), `gem` (cost), `inset` (art window), `bg` (backdrop). |
| `game/` | `game.gd` autoload (run state, saving) and the main scene. |
| `tests/` | `trace.gd` (parity trace), `mockup.tscn` (renders a style sheet to PNG). |
| `docs/` | Style mockups. `candy-style.png` is the chosen direction. |

## Checks

```
GODOT=/path/to/godot tools/parity.sh                 # engine parity with the JS build
godot --path godot res://tests/mockup.tscn -- out.png  # render the card style sheet
```

Fonts: Fredoka and Nunito (SIL OFL 1.1), licences in `fonts/licenses/`.
