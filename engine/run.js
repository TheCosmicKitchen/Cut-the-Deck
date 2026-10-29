// One act: a fixed list of nodes from rules.run. The run owns the deck, Ink,
// clipboard and HP; each fight works on a copy of the deck.

import { makeCard, cloneCard, stripChunk } from './grammar.js';
import { startCombat } from './combat.js';
import { shuffle } from './rng.js';

export function enemyDefs(db, keys) {
  return keys.map((key) => ({ key, ...db.enemies.enemies[key] }));
}

export function cardDef(db, id) {
  return db.cards.cards.find((c) => c.id === id);
}

export function newCardUid(run) {
  return 'c' + run.nextUid++;
}

export function newRun(db, seed = (Date.now() % 2147483647) | 0, sandbox = false) {
  const run = {
    seed,
    hp: db.rules.player.hp,
    maxHp: db.rules.player.hp,
    deck: [],
    ink: db.rules.ink.start,
    clipboard: [],
    freeUses: {},
    node: 0,
    phase: 'map',
    combat: null,
    reward: null,
    sandbox,
    nextUid: 1,
  };
  for (const { card, copies } of db.cards.starterDeck) {
    for (let k = 0; k < copies; k++) run.deck.push(makeCard(cardDef(db, card), newCardUid(run)));
  }
  return run;
}

export function currentNode(db, run) {
  return db.rules.run[run.node];
}

export function enterNode(db, run) {
  const node = currentNode(db, run);
  if (!node) return;
  if (node.type === 'workshop') {
    run.ink += db.rules.ink.workshopBonus;
    run.phase = 'workshop';
    return;
  }
  run.combat = startCombat(db, run.deck, enemyDefs(db, node.enemies), run.seed++, { hp: run.hp, maxHp: run.maxHp });
  run.phase = 'combat';
}

// Call once the fight's phase is 'won' or 'lost'.
export function finishCombat(db, run) {
  const s = run.combat;
  const node = currentNode(db, run);
  run.hp = s.player.hp;
  if (s.phase === 'lost') {
    run.phase = 'defeat';
    return;
  }
  if (node.type === 'boss') {
    run.phase = 'victory';
    return;
  }
  const gained = node.type === 'elite' ? db.rules.ink.perElite : db.rules.ink.perFight;
  run.ink += gained;
  const drops = [];
  for (const key of node.enemies) {
    const d = db.enemies.enemies[key].drops ?? {};
    for (const [tool, n] of Object.entries(d.tools ?? {})) {
      run.freeUses[tool] = (run.freeUses[tool] ?? 0) + n;
      drops.push(`a free ${tool}`);
    }
    if (d.chunk) {
      if (run.clipboard.length < db.rules.clipboardSize) {
        run.clipboard.push(stripChunk(d.chunk));
        drops.push(`a ${d.chunk.type} chunk`);
      } else drops.push(`a ${d.chunk.type} chunk (lost: clipboard full)`);
    }
  }
  const pool = db.cards.cards.filter((c) => c.pool === 'reward');
  const rs = { seed: run.seed++ };
  run.reward = { ink: gained, drops, choices: shuffle(rs, pool).slice(0, db.rules.rewardChoices).map((c) => c.id) };
  run.phase = 'reward';
}

export function takeReward(db, run, cardId) {
  if (cardId) run.deck.push(makeCard(cardDef(db, cardId), newCardUid(run)));
  run.reward = null;
  run.combat = null;
  run.phase = 'workshop';
}

export function leaveWorkshop(db, run) {
  run.node++;
  run.phase = run.node >= db.rules.run.length ? 'victory' : 'map';
}

export function addCardToDeck(db, run, card) {
  const c = cloneCard(card);
  c.uid = newCardUid(run);
  run.deck.push(c);
  return c;
}
