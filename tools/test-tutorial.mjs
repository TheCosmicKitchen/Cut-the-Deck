// node tools/test-tutorial.mjs — each tutorial step's solve must satisfy its own check.
import { readFileSync } from 'node:fs';
import { TUTORIAL, newTutorialRun } from '../ui/tutorial.js';
import { cardCost, cardText } from '../engine/grammar.js';
const load = (f) => JSON.parse(readFileSync(new URL(`../data/${f}.json`, import.meta.url)));
const db = { chunks: load('chunks'), cards: load('cards'), enemies: load('enemies'), rules: load('rules') };
const run = newTutorialRun(db);
TUTORIAL.forEach((s, i) => {
  if (!s.solve) return;
  const before = s.check(run, db);
  const res = s.solve(run, db);
  console.log(`${i + 1}. ${s.title.padEnd(24)} ok=${res.ok} checkBefore=${before} checkAfter=${s.check(run, db)} ink=${run.ink}`);
});
for (const c of run.deck) console.log('   ', cardCost(db, c)?.cost, c.name, '-', cardText(db, c));
console.log('   clipboard:', run.clipboard.map((c) => c.type + ':' + c.id).join(', '));
