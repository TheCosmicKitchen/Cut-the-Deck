// Phase 2 gate: generate random legal cards and decks, play random turns,
// and fail if any turn passes N plays, N draws or 3N clause resolutions.

import { chunkIds, emptyClause, SLOTS } from './grammar.js';
import { combatEdit, endTurn, playCard, playInfo, startCombat } from './combat.js';
import { pick, rand, randInt } from './rng.js';

function randomClause(db, s) {
  const c = emptyClause();
  c.verb = { type: 'verb', id: pick(s, chunkIds(db, 'verb')) };
  c.amount = { type: 'amount', id: pick(s, chunkIds(db, 'amount')) };
  for (const slot of ['trigger', 'repeat', 'target', 'condition']) {
    if (rand(s) < 0.4) c[slot] = { type: slot, id: pick(s, chunkIds(db, slot)), neg: slot === 'condition' && rand(s) < 0.5 };
  }
  return c;
}

export function randomCard(db, s, uid) {
  const n = 1 + randInt(s, db.rules.maxClauses);
  return { uid, base: 'fuzz', name: 'Fuzz ' + uid, clauses: Array.from({ length: n }, () => randomClause(db, s)) };
}

const DUMMY = { key: 'dummy', name: 'Dummy', role: 'Test', hp: 99999, pattern: [{ attack: 1 }, { edit: 'invert_verb' }, { edit: 'typo' }, { edit: 'blackout' }] };

export function fuzz(db, { decks = 300, turns = 8, seed = 1 } = {}) {
  const s = { seed };
  const result = { decks, turnsPlayed: 0, maxRatio: { plays: 0, draws: 0, resolutions: 0 }, failures: [], safetyNet: 0 };
  for (let d = 0; d < decks; d++) {
    const N = 5 + randInt(s, 20);
    const deck = Array.from({ length: N }, (_, k) => randomCard(db, s, `f${d}_${k}`));
    const c = startCombat(db, deck, [DUMMY], randInt(s, 1e9), { hp: 99999, maxHp: 99999 });
    for (let t = 0; t < turns && c.phase === 'player'; t++) {
      for (let guard = 0; guard < 200 && c.phase === 'player'; guard++) {
        if (c.hand.length && rand(s) < 0.15) {
          const uid = pick(s, c.hand);
          const card = c.cards[uid];
          const ci = randInt(s, card.clauses.length);
          const slot = pick(s, SLOTS.filter((sl) => card.clauses[ci]?.[sl]));
          if (slot) combatEdit(db, c, rand(s) < 0.5 ? 'mute' : 'invert', uid, ci, slot);
        }
        const playable = c.hand.filter((u) => playInfo(db, c, u).can);
        if (!playable.length) break;
        playCard(db, c, pick(s, playable));
      }
      check(c, N, result, d);
      if (c.phase === 'player') endTurn(db, c);
      result.turnsPlayed++;
    }
  }
  result.ok = result.failures.length === 0 && result.safetyNet === 0;
  return result;
}

function check(c, N, result, d) {
  const st = c.stats;
  const r = { plays: st.plays / N, draws: st.draws / N, resolutions: st.resolutions / (3 * N) };
  for (const k of Object.keys(r)) result.maxRatio[k] = Math.max(result.maxRatio[k], r[k]);
  if (c.aborted) result.safetyNet++;
  if (r.plays > 1 || r.draws > 1 || r.resolutions > 1) {
    if (result.failures.length < 5) result.failures.push({ deck: d, N, ...st });
  }
}
