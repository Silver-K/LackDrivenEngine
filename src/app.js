import { PEOPLE, ANCHORS, EVENTS, ACTIONS, GRADIENTS, EMOTIONS } from './data.js';
import { createGame, advance, act, serialize, restore, catchUp, expressionInput } from './engine.js';

const $ = selector => document.querySelector(selector);
const $$ = selector => [...document.querySelectorAll(selector)];
const esc = value => String(value ?? '').replace(/[&<>"']/g, char => ({ '&':'&amp;', '<':'&lt;', '>':'&gt;', '"':'&quot;', "'":'&#39;' }[char]));
const SAVE_KEY = 'before-rain-ends-v1';
let state;
let storageAvailable = true;
let loadError = false;
try { const saved = localStorage.getItem(SAVE_KEY); state = saved ? restore(saved) : createGame(); catchUp(state); }
catch { state = createGame(); loadError = true; }
let tab = 'heart';
let pinnedTrace = null;
let lastLogIds = '';
let modelEnabled = false;
let busy = false;
let sound = null;
let soundEnabled = false;
let toastTimer;
let lastTick = Date.now();

function time(minute) { const total = 18 * 60 + minute; return `${String(Math.floor(total / 60) % 24).padStart(2, '0')}:${String(total % 60).padStart(2, '0')}`; }
function personName(id) { return id === 'player' ? '你' : id === 'world' ? '酒馆' : PEOPLE.find(p => p.id === id)?.name ?? '某人'; }
function toast(text) { $('#toast').textContent = text; $('#toast').classList.add('show'); clearTimeout(toastTimer); toastTimer = setTimeout(() => $('#toast').classList.remove('show'), 3300); }
function save() {
  try { localStorage.setItem(SAVE_KEY, serialize(state)); storageAvailable = true; $('#save-status').textContent = '此刻已留存'; }
  catch { if (storageAvailable) toast('浏览器暂时无法保存，请在设置中导出这一晚。'); storageAvailable = false; $('#save-status').textContent = '请导出存档'; }
}

function portrait(person) {
  const hair = person.id === 'zhou' ? '#aab19a' : '#283b2d';
  const shirt = person.id === 'lin' ? '#728e7a' : person.id === 'zhou' ? '#968560' : '#5f7766';
  return `<span class="avatar"><svg viewBox="0 0 60 72" aria-hidden="true"><rect width="60" height="72" fill="#3b4d3b"/><circle cx="32" cy="28" r="24" fill="${esc(person.color)}" opacity=".15"/><path d="M8 72V56Q12 43 29 43Q48 43 54 58V72" fill="${shirt}"/><path d="M24 39V48Q30 54 38 46V37" fill="#b49875"/><path d="M17 20Q18 9 32 10Q47 12 45 29L40 42Q31 49 22 40z" fill="#c4a582"/><path d="M16 31Q8 9 29 6Q48 3 49 29L43 30L39 17L23 21L22 33z" fill="${hair}"/><path d="M25 30H29M36 29H40" stroke="#615b43" stroke-width="1.5"/><path d="M29 39H36" stroke="#957657" fill="none"/>${person.id === 'zhou' ? '<path d="M24 37Q32 43 40 36" stroke="#a9a889" stroke-width="3" fill="none"/>' : ''}${person.id === 'shen' ? '<path d="M20 50L23 72H43L42 51" fill="#a99063"/>' : ''}</svg></span>`;
}

function renderPeople() {
  $('#people').innerHTML = PEOPLE.map(p => `<button class="person-card ${state.selected === p.id ? 'active' : ''}" data-person="${p.id}" aria-pressed="${state.selected === p.id}">${portrait(p)}<span><span class="person-name">${p.name}</span><span class="person-role">${p.role}</span></span><i class="person-indicator"></i></button>`).join('');
  $$('.person-hotspot').forEach(button => { button.classList.toggle('active', button.dataset.person === state.selected); button.setAttribute('aria-pressed', button.dataset.person === state.selected); });
}

function renderJournal() {
  const ids = state.log.map(e => `${e.id}:${e.enhanced ? '1' : '0'}`).join(',');
  if (lastLogIds === ids) return;
  lastLogIds = ids;
  const journal = $('#journal');
  const nearBottom = journal.scrollHeight - journal.scrollTop - journal.clientHeight < 65;
  journal.innerHTML = state.log.slice(-65).map(entry => {
    if (entry.type === 'world') return `<div class="log-entry world"><time>${time(entry.minute)}</time>${esc(entry.text)}</div>`;
    if (entry.type === 'player') return `<div class="log-entry player">${esc(entry.text)}<span>你 → ${esc(personName(entry.target))}</span></div>`;
    return `<article class="log-entry"><div class="entry-heading"><strong>${esc(personName(entry.actor))}</strong><time>${time(entry.minute)}</time>${entry.target && entry.target !== 'world' ? `<small>对${esc(personName(entry.target))}</small>` : '<small>独自片刻</small>'}${entry.traceId ? `<button class="trace-link" data-trace="${entry.traceId}">这一刻的因果 ↗</button>` : ''}</div>${entry.dialogue ? `<p class="dialogue">“${esc(entry.dialogue)}”</p>` : ''}<p class="stage-direction">${esc(entry.action)} ${esc(entry.expression)}</p></article>`;
  }).join('');
  if (nearBottom || state.log.at(-1)?.target === 'player') journal.scrollTop = journal.scrollHeight;
}

function renderHeart(npc) {
  const body = npc.body.fatigue > 65 ? '疲惫积在肩上' : npc.body.hunger > 60 ? '有些饿了' : '还有余力过这一晚';
  const rel = npc.relationships.player;
  const tiers = ['latent', 'activated', 'focused', 'flooded'];
  return `<div class="note-label">此刻的情绪</div><div class="emotion-row"><span class="emotion-pill">${EMOTIONS[npc.emotion]}</span><span class="body-state">${body}</span></div><div class="note-label">始终存在的缺口</div>${Object.entries(npc.anchors).map(([id, anchor]) => `<div class="anchor-item"><div class="anchor-heading"><strong>${ANCHORS[id].name}</strong><span class="gradient-label ${anchor.gradient}">${GRADIENTS[anchor.gradient]}</span></div><div class="anchor-dots ${anchor.gradient}" aria-label="${GRADIENTS[anchor.gradient]}">${tiers.map((_, i) => `<span class="${i <= tiers.indexOf(anchor.gradient) ? 'on' : ''}"></span>`).join('')}</div><p>${id === npc.attention.focus ? '此刻牵着注意力 · ' : '留在心底 · '}${ANCHORS[id].counter}</p></div>`).join('')}<div class="relationship-card"><h3>你们之间</h3><p>${rel.unfinished ? '那次离开或拒绝还留着回声。靠近时，多了一点迟疑。' : rel.safeEncounters >= 3 ? '一些安静的相处被记住了。仍有顾虑，但偶尔可以不用逞强。' : '你还是一个可以随时离开的人。此刻坐在这里，已经带来一点变化。'}</p>${Object.entries(npc.relationships).filter(([id]) => id !== 'player').map(([id, r]) => `<div class="rel-person"><b>与${personName(id)}</b><span>${r.unfinished ? '话里留了刺' : r.safeEncounters > 1 ? '习惯了彼此在场' : '同在一盏灯下'}</span></div>`).join('')}</div><div class="narrative">“${esc(npc.narrative)}”<small>他对自己的解释，不一定是全部。</small></div>`;
}

function renderMemory(npc) {
  if (!npc.memories.length) return '<p class="empty-note">有些片刻还没有变成记忆。<br>先坐一会儿吧。</p>';
  return `<div class="note-label">记住的，不一定是发生过的全部</div>${[...npc.memories].reverse().slice(0, 8).map(m => `<div class="memory-item"><small>${time(m.minute)} · ${esc(personName(m.actor))}${m.role === 'user' ? '说过 / 做过' : '留下的片刻'}</small><p>${esc(m.content)}</p><em>${esc(m.recalled ?? (m.weight > 0.75 ? '这个片刻留下了较深的痕迹。' : '想起来时，仍留着一点温度。'))}</em></div>`).join('')}`;
}

function renderTrace(npc) {
  const trace = state.traces.find(t => t.id === pinnedTrace && t.npc === npc.id) ?? [...state.traces].reverse().find(t => t.npc === npc.id);
  if (!trace) return '<p class="empty-note">一句话之后，可以在这里看见它怎样触动了一个人。<br>也可以什么都不说，看看他自己会做什么。</p>';
  const structure = trace.structure;
  return `<div class="note-label">${time(trace.minute)} · 这一刻为何发生</div><div class="trace-block"><h4>01 / 被感知的事</h4><p>${esc(personName(trace.event.actor))}：${esc(trace.event.content || EVENTS[trace.event.id]?.label)}</p>${trace.event.certainty === 'uncertain' ? '<p>含义未定，留在歧义池中。</p>' : ''}</div><div class="trace-arrow">↓</div><div class="trace-block"><h4>02 / 被牵动的缺口</h4><div class="trace-tags">${Object.entries(trace.activated).filter(([, g]) => g !== 'latent').map(([id, g]) => `<span>${ANCHORS[id]?.name ?? esc(id)} · ${GRADIENTS[g]}</span>`).join('') || '<span>缺口留在背景，日常接管</span>'}</div><p>${trace.distortions.map(esc).join('；')}</p></div><div class="trace-arrow">↓</div><div class="trace-block"><h4>03 / 熟悉的应对</h4><p>${esc(structure.defenses.join('、') || '习惯里的小动作')}<br>${esc(structure.pattern)}</p></div><div class="trace-summary">${esc(structure.contradiction)}</div>${trace.soothing.channel ? `<div class="trace-block"><h4>这次靠近留下什么</h4><p>${trace.soothing.count <= 1 ? '这次安抚暂时松动了张力。' : '同一安抚通道已重复，换一种说法也不会重新开始。'}${trace.soothing.factor < 0.3 ? '话依然听见了，缓解却已经很有限。' : ''}</p></div>` : ''}<div class="trace-block"><h4>04 / 说出口与没说出口</h4><p>${esc(structure.pull)}；${esc(structure.counter_pull)}。</p></div><details class="trace-details"><summary>查看完整心理记录</summary><pre>${esc(JSON.stringify(trace, null, 2))}</pre></details>`;
}

function renderNotebook() {
  const person = PEOPLE.find(p => p.id === state.selected);
  const npc = state.npcs[state.selected];
  $('#person-profile').innerHTML = `<div class="profile-top">${portrait(person)}<div><h2>${person.name}</h2><span>${person.age} · ${person.role}</span></div></div><p class="profile-intro">${person.intro}</p>`;
  $$('.notebook-tabs button').forEach(button => { button.classList.toggle('active', button.dataset.tab === tab); button.setAttribute('aria-selected', button.dataset.tab === tab); });
  const content = $('#notebook-content');
  content.setAttribute('aria-labelledby', `tab-${tab}`);
  const wasOpen = $('.trace-details')?.open;
  content.innerHTML = tab === 'heart' ? renderHeart(npc) : tab === 'memory' ? renderMemory(npc) : renderTrace(npc);
  if (wasOpen && $('.trace-details')) $('.trace-details').open = true;
}

function render() {
  renderPeople(); renderJournal(); renderNotebook();
  $('#clock').textContent = time(state.minute);
  $('#weather').textContent = `第 ${Math.floor((state.minute + 1080) / 1440) + 1} 夜 · ${state.weather}`;
  $('#target-name').textContent = personName(state.selected);
  $('#scene').classList.toggle('away', !state.present);
  $('#presence-label').textContent = state.present ? '你在酒馆里' : '你在檐下旁观';
  $('#world-status').textContent = state.paused ? '这一刻，暂且停留' : state.present ? '这一晚正在继续' : '门内的生活仍在继续';
  $('#pause-button').textContent = state.paused ? '▷ 继续' : 'Ⅱ 暂停';
  $('#pause-button').setAttribute('aria-pressed', state.paused);
  $('#leave-button').innerHTML = state.present ? '去檐下走走 <span>↗</span>' : '推门回去 <span>↙</span>';
  $('#action-note').textContent = state.present ? '一句话，也是一阵涟漪' : '隔着窗，看看他们的生活';
  $('#scene-caption span').textContent = state.present ? '雨落在屋檐上，也落在没有说出口的话里。' : '你暂时离开了他们的视线。灯下的故事没有停止。';
  $('#choices').innerHTML = ACTIONS.map(id => `<button class="choice" data-action="${id}" ${!state.present || busy ? 'disabled' : ''}>${EVENTS[id].label}</button>`).join('');
  $('#dialogue-input').disabled = !state.present || busy;
  $('#dialogue-form button').disabled = !state.present || busy;
  $('#leave-button').disabled = busy;
  $('#input-note').textContent = state.present ? '不确定的话会被留在心里，不会被当成已经发生的事。' : '先推门回来，才能继续交谈。你也可以静坐五分钟，继续旁观。';
}

async function interact(action, text) {
  if (busy) return;
  try {
    const trace = act(state, state.selected, action, text);
    pinnedTrace = null;
    save(); render();
    $('#journal').scrollTop = $('#journal').scrollHeight;
    if (modelEnabled && trace.output.dialogue) {
      busy = true; render();
      const currentState = state;
      try {
        const response = await fetch('/api/expression', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(expressionInput(state.npcs[trace.npc], trace.structure, trace.output)), signal: AbortSignal.timeout(14000) });
        if (response.ok) {
          const result = await response.json();
          if (state === currentState && result.dialogue && result.validated) {
            const entry = state.log.find(item => item.traceId === trace.id);
            if (entry) { entry.dialogue = result.dialogue; entry.enhanced = true; }
            // Rephrasing has no write access to psychological state or memory.
          }
        }
      } catch { /* The already-visible local expression is the bounded fallback. */ }
      finally { busy = false; save(); render(); }
    }
  } catch (error) { toast(error.message); }
}

document.addEventListener('click', event => {
  const person = event.target.closest('[data-person]');
  if (person) { state.selected = person.dataset.person; pinnedTrace = null; render(); save(); }
  const action = event.target.closest('[data-action]');
  if (action) interact(action.dataset.action);
  const trace = event.target.closest('[data-trace]');
  if (trace) {
    pinnedTrace = Number(trace.dataset.trace); const record = state.traces.find(t => t.id === pinnedTrace);
    if (record) { state.selected = record.npc; tab = 'trace'; render(); if (innerWidth < 720) $('.notebook').scrollIntoView({ behavior: 'smooth' }); }
  }
  const tabButton = event.target.closest('[data-tab]');
  if (tabButton) { tab = tabButton.dataset.tab; pinnedTrace = null; renderNotebook(); }
  if (event.target.closest('[data-close]')) event.target.closest('dialog').close();
});
$('.notebook-tabs').addEventListener('keydown', event => {
  if (!['ArrowLeft', 'ArrowRight', 'Home', 'End'].includes(event.key)) return;
  event.preventDefault();
  const tabs = ['heart', 'memory', 'trace'];
  const next = event.key === 'Home' ? 0 : event.key === 'End' ? 2 : (tabs.indexOf(tab) + (event.key === 'ArrowRight' ? 1 : 2)) % 3;
  tab = tabs[next]; renderNotebook(); $(`#tab-${tab}`).focus();
});
$('#dialogue-form').addEventListener('submit', event => { event.preventDefault(); const input = $('#dialogue-input'); const text = input.value.trim(); if (text && !busy) { input.value = ''; interact('text', text); } });
$('#pause-button').addEventListener('click', () => { state.paused = !state.paused; state.updatedAt = Date.now(); lastTick = Date.now(); render(); save(); });
$('#wait-button').addEventListener('click', () => { advance(state, 5); pinnedTrace = null; render(); save(); toast('炉火轻响，五分钟过去了。'); });
$('#leave-button').addEventListener('click', () => interact(state.present ? 'leaving' : 'return'));
$('#view-toggle').addEventListener('click', () => { const hidden = $('#scene-caption').hidden = !$('#scene-caption').hidden; $$('.person-hotspot').forEach(element => element.hidden = hidden); $('#view-toggle span').textContent = hidden ? '看见彼此' : '看见日常'; });
$('#help-button').addEventListener('click', () => $('#help-dialog').showModal());
$('#settings-button').addEventListener('click', () => { $('#reset-confirm').hidden = true; $('#settings-dialog').showModal(); });

function download(data, name) { const url = URL.createObjectURL(new Blob([data], { type: 'application/json;charset=utf-8' })); const a = document.createElement('a'); a.href = url; a.download = name; a.click(); setTimeout(() => URL.revokeObjectURL(url), 1000); }
$('#export-button').addEventListener('click', () => { download(serialize(state), `雨停之前-第${state.minute}分钟.json`); toast('这一晚已打包成存档。'); });
$('#trace-export-button').addEventListener('click', () => download(JSON.stringify({ version: 1, traces: state.traces }, null, 2), '雨停之前-心理因果.json'));
$('#import-button').addEventListener('click', () => $('#import-file').click());
$('#import-file').addEventListener('change', async event => {
  const file = event.target.files[0]; if (!file) return;
  try { if (file.size > 5 * 1024 * 1024) throw new Error('存档文件过大'); const loaded = restore(await file.text()); loaded.updatedAt = Date.now(); state = loaded; lastLogIds = ''; pinnedTrace = null; lastTick = Date.now(); save(); render(); $('#settings-dialog').close(); toast('这一晚，又接上了。'); }
  catch (error) { toast(`未载入：${error.message}`); }
  event.target.value = '';
});
$('#reset-button').addEventListener('click', () => { $('#reset-confirm').hidden = false; });
$('#reset-no').addEventListener('click', () => { $('#reset-confirm').hidden = true; });
$('#reset-yes').addEventListener('click', () => { state = createGame(); lastLogIds = ''; pinnedTrace = null; tab = 'heart'; lastTick = Date.now(); render(); save(); $('#settings-dialog').close(); toast('傍晚六点。你重新推开了门。'); });

async function toggleSound() {
  try {
    if (!sound) {
      const context = new AudioContext();
      const buffer = context.createBuffer(1, context.sampleRate * 4, context.sampleRate);
      const values = buffer.getChannelData(0);
      for (let i = 0; i < values.length; i++) values[i] = Math.random() * 2 - 1;
      const source = context.createBufferSource(); source.buffer = buffer; source.loop = true;
      const low = context.createBiquadFilter(); low.type = 'lowpass'; low.frequency.value = 1600;
      const high = context.createBiquadFilter(); high.type = 'highpass'; high.frequency.value = 350;
      const gain = context.createGain(); gain.gain.value = 0;
      source.connect(low).connect(high).connect(gain).connect(context.destination); source.start();
      sound = { context, gain };
    }
    await sound.context.resume(); soundEnabled = !soundEnabled;
    sound.gain.gain.setTargetAtTime(soundEnabled ? 0.11 : 0, sound.context.currentTime, 0.4);
    $('#sound-button span').textContent = soundEnabled ? '开' : '关';
    $('#sound-button').setAttribute('aria-label', soundEnabled ? '关闭雨声' : '开启雨声');
    $('#sound-button').title = soundEnabled ? '关闭雨声' : '开启雨声';
  } catch { toast('当前浏览器无法播放雨声。'); }
}
$('#sound-button').addEventListener('click', toggleSound);
$('#settings-sound').addEventListener('click', toggleSound);

setInterval(() => {
  // A hidden tab catches up from its last visible moment, even when timers are throttled.
  if (document.hidden) return;
  if (state.paused || busy || document.querySelector('dialog[open]')) { lastTick = Date.now(); state.updatedAt = lastTick; return; }
  const elapsed = Math.min(180, Math.floor((Date.now() - lastTick) / 10000));
  if (elapsed > 0) { advance(state, elapsed); lastTick = Date.now(); render(); save(); }
}, 1000);
document.addEventListener('visibilitychange', () => {
  if (document.hidden) { state.updatedAt = Date.now(); save(); }
  else { catchUp(state); lastTick = Date.now(); render(); save(); }
});
window.addEventListener('pagehide', () => { state.updatedAt = Date.now(); save(); });

render();
save();
$('#journal').scrollTop = $('#journal').scrollHeight;
if (loadError) toast('旧存档无法读取，已进入新的一晚。');
fetch('/api/config').then(r => r.json()).then(config => { modelEnabled = Boolean(config.expressionEnabled); $('#expression-mode').textContent = modelEnabled ? '模型润色 · 心理引擎主导' : '本地叙事'; $('#settings-model').textContent = modelEnabled ? '模型只润色台词，行为由心理引擎确定' : '本地确定性叙事，无需联网'; }).catch(() => {});
