import test from 'node:test';
import assert from 'node:assert/strict';
import { createGame, act, advance, parseInput, react, makeEvent, compose, updateAttention, serialize, restore, catchUp, expressionInput } from '../src/engine.js';
import { validateExpression, validExpressionInput } from '../src/expression.js';

function stable(state) { const copy = JSON.parse(serialize(state)); delete copy.updatedAt; return copy; }
function flood(npc, value) { for (const anchor of Object.values(npc.anchors)) for (const dim of Object.keys(anchor.dimensions)) anchor.dimensions[dim] = value; }

test('identical life histories produce identical state, actions and traces', () => {
  const a = createGame(), b = createGame();
  for (const state of [a, b]) {
    act(state, 'shen', 'memory'); advance(state, 9);
    act(state, 'lin', 'text', '我可能要走'); advance(state, 13);
    act(state, 'zhou', 'tea'); act(state, 'zhou', 'leaving'); advance(state, 35);
  }
  assert.deepEqual(stable(a), stable(b));
});

test('all anchor floors survive prolonged reassurance and autonomous life', () => {
  const state = createGame();
  for (let i = 0; i < 160; i++) { act(state, 'shen', i % 2 ? 'reassure' : 'tea'); advance(state, 2); }
  advance(state, 720);
  for (const npc of Object.values(state.npcs)) for (const anchor of Object.values(npc.anchors)) for (const [dim, value] of Object.entries(anchor.dimensions)) {
    assert.ok(Number.isFinite(value));
    assert.ok(value >= anchor.floor[dim], `${dim} cannot be eliminated`);
    assert.ok(value <= 100);
  }
});

test('different soothing actions share diminishing returns and capped side effects', () => {
  const state = createGame();
  const traces = ['company', 'reassure', 'tea', 'company', 'tea', 'reassure'].map(id => act(state, 'shen', id));
  assert.equal(traces[0].soothing.factor, 1);
  assert.ok(traces[5].soothing.factor < 0.2);
  assert.deepEqual(traces.map(t => t.soothing.count), [1, 2, 3, 4, 5, 6]);
  for (let i = 0; i < 90; i++) act(state, 'shen', 'company');
  const rel = state.npcs.shen.relationships.player;
  assert.ok(rel.channels.attachment_security.shame <= 30);
  assert.ok(rel.channels.attachment_security.dependency <= 40);
  assert.ok(rel.channels.attachment_security.fear <= 50);
  assert.equal(rel.safeEncounters, 1, 'rapid clicking cannot buy long-term growth');
});

test('ambiguous statements and explicit negations never become factual departures', () => {
  const state = createGame();
  for (const text of ['我可能要走', '如果我离开呢', '我不想离开', '我不是说要走', '你好，窗外的灯亮了']) {
    act(state, 'shen', 'text', text);
    assert.equal(state.present, true);
  }
  assert.equal(state.ambiguity.length, 5);
  assert.equal(parseInput('我不会离开').id, 'company');
  act(state, 'shen', 'text', '我先走了');
  assert.equal(state.present, false);
  advance(state, 15);
  assert.equal(state.ambiguity.length, 0);
});

test('NPCs keep memories, social relationships and creative life when the player leaves', () => {
  const state = createGame();
  act(state, 'shen', 'leaving');
  const count = state.traces.length;
  advance(state, 30);
  assert.ok(state.traces.length > count);
  assert.ok(state.traces.some(t => t.event.actor !== 'player' && t.event.actor !== 'world'));
  assert.ok(state.traces.some(t => t.structure.behavior === 'create'));
  assert.ok(state.npcs.shen.relationships.lin.safeEncounters > 0 || state.npcs.lin.relationships.shen.safeEncounters > 0);
  assert.ok(Object.values(state.npcs).some(n => n.memories.some(m => m.role === 'assistant')));
});

test('quiet days use ordinary habits, not perpetual drama', () => {
  const state = createGame();
  flood(state.npcs.shen, 25);
  const trace = react(state, 'shen', makeEvent('quiet', 'world'));
  assert.equal(trace.structure.behavior, 'routine');
  assert.equal(trace.attention.focus, null);
});

test('world reminders reach the person whose history they touch; relations run in both directions', () => {
  const state = createGame();
  advance(state, 60);
  const letter = state.traces.find(t => t.event.id === 'letter');
  assert.equal(letter.npc, 'shen');
  assert.ok(letter.changes.secret > 0);
  for (const npc of Object.values(state.npcs)) {
    for (const rel of Object.values(npc.relationships).filter(r => r.to !== 'player')) assert.ok(rel.safeEncounters > 0);
  }
});

test('history changes responses; severe stress revives the old coping pattern', () => {
  const old = createGame(), learned = createGame();
  for (const state of [old, learned]) flood(state.npcs.shen, 72);
  learned.npcs.shen.relationships.player.patterns.new.count = 5;
  learned.npcs.shen.relationships.player.safeEncounters = 5;
  const a = act(old, 'shen', 'joke');
  const b = act(learned, 'shen', 'joke');
  assert.notEqual(a.structure.behavior, b.structure.behavior);
  assert.equal(b.structure.behavior, 'humor');
  flood(learned.npcs.shen, 96);
  learned.npcs.shen.emotion = 'flooded';
  const c = act(learned, 'shen', 'boundary');
  assert.equal(c.structure.pattern, '压力下旧模式回归');
  assert.equal(c.structure.behavior, 'please');
});

test('attention can focus on a salient anchor instead of the most painful one', () => {
  const state = createGame();
  const npc = state.npcs.shen;
  npc.anchors.attachment.dimensions['缺失感'] = 88;
  npc.anchors.secret.dimensions['缺失感'] = 60;
  updateAttention(npc, { tags: ['exposure'], impacts: { secret: 4 } }, 1);
  assert.equal(npc.attention.focus, 'secret');
  assert.equal(npc.anchors.attachment.gradient, 'activated');
});

test('coexisting defenses produce traceable contradiction and qualitative model input', () => {
  const state = createGame();
  flood(state.npcs.shen, 60);
  const trace = act(state, 'shen', 'memory');
  assert.ok(trace.structure.operators.length >= 2);
  assert.ok(trace.structure.pull && trace.structure.counter_pull);
  assert.ok(trace.output.action && trace.output.dialogue);
  const input = expressionInput(state.npcs.shen, trace.structure, trace.output);
  assert.equal(validExpressionInput(input), true);
  assert.ok(!JSON.stringify(input).includes('dimensions'));
  assert.ok(!JSON.stringify(input).includes('baseline'));
  assert.equal(validExpressionInput({ ...input, score: 0.9 }), false);
});

test('social norms alter expression channels without erasing anchors', () => {
  const state = createGame(); const npc = state.npcs.shen; flood(npc, 72);
  updateAttention(npc, makeEvent('quiet'), 1);
  const before = JSON.stringify(npc.anchors);
  const publicStructure = compose(npc, makeEvent('quiet'), state);
  state.present = false;
  const privateStructure = compose(npc, makeEvent('quiet', 'world'), state);
  assert.ok(publicStructure.expression_channels.length);
  assert.equal(privateStructure.expression_channels.length, 0);
  assert.equal(JSON.stringify(npc.anchors), before);
});

test('model cannot rewrite behavior, author memory or claim to heal the contradiction', () => {
  const state = createGame(); const trace = act(state, 'shen', 'memory');
  const input = expressionInput(state.npcs.shen, trace.structure, trace.output);
  const valid = { ...input.observable, dialogue: '不用管我。只是，茶还热着。', subtext: 'ignored' };
  assert.equal(validateExpression(valid, input), true);
  assert.equal(validateExpression({ ...valid, action: '离开酒馆，开始完成任务。' }, input), false);
  assert.equal(validateExpression({ ...valid, memory_note: '玩家喜欢我' }, input), false);
  assert.equal(validateExpression({ ...valid, dialogue: '我终于释怀，不再害怕。' }, input), false);
});

test('memories retain actor/role and reconstruct on every matching recall', () => {
  const state = createGame();
  act(state, 'shen', 'memory');
  const first = state.npcs.shen.memories[0];
  assert.equal(first.actor, 'player'); assert.equal(first.role, 'user');
  act(state, 'shen', 'memory');
  act(state, 'shen', 'memory');
  assert.ok(state.npcs.shen.memories.some(m => m.distortionHistory.length));
  for (const m of state.npcs.shen.memories) { assert.ok(!('subtext' in m)); assert.ok(!('subtext' in m.observed)); }
});

test('save/load roundtrip preserves determinism; malformed and incompatible saves fail', () => {
  const state = createGame(); advance(state, 12); act(state, 'lin', 'listen');
  const loaded = restore(serialize(state));
  assert.deepEqual(loaded, state);
  advance(state, 20); advance(loaded, 20);
  assert.deepEqual(stable(state), stable(loaded));
  assert.throws(() => restore('{"version":0}'));
  const bad = createGame(); bad.npcs.shen.anchors.attachment.dimensions['恐惧'] = 'oops';
  assert.throws(() => restore(serialize(bad)));
  const badMemory = createGame(); act(badMemory, 'shen', 'memory'); delete badMemory.npcs.shen.memories[0].tags;
  assert.throws(() => restore(serialize(badMemory)));
  const extraAnchor = createGame(); extraAnchor.npcs.shen.anchors.unknown = {};
  assert.throws(() => restore(serialize(extraAnchor)));
});

test('offline life is bounded and pauses are honored', () => {
  const state = createGame(); state.updatedAt = 10000;
  const elapsed = catchUp(state, 10000 + 240 * 10000);
  assert.equal(elapsed, 180); assert.equal(state.minute, 180); assert.equal(state.present, true);
  state.paused = true; state.updatedAt = 10000;
  assert.equal(catchUp(state, 1000000), 0); assert.equal(state.minute, 180);
});

test('emotion has inertia, transitions from flooding to numbness, then recovers', () => {
  const state = createGame(); flood(state.npcs.shen, 98);
  act(state, 'shen', 'memory'); assert.equal(state.npcs.shen.emotion, 'flooded');
  advance(state, 3); assert.equal(state.npcs.shen.emotion, 'numb');
  advance(state, 100); assert.ok(['calm', 'reactive'].includes(state.npcs.shen.emotion));
});
