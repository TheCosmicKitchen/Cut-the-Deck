// Web viewer/editor. All game rules live in ../engine; this file only renders
// state and turns clicks into engine calls, so a Godot front end can replace it.

import * as G from '../engine/grammar.js';
import * as E from '../engine/edits.js';
import * as C from '../engine/combat.js';
import * as R from '../engine/run.js';
import { fuzz } from '../engine/fuzz.js';

const SAVE_KEY = 'cut-the-deck.v1';
const app = {
  db: null,
  run: null,
  view: 'run',
  ws: { sel: null, tool: null, clip: null, confirmShred: false },
  ctool: null,
  lab: { combat: null, enemies: ['redactor'], fuzz: null, io: '' },
};

const $ = (sel) => document.querySelector(sel);
const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

// ---------- boot ----------

async function boot() {
  const names = ['chunks', 'cards', 'enemies', 'rules'];
  try {
    const [chunks, cards, enemies, rules] = await Promise.all(names.map((n) => fetch(`data/${n}.json`).then((r) => r.json())));
    app.db = { chunks, cards, enemies, rules };
  } catch (err) {
    $('#main').innerHTML = `<p class="banner">Couldn't load the card data (${esc(err.message)}). Serve this folder over http, not file://.</p>`;
    return;
  }
  const saved = window.claude?.hot?.data?.app ?? readSave();
  if (saved?.run?.deck) {
    app.run = saved.run;
    app.view = saved.view ?? 'run';
  } else app.run = R.newRun(app.db);
  window.claude?.hot?.snapshot?.(() => ({ app: { run: app.run, view: app.view } }));
  render();
}

function readSave() {
  try { return JSON.parse(localStorage.getItem(SAVE_KEY) || 'null'); } catch { return null; }
}
function writeSave() {
  try { localStorage.setItem(SAVE_KEY, JSON.stringify({ run: app.run, view: app.view })); } catch { /* storage unavailable */ }
}

let toastTimer = 0;
function toast(msg) {
  const t = $('#toast');
  t.textContent = msg;
  t.hidden = false;
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => (t.hidden = true), 2600);
}
function result(res) {
  if (!res.ok) toast(res.error);
  else if (res.note) toast(res.note);
  return res.ok;
}

// ---------- card rendering ----------

function costHTML(card) {
  const c = G.cardCost(app.db, card);
  if (!c) return `<div class="cost none" title="Broken: can't be played">–</div>`;
  if (!G.isPlayable(card)) return `<div class="cost none" title="Nothing triggers when played">–</div>`;
  return `<div class="cost${c.x ? ' x' : ''}" title="Energy cost">${c.cost}${c.x ? '+X' : ''}</div>`;
}

function chunkSpan(tok, ci, uid, o, tele) {
  const { slot, chunk } = tok;
  const act = o.chunkAct ? ` data-act="${o.chunkAct}" data-uid="${uid}" data-ci="${ci}" data-slot="${slot}"` : '';
  if (!chunk) {
    const req = G.REQUIRED.includes(slot);
    const fits = o.fitType === slot ? ' fits' : '';
    return `<span class="chunk empty t-${slot}${req ? ' req' : ''}${fits}"${act} title="Empty ${slot} slot">${slot}</span>`;
  }
  const cls = ['chunk', 't-' + slot];
  if (chunk.muted) cls.push('muted');
  if (chunk.redacted) cls.push('redacted');
  if (chunk.enemyEdit) cls.push('enemy');
  if (o.fitType === slot) cls.push('fits');
  const t = tele.find((x) => x.ci === ci && x.slot === slot);
  if (t) cls.push('tele');
  let title = `${slot}${chunk.muted ? ' (muted)' : ''}${chunk.redacted ? ' (blacked out by an enemy)' : ''}${chunk.enemyEdit ? ' (edited by an enemy)' : ''}`;
  if (t) title += ` · ${app.combatView?.enemies[t.enemy].name} will edit this`;
  return `<span class="${cls.join(' ')}"${act} title="${esc(title)}">${esc(tok.text)}</span>`;
}

function clauseHTML(clause, ci, uid, o, tele) {
  const toks = G.clauseTokens(app.db, clause, o.showEmpty);
  const body = toks.map((t) => chunkSpan(t, ci, uid, o, tele)).join(' ');
  const label = o.showEmpty ? `<span class="clause-label">Clause ${ci + 1}</span>` : '';
  return `<div class="clause">${label}${body}</div>`;
}

function cardHTML(card, o = {}) {
  const db = app.db;
  const tele = o.tele ?? [];
  const cls = ['card', ...(o.cls ?? [])];
  if (o.chunkAct && o.editable !== false) cls.push('editable');
  let text = card.clauses.map((cl, ci) => clauseHTML(cl, ci, card.uid, o, tele)).join('');
  if (o.showEmpty && card.clauses.length < db.rules.maxClauses) {
    const newToks = G.clauseTokens(db, G.emptyClause(), true);
    text += `<div class="clause new"><span class="clause-label">New clause: glue a chunk in to start one</span>${newToks.map((t) => chunkSpan(t, card.clauses.length, card.uid, o, [])).join(' ')}</div>`;
  }
  if (!card.clauses.length && !o.showEmpty) text = `<div class="clause"><span class="chunk empty req">empty</span></div>`;
  const tags = [];
  if (G.isBroken(card)) tags.push(`<span class="tag broken">Broken</span>`);
  if (o.spent) tags.push(`<span class="tag">Spent</span>`);
  for (const t of tele) tags.push(`<span class="tag warn">${esc(app.combatView?.enemies[t.enemy].name ?? 'Enemy')}</span>`);
  if (o.extraTag) tags.push(o.extraTag);
  const tag = o.act ? 'button' : 'div';
  const attrs = o.act ? ` type="button" data-act="${o.act}" data-uid="${card.uid}"${o.dataId ? ` data-id="${o.dataId}"` : ''}${o.disabled ? ' aria-disabled="true"' : ''}` : '';
  return `<${tag} class="${cls.join(' ')}"${attrs}>
    ${costHTML(card)}
    <div class="head"><span class="name">${esc(card.name)}</span></div>
    <div class="text">${text}</div>
    ${tags.length ? `<div class="foot">${tags.join('')}</div>` : ''}
  </${tag}>`;
}

// ---------- shell ----------

const TABS = [['run', 'Run'], ['workshop', 'Workshop'], ['library', 'Library'], ['lab', 'Lab']];

function render() {
  const run = app.run;
  $('#tabs').innerHTML = TABS.map(([id, label]) => `<button type="button" data-act="tab" data-id="${id}"${app.view === id ? ' aria-current="page"' : ''}>${label}</button>`).join('');
  $('#status').innerHTML = `
    <span title="Hit points">HP <b>${run.hp}/${run.maxHp}</b></span>
    <span title="Crafting currency">Ink <b>${run.sandbox ? '∞' : run.ink}</b></span>
    <span>Deck <b>${run.deck.length}</b></span>
    <span>Clipboard <b>${run.clipboard.length}/${app.db.rules.clipboardSize}</b></span>
    ${run.sandbox ? '<span class="pill sandbox">Sandbox</span>' : ''}`;
  const view = { run: runView, workshop: () => workshopView(false), library: libraryView, lab: labView }[app.view];
  app.combatView = null;
  $('#main').innerHTML = view();
  writeSave();
}

// ---------- run ----------

const NODE_LABEL = { fight: 'Fight', elite: 'Elite', boss: 'Boss', workshop: 'Workshop' };

function nodeName(node) {
  if (node.type === 'workshop') return `+${app.db.rules.ink.workshopBonus} Ink`;
  return node.enemies.map((k) => app.db.enemies.enemies[k].name).join(' + ');
}

function trackHTML() {
  const run = app.run;
  return `<div class="track" aria-label="Act map">${app.db.rules.run.map((n, i) => {
    const st = i < run.node ? 'done' : i === run.node && run.phase !== 'victory' ? 'now' : '';
    return `<div class="node ${st}"><span class="dot">${i + 1}</span><span>${NODE_LABEL[n.type]}<br>${esc(nodeName(n))}</span></div>`;
  }).join('')}</div>`;
}

function runView() {
  const run = app.run;
  const db = app.db;
  const node = R.currentNode(db, run);
  let body = '';
  if (run.phase === 'map') {
    body = `<div class="panel stack">
      <div><h3>Next</h3><h2>${NODE_LABEL[node.type]}: ${esc(nodeName(node))}</h2>
      <p class="sub">${node.type === 'workshop' ? `+${db.rules.ink.workshopBonus} Ink, then edit your deck with any tool.` : 'Win to earn Ink, a reward card and whatever the enemies drop.'}</p></div>
      <div class="row"><button class="btn primary" type="button" data-act="enter">Enter</button>
      <button class="btn" type="button" data-act="tab" data-id="workshop">Look at your deck</button></div>
    </div>`;
  } else if (run.phase === 'combat') {
    body = combatHTML(run.combat, false);
  } else if (run.phase === 'reward') {
    const r = run.reward;
    body = `<div class="panel stack">
      <div><h3>Fight won</h3><h2>Pick a card to take apart later</h2>
      <p class="sub">+${r.ink} Ink${r.drops.length ? `. Dropped: ${esc(r.drops.join(', '))}` : ''}.</p></div>
      <div class="cards">${r.choices.map((id) => cardHTML(G.makeCard(R.cardDef(db, id), 'r-' + id), { act: 'reward', dataId: id, cls: ['clickable'] })).join('')}</div>
      <div class="row"><button class="btn" type="button" data-act="reward" data-id="">Skip the card</button></div>
    </div>`;
  } else if (run.phase === 'workshop') {
    return trackHTML() + workshopView(true);
  } else {
    const won = run.phase === 'victory';
    body = `<div class="panel result stack">
      <h2>${won ? 'Act cleared' : 'Defeated'}</h2>
      <p class="sub" style="margin-inline:auto">${won ? 'You beat the Plagiarist with your own words.' : `You fell at ${esc(NODE_LABEL[node.type])}: ${esc(nodeName(node))}.`} Deck of ${run.deck.length}, ${run.ink} Ink left.</p>
      <div class="row" style="justify-content:center"><button class="btn primary" type="button" data-act="newrun">New run</button></div>
    </div>`;
  }
  return trackHTML() + body;
}

// ---------- combat ----------

function combatHTML(s, isLab) {
  const db = app.db;
  app.combatView = s;
  const foes = s.enemies.map((e, i) => {
    const it = e.intent;
    const intent = e.dead ? '' : `<div class="intent${it?.edit && !it.fizzle ? ' edit' : ''}">Next: ${esc(C.intentText(db, s, i))}</div>`;
    return `<button type="button" class="foe${s.target === i && !e.dead ? ' targeted' : ''}${e.dead ? ' dead' : ''}" data-act="target" data-i="${i}" ${e.dead ? 'disabled' : ''}>
      <div class="fn"><b>${esc(e.name)}</b><span class="role">${esc(e.role)}${s.target === i && !e.dead ? ' · target' : ''}</span></div>
      <div class="bar"><i style="width:${(100 * e.hp) / e.maxHp}%"></i></div>
      <div class="nums"><span>HP <b>${e.hp}/${e.maxHp}</b></span>${e.block ? `<span>Block <b>${e.block}</b></span>` : ''}${e.weak ? `<span>Weak <b>${e.weak}</b></span>` : ''}${e.strength ? `<span>Str <b>${e.strength}</b></span>` : ''}</div>
      ${intent}
    </button>`;
  }).join('');

  const p = s.player;
  const pips = Array.from({ length: Math.max(p.energy, db.rules.player.energyPerTurn) }, (_, k) => `<i class="${k < p.energy ? 'on' : ''}"></i>`).join('');
  const qt = Object.entries(db.rules.combatEdits.tools).map(([tool, r]) =>
    `<button type="button" class="tool" data-act="ctool" data-tool="${tool}" aria-pressed="${app.ctool === tool}"><span class="tn">${tool === 'mute' ? 'Mute' : 'Invert'}</span><span class="tc">${r.energy} energy</span></button>`).join('');
  const over = s.phase === 'won' || s.phase === 'lost';
  const hand = s.hand.map((uid) => {
    const card = s.cards[uid];
    const info = C.playInfo(db, s, uid);
    const cls = [];
    if (!info.can) cls.push('unaffordable');
    if (!app.ctool) cls.push('clickable');
    return cardHTML(card, { act: app.ctool || over ? null : 'play', chunkAct: app.ctool && !over ? 'cedit' : null, tele: C.telegraphsOn(s, uid), cls });
  }).join('');
  const note = app.ctool
    ? `Tap a chunk on a card in your hand to ${app.ctool} it for ${db.rules.combatEdits.tools[app.ctool].energy} energy. It lasts until this fight ends.`
    : 'Tap a card to play it. Tap an enemy to target it. Dashed chunks are about to be edited by an enemy.';

  const resultBox = over ? `<div class="panel result stack">
      <h2>${s.phase === 'won' ? 'Victory' : 'Defeated'}</h2>
      <div class="row" style="justify-content:center">${isLab
        ? `<button class="btn primary" type="button" data-act="labfight">Fight again</button><button class="btn" type="button" data-act="labclear">Close</button>`
        : `<button class="btn primary" type="button" data-act="finish">Continue</button>`}</div>
    </div>` : '';

  let lastTurn = null;
  const logHTML = s.log.slice().reverse().slice(0, 60).map((l) => {
    let head = '';
    if (l.turn !== lastTurn) { head = `<div class="t">Turn ${l.turn}</div>`; lastTurn = l.turn; }
    return `${head}<div>${esc(l.msg)}</div>`;
  }).join('');

  return `<div class="arena">
    <div class="stack">
      <div class="foes">${foes}</div>
      ${resultBox}
      <div class="panel me-row">
        <div class="stack" style="gap:6px;flex:1 1 200px;min-width:0">
          <div class="fn"><b>You</b></div>
          <div class="bar me"><i style="width:${(100 * p.hp) / p.maxHp}%"></i></div>
          <div class="nums"><span>HP <b>${p.hp}/${p.maxHp}</b></span><span>Block <b>${p.block}</b></span>${p.weak ? `<span>Weak <b>${p.weak}</b></span>` : ''}${p.strength ? `<span>Str <b>${p.strength}</b></span>` : ''}<span>Draw <b>${s.draw.length}</b></span><span>Discard <b>${s.discard.length}</b></span><span>Turn <b>${s.turn}</b></span></div>
        </div>
        <div class="energy" title="Energy">${pips}<span>${p.energy}</span></div>
        <div class="qtools">${qt}</div>
        <button class="btn primary" type="button" data-act="endturn" ${s.phase !== 'player' ? 'disabled' : ''}>End turn</button>
      </div>
      <div class="hand-note">${esc(note)}</div>
      <div class="cards">${hand || '<p class="sub">Your hand is empty.</p>'}</div>
    </div>
    <aside class="panel"><h3>Log</h3><div class="log">${logHTML}</div></aside>
  </div>`;
}

// ---------- workshop ----------

const TOOL_INFO = {
  scissors: ['Scissors', 'Cut a chunk onto your clipboard.'],
  glue: ['Glue', 'Paste a clipboard chunk into a slot of the same type.'],
  mute: ['Mute', 'Silence a chunk, or unmute it.'],
  invert: ['Invert', 'Flip a chunk to its opposite.'],
  merge: ['Merge', "Fold another card's clauses into this one."],
  shred: ['Shred', 'Destroy this card; its chunks go to your clipboard.'],
};

function workshopView(inRun) {
  const db = app.db;
  const run = app.run;
  const ws = app.ws;
  const canEdit = run.phase === 'workshop' || run.sandbox;
  if (!run.deck.some((c) => c.uid === ws.sel)) ws.sel = run.deck[0]?.uid ?? null;
  const sel = run.deck.find((c) => c.uid === ws.sel);

  const list = run.deck.map((c) => cardHTML(c, {
    act: 'wsel', cls: ['mini', c.uid === ws.sel ? 'selected' : '', ws.tool === 'merge' && c.uid !== ws.sel ? 'clickable' : ''],
  })).join('');

  const tools = Object.keys(TOOL_INFO).map((t) => {
    const { ink, free } = E.toolCost(db, run, t);
    const cost = free ? `free ×${run.freeUses[t]}` : ink < 0 ? `+${-ink} Ink` : `${ink} Ink`;
    return `<button type="button" class="tool" data-act="wtool" data-tool="${t}" aria-pressed="${ws.tool === t}" title="${esc(TOOL_INFO[t][1])}" ${canEdit ? '' : 'disabled'}><span class="tn">${TOOL_INFO[t][0]}</span><span class="tc">${cost}</span></button>`;
  }).join('');

  const fitType = ws.tool === 'glue' && ws.clip != null ? run.clipboard[ws.clip]?.type : null;
  let help = canEdit ? (ws.tool ? TOOL_INFO[ws.tool][1] : 'Pick a tool, then tap a chunk on the card.') : '';
  if (ws.tool === 'glue') help = ws.clip == null ? 'Pick a chunk on your clipboard, then tap a matching slot.' : `Tap a ${fitType} slot (outlined) to paste.`;
  if (ws.tool === 'merge') help = `Tap another card in your deck to fold it into ${sel?.name ?? 'this card'}.`;

  const shredBox = ws.tool === 'shred' && sel ? `<div class="row">${ws.confirmShred
    ? `<button class="btn danger" type="button" data-act="shred">Yes, shred ${esc(sel.name)}</button><button class="btn" type="button" data-act="wtool" data-tool="shred">Keep it</button>`
    : `<button class="btn danger" type="button" data-act="shredask">Shred ${esc(sel.name)}</button>`}</div>` : '';

  const clip = Array.from({ length: db.rules.clipboardSize }, (_, i) => {
    const ch = run.clipboard[i];
    if (!ch) return `<div class="slot emptyslot"></div>`;
    return `<div class="slot${ws.clip === i ? ' sel' : ''}"><button type="button" class="pickc" data-act="clip" data-i="${i}" title="${ch.type}"><span class="chunk t-${ch.type}">${esc(G.chunkLabel(db, ch))}</span></button><button type="button" class="x" data-act="dropclip" data-i="${i}" title="Drop this chunk" aria-label="Drop">×</button></div>`;
  }).join('');
  const frees = Object.entries(run.freeUses).filter(([, n]) => n > 0).map(([t, n]) => `${n} free ${t}`).join(', ');

  return `<div class="stack">
    ${inRun ? `<div class="row" style="justify-content:space-between"><div><h3>Workshop</h3><h2>Cut up your deck</h2></div><button class="btn primary" type="button" data-act="leavews">Continue</button></div>` : ''}
    ${canEdit ? '' : `<div class="banner">Edits open at Workshops and after fights. Turn on Sandbox in the Lab to edit any time.</div>`}
    <div class="ws">
      <div class="panel stack"><h3>Deck · ${run.deck.length}</h3><div class="decklist">${list}</div></div>
      <div class="stack" style="min-width:0">
        <div class="tools">${tools}</div>
        ${canEdit ? `<div class="hand-note">${esc(help)}</div>` : ''}
        ${sel ? cardHTML(sel, { cls: ['big'], showEmpty: canEdit, chunkAct: canEdit ? 'wchunk' : null, fitType }) : '<p class="sub">Your deck is empty.</p>'}
        <div class="preview" id="preview">${sel ? esc(costLine(sel)) : ''}</div>
        ${shredBox}
      </div>
      <div class="panel stack">
        <h3>Clipboard · ${run.clipboard.length}/${db.rules.clipboardSize}</h3>
        <div class="clip">${clip}</div>
        <p class="sub" style="font-size:13px">Ink ${run.sandbox ? '∞ (sandbox)' : run.ink}${frees ? ` · ${esc(frees)}` : ''}</p>
      </div>
    </div>
  </div>`;
}

function costLine(card, next) {
  const c = G.cardCost(app.db, card);
  const fmt = (c) => (!c ? 'Broken' : `${c.cost}${c.x ? '+X' : ''} energy`);
  if (next === undefined) return `Cost: ${fmt(c)}`;
  return next === null ? `Cost: ${fmt(c)}` : `Cost: ${fmt(c)} → ${fmt(G.cardCost(app.db, next))}`;
}

// ---------- library ----------

function libraryView() {
  const db = app.db;
  const sandbox = app.run.sandbox;
  const types = [['trigger', 'Trigger'], ['verb', 'Verb'], ['amount', 'Amount'], ['repeat', 'Repeat'], ['target', 'Target'], ['condition', 'Condition']];
  const legend = types.map(([t, l]) => `<span class="chunk t-${t}">${l}</span>`).join('');
  const pool = (p) => db.cards.cards.filter((c) => c.pool === p).map((def) => `<div class="stack" style="gap:6px">${cardHTML(G.makeCard(def, 'lib-' + def.id))}${sandbox ? `<button class="btn" type="button" data-act="addcard" data-id="${def.id}">Add to deck</button>` : ''}</div>`).join('');
  const enemyRows = Object.entries(db.enemies.enemies).map(([k, e]) => {
    const pat = e.pattern.map((it) => [it.attack != null ? `Attack ${it.attack}${it.hits > 1 ? '×' + it.hits : ''}` : '', it.block ? `Block ${it.block}` : '', it.strength ? `+${it.strength} Str` : '', it.edit ? `Edit: ${it.edit.replace('_', ' ')}` : ''].filter(Boolean).join(', ')).join(' → ');
    const d = e.drops ?? {};
    const drops = [...Object.entries(d.tools ?? {}).map(([t, n]) => `${n} free ${t}`), d.chunk ? `${d.chunk.type} chunk: ${G.chunkLabel(db, d.chunk)}` : '', d.copiedCard ? 'your copied card' : ''].filter(Boolean).join(', ');
    return `<tr><td><b>${esc(e.name)}</b></td><td>${esc(e.role)}</td><td>${e.hp}</td><td>${esc(pat)}</td><td>${esc(drops)}</td></tr>`;
  }).join('');
  return `<div class="stack">
    <div class="panel stack">
      <h2>Card grammar</h2>
      <p class="sub">Each clause reads <b>[Trigger] Verb Amount [Repeat] Target [Condition]</b>. Verb and Amount are required; an empty Target uses the verb's default. Chunks only paste into slots of their own type.</p>
      <div class="legend">${legend}<span class="chunk t-verb muted">muted</span><span class="chunk t-amount redacted">99</span> <span style="font-size:13px;color:var(--fg-2)">blacked out by an enemy</span></div>
    </div>
    ${sandbox ? '' : '<div class="banner">Turn on Sandbox in the Lab to add any of these cards to your deck.</div>'}
    <h3>Starter cards</h3><div class="cards">${pool('starter')}</div>
    <h3>Reward cards · junk with good parts</h3><div class="cards">${pool('reward')}</div>
    <div class="panel stack"><h3>Enemies</h3><div class="tblwrap"><table class="pat"><thead><tr><th>Enemy</th><th>Role</th><th>HP</th><th>Pattern (repeats)</th><th>Drops</th></tr></thead><tbody>${enemyRows}</tbody></table></div></div>
  </div>`;
}

// ---------- lab ----------

function labView() {
  const db = app.db;
  const lab = app.lab;
  const run = app.run;
  const opts = Object.entries(db.enemies.enemies).map(([k, e]) => `<option value="${k}">${esc(e.name)} (${e.hp} HP)</option>`).join('');
  const f = lab.fuzz;
  const fuzzOut = f ? `<p class="sub">${f.ok ? 'Passed' : '<b>Failed</b>'}: ${f.turnsPlayed} turns across ${f.decks} random decks. Worst turn used ${Math.round(f.maxRatio.plays * 100)}% of the play limit, ${Math.round(f.maxRatio.draws * 100)}% of the draw limit and ${Math.round(f.maxRatio.resolutions * 100)}% of the resolution limit. Safety net hit ${f.safetyNet} times.</p>${f.failures.length ? `<pre>${esc(JSON.stringify(f.failures, null, 1))}</pre>` : ''}` : '';
  if (lab.combat) {
    return `<div class="stack"><div class="row" style="justify-content:space-between"><div><h3>Lab</h3><h2>Test fight</h2><p class="sub">Uses a copy of your current deck at full HP. Nothing here changes your run.</p></div><button class="btn" type="button" data-act="labclear">Leave test fight</button></div>${combatHTML(lab.combat, true)}</div>`;
  }
  return `<div class="grid-2">
    <div class="panel stack">
      <h2>Sandbox</h2>
      <p class="sub">Edits cost no Ink and work any time, and the Library can add any card to your deck.</p>
      <div class="row"><button class="btn${run.sandbox ? ' primary' : ''}" type="button" data-act="sandbox">${run.sandbox ? 'Sandbox is on: turn off' : 'Turn on sandbox'}</button></div>
    </div>
    <div class="panel stack">
      <h2>Test fight</h2>
      <p class="sub">Fight any enemies with your current deck.</p>
      <div class="row">${lab.enemies.map((k, i) => `<span class="pill">${esc(db.enemies.enemies[k].name)} <button type="button" class="x" style="border:none;background:none;padding:0" data-act="labrm" data-i="${i}" aria-label="Remove">×</button></span>`).join('') || '<span class="sub">No enemies yet.</span>'}</div>
      <div class="row"><select id="lab-enemy">${opts}</select><button class="btn" type="button" data-act="labadd">Add enemy</button><button class="btn primary" type="button" data-act="labfight" ${lab.enemies.length ? '' : 'disabled'}>Start fight</button></div>
    </div>
    <div class="panel stack">
      <h2>Loop fuzz test</h2>
      <p class="sub">Plays 500 random decks of random legal cards for 8 turns each, with random mid-fight edits, and checks that no turn passes N plays, N draws or 3N clause resolutions.</p>
      <div class="row"><button class="btn" type="button" data-act="fuzz">Run fuzz test</button></div>
      ${fuzzOut}
    </div>
    <div class="panel stack">
      <h2>Deck JSON</h2>
      <p class="sub">The same clause format as data/cards.json, so cards built here can be pasted into the content files (and read by a Godot build).</p>
      <textarea id="lab-io" spellcheck="false">${esc(lab.io || exportDeck())}</textarea>
      <div class="row"><button class="btn" type="button" data-act="copyio">Copy</button><button class="btn" type="button" data-act="importio">Replace deck with this</button><button class="btn" type="button" data-act="refreshio">Reload from deck</button></div>
    </div>
    <div class="panel stack">
      <h2>New run</h2>
      <p class="sub">Starts over with the starter deck. Current seed: <code>${run.seed}</code>.</p>
      <div class="row"><button class="btn danger" type="button" data-act="newrun">Start a new run</button></div>
    </div>
  </div>`;
}

function exportDeck() {
  return JSON.stringify(app.run.deck.map((c) => ({ id: c.base, name: c.name, pool: 'custom', clauses: c.clauses.map(G.clauseShorthand) })), null, 1);
}

// ---------- actions ----------

const actions = {
  tab: (el) => { app.view = el.dataset.id; app.ws.confirmShred = false; },
  enter: () => { R.enterNode(app.db, app.run); app.ctool = null; },
  target: (el) => { const s = currentCombat(); if (s) s.target = +el.dataset.i; },
  play: (el) => {
    const s = currentCombat();
    result(C.playCard(app.db, s, el.dataset.uid));
  },
  endturn: () => { const s = currentCombat(); result(C.endTurn(app.db, s)); app.ctool = null; },
  ctool: (el) => { app.ctool = app.ctool === el.dataset.tool ? null : el.dataset.tool; },
  cedit: (el) => {
    const s = currentCombat();
    if (result(C.combatEdit(app.db, s, app.ctool, el.dataset.uid, +el.dataset.ci, el.dataset.slot))) app.ctool = null;
  },
  finish: () => { R.finishCombat(app.db, app.run); },
  reward: (el) => { R.takeReward(app.db, app.run, el.dataset.id || null); app.ws.tool = null; },
  leavews: () => { R.leaveWorkshop(app.db, app.run); app.ws.tool = null; app.ws.clip = null; },
  newrun: () => { app.run = R.newRun(app.db); app.lab.combat = null; app.lab.io = ''; app.view = 'run'; app.ws = { sel: null, tool: null, clip: null, confirmShred: false }; },

  wsel: (el) => {
    const ws = app.ws;
    if (ws.tool === 'merge' && ws.sel && el.dataset.uid !== ws.sel) {
      if (result(E.merge(app.db, app.run, ws.sel, el.dataset.uid))) ws.tool = null;
      return;
    }
    ws.sel = el.dataset.uid;
    ws.confirmShred = false;
  },
  wtool: (el) => {
    const ws = app.ws;
    ws.tool = ws.tool === el.dataset.tool ? null : el.dataset.tool;
    ws.confirmShred = false;
    if (ws.tool !== 'glue') ws.clip = null;
  },
  wchunk: (el) => {
    const ws = app.ws;
    const args = [el.dataset.uid, +el.dataset.ci, el.dataset.slot];
    const db = app.db;
    const run = app.run;
    switch (ws.tool) {
      case 'scissors': result(E.cut(db, run, ...args)); break;
      case 'mute': result(E.mute(db, run, ...args)); break;
      case 'invert': result(E.invert(db, run, ...args)); break;
      case 'glue':
        if (ws.clip == null) toast('Pick a chunk on your clipboard first.');
        else if (result(E.glue(db, run, ...args, ws.clip))) ws.clip = null;
        break;
      default: toast(ws.tool ? `${TOOL_INFO[ws.tool][0]} works on the whole card.` : 'Pick a tool first.');
    }
  },
  clip: (el) => {
    const ws = app.ws;
    const i = +el.dataset.i;
    ws.clip = ws.clip === i ? null : i;
    if (ws.clip != null) ws.tool = 'glue';
  },
  dropclip: (el) => { E.dropClip(app.run, +el.dataset.i); app.ws.clip = null; },
  shredask: () => { app.ws.confirmShred = true; },
  shred: () => { if (result(E.shred(app.db, app.run, app.ws.sel))) { app.ws.tool = null; app.ws.sel = null; } app.ws.confirmShred = false; },

  addcard: (el) => {
    const c = R.addCardToDeck(app.db, app.run, G.makeCard(R.cardDef(app.db, el.dataset.id), 'tmp'));
    toast(`Added ${c.name} to your deck.`);
  },
  sandbox: () => { app.run.sandbox = !app.run.sandbox; },
  labadd: () => { app.lab.enemies.push($('#lab-enemy').value); },
  labrm: (el) => { app.lab.enemies.splice(+el.dataset.i, 1); },
  labfight: () => {
    const db = app.db;
    app.lab.combat = C.startCombat(db, app.run.deck, R.enemyDefs(db, app.lab.enemies), (Math.random() * 1e9) | 0, { hp: app.run.maxHp, maxHp: app.run.maxHp });
    app.ctool = null;
  },
  labclear: () => { app.lab.combat = null; app.ctool = null; },
  fuzz: () => { app.lab.fuzz = fuzz(app.db, { decks: 500, turns: 8, seed: (Math.random() * 1e9) | 0 }); },
  copyio: () => {
    const ta = $('#lab-io');
    navigator.clipboard?.writeText(ta.value).then(() => toast('Copied.'), () => { ta.select(); toast('Select-all done: press Ctrl+C to copy.'); });
    return false;
  },
  refreshio: () => { app.lab.io = ''; },
  importio: () => {
    const text = $('#lab-io').value;
    try {
      const defs = JSON.parse(text);
      if (!Array.isArray(defs)) throw new Error('Expected a list of cards.');
      const run = app.run;
      const deck = defs.map((d) => {
        const card = G.makeCard({ id: d.id ?? 'custom', name: d.name ?? 'Custom', clauses: d.clauses ?? [] }, R.newCardUid(run));
        for (const cl of card.clauses) for (const slot of G.SLOTS) {
          const ch = cl[slot];
          if (!ch) continue;
          const known = slot === 'amount' ? G.chunkIds(app.db, 'amount').includes(ch.id) : app.db.chunks[slot][ch.id];
          if (!known) throw new Error(`"${ch.id}" is not a ${slot} chunk.`);
        }
        return card;
      });
      run.deck = deck;
      app.lab.io = '';
      toast(`Deck replaced: ${deck.length} cards.`);
    } catch (err) {
      app.lab.io = text;
      toast(`Couldn't read that JSON: ${err.message}`);
    }
  },
};

function currentCombat() {
  return app.view === 'lab' ? app.lab.combat : app.run.combat;
}

document.addEventListener('click', (ev) => {
  const el = ev.target.closest('[data-act]');
  if (!el || el.disabled || !app.db) return;
  const fn = actions[el.dataset.act];
  if (!fn) return;
  ev.preventDefault();
  if (fn(el) === false) return;
  render();
});

// Live cost preview while hovering a chunk with a tool selected.
document.addEventListener('mouseover', (ev) => {
  const el = ev.target.closest('[data-act="wchunk"]');
  const out = $('#preview');
  if (!out || !app.db) return;
  const sel = app.run.deck.find((c) => c.uid === app.ws.sel);
  if (!sel) return;
  const tool = app.ws.tool;
  if (!el || !tool) { out.textContent = costLine(sel); return; }
  const args = [el.dataset.uid, +el.dataset.ci, el.dataset.slot];
  if (tool === 'glue') { if (app.ws.clip == null) return; args.push(app.ws.clip); }
  const next = E.preview(app.db, app.run, tool, args);
  out.textContent = costLine(sel, next);
});

const start = () => boot();
start();
