// node tools/trace.mjs > out.txt — deterministic trace of whole runs (fights, quick edits,
// workshop edits, rewards) used to check the Godot port: godot/tests/trace.gd must print
// exactly the same text. Run both with tools/parity.sh.
import { readFileSync } from 'node:fs';
import { cardCost, cardText, SLOTS } from '../engine/grammar.js';
import * as E from '../engine/edits.js';
import { fuzz } from '../engine/fuzz.js';
import { newRun, enterNode, finishCombat, takeReward, leaveWorkshop } from '../engine/run.js';
import { playCard, playInfo, endTurn, combatEdit, intentText } from '../engine/combat.js';

const load = (f) => JSON.parse(readFileSync(new URL(`../data/${f}.json`, import.meta.url)));
const db = { chunks: load('chunks'), cards: load('cards'), enemies: load('enemies'), rules: load('rules') };
const out = [];
const p = (s) => out.push(s);

function costStr(card) { const c = cardCost(db, card); return c ? `${c.cost}${c.x ? '+X' : ''}` : 'broken'; }

function workshop(run, step) {
  const deck = run.deck;
  const first = deck[0];
  const results = [];
  if (step % 2 === 0) {
    const ci = 0;
    const slot = SLOTS.find((s) => first.clauses[0]?.[s] && s !== 'verb');
    if (slot) results.push(E.cut(db, run, first.uid, ci, slot));
    const clip = run.clipboard.length - 1;
    const tgt = deck.find((c) => c !== first && c.clauses[0] && clip >= 0 && c.clauses[0][run.clipboard[clip].type] !== undefined);
    if (tgt && clip >= 0) results.push(E.glue(db, run, tgt.uid, 0, run.clipboard[clip].type, clip));
  } else {
    const last = deck[deck.length - 1];
    if (last.clauses[0]?.verb) results.push(E.invert(db, run, last.uid, 0, 'verb'));
    if (last.clauses[0]?.amount) results.push(E.mute(db, run, last.uid, 0, 'amount'));
    if (deck.length > 3) results.push(E.merge(db, run, deck[1].uid, deck[2].uid));
    if (deck.length > 8) results.push(E.shred(db, run, deck[deck.length - 2].uid));
  }
  for (const r of results) p(`  edit: ${r.ok ? 'ok' + (r.note ? ' ' + r.note : '') : r.error}`);
}

for (let seed = 1; seed <= 25; seed++) {
  p(`== run ${seed}`);
  const run = newRun(db, seed * 7919);
  let wsStep = 0;
  while (run.phase !== 'victory' && run.phase !== 'defeat') {
    if (run.phase === 'map') enterNode(db, run);
    else if (run.phase === 'combat') {
      const s = run.combat;
      let guard = 0, act = 0;
      while (s.phase === 'player' && guard++ < 80) {
        s.enemies.forEach((e, i) => { if (!e.dead) p(`  intent ${e.name}: ${intentText(db, s, i)}`); });
        act++;
        if (act % 4 === 0 && s.hand.length) {
          const uid = s.hand[s.hand.length - 1];
          const cl = s.cards[uid].clauses[0];
          if (cl) {
            const slot = SLOTS.find((x) => cl[x]);
            const r = combatEdit(db, s, act % 8 === 0 ? 'invert' : 'mute', uid, 0, slot);
            p(`  cedit: ${r.ok ? 'ok' : r.error}`);
          }
        }
        const alive = s.enemies.map((e, i) => i).filter((i) => !s.enemies[i].dead);
        const target = alive[act % alive.length];
        const pl = s.hand.find((u) => playInfo(db, s, u).can);
        if (pl) playCard(db, s, pl, target); else endTurn(db, s);
      }
      for (const l of s.log) p(`  [${l.turn}] ${l.msg}`);
      finishCombat(db, run);
      p(`  after fight: phase=${run.phase} hp=${run.hp} ink=${run.ink} free=${JSON.stringify(run.freeUses)} clip=${run.clipboard.map((c) => c.type + ':' + c.id + (c.neg ? '!' : '')).join(',')}`);
    } else if (run.phase === 'reward') {
      p(`  reward: ${run.reward.choices.join(',')} drops=${run.reward.drops.join('; ')}`);
      takeReward(db, run, run.reward.choices[seed % 3]);
    } else if (run.phase === 'workshop') {
      workshop(run, wsStep++);
      for (const c of run.deck) p(`  deck ${c.uid} ${costStr(c)} ${c.name}: ${cardText(db, c)}`);
      leaveWorkshop(db, run);
    }
  }
  p(`  end: ${run.phase} node=${run.node} hp=${run.hp} ink=${run.ink}`);
}
const f = fuzz(db, { decks: 120, turns: 6, seed: 99 });
p(`fuzz ok=${f.ok} turns=${f.turnsPlayed} plays=${f.maxRatio.plays.toFixed(4)} draws=${f.maxRatio.draws.toFixed(4)} res=${f.maxRatio.resolutions.toFixed(4)} net=${f.safetyNet}`);
console.log(out.join('\n'));
