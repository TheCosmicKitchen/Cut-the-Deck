// Card text grammar: clauses of typed chunks in fixed slots.
// A chunk is { type, id, muted?, neg?, redacted?, enemyEdit? }.
// A clause is { trigger, verb, amount, repeat, target, condition }, each a chunk or null.
// `db` is the loaded content: { chunks, cards, enemies, rules }.

export const SLOTS = ['trigger', 'verb', 'amount', 'repeat', 'target', 'condition'];
export const REQUIRED = ['verb', 'amount'];

export function emptyClause() {
  const c = {};
  for (const slot of SLOTS) c[slot] = null;
  return c;
}

// cards.json shorthand -> clause
export function parseClause(short) {
  const c = emptyClause();
  for (const [slot, v] of Object.entries(short)) {
    if (!SLOTS.includes(slot)) continue;
    if (slot === 'condition' && typeof v === 'string' && v.startsWith('!')) {
      c.condition = { type: 'condition', id: v.slice(1), neg: true };
    } else {
      c[slot] = { type: slot, id: v };
    }
  }
  for (const slot of short.muted ?? []) if (c[slot]) c[slot].muted = true;
  return c;
}

// clause -> cards.json shorthand (muted/edit flags are kept so exports round-trip)
export function clauseShorthand(clause) {
  const out = {};
  for (const slot of SLOTS) {
    const ch = clause[slot];
    if (!ch) continue;
    out[slot] = slot === 'condition' && ch.neg ? '!' + ch.id : ch.id;
    if (ch.muted) (out.muted ??= []).push(slot);
  }
  return out;
}

export function makeCard(def, uid) {
  return { uid, base: def.id, name: def.name, clauses: def.clauses.map(parseClause) };
}

export function cloneCard(card) {
  return JSON.parse(JSON.stringify(card));
}

export function stripChunk(ch) {
  const out = { type: ch.type, id: ch.id };
  if (ch.neg) out.neg = true;
  return out;
}

const live = (ch) => (ch && !ch.muted ? ch : null);

export function triggerOf(clause) {
  return live(clause.trigger)?.id ?? 'played';
}

// What a clause actually does right now, or null if it is inert
// (its Verb or Amount is missing or muted).
export function effective(db, clause) {
  const verb = live(clause.verb);
  const amount = live(clause.amount);
  if (!verb || !amount) return null;
  const vdef = db.chunks.verb[verb.id];
  const rep = live(clause.repeat);
  const tgt = live(clause.target);
  const cond = live(clause.condition);
  return {
    verb: verb.id,
    amount: amount.id,
    hits: rep ? db.chunks.repeat[rep.id].hits : 1,
    target: tgt ? tgt.id : vdef.defaultTarget,
    condition: cond ? { id: cond.id, neg: !!cond.neg } : null,
    trigger: triggerOf(clause),
  };
}

export function isBroken(card) {
  return card.clauses.length === 0 || card.clauses.some((c) => REQUIRED.some((s) => !c[s]));
}

export function isPlayable(card) {
  return !isBroken(card) && card.clauses.some((c) => triggerOf(c) === 'played');
}

export function isDrawback(db, eff) {
  const side = db.chunks.target[eff.target].side;
  const harm = db.chunks.verb[eff.verb].polarity === 'harm';
  return harm === (side === 'self');
}

export function clauseWeight(db, eff) {
  const v = db.chunks.verb[eff.verb];
  const amt = eff.amount === 'X' ? 0 : eff.amount;
  let w = v.weight + v.amountScale * amt * eff.hits + db.chunks.target[eff.target].weight;
  if (eff.condition) w += db.chunks.condition[eff.condition.id].weight;
  w += db.chunks.trigger[eff.trigger].weight;
  if (isDrawback(db, eff)) w = Math.abs(w) * db.rules.cost.drawbackFactor;
  return w;
}

// { cost, x } — x is true when an X amount spends all remaining energy.
// Returns null for Broken cards.
export function cardCost(db, card) {
  if (isBroken(card)) return null;
  let sum = 0;
  let x = false;
  for (const clause of card.clauses) {
    const eff = effective(db, clause);
    if (!eff) continue;
    sum += clauseWeight(db, eff);
    if (eff.amount === 'X' && eff.trigger === 'played') x = true;
  }
  return { cost: Math.max(0, Math.round(sum + 1e-9)), x };
}

export function chunkLabel(db, ch) {
  switch (ch.type) {
    case 'verb': return db.chunks.verb[ch.id].label;
    case 'amount': return String(ch.id);
    case 'repeat': return db.chunks.repeat[ch.id].label;
    case 'target': return 'to ' + db.chunks.target[ch.id].label;
    case 'condition': return db.chunks.condition[ch.id][ch.neg ? 'unless' : 'if'];
    case 'trigger': return (db.chunks.trigger[ch.id].label || 'When played') + ':';
  }
  return '?';
}

// Display order of a clause. Empty slots appear only when showEmpty is set
// (the editor), except required ones, which always show so Broken cards read as broken.
export function clauseTokens(db, clause, showEmpty = false) {
  const order = ['trigger', 'verb', 'amount', 'repeat', 'target', 'condition'];
  const out = [];
  for (const slot of order) {
    const ch = clause[slot];
    if (ch) out.push({ slot, chunk: ch, text: chunkLabel(db, ch) });
    else if (showEmpty || REQUIRED.includes(slot)) out.push({ slot, chunk: null, text: slot });
  }
  return out;
}

export function cardText(db, card) {
  return card.clauses
    .map((c) => clauseTokens(db, c).map((t) => (t.chunk ? t.text : `[${t.text}]`)).join(' '))
    .join('. ');
}

function clampAmount(db, n) {
  const a = db.chunks.amount;
  return Math.max(a.min, Math.min(a.max, n));
}

export function shiftAmount(db, ch, delta) {
  if (ch.type === 'amount' && ch.id !== 'X') ch.id = clampAmount(db, ch.id + delta);
}

// Flip one chunk to its opposite, in place. Inverting a Verb keeps who it hits:
// if the Target slot is empty, the old verb's default target is written into it.
export function invertChunk(db, clause, slot) {
  const ch = clause[slot];
  if (!ch) return false;
  const C = db.chunks;
  switch (slot) {
    case 'verb': {
      const oldDef = C.verb[ch.id].defaultTarget;
      const next = C.verb[ch.id].invert;
      if (!live(clause.target) && C.verb[next].defaultTarget !== oldDef) {
        clause.target = { type: 'target', id: oldDef };
      }
      ch.id = next;
      break;
    }
    case 'amount':
      ch.id = ch.id === 'X' ? C.amount.xInvertsTo : clampAmount(db, C.amount.invertPivot - ch.id);
      break;
    case 'condition':
      ch.neg = !ch.neg;
      break;
    default:
      ch.id = C[slot][ch.id].invert;
  }
  return true;
}

// Every slot a chunk could go into, for random card generation (fuzz test).
export function chunkIds(db, type) {
  if (type === 'amount') {
    const ids = [];
    for (let n = db.chunks.amount.min; n <= db.chunks.amount.max; n++) ids.push(n);
    return ids.concat(['X']);
  }
  return Object.keys(db.chunks[type]);
}
