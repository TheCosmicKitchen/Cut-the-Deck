// node tools/test.mjs — engine checks without a browser: cost table, fuzz test, and autoplayed runs.
import { readFileSync } from 'node:fs';
import { cardCost, cardText, makeCard } from '../engine/grammar.js';
import { fuzz } from '../engine/fuzz.js';
import { newRun, enterNode, finishCombat, takeReward, leaveWorkshop } from '../engine/run.js';
import { playCard, playInfo, endTurn } from '../engine/combat.js';

const load = (f) => JSON.parse(readFileSync(new URL(`../data/${f}.json`, import.meta.url)));
const db = { chunks: load('chunks'), cards: load('cards'), enemies: load('enemies'), rules: load('rules') };

console.log('Card costs:');
for (const def of db.cards.cards) {
  const c = cardCost(db, makeCard(def, 'x'));
  console.log(`  ${String(c.cost).padStart(2)}${c.x ? '+X' : '  '}  ${def.name.padEnd(15)} ${cardText(db, makeCard(def, 'x'))}`);
}

const f = fuzz(db, { decks: 500, turns: 8, seed: 7 });
console.log('\nFuzz:', JSON.stringify({ ok: f.ok, turns: f.turnsPlayed, maxRatio: f.maxRatio, safetyNet: f.safetyNet, failures: f.failures }));

let wins = 0, reached = [];
for (let seed = 1; seed <= 40; seed++) {
  const run = newRun(db, seed);
  while (run.phase !== 'victory' && run.phase !== 'defeat') {
    if (run.phase === 'map') enterNode(db, run);
    else if (run.phase === 'combat') {
      const s = run.combat;
      let guard = 0;
      while (s.phase === 'player' && guard++ < 50) {
        const p = s.hand.find((u) => playInfo(db, s, u).can);
        if (p) playCard(db, s, p); else endTurn(db, s);
      }
      if (s.turn > 60) throw new Error('fight did not end');
      finishCombat(db, run);
    } else if (run.phase === 'reward') takeReward(db, run, run.reward.choices[0]);
    else if (run.phase === 'workshop') leaveWorkshop(db, run);
  }
  if (run.phase === 'victory') wins++;
  reached.push(run.node);
}
console.log(`\nAutoplay (greedy, no edits): ${wins}/40 wins; nodes reached: ${reached.join(' ')}`);
