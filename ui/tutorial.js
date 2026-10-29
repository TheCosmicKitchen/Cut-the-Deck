// Guided editing tutorial on a fixed practice deck. Each step names the card to
// select, what to highlight, and a check that advances once the player has done it.
// `solve` replays a step's edit so "Back" can rebuild the deck as it stood.

import { makeCard } from '../engine/grammar.js';
import * as E from '../engine/edits.js';

const PRACTICE = [
  ['t-swing', 'reckless_swing'],
  ['t-strike', 'strike'],
  ['t-over', 'overcharge'],
  ['t-jab', 'jab'],
  ['t-defend', 'defend'],
];

const card = (run, uid) => run.deck.find((c) => c.uid === uid);

export const TUTORIAL = [
  {
    title: 'Cards are made of chunks',
    select: 't-swing',
    body: `<p>Every line of card text is built from colored chunks in a fixed order:
      <span class="chunk t-trigger">Trigger</span> <span class="chunk t-verb">Verb</span> <span class="chunk t-amount">Amount</span>
      <span class="chunk t-repeat">Repeat</span> <span class="chunk t-target">Target</span> <span class="chunk t-condition">Condition</span>.
      Only Verb and Amount are required.</p>
      <p>Reward cards are junk with good parts. Reckless Swing hits ALL enemies, but it also hits you. Let's take it apart.</p>`,
  },
  {
    title: 'Mute the drawback',
    select: 't-swing',
    body: '<p>Pick <b>Mute</b>, then tap <b>Deal</b> in the second line, "Deal 6 to yourself". A muted chunk does nothing until you unmute it.</p><p>Watch the cost in the corner as you do it.</p>',
    hint: () => ({ uid: 't-swing', ci: 1, slot: 'verb', tool: 'mute' }),
    check: (run) => { const cl = card(run, 't-swing')?.clauses[1]; return !!(cl?.verb?.muted || cl?.amount?.muted); },
    solve: (run, db) => E.mute(db, run, 't-swing', 1, 'verb'),
    success: 'Muted. The cost went from 2 to 3: drawbacks make a card cheaper, so silencing one costs energy.',
  },
  {
    title: 'Cut out the good part',
    select: 't-swing',
    body: '<p>Pick <b>Scissors</b> and tap <b>to ALL enemies</b>. The chunk moves to your clipboard on the right.</p>',
    hint: () => ({ uid: 't-swing', ci: 0, slot: 'target', tool: 'scissors' }),
    check: (run) => run.clipboard.some((ch) => ch.type === 'target' && ch.id === 'all'),
    solve: (run, db) => E.cut(db, run, 't-swing', 0, 'target'),
    success: '"to ALL enemies" is on your clipboard. Reckless Swing still works: an empty Target falls back to the verb\'s default.',
  },
  {
    title: 'Glue it onto Strike',
    select: 't-strike',
    body: '<p>Tap <b>to ALL enemies</b> on your clipboard. That picks up <b>Glue</b> and outlines every slot it fits. Then tap Strike\'s Target, <b>to an enemy</b>.</p><p>Chunks only fit slots of their own type.</p>',
    hint: (run, ws) => (ws.clip == null ? { clipType: 'target' } : { uid: 't-strike', ci: 0, slot: 'target' }),
    check: (run) => card(run, 't-strike')?.clauses[0]?.target?.id === 'all',
    solve: (run, db) => E.glue(db, run, 't-strike', 0, 'target', run.clipboard.findIndex((ch) => ch.type === 'target' && ch.id === 'all')),
    success: 'Strike now hits every enemy. Its old Target went to your clipboard in exchange.',
  },
  {
    title: 'Invert a chunk',
    select: 't-over',
    body: '<p>Overcharge gives energy but makes you Weak. Pick <b>Invert</b> and tap <b>Apply Weak</b>. Invert flips a chunk to its opposite: Deal ↔ Heal, an enemy ↔ yourself, if ↔ unless, an Amount n ↔ 10 − n.</p>',
    hint: () => ({ uid: 't-over', ci: 1, slot: 'verb', tool: 'invert' }),
    check: (run) => card(run, 't-over')?.clauses[1]?.verb?.id === 'strength',
    solve: (run, db) => E.invert(db, run, 't-over', 1, 'verb'),
    success: 'Apply Weak became Apply Strength, still aimed at you. Overcharge is now pure upside.',
  },
  {
    title: 'Merge two cards',
    select: 't-jab',
    body: '<p>With Jab selected, pick <b>Merge</b>, then tap <b>Defend</b> in your deck below. Jab keeps both cards\' lines (up to 3) and Defend is used up.</p>',
    hint: (run, ws) => (ws.tool === 'merge' ? { deckUid: 't-defend' } : { tool: 'merge' }),
    check: (run) => !card(run, 't-defend') && card(run, 't-jab')?.clauses.length === 2,
    solve: (run, db) => E.merge(db, run, 't-jab', 't-defend'),
    success: 'Jab Defend deals damage and blocks. A merged card costs about what its parts did together.',
  },
  {
    title: 'Shred what is left',
    select: 't-swing',
    body: '<p>Reckless Swing has given up its best part. Pick <b>Shred</b> and confirm. Its chunks go to your clipboard and you get 2 Ink back.</p>',
    hint: (run, ws) => (ws.tool === 'shred' ? { shred: true } : { tool: 'shred' }),
    check: (run) => !card(run, 't-swing'),
    solve: (run, db) => E.shred(db, run, 't-swing'),
    success: 'Shredded. Chunks you can\'t use yet wait on the clipboard, which holds 8.',
  },
  {
    title: "That's the whole toolkit",
    body: `<ul>
      <li><b>Workshops and after fights:</b> all six tools, paid for with Ink.</li>
      <li><b>During a fight:</b> Mute or Invert a chunk on a card in your hand for 1 energy. It lasts until the fight ends.</li>
      <li><b>Broken cards:</b> a card missing its Verb or Amount can't be played until you glue one back in.</li>
      <li><b>Enemies edit you back:</b> a dashed outline marks the chunk an enemy will change at the end of your turn. Play the card first, or edit it yourself.</li>
    </ul>`,
  },
];

export function newTutorialRun(db, upToStep = 0) {
  const run = {
    hp: db.rules.player.hp, maxHp: db.rules.player.hp, deck: [], ink: 10, clipboard: [], freeUses: {},
    node: 0, phase: 'workshop', sandbox: false, nextUid: 1, seed: 1,
  };
  for (const [uid, id] of PRACTICE) run.deck.push(makeCard(db.cards.cards.find((c) => c.id === id), uid));
  for (let i = 0; i < upToStep; i++) TUTORIAL[i].solve?.(run, db);
  return run;
}
