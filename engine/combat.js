// Combat rules. State is plain data; every function mutates it and appends to s.log.
//
// Loop invariants (engine rules, not settings):
//   1. Spent: a card is played at most once per turn.
//   2. No mid-turn reshuffle: drawing from an empty pile does nothing.
//   3. Triggers fire once: each clause fires at most once per turn.
//   4. No card creation: no verb adds cards.
// Safety net: a turn aborts after rules.safetyNetResolutions clause resolutions.

import { cardCost, cloneCard, effective, invertChunk, isBroken, isPlayable, shiftAmount, SLOTS } from './grammar.js';
import { pick, randInt, shuffle } from './rng.js';

const fail = (error) => ({ ok: false, error });

// deck: run cards (copied, so fight edits end with the fight)
// enemyDefs: [{ key, ...enemies.json entry }]
export function startCombat(db, deck, enemyDefs, seed, opts = {}) {
  const cards = {};
  for (const c of deck) cards[c.uid] = cloneCard(c);
  const s = {
    seed,
    turn: 0,
    phase: 'player',
    player: { hp: opts.hp ?? db.rules.player.hp, maxHp: opts.maxHp ?? db.rules.player.hp, block: 0, energy: 0, weak: 0, strength: 0 },
    enemies: enemyDefs.map((d, i) => ({
      key: d.key, name: d.name + (enemyDefs.filter((e) => e.key === d.key).length > 1 ? ' ' + 'AB'[enemyDefs.slice(0, i).filter((e) => e.key === d.key).length] : ''),
      role: d.role, hp: d.hp, maxHp: d.hp, block: 0, weak: 0, strength: 0, step: 0, pattern: d.pattern, intent: null, dead: false,
    })),
    cards,
    draw: [],
    hand: [],
    discard: [],
    spent: {},
    fired: {},
    stats: { plays: 0, draws: 0, resolutions: 0 },
    target: 0,
    copied: null,
    log: [],
  };
  s.draw = shuffle(s, Object.keys(cards));
  s.log.push({ turn: 1, msg: `Fight begins: ${s.enemies.map((e) => e.name).join(', ')}.` });
  startPlayerTurn(db, s);
  return s;
}

function log(s, msg) {
  s.log.push({ turn: s.turn, msg });
  if (s.log.length > 200) s.log.shift();
}

const alive = (s) => s.enemies.map((e, i) => i).filter((i) => !s.enemies[i].dead);
const actor = (s, ref) => (ref === 'p' ? s.player : s.enemies[ref]);
const who = (s, ref) => (ref === 'p' ? 'you' : s.enemies[ref].name);

export function startPlayerTurn(db, s) {
  s.turn++;
  s.spent = {};
  s.fired = {};
  s.stats = { plays: 0, draws: 0, resolutions: 0 };
  s.aborted = false;
  s.player.block = 0;
  s.player.energy = db.rules.player.energyPerTurn;
  const n = db.rules.player.handSize;
  if (s.draw.length < n && s.discard.length) {
    s.draw = s.draw.concat(shuffle(s, s.discard));
    s.discard = [];
    log(s, 'Discard pile shuffled into your draw pile.');
  }
  drawCards(db, s, n);
  for (const i of alive(s)) chooseIntent(db, s, i);
  if (!alive(s).includes(s.target)) s.target = alive(s)[0] ?? 0;
}

function drawCards(db, s, n) {
  for (let k = 0; k < n; k++) {
    if (!s.draw.length) {
      log(s, 'Draw pile is empty.');
      return;
    }
    const uid = s.draw.shift();
    s.hand.push(uid);
    s.stats.draws++;
    fireTrigger(db, s, uid, 'drawn');
    if (s.phase !== 'player') return;
  }
}

function fireTrigger(db, s, uid, trigger, ctx = {}) {
  const card = s.cards[uid];
  card.clauses.forEach((clause, ci) => {
    if (s.phase !== 'player' || s.aborted) return;
    const eff = effective(db, clause);
    if (!eff || eff.trigger !== trigger) return;
    const key = uid + ':' + ci;
    if (s.fired[key]) return;
    s.fired[key] = true;
    resolve(db, s, eff, { src: 'p', uid, targetIdx: s.target, first: ctx.first ?? false, x: ctx.x ?? 0, name: card.name });
  });
}

function conditionHolds(s, eff, ctx) {
  if (!eff.condition) return true;
  let v;
  if (ctx.src === 'p') {
    if (eff.condition.id === 'has_block') v = s.player.block > 0;
    else if (eff.condition.id === 'enemy_weak') v = (s.enemies[ctx.targetIdx]?.weak ?? 0) > 0;
    else v = ctx.first;
  } else {
    if (eff.condition.id === 'has_block') v = s.enemies[ctx.src].block > 0;
    else if (eff.condition.id === 'enemy_weak') v = s.player.weak > 0;
    else v = true;
  }
  return eff.condition.neg ? !v : v;
}

function targetsFor(db, s, eff, ctx) {
  const side = db.chunks.target[eff.target].side;
  if (ctx.src !== 'p') return side === 'self' ? [ctx.src] : ['p'];
  if (side === 'self') return ['p'];
  const live = alive(s);
  if (!live.length) return [];
  if (eff.target === 'all') return live;
  if (eff.target === 'random') return [pick(s, live)];
  return [live.includes(ctx.targetIdx) ? ctx.targetIdx : live[0]];
}

function resolve(db, s, eff, ctx) {
  s.stats.resolutions++;
  if (s.stats.resolutions > db.rules.safetyNetResolutions) {
    s.aborted = true;
    log(s, `SAFETY NET: turn aborted after ${db.rules.safetyNetResolutions} resolutions. Last card: ${ctx.name}. This is an engine bug.`);
    return;
  }
  if (!conditionHolds(s, eff, ctx)) {
    log(s, `${ctx.name}: condition not met.`);
    return;
  }
  const cap = db.rules.status.amountCap;
  const amt = Math.min(cap, eff.amount === 'X' ? ctx.x : eff.amount);
  for (let h = 0; h < eff.hits; h++) {
    const targets = targetsFor(db, s, eff, ctx);
    for (const t of targets) applyVerb(db, s, eff.verb, ctx, t, amt);
    if (s.phase !== 'player' && s.phase !== 'enemy') return;
  }
}

function applyVerb(db, s, verb, ctx, t, amt) {
  const tgt = actor(s, t);
  if (tgt.dead) return;
  const src = ctx.src;
  switch (verb) {
    case 'deal': dealDamage(db, s, src, t, amt); break;
    case 'heal': {
      const before = tgt.hp;
      tgt.hp = Math.min(tgt.maxHp, tgt.hp + amt);
      log(s, `${ctx.name}: ${who(s, t)} heal${t === 'p' ? '' : 's'} ${tgt.hp - before}.`);
      break;
    }
    case 'block': tgt.block += amt; log(s, `${ctx.name}: ${who(s, t)} gain${t === 'p' ? '' : 's'} ${amt} Block.`); break;
    case 'lose_block': tgt.block = Math.max(0, tgt.block - amt); log(s, `${ctx.name}: ${who(s, t)} lose${t === 'p' ? '' : 's'} ${amt} Block.`); break;
    case 'draw': if (t === 'p') drawCards(db, s, amt); break;
    case 'discard': if (t === 'p') discardRandom(s, amt, ctx.uid); break;
    case 'energy': if (t === 'p') { s.player.energy += amt; log(s, `${ctx.name}: +${amt} energy.`); } break;
    case 'lose_energy': if (t === 'p') { s.player.energy = Math.max(0, s.player.energy - amt); log(s, `${ctx.name}: −${amt} energy.`); } break;
    case 'weak': tgt.weak += amt; log(s, `${ctx.name}: ${who(s, t)} gain${t === 'p' ? '' : 's'} ${amt} Weak.`); break;
    case 'strength': tgt.strength += amt; log(s, `${ctx.name}: ${who(s, t)} gain${t === 'p' ? '' : 's'} ${amt} Strength.`); break;
  }
}

function dealDamage(db, s, src, t, base) {
  const a = actor(s, src);
  const d = actor(s, t);
  let amt = base + a.strength;
  if (a.weak > 0) amt = Math.floor(amt * db.rules.status.weakDamageMultiplier);
  amt = Math.max(0, Math.min(db.rules.status.amountCap, amt));
  const absorbed = Math.min(d.block, amt);
  d.block -= absorbed;
  const dmg = amt - absorbed;
  d.hp -= dmg;
  log(s, `${who(s, src)} hit${src === 'p' ? '' : 's'} ${who(s, t)} for ${dmg}${absorbed ? ` (${absorbed} blocked)` : ''}.`);
  if (d.hp <= 0) {
    d.hp = 0;
    if (t === 'p') {
      s.phase = 'lost';
      log(s, 'You were defeated.');
    } else {
      d.dead = true;
      log(s, `${d.name} is defeated.`);
      if (!alive(s).length) {
        s.phase = 'won';
        log(s, 'Victory!');
      } else if (s.target === t) s.target = alive(s)[0];
    }
  }
}

function discardRandom(s, n, exceptUid) {
  for (let k = 0; k < n; k++) {
    const pool = s.hand.filter((u) => u !== exceptUid);
    if (!pool.length) return;
    const uid = pool[randInt(s, pool.length)];
    s.hand = s.hand.filter((u) => u !== uid);
    s.discard.push(uid);
    log(s, `Discarded ${s.cards[uid].name}.`);
  }
}

export function playInfo(db, s, uid) {
  const card = s.cards[uid];
  const c = cardCost(db, card);
  if (s.phase !== 'player') return { can: false, why: 'Not your turn.' };
  if (!s.hand.includes(uid)) return { can: false, why: 'That card is not in your hand.' };
  if (s.spent[uid]) return { can: false, why: 'Spent: already played this turn.' };
  if (isBroken(card)) return { can: false, why: 'Broken: it is missing a Verb or Amount.' };
  if (!isPlayable(card)) return { can: false, why: 'Nothing on this card triggers when played.' };
  if (s.aborted) return { can: false, why: 'Turn aborted by the safety net. End your turn.' };
  if (c.cost > s.player.energy) return { can: false, why: `Costs ${c.cost} energy; you have ${s.player.energy}.` };
  return { can: true, cost: c.cost, x: c.x };
}

export function playCard(db, s, uid, targetIdx = s.target) {
  const info = playInfo(db, s, uid);
  if (!info.can) return fail(info.why);
  if (alive(s).includes(targetIdx)) s.target = targetIdx;
  let x = 0;
  s.player.energy -= info.cost;
  if (info.x) {
    x = s.player.energy;
    s.player.energy = 0;
  }
  s.spent[uid] = true;
  s.hand = s.hand.filter((u) => u !== uid);
  s.discard.push(uid);
  const first = s.stats.plays === 0;
  s.stats.plays++;
  log(s, `You play ${s.cards[uid].name}${info.x ? ` (X = ${x})` : ''}.`);
  fireTrigger(db, s, uid, 'played', { first, x });
  return { ok: true };
}

// Mid-fight quick edits: one tap, no clipboard, applied at once, gone after the fight.
export function combatEdit(db, s, tool, uid, ci, slot) {
  const rule = db.rules.combatEdits.tools[tool];
  if (!rule) return fail(`${tool} can only be used at a Workshop.`);
  if (s.phase !== 'player') return fail('Not your turn.');
  if (!s.hand.includes(uid)) return fail('You can only edit cards in your hand.');
  const clause = s.cards[uid].clauses[ci];
  const ch = clause?.[slot];
  if (!ch) return fail('There is no chunk there.');
  if (s.player.energy < rule.energy) return fail(`That edit costs ${rule.energy} energy; you have ${s.player.energy}.`);
  s.player.energy -= rule.energy;
  if (tool === 'mute') {
    ch.muted = !ch.muted;
    delete ch.redacted;
  } else invertChunk(db, clause, slot);
  log(s, `You ${tool === 'mute' ? (ch.muted ? 'mute' : 'unmute') : 'invert'} a chunk on ${s.cards[uid].name}.`);
  return { ok: true };
}

export function endTurn(db, s) {
  if (s.phase !== 'player') return fail('Not your turn.');
  for (const uid of s.hand.slice()) {
    fireTrigger(db, s, uid, 'end_turn');
    if (s.phase !== 'player') return { ok: true };
  }
  s.discard.push(...s.hand);
  s.hand = [];
  s.player.weak = Math.max(0, s.player.weak - 1);
  s.phase = 'enemy';
  for (const i of alive(s)) {
    s.enemies[i].block = 0;
    enemyAct(db, s, i);
    if (s.phase !== 'enemy') return { ok: true };
  }
  for (const e of s.enemies) e.weak = Math.max(0, e.weak - 1);
  s.phase = 'player';
  startPlayerTurn(db, s);
  return { ok: true };
}

// ---- enemies ----

function handChunks(s, filter) {
  const out = [];
  for (const uid of s.hand) {
    s.cards[uid].clauses.forEach((clause, ci) => {
      for (const slot of SLOTS) {
        const ch = clause[slot];
        if (ch && filter(ch, slot)) out.push({ uid, ci, slot });
      }
    });
  }
  return out;
}

function chooseIntent(db, s, i) {
  const e = s.enemies[i];
  const intent = JSON.parse(JSON.stringify(e.pattern[e.step % e.pattern.length]));
  e.step++;
  if (intent.edit === 'blackout') {
    intent.at = pick(s, handChunks(s, (ch) => !ch.muted));
  } else if (intent.edit === 'invert_verb') {
    intent.at = pick(s, handChunks(s, (ch, slot) => slot === 'verb'));
  } else if (intent.edit === 'typo') {
    intent.at = pick(s, handChunks(s, (ch, slot) => slot === 'amount' && ch.id !== 'X'));
    intent.delta = randInt(s, 2) ? 1 : -1;
  } else if (intent.edit === 'copy') {
    let best = null;
    for (const uid of Object.keys(s.cards)) {
      const c = cardCost(db, s.cards[uid]);
      if (c && (!best || c.cost > best.cost)) best = { uid, cost: c.cost };
    }
    intent.at = best ? { uid: best.uid } : undefined;
  }
  if (intent.edit && intent.edit !== 'censor' && !intent.at) intent.fizzle = true;
  e.intent = intent;
}

export function intentText(db, s, i) {
  const it = s.enemies[i].intent;
  if (!it) return '';
  const parts = [];
  const e = s.enemies[i];
  if (it.attack != null) {
    let a = it.attack + e.strength;
    if (e.weak > 0) a = Math.floor(a * db.rules.status.weakDamageMultiplier);
    parts.push(`Attack ${a}${it.hits > 1 ? ' ×' + it.hits : ''}`);
  }
  if (it.block) parts.push(`Block ${it.block}`);
  if (it.strength) parts.push(`+${it.strength} Strength`);
  if (it.weak) parts.push(`Weak ${it.weak} on you`);
  if (it.edit) {
    const name = it.at ? s.cards[it.at.uid].name : '';
    const text = {
      blackout: `Black out a chunk on ${name}`,
      invert_verb: `Invert the Verb on ${name}`,
      typo: `${it.delta > 0 ? '+1' : '−1'} to an Amount on ${name}`,
      censor: 'Mute every Amount above 5 in your deck',
      copy: `Copy ${name} and play it at you`,
    }[it.edit];
    parts.push(it.fizzle ? 'Edit: nothing to target' : text);
  }
  return parts.join(' · ');
}

function enemyAct(db, s, i) {
  const e = s.enemies[i];
  const it = e.intent;
  if (!it) return;
  if (it.attack != null) for (let h = 0; h < (it.hits ?? 1); h++) {
    dealDamage(db, s, i, 'p', it.attack);
    if (s.phase === 'lost') return;
  }
  if (it.block) { e.block += it.block; log(s, `${e.name} gains ${it.block} Block.`); }
  if (it.strength) { e.strength += it.strength; log(s, `${e.name} gains ${it.strength} Strength.`); }
  if (it.weak) { s.player.weak += it.weak; log(s, `${e.name} makes you Weak ${it.weak}.`); }
  if (it.edit && !it.fizzle) applyEnemyEdit(db, s, i, it);
}

function applyEnemyEdit(db, s, i, it) {
  const e = s.enemies[i];
  const at = it.at;
  const clause = at && s.cards[at.uid]?.clauses[at.ci];
  switch (it.edit) {
    case 'blackout': {
      const ch = clause?.[at.slot];
      if (ch && !ch.muted) { ch.muted = true; ch.redacted = true; log(s, `${e.name} blacks out a chunk on ${s.cards[at.uid].name}.`); }
      break;
    }
    case 'invert_verb':
      if (clause?.verb) {
        invertChunk(db, clause, 'verb');
        clause.verb.enemyEdit = true;
        log(s, `${e.name} inverts the Verb on ${s.cards[at.uid].name}.`);
      }
      break;
    case 'typo': {
      const ch = clause?.amount;
      if (ch && ch.id !== 'X') { shiftAmount(db, ch, it.delta); ch.enemyEdit = true; log(s, `${e.name} changes an Amount on ${s.cards[at.uid].name} to ${ch.id}.`); }
      break;
    }
    case 'censor': {
      let n = 0;
      for (const card of Object.values(s.cards)) for (const cl of card.clauses) {
        const ch = cl.amount;
        if (ch && ch.id !== 'X' && ch.id > 5 && !ch.muted) { ch.muted = true; ch.redacted = true; n++; }
      }
      log(s, `${e.name} censors ${n} Amount${n === 1 ? '' : 's'} in your deck.`);
      break;
    }
    case 'copy': {
      const card = s.cards[at.uid];
      s.copied = cloneCard(card);
      log(s, `${e.name} copies ${card.name} and plays it at you.`);
      for (const cl of card.clauses) {
        const eff = effective(db, cl);
        if (eff) resolve(db, s, eff, { src: i, name: `${e.name} (${card.name})`, x: 3 });
        if (s.phase === 'lost') return;
      }
      break;
    }
  }
}

// Has an enemy telegraphed an edit on this chunk? Used by the UI to mark it.
export function telegraphsOn(s, uid) {
  const out = [];
  s.enemies.forEach((e, i) => {
    const it = e.intent;
    if (!e.dead && it?.at?.uid === uid && !it.fizzle) out.push({ enemy: i, edit: it.edit, ci: it.at.ci, slot: it.at.slot ?? (it.edit === 'invert_verb' ? 'verb' : null) });
  });
  return out;
}
