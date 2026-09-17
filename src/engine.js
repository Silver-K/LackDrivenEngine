import { ANCHORS, PEOPLE, EVENTS, OPERATORS, LINES, GRADIENTS } from './data.js';

export const VERSION = 1;
const DIMS = ['缺失感', '羞耻', '恐惧', '怨恨', '欲望', '义务'];
const clone = value => structuredClone(value);
const clamp = (n, min = 0, max = 100) => Math.max(min, Math.min(max, n));
const rounds = n => Math.round(n * 100) / 100;
const add = (a, key, delta) => { a.dimensions[key] = rounds(clamp(a.dimensions[key] + delta, a.floor[key])); };
const has = (event, tag) => event.tags.includes(tag);
const primary = anchor => Math.max(anchor.dimensions['缺失感'], anchor.dimensions['恐惧'], anchor.dimensions['羞耻']);

export function makeRelationship(from, to) {
  return { from, to, trust: 0.35, dependency: 0.1, fearOfLoss: 0.15, security: 0.25, unfinished: '', channels: {}, safeEncounters: 0, lastSafe: -100, patterns: { old: { count: 8, weight: 0.8 }, new: { count: 0, weight: 0.6 } } };
}

export function createGame() {
  const state = { version: VERSION, minute: 0, present: true, weather: '细雨', paused: false, selected: 'shen', npcs: {}, log: [], traces: [], ambiguity: [], nextId: 1, updatedAt: Date.now(), director: { pressure: 'low', lastEvent: 'quiet' } };
  for (const person of PEOPLE) {
    const anchors = Object.fromEntries(person.anchors.map((id, index) => {
      const spec = ANCHORS[id];
      const floor = Object.fromEntries(DIMS.map((dim, i) => [dim, Math.max(5, spec.floor - i * 2)]));
      const baseline = Object.fromEntries(DIMS.map((dim, i) => [dim, Math.max(floor[dim], spec.baseline - [0, 7, 2, 15, -2, 12][i]) ]));
      return [id, { id, floor, baseline, dimensions: { '缺失感': person.values[index], '羞耻': person.values[index] - 7, '恐惧': person.values[index] - 3, '怨恨': 22, '欲望': person.values[index] + 4, '义务': 25 }, gradient: 'latent', dimensionGradients: {} }];
    }));
    state.npcs[person.id] = { id: person.id, anchors, attention: { focus: person.habit, background: [], inhibited: [] }, emotion: 'calm', emotionSince: 0, body: { fatigue: 20, hunger: 18, alcohol: 0 }, relationships: Object.fromEntries(['player', ...PEOPLE.filter(p => p.id !== person.id).map(p => p.id)].map(to => [to, makeRelationship(person.id, to)])), memories: [], behavior: 'routine', actionCount: 0, lastEvent: 'quiet', narrative: person.narrative, lastOutput: null };
    updateAttention(state.npcs[person.id], { tags: [], impacts: {} }, 0);
  }
  appendLog(state, { type: 'world', text: '傍晚六点。你推开雨停酒馆的门，暖光落在湿漉漉的鞋尖。没有人问你为什么来。' });
  appendLog(state, { type: 'npc', actor: 'shen', dialogue: '进来吧。门边有干毛巾。', action: '他往炉里添了一块木柴，给吧台旁留出一张椅子。', expression: '抬了抬眼，又低头擦杯子。', behavior: 'routine' });
  return state;
}

export function appendLog(state, item) {
  const entry = { id: state.nextId++, minute: state.minute, ...item };
  state.log.push(entry);
  if (state.log.length > 240) state.log.splice(0, state.log.length - 240);
  return entry;
}

export function parseInput(text, actor = 'player', target = 'shen') {
  const content = String(text).trim().slice(0, 500);
  const matches = Object.entries(EVENTS).filter(([, spec]) => spec.patterns.some(pattern => content.includes(pattern))).map(([id]) => id);
  // A promise not to leave contains "离开"; the longer, explicit negation wins.
  const candidates = matches.includes('company') && /不(?:会)?(?:走|离开)/u.test(content) ? matches.filter(id => id !== 'leaving') : matches;
  const uncertain = /可能|也许|或许|如果|说不定|不一定|假如/u.test(content);
  const negated = /(?:不是|并非|别说|没有说|不想).*(?:离开|要走|讨厌|秘密)/u.test(content);
  const id = uncertain || negated || candidates.length !== 1 ? 'ambiguous' : candidates[0];
  return { id, actor, target, content, certainty: id === 'ambiguous' ? 'uncertain' : 'explicit', candidates: id === 'ambiguous' ? candidates : [], ...clone(EVENTS[id]) };
}

export function makeEvent(id, actor = 'player', target = 'shen', content) {
  if (!EVENTS[id]) throw new Error('未知事件');
  return { id, actor, target, content: content ?? EVENTS[id].text ?? EVENTS[id].label, certainty: 'explicit', candidates: [], ...clone(EVENTS[id]) };
}

export function updateAttention(npc, event, minute) {
  const ids = Object.keys(npc.anchors);
  const threshold = npc.body.fatigue > 65 ? 43 : 50;
  const relevant = ids.filter(id => event.impacts[id] > 0 && primary(npc.anchors[id]) >= threshold);
  const previous = npc.attention.focus;
  // Salience, persistence, habitual order. No utility function, scoring or argmax.
  let focus = relevant[0] ?? (previous && primary(npc.anchors[previous]) >= threshold ? previous : null);
  if (!focus) focus = ids.find(id => primary(npc.anchors[id]) >= threshold) ?? null;
  if (minute % 9 === 0 && !relevant.length && ids.every(id => primary(npc.anchors[id]) < 70)) focus = null;
  const inhibited = focus && npc.anchors[focus].dimensions['恐惧'] >= 78 ? ids.filter(id => id !== focus && id === 'pride') : [];
  npc.attention = { focus, background: ids.filter(id => id !== focus && !inhibited.includes(id)), inhibited };
  for (const [id, anchor] of Object.entries(npc.anchors)) {
    for (const dim of DIMS) {
      const value = anchor.dimensions[dim];
      anchor.dimensionGradients[dim] = value >= 90 ? 'flooded' : value >= 70 && focus === id ? 'focused' : value >= threshold ? 'activated' : 'latent';
    }
    anchor.gradient = Object.values(anchor.dimensionGradients).includes('flooded') ? 'flooded' : focus === id && primary(anchor) >= 70 ? 'focused' : primary(anchor) >= threshold ? 'activated' : 'latent';
  }
}

function updateEmotion(npc, minute) {
  const anchors = Object.values(npc.anchors);
  const flooded = anchors.some(a => a.gradient === 'flooded');
  const many = anchors.filter(a => primary(a) >= 70).length >= 2;
  const badBody = npc.body.fatigue >= 68 || npc.body.hunger >= 70;
  const elapsed = minute - npc.emotionSince;
  let next = npc.emotion;
  if (npc.emotion === 'flooded' && elapsed >= 3) next = 'numb';
  else if (npc.emotion === 'numb') { if (elapsed >= 6 && !flooded && !badBody) next = 'calm'; }
  else if (flooded || (npc.emotion === 'reactive' && many)) next = 'flooded';
  else if (npc.emotion === 'calm' && (badBody || anchors.some(a => primary(a) >= 62))) next = 'reactive';
  else if (npc.emotion === 'reactive' && elapsed >= 4 && !badBody && anchors.every(a => primary(a) < 62)) next = 'calm';
  if (next !== npc.emotion) { npc.emotion = next; npc.emotionSince = minute; }
}

function retrieveMemory(npc, event, minute) {
  const memory = [...npc.memories].reverse().find(m => m.actor === event.actor && (m.event === event.id || event.tags.some(t => m.tags.includes(t))));
  if (!memory) return null;
  const anchors = Object.values(npc.anchors);
  let distortion = '重新想起';
  if (anchors.some(a => a.dimensions['羞耻'] >= 65) && !has(event, 'exposure')) distortion = '压抑：记得发生过，却避开细节';
  else if (anchors.some(a => a.dimensions['恐惧'] >= 65)) { distortion = '闪回：离开的细节变得格外清楚'; memory.weight = clamp(memory.weight + 0.05, 0, 1); }
  else if (anchors.some(a => a.dimensions['怨恨'] >= 60)) distortion = '选择性注意：更记得受伤的部分';
  else if (anchors.some(a => a.dimensions['欲望'] >= 60)) distortion = '理想化：更记得靠近的部分';
  memory.distortionHistory.push({ minute, distortion });
  memory.distortionHistory = memory.distortionHistory.slice(-8);
  memory.recalled = distortion;
  return { content: memory.content, role: memory.role, distortion };
}

function soothe(npc, event, minute) {
  const rel = npc.relationships[event.actor];
  if (!event.channel || !rel) return { factor: 1, count: 0, channel: null };
  const channel = rel.channels[event.channel] ??= { count: 0, last: minute, shame: 0, dependency: 0, fear: 0 };
  // A quiet interval only partially restores receptivity. Rephrasing shares the same channel.
  if (minute - channel.last > 90) channel.count = Math.max(0, channel.count - 1);
  const inconsistent = rel.unfinished && minute - (rel.lastRejection ?? -100) < 8;
  const factor = rounds(Math.pow(rel.security < 0.4 ? 0.68 : 0.8, channel.count) * (inconsistent ? 0.5 : 1));
  channel.count++;
  channel.last = minute;
  channel.shame = Math.min(30, channel.shame + (channel.count > 2 ? 2 : 0));
  channel.dependency = Math.min(40, channel.dependency + 2);
  channel.fear = Math.min(50, channel.fear + (channel.count > 2 ? 2 : 1));
  rel.dependency = Math.min(0.65, rel.dependency + 0.012);
  rel.fearOfLoss = Math.min(0.75, rel.fearOfLoss + (channel.count > 2 ? 0.015 : 0.004));
  if (minute - rel.lastSafe >= 5 && !inconsistent) {
    rel.safeEncounters++;
    rel.lastSafe = minute;
    rel.trust = Math.min(0.85, rel.trust + 0.025);
    rel.security = Math.min(0.75, rel.security + 0.025);
    if (['listen', 'boundary', 'joke', 'company', 'npc_care'].includes(event.id)) rel.patterns.new.count++;
  }
  return { factor, count: channel.count, channel: event.channel, inconsistent: Boolean(inconsistent) };
}

export function compose(npc, event, world, memory = null) {
  const anchors = Object.values(npc.anchors);
  const active = anchors.filter(a => a.gradient !== 'latent');
  const rel = npc.relationships[event.actor] ?? npc.relationships.player;
  const stress = ['flooded', 'numb'].includes(npc.emotion) || npc.body.fatigue > 72;
  const oldFamiliarity = rel.patterns.old.count * rel.patterns.old.weight;
  const newFamiliarity = rel.patterns.new.count * rel.patterns.new.weight;
  const inhibition = newFamiliarity / (newFamiliarity + oldFamiliarity);
  const context = {
    stress, alone: !world.present && event.actor === 'world', active: active.length > 0,
    rested: npc.body.fatigue < 65, learned: newFamiliarity >= 1.8 && inhibition > 0.18,
    safe: has(event, 'safe'), ambiguous: has(event, 'ambiguous'), vulnerable: anchors.some(a => a.dimensions['恐惧'] >= 50),
    rejected: has(event, 'rejection'), constrained: world.present && npc.body.alcohol < 45,
    exposed: has(event, 'exposure'), secret: Boolean(npc.anchors.secret), multiple: active.length >= 2
  };
  const eligible = OPERATORS.filter(op => Object.entries(op.when).every(([key, value]) => context[key] === value));
  const tier = eligible.length ? Math.min(...eligible.map(op => op.tier)) : null;
  const operators = eligible.filter(op => op.tier === tier);
  let behavior = operators[0]?.behavior ?? 'routine';
  if (npc.emotion === 'numb') behavior = 'evade';
  const focus = npc.attention.focus;
  const spec = ANCHORS[focus];
  const suppression = context.constrained && context.active ? ['直接需要 → 试探', '直接愤怒 → 对物件发泄', '直接脆弱 → 停顿与回避'] : [];
  return {
    focus, background: npc.attention.background, inhibited: npc.attention.inhibited,
    pull: spec?.pull ?? '让此刻平平常常地过去', counter_pull: spec?.counter ?? '那些没有说完的事仍在背景里',
    operators: operators.map(op => op.id), defenses: operators.map(op => op.defense),
    contradiction: operators.map(op => op.contradiction).join('；') || '日常暂时容纳了缺口，并未填平它',
    behavior, surface_action: behavior === 'routine' ? '做一件平常的小事' : operators[0]?.name ?? '隔离',
    expression_channels: suppression, history: memory?.distortion ?? '过去熟悉的应对仍在',
    pattern: stress ? '压力下旧模式回归' : context.learned && context.safe ? '新经验暂时抑制旧模式' : '沿用熟悉模式',
    body: npc.body.fatigue > 65 ? '疲惫让防御变薄' : npc.body.hunger > 60 ? '饥饿使人敏感' : '身体尚能承受',
    norm: context.constrained ? '在客人面前维持体面，不能直说需要' : '独处时可以放下待客的体面',
    constraints: ['不要解决矛盾', '不要选一个方向', '让矛盾同时存在于对话、动作、表情中', '不增加行为，不改变事实，不写入记忆']
  };
}

export function express(npc, structure, event, world) {
  const person = PEOPLE.find(p => p.id === npc.id);
  const variants = LINES[npc.id][structure.behavior] ?? LINES[npc.id].routine;
  const index = (npc.actionCount + Math.floor(world.minute / 7) + (event.actor === 'player' ? 0 : 1)) % variants.length;
  const actions = {
    routine: person.routine[(npc.actionCount + Math.floor(world.minute / 4)) % person.routine.length],
    approach_avoid: '说完却没有转身，把身旁的椅子往外拉了一点。',
    indirect: '故作随意地推来一只杯子，手还停在你这一侧。',
    test: '看了一眼门口，又悄悄把视线移回来。',
    displace: '手上的动作重了些，碰到杯沿时又立刻放轻。',
    evade: '手指收紧了一瞬，把话停在半途，仍没有走开。',
    please: '往前挪了半步，像是要伸手，又把手收回去。',
    humor: '笑了一下，把手边的活放下，给沉默留出一点位置。',
    create: person.creative
  };
  let action = actions[structure.behavior];
  // Physical acknowledgements are engine-owned facts, independent of the expression layer.
  if (event.id === 'tea' || event.id === 'npc_care') action = `接过热茶，把杯子握在手里。${action}`;
  if (event.id === 'memory' && structure.behavior === 'routine') action = `听见你问起过去，抬眼停了一会儿。${action}`;
  if (event.id === 'boundary') action = `轻轻点了点头。${action}`;
  if (event.id === 'company') action = `注意到身旁多坐了一个人，肩膀稍稍放松。${action}`;
  if (event.actor !== 'player') action = action.replaceAll('你这一侧', '桌子另一侧');
  return { dialogue: !world.present && event.actor === 'world' ? '' : variants[index], action, expression: npc.emotion === 'numb' ? '目光有些失焦。' : npc.emotion === 'flooded' ? '话到嘴边比平时急促。' : structure.behavior === 'routine' ? '神情松下来片刻。' : '像有另一句话没有说出口。', subtext: structure.contradiction };
}

export function expressionInput(npc, structure, output) {
  // Whitelist: no scores, raw state, memory mutation or intention vectors reach the model.
  return {
    character: PEOPLE.find(p => p.id === npc.id).name,
    anchor_state: Object.fromEntries(Object.entries(npc.anchors).map(([id, a]) => [ANCHORS[id].name, GRADIENTS[a.gradient]])),
    contradiction_structure: Object.fromEntries(['pull', 'counter_pull', 'contradiction', 'defenses', 'surface_action', 'expression_channels', 'history', 'pattern', 'body', 'norm', 'constraints'].map(k => [k, clone(structure[k])])),
    observable: { dialogue: output.dialogue, action: output.action, expression: output.expression }
  };
}

export function react(state, npcId, event, { visible = true } = {}) {
  const npc = state.npcs[npcId];
  const before = clone(npc.anchors);
  const memory = retrieveMemory(npc, event, state.minute);
  const soothing = soothe(npc, event, state.minute);
  const distortions = [];
  for (const [id, anchor] of Object.entries(npc.anchors)) {
    const impact = event.impacts[id] ?? 0;
    const applied = impact < 0 ? impact * soothing.factor : impact * (npc.body.fatigue > 65 ? 1.18 : 1);
    add(anchor, '缺失感', applied);
    add(anchor, '恐惧', applied * 0.8);
    if (has(event, 'exposure')) add(anchor, '羞耻', Math.max(0, impact) * 0.7);
    if (has(event, 'rejection')) add(anchor, '怨恨', Math.max(0, impact) * 0.4);
    if (has(event, 'safe') && soothing.count > 2) add(anchor, '羞耻', soothing.count <= 17 ? 1.2 : 0);
    if (has(event, 'ambiguous') && anchor.dimensions['恐惧'] >= 55 && npc.emotion !== 'numb') {
      add(anchor, '恐惧', 5); add(anchor, '怨恨', 2);
      distortions.push(`${ANCHORS[id].name}：把不确定读成了疏远`);
    }
    if (memory?.distortion.startsWith('闪回') && impact > 0) add(anchor, '恐惧', 3);
  }
  if (event.id === 'tea' || event.id === 'npc_care') npc.body.fatigue = clamp(npc.body.fatigue - 4);
  if (has(event, 'rejection') || has(event, 'departure')) {
    const rel = npc.relationships[event.actor];
    if (rel) { rel.unfinished = event.content; rel.lastRejection = state.minute; rel.trust = clamp(rel.trust - 0.025, 0.1, 0.9); }
  }
  if (has(event, 'return')) { const rel = npc.relationships[event.actor]; if (rel) rel.unfinished = ''; }
  updateAttention(npc, event, state.minute);
  updateEmotion(npc, state.minute);
  const structure = compose(npc, event, state, memory);
  const output = express(npc, structure, event, state);
  npc.behavior = structure.behavior;
  npc.actionCount++;
  npc.lastEvent = event.id;
  npc.lastOutput = { ...output, minute: state.minute };
  const rel = npc.relationships[event.actor];
  if (rel && structure.pattern !== '新经验暂时抑制旧模式' && structure.behavior !== 'routine') rel.patterns.old.count = Math.min(30, rel.patterns.old.count + 0.1);
  // Consequences come from engine-owned observable behavior, never subtext or model claims.
  if (['create', 'humor'].includes(structure.behavior) && structure.focus) add(npc.anchors[structure.focus], '缺失感', -3);
  if (structure.behavior === 'please' && structure.focus) { add(npc.anchors[structure.focus], '缺失感', -2 * Math.pow(0.8, rel?.channels.attachment_security?.count ?? 0)); add(npc.anchors[structure.focus], '羞耻', 2); }
  const significant = Object.values(event.impacts).some(value => Math.abs(value) >= 7) || structure.behavior === 'create';
  if (significant) {
    npc.memories.push({ id: state.nextId++, minute: state.minute, actor: event.actor, role: event.actor === 'player' ? 'user' : event.actor === 'world' ? 'system' : 'assistant', event: event.id, tags: clone(event.tags), content: event.content, observed: { action: output.action, dialogue: output.dialogue }, weight: has(event, 'rejection') || has(event, 'exposure') ? 0.85 : 0.55, anchors: Object.keys(event.impacts).filter(id => npc.anchors[id]), distortionHistory: [] });
    npc.memories = npc.memories.slice(-48);
  }
  const trace = { id: state.nextId++, minute: state.minute, npc: npcId, event: { id: event.id, actor: event.actor, content: event.content, certainty: event.certainty }, activated: Object.fromEntries(Object.entries(npc.anchors).map(([id, a]) => [id, a.gradient])), attention: clone(npc.attention), distortions, soothing, structure, output, changes: Object.fromEntries(Object.keys(npc.anchors).map(id => [id, rounds(npc.anchors[id].dimensions['缺失感'] - before[id].dimensions['缺失感'])])) };
  state.traces.push(trace);
  state.traces = state.traces.slice(-180);
  if (visible) appendLog(state, { type: 'npc', actor: npcId, target: event.actor, ...output, traceId: trace.id, behavior: structure.behavior });
  return trace;
}

function slowTick(state) {
  for (const npc of Object.values(state.npcs)) {
    const hour = (18 + Math.floor(state.minute / 60)) % 24;
    const sleeping = hour >= 2 && hour < 7;
    npc.body.fatigue = clamp(npc.body.fatigue + (sleeping ? -4 : state.minute % 16 < 3 ? -1.4 : 0.28));
    npc.body.hunger = clamp(npc.body.hunger + (state.minute % 32 === 0 ? -20 : 0.25));
    npc.body.alcohol = clamp(npc.body.alcohol - 0.5);
    for (const anchor of Object.values(npc.anchors)) {
      for (const dim of DIMS) {
        // Inertia, not a target for planning. There is no action reward attached to this value.
        const drift = (anchor.baseline[dim] - anchor.dimensions[dim]) * 0.025;
        add(anchor, dim, drift + (sleeping ? -1.2 : 0));
      }
    }
    for (const memory of npc.memories) memory.weight = Math.max(0.1, memory.weight - (memory.weight > 0.75 ? 0.0002 : 0.001));
    if (state.minute % 60 === 0) {
      npc.narrative = npc.behavior === 'create' ? '也不是为了谁。只是手里恰好有这个。' : PEOPLE.find(p => p.id === npc.id).narrative;
      // Widely separated experiences, including NPC relationships, can slowly alter baseline.
      const secure = Object.values(npc.relationships).filter(r => r.safeEncounters >= 4).length;
      if (secure >= 2) for (const anchor of Object.values(npc.anchors)) anchor.baseline['恐惧'] = Math.max(anchor.floor['恐惧'] + 8, anchor.baseline['恐惧'] - 0.15);
    }
    updateAttention(npc, EVENTS.quiet, state.minute);
    updateEmotion(npc, state.minute);
  }
  state.ambiguity = state.ambiguity.filter(item => state.minute - item.minute < 12);
}

export function advance(state, minutes = 1, { quiet = false } = {}) {
  if (!Number.isInteger(minutes) || minutes < 0 || minutes > 720) throw new Error('时间步长无效');
  for (let step = 0; step < minutes; step++) {
    state.minute++;
    slowTick(state);
    const phase = state.minute % 48;
    state.weather = phase < 16 ? '细雨' : phase < 28 ? '雨渐密' : phase < 40 ? '檐下滴雨' : '雨暂歇';
    const eventId = state.minute % 23 === 0 ? 'letter' : state.minute % 17 === 0 ? 'closing' : state.minute % 11 === 0 ? 'rain' : 'quiet';
    state.director = { pressure: eventId === 'quiet' ? 'low' : 'changing', lastEvent: eventId };
    if (eventId !== 'quiet' && !quiet) appendLog(state, { type: 'world', text: EVENTS[eventId].label + '。' });
    const npcId = eventId === 'letter' ? 'shen' : PEOPLE[state.minute % PEOPLE.length].id;
    if (state.minute % 2 === 0 || eventId !== 'quiet') react(state, npcId, makeEvent(eventId, 'world', npcId), { visible: !quiet });
    // Directed social feedback. The director never supplies a dialogue or an action.
    if (state.minute % 5 === 0) {
      const actorIndex = Math.floor(state.minute / 5) % PEOPLE.length;
      const actor = state.npcs[PEOPLE[actorIndex].id];
      const neighbor = Math.floor(state.minute / 15) % 2 === 0 ? 1 : 2;
      const target = PEOPLE[(actorIndex + neighbor) % PEOPLE.length].id;
      const social = actor.behavior === 'displace' || actor.emotion === 'numb' ? 'npc_distance' : 'npc_care';
      const name = PEOPLE.find(p => p.id === actor.id).name;
      const targetName = PEOPLE.find(p => p.id === target).name;
      const event = makeEvent(social, actor.id, target, `${name}朝${targetName}${social === 'npc_care' ? '推去一杯热茶' : '挪远了椅子'}。`);
      if (!quiet) appendLog(state, { type: 'world', text: event.content });
      react(state, target, event, { visible: !quiet });
    }
  }
  state.updatedAt = Date.now();
  return state;
}

export function act(state, target, action, text) {
  if (!state.npcs[target]) throw new Error('角色不存在');
  if (!state.present && action !== 'return') throw new Error('你在门外，先回到酒馆吧。');
  const event = action === 'text' ? parseInput(text, 'player', target) : makeEvent(action, 'player', target);
  if (event.id === 'ambiguous') state.ambiguity.push({ minute: state.minute, target, content: event.content, candidates: event.candidates });
  // Ambiguous language never mutates physical world facts ("可能要走" is not departure).
  if (event.id === 'leaving') state.present = false;
  if (event.id === 'return') state.present = true;
  appendLog(state, { type: 'player', text: event.content || '你没有说话，只听着窗外的雨。', target });
  const trace = react(state, target, event);
  if (['leaving', 'return'].includes(event.id)) {
    for (const id of Object.keys(state.npcs).filter(id => id !== target)) react(state, id, { ...event, target: id }, { visible: false });
    appendLog(state, { type: 'world', text: state.present ? '门铃轻响。你身后带进一点雨的气味。' : '你走到檐下。门内的生活继续，隔着窗还看得见灯光。' });
  }
  state.updatedAt = Date.now();
  return trace;
}

export function serialize(state) { return JSON.stringify(state); }
export function restore(raw) {
  const state = JSON.parse(raw);
  if (!state || state.version !== VERSION || !Number.isInteger(state.minute) || state.minute < 0 || state.minute > 10000000 || typeof state.present !== 'boolean' || typeof state.paused !== 'boolean' || !Number.isInteger(state.nextId) || !Array.isArray(state.log) || state.log.length > 240 || !Array.isArray(state.traces) || state.traces.length > 180 || !Array.isArray(state.ambiguity) || !Number.isFinite(state.updatedAt) || !PEOPLE.some(p => p.id === state.selected)) throw new Error('存档格式不兼容');
  for (const person of PEOPLE) {
    const npc = state.npcs?.[person.id];
    if (!npc || npc.id !== person.id || !Array.isArray(npc.memories) || !npc.attention || !['calm', 'reactive', 'flooded', 'numb'].includes(npc.emotion) || !Number.isFinite(npc.actionCount) || !Number.isFinite(npc.emotionSince) || Object.keys(npc.anchors ?? {}).length !== person.anchors.length) throw new Error('角色存档损坏');
    for (const key of ['fatigue', 'hunger', 'alcohol']) if (!Number.isFinite(npc.body?.[key]) || npc.body[key] < 0 || npc.body[key] > 100) throw new Error('身体状态损坏');
    for (const id of person.anchors) for (const field of ['dimensions', 'floor', 'baseline']) for (const dim of DIMS) if (!Number.isFinite(npc.anchors?.[id]?.[field]?.[dim]) || npc.anchors[id][field][dim] < 0 || npc.anchors[id][field][dim] > 100) throw new Error('锚点存档损坏');
    for (const to of ['player', ...PEOPLE.filter(p => p.id !== person.id).map(p => p.id)]) {
      const rel = npc.relationships?.[to];
      if (!rel?.channels || !rel.patterns?.old || !rel.patterns?.new || !['trust', 'safeEncounters', 'lastSafe', 'security', 'dependency', 'fearOfLoss'].every(key => Number.isFinite(rel[key])) || ![rel.patterns.new.count, rel.patterns.new.weight, rel.patterns.old.count, rel.patterns.old.weight].every(Number.isFinite)) throw new Error('关系存档损坏');
      for (const channel of Object.values(rel.channels)) if (!['count', 'last', 'shame', 'dependency', 'fear'].every(key => Number.isFinite(channel[key]) && channel[key] >= 0)) throw new Error('安抚记录损坏');
    }
    for (const memory of npc.memories) if (typeof memory.content !== 'string' || !Array.isArray(memory.tags) || !Array.isArray(memory.distortionHistory) || !Number.isFinite(memory.weight) || !['user', 'system', 'assistant'].includes(memory.role)) throw new Error('记忆存档损坏');
  }
  for (const trace of state.traces) if (!state.npcs[trace.npc] || !trace.structure || !Array.isArray(trace.structure.defenses) || !trace.event || !trace.activated || !trace.soothing || !Array.isArray(trace.distortions)) throw new Error('因果记录损坏');
  return state;
}

export function catchUp(state, now = Date.now()) {
  if (state.paused) { state.updatedAt = now; return 0; }
  const elapsed = Math.max(0, Math.min(180, Math.floor((now - state.updatedAt) / 10000)));
  if (elapsed > 0) {
    const presence = state.present;
    state.present = false;
    advance(state, elapsed, { quiet: true });
    state.present = presence;
    appendLog(state, { type: 'world', text: `你不在的这段时间，酒馆又度过了 ${elapsed} 分钟。有人添了茶，有人没有把话说完。` });
  }
  state.updatedAt = now;
  return elapsed;
}
