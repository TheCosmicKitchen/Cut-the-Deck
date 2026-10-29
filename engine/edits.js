// Workshop editing tools. Each takes the run state and returns
// { ok: true, note? } or { ok: false, error }. Validation happens before any Ink is spent.

import { emptyClause, invertChunk, stripChunk, SLOTS } from './grammar.js';

const fail = (error) => ({ ok: false, error });

function findCard(run, uid) {
  return run.deck.find((c) => c.uid === uid);
}

export function toolCost(db, run, tool) {
  if (run.sandbox) return { ink: 0, free: false };
  if ((run.freeUses[tool] ?? 0) > 0) return { ink: 0, free: true };
  return { ink: db.rules.workshopTools[tool].ink, free: false };
}

function canPay(db, run, tool) {
  const { ink } = toolCost(db, run, tool);
  return ink <= run.ink;
}

function pay(db, run, tool) {
  const { ink, free } = toolCost(db, run, tool);
  if (free) run.freeUses[tool]--;
  run.ink -= ink;
}

function needInk(db, run, tool) {
  return fail(`${cap(tool)} needs ${toolCost(db, run, tool).ink} Ink. You have ${run.ink}.`);
}

const cap = (s) => s[0].toUpperCase() + s.slice(1);
const article = (word) => (/^[aeiou]/i.test(word) ? 'an' : 'a');

function tidy(card) {
  card.clauses = card.clauses.filter((c) => SLOTS.some((s) => c[s]));
}

export function cut(db, run, uid, ci, slot) {
  const card = findCard(run, uid);
  const ch = card?.clauses[ci]?.[slot];
  if (!ch) return fail('There is no chunk there to cut.');
  if (run.clipboard.length >= db.rules.clipboardSize) return fail('Your clipboard is full. Drop a chunk first.');
  if (!canPay(db, run, 'scissors')) return needInk(db, run, 'scissors');
  pay(db, run, 'scissors');
  card.clauses[ci][slot] = null;
  run.clipboard.push(stripChunk(ch));
  tidy(card);
  return { ok: true };
}

// Paste clipboard[clipIdx] into a slot. ci === clauses.length starts a new clause.
export function glue(db, run, uid, ci, slot, clipIdx) {
  const card = findCard(run, uid);
  const ch = run.clipboard[clipIdx];
  if (!card || !ch) return fail('Pick a chunk from your clipboard first.');
  if (ch.type !== slot) return fail(`${cap(article(ch.type))} ${cap(ch.type)} chunk only fits ${article(ch.type)} ${cap(ch.type)} slot.`);
  const isNew = ci === card.clauses.length;
  if (isNew && card.clauses.length >= db.rules.maxClauses) return fail(`A card holds at most ${db.rules.maxClauses} clauses.`);
  if (!isNew && !card.clauses[ci]) return fail('That clause does not exist.');
  if (!canPay(db, run, 'glue')) return needInk(db, run, 'glue');
  pay(db, run, 'glue');
  if (isNew) card.clauses.push(emptyClause());
  const old = card.clauses[ci][slot];
  card.clauses[ci][slot] = ch;
  run.clipboard.splice(clipIdx, 1);
  if (old) run.clipboard.push(stripChunk(old));
  return { ok: true };
}

export function mute(db, run, uid, ci, slot) {
  const ch = findCard(run, uid)?.clauses[ci]?.[slot];
  if (!ch) return fail('There is no chunk there to mute.');
  if (!canPay(db, run, 'mute')) return needInk(db, run, 'mute');
  pay(db, run, 'mute');
  ch.muted = !ch.muted;
  delete ch.redacted;
  return { ok: true };
}

export function invert(db, run, uid, ci, slot) {
  const clause = findCard(run, uid)?.clauses[ci];
  if (!clause?.[slot]) return fail('There is no chunk there to invert.');
  if (!canPay(db, run, 'invert')) return needInk(db, run, 'invert');
  pay(db, run, 'invert');
  invertChunk(db, clause, slot);
  return { ok: true };
}

export function mergedName(a, b) {
  const first = a.split(' ')[0];
  const last = b.split(' ').slice(-1)[0];
  return first === last ? a : `${first} ${last}`;
}

export function merge(db, run, uidA, uidB) {
  const a = findCard(run, uidA);
  const b = findCard(run, uidB);
  if (!a || !b || a === b) return fail('Pick two different cards to merge.');
  if (a.clauses.length + b.clauses.length > db.rules.maxClauses) {
    return fail(`Together they have ${a.clauses.length + b.clauses.length} clauses; a card holds at most ${db.rules.maxClauses}.`);
  }
  if (!canPay(db, run, 'merge')) return needInk(db, run, 'merge');
  pay(db, run, 'merge');
  a.clauses.push(...b.clauses);
  a.name = mergedName(a.name, b.name);
  run.deck = run.deck.filter((c) => c !== b);
  return { ok: true };
}

export function shred(db, run, uid) {
  const card = findCard(run, uid);
  if (!card) return fail('Pick a card to shred.');
  if (run.deck.length <= 1) return fail('You need at least one card in your deck.');
  pay(db, run, 'shred');
  let lost = 0;
  for (const clause of card.clauses) {
    for (const slot of SLOTS) {
      if (!clause[slot]) continue;
      if (run.clipboard.length < db.rules.clipboardSize) run.clipboard.push(stripChunk(clause[slot]));
      else lost++;
    }
  }
  run.deck = run.deck.filter((c) => c !== card);
  return { ok: true, note: lost ? `${lost} chunk${lost > 1 ? 's' : ''} didn't fit on the clipboard and were lost.` : undefined };
}

export function dropClip(run, idx) {
  run.clipboard.splice(idx, 1);
  return { ok: true };
}

// Apply a tool to a throwaway copy, for the live cost preview.
export function preview(db, run, tool, args) {
  const copy = JSON.parse(JSON.stringify(run));
  copy.sandbox = true;
  const fn = { scissors: cut, glue, mute, invert }[tool];
  if (!fn) return null;
  const res = fn(db, copy, ...args);
  return res.ok ? copy.deck.find((c) => c.uid === args[0]) : null;
}
