# Cut the Deck

**Live at https://thecosmickitchen.github.io/Cut-the-Deck/**: a paper-proxy table and card editor for inventing and playtesting cards.

- **Table:** play by hand, like paper proxies. Trackers, draw/shuffle/end turn, enemy intents, counters on cards, undo. Click any word on a card to cut, copy, mute, invert or paste.
- **Cards:** the card library. Write text in plain words; keywords are recognized and colored as you type.
- **Keywords & colors:** each keyword's color, opposite (for Invert) and meaning; the six-color pie; hand size and starting trackers.
- **Save & share:** saves in the browser automatically; download or load a save file (`cut-the-deck-proxies` JSON) to trade sets.

The whole app is the single file `index.html`. Nothing to build or install.

## Older web prototype

`prototype.html` is the earlier rules-engine prototype (one act with automated combat and Workshop tools). The notes below are about it.

## Run it

```
node tools/serve.mjs           # http://localhost:5173
node tools/test.mjs            # cost table, fuzz test, 40 autoplayed runs
node tools/test-tutorial.mjs   # every tutorial step's solution passes its check
```

## Layout

| Folder | What's in it | Godot port |
|---|---|---|
| `data/` | All content and tuning as JSON: `chunks.json` (vocabulary, inverts, weights), `cards.json`, `enemies.json`, `rules.json` | Load as-is with `JSON.parse_string(FileAccess.get_file_as_string(...))` |
| `engine/` | The rules as pure functions over plain data. No DOM, no classes, no globals; randomness comes from a seeded RNG stored in state | Port file by file to GDScript (Dictionaries/Arrays map 1:1) |
| `ui/` | Web front end only: renders state and turns clicks into engine calls. `tutorial.js` holds the tutorial steps as data (card to select, what to highlight, a check, a scripted solution) | Replace with Godot scenes; the tutorial steps port as-is |

Engine files, in dependency order: `rng.js` → `grammar.js` (clauses, cost, invert, text) → `edits.js` (Workshop tools) → `combat.js` (turns, enemies, invariants) → `run.js` (the act) → `fuzz.js` (phase 2 gate).

Because the RNG is mulberry32 with its seed in state, a GDScript port can be checked against this one: same seed, same deck, same actions should give the same log.

## Rules decided in this build

- **Mid-fight edits** are one-tap and apply at once: Mute/Unmute and Invert on a card in hand, 1 energy each, lasting until the fight ends. No clipboard in combat; Scissors, Glue, Merge and Shred stay at Workshops.
- **Cost:** a clause weighs `verb.weight + amountScale × amount × hits + target + condition + trigger`. A drawback clause (hurts you or helps an enemy) counts −0.5× its weight, so muting a drawback raises the card's cost.
- **Inverting a Verb keeps who it hits:** Strike inverts to "Heal 6 to an enemy", not a self-heal.
- **Muted Verb or Amount** makes the clause do nothing; a muted optional chunk acts as an empty slot.
- All enemy and fight edits work on a copy of the deck and end with the fight.

Every number in `data/` is a placeholder.
