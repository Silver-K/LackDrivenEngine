extends RefCounted
## Native deterministic psychology. LLM never owns state transitions.

var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world.json"))
var story: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/story.json"))
var state: Dictionary = {}
var last_spoken_minute: int = -10
var life = preload("res://scripts/life.gd").new()
const DIMENSIONS = ["缺失感", "羞耻", "恐惧", "怨恨", "欲望", "义务"]
const GRADIENTS = ["latent", "activated", "focused", "flooded"]

func _init() -> void:
	# He was an adult when Wanqing left twenty-five years ago.
	data.PEOPLE[0].age = "四十九岁"
	new_game()

func new_game(seed_value: int = -1) -> void:
	last_spoken_minute = -10
	state = {"version": 2, "minute": 0, "present": true, "paused": false, "selected": "shen", "started": false, "npcs": {}, "log": [], "traces": [], "ambiguity": [], "objects": [], "fragments": [], "topics": {}, "player_response": "", "next_id": 1, "saved_at": Time.get_unix_time_from_system()}
	for person in data.PEOPLE:
		var anchors: Dictionary = {}
		for i in range(person.anchors.size()):
			var id: String = person.anchors[i]
			var spec: Dictionary = data.ANCHORS[id]
			var dimensions: Dictionary = {}
			var floors: Dictionary = {}
			var baselines: Dictionary = {}
			var offsets = [0, -7, -3, -24, 4, -20]
			for j in range(DIMENSIONS.size()):
				dimensions[DIMENSIONS[j]] = maxf(10, float(person.values[i]) + offsets[j])
				floors[DIMENSIONS[j]] = maxf(5, spec.floor - j * 2)
				baselines[DIMENSIONS[j]] = maxf(floors[DIMENSIONS[j]], spec.baseline + offsets[j])
			anchors[id] = {"dimensions": dimensions, "floor": floors, "baseline": baselines, "gradient": "latent", "dimension_gradients": {}}
		var relationships: Dictionary = {}
		for target in ["player", "shen", "lin", "zhou"]:
			if target != person.id:
				relationships[target] = {"channels": {}, "safe": 0, "last_safe": -99, "old_count": 8.0, "new_count": 0.0, "security": 0.25, "trust": 0.35, "unfinished": "", "last_hurt": -99}
		state.npcs[person.id] = {"id": person.id, "anchors": anchors, "focus": person.habit, "background": [], "inhibited": [], "emotion": "calm", "emotion_since": 0, "fatigue": 20.0, "hunger": 18.0, "relationships": relationships, "memories": [], "behavior": "routine", "count": 0, "narrative": person.narrative}
		attention(state.npcs[person.id], {})
	state.life_seed = seed_value if seed_value > 0 else int(Time.get_ticks_usec()) % 2147483646 + 1
	life.ensure(self)
	log_event("world", "你推开雨停酒馆的门。信封被雨水打湿，沈砚看见上面的字，手里的杯子停住了。")
	log_event("npc", story.characters.shen.opening, "shen", "他拉开吧台边的椅子，却没有伸手接那只信封。", "开场")

func person(id: String) -> Dictionary:
	for p in data.PEOPLE:
		if p.id == id:
			return p
	return {}

func log_event(kind: String, text: String, actor: String = "world", action: String = "", source: String = "") -> Dictionary:
	var entry = {"id": state.next_id, "minute": state.minute, "kind": kind, "text": text, "actor": actor, "action": action, "source": source}
	state.next_id += 1
	state.log.append(entry)
	if state.log.size() > 160:
		state.log.pop_front()
	return entry

func _raise(anchor: Dictionary, dim: String, amount: float) -> void:
	anchor.dimensions[dim] = clampf(anchor.dimensions[dim] + amount, anchor.floor[dim], 100)

func _strength(anchor: Dictionary) -> float:
	return maxf(anchor.dimensions["缺失感"], maxf(anchor.dimensions["恐惧"], anchor.dimensions["羞耻"]))

func attention(npc: Dictionary, impacts: Dictionary) -> void:
	var threshold: float = 43 if npc.fatigue > 65 else 50
	var focus: String = ""
	for id in npc.anchors:
		if impacts.get(id, 0) > 0 and _strength(npc.anchors[id]) >= threshold:
			focus = id
			break
	if focus.is_empty() and npc.anchors.has(npc.focus) and _strength(npc.anchors[npc.focus]) >= threshold:
		focus = npc.focus
	if focus.is_empty():
		for id in npc.anchors:
			if _strength(npc.anchors[id]) >= threshold:
				focus = id
				break
	if state.minute % 9 == 0 and impacts.is_empty():
		var quiet = true
		for a in npc.anchors.values():
			if _strength(a) >= 70:
				quiet = false
		if quiet:
			focus = ""
	npc.focus = focus
	npc.background = []
	npc.inhibited = []
	for id in npc.anchors:
		var a: Dictionary = npc.anchors[id]
		var flooded = false
		for dim in DIMENSIONS:
			var value: float = a.dimensions[dim]
			a.dimension_gradients[dim] = "flooded" if value >= 90 else "focused" if value >= 70 and id == focus else "activated" if value >= threshold else "latent"
			flooded = flooded or value >= 90
		a.gradient = "flooded" if flooded else "focused" if id == focus and _strength(a) >= 70 else "activated" if _strength(a) >= threshold else "latent"
		if id != focus:
			if not focus.is_empty() and npc.anchors[focus].dimensions["恐惧"] >= 78 and id == "pride":
				npc.inhibited.append(id)
			else:
				npc.background.append(id)

func emotion(npc: Dictionary) -> void:
	var flooded = false
	var high = 0
	var sensitive = false
	for a in npc.anchors.values():
		flooded = flooded or a.gradient == "flooded"
		high += int(_strength(a) >= 70)
		sensitive = sensitive or _strength(a) >= 62
	var elapsed: int = state.minute - npc.emotion_since
	var next: String = npc.emotion
	if next == "flooded" and elapsed >= 3:
		next = "numb"
	elif next == "numb":
		if elapsed >= 6 and not flooded and npc.fatigue < 65:
			next = "calm"
	elif flooded or (next == "reactive" and high >= 2):
		next = "flooded"
	elif next == "calm" and (sensitive or npc.fatigue >= 68):
		next = "reactive"
	elif next == "reactive" and elapsed >= 4 and not sensitive and npc.fatigue < 65:
		next = "calm"
	if next != npc.emotion:
		npc.emotion = next
		npc.emotion_since = state.minute

func parse_input(text: String) -> String:
	for marker in ["可能", "也许", "如果", "或许", "不一定", "不想离开", "不是说要走"]:
		if marker in text:
			return "ambiguous"
	for marker in ["不走", "不会走", "不离开", "不会离开"]:
		if marker in text:
			return "company"
	var candidates: Array = []
	for id in data.EVENTS:
		for pattern in data.EVENTS[id].patterns:
			if pattern in text:
				candidates.append(id)
				break
	return candidates[0] if candidates.size() == 1 else "ambiguous"

func act(target: String, action: String, text: String = "") -> Dictionary:
	if not state.present and action != "return":
		return {}
	var event_id = parse_input(text) if action == "text" else action
	if not data.EVENTS.has(event_id):
		return {}
	var event: Dictionary = data.EVENTS[event_id].duplicate(true)
	event.id = event_id
	event.actor = "player"
	event.content = text if not text.is_empty() else event.get("text", event.label)
	if event_id == "ambiguous":
		state.ambiguity.append({"minute": state.minute, "text": text, "target": target})
	if event_id == "leaving":
		state.present = false
	elif event_id == "return":
		state.present = true
	var player_entry = log_event("player", event.content, "player")
	player_entry.recipient = target
	last_spoken_minute = int(state.minute)
	var result = react(target, event)
	if event_id in ["leaving", "return"]:
		for id in state.npcs:
			if id != target:
				react(id, event, false)
		log_event("world", "你走到檐下，门内的生活继续。" if not state.present else "门铃再响了一次。你把伞放回门边。")
	return result

func react(target: String, event: Dictionary, visible: bool = true) -> Dictionary:
	var npc: Dictionary = state.npcs[target]
	var rel: Dictionary = npc.relationships.get(event.actor, npc.relationships.player)
	var soothing = {"factor": 1.0, "count": 0, "channel": event.get("channel", "")}
	if event.has("channel") and npc.relationships.has(event.actor):
		if not rel.channels.has(event.channel):
			rel.channels[event.channel] = {"count": 0, "last": state.minute, "shame": 0, "dependency": 0, "fear": 0}
		var channel: Dictionary = rel.channels[event.channel]
		if state.minute - channel.last > 90:
			channel.count = maxi(0, channel.count - 1)
		soothing.factor = pow(0.68 if rel.security < 0.4 else 0.8, channel.count)
		if state.minute - rel.last_hurt < 8:
			soothing.factor *= 0.5
		channel.count += 1
		channel.last = state.minute
		channel.shame = mini(30, channel.shame + int(channel.count > 2) * 2)
		channel.dependency = mini(40, channel.dependency + 2)
		channel.fear = mini(50, channel.fear + 1)
		soothing.count = channel.count
		life.soothing(self, npc, event.actor, channel.count)
		if state.minute - rel.last_safe >= 5 and state.minute - rel.last_hurt >= 8:
			rel.safe += 1
			rel.last_safe = state.minute
			rel.new_count += 1
			rel.security = minf(0.75, rel.security + 0.025)
			rel.trust = minf(0.85, rel.trust + 0.025)
	var recalled: String = ""
	for i in range(npc.memories.size() - 1, -1, -1):
		var memory: Dictionary = npc.memories[i]
		if memory.actor == event.actor and memory.event == event.id:
			recalled = "重新想起"
			for a in npc.anchors.values():
				if a.dimensions["恐惧"] >= 65:
					recalled = "闪回：离别的细节变得清晰"
					memory.weight = minf(1, memory.weight + 0.05)
				elif a.dimensions["羞耻"] >= 65:
					recalled = "压抑：避开最难堪的细节"
			memory.distortions.append(recalled)
			if memory.distortions.size() > 8:
				memory.distortions.pop_front()
			break
	var changes: Dictionary = {}
	var distortions: Array = []
	for id in npc.anchors:
		var anchor: Dictionary = npc.anchors[id]
		var impact: float = event.impacts.get(id, 0)
		var actual: float = impact * (soothing.factor if impact < 0 else 1.18 if npc.fatigue > 65 else 1.0)
		var before: float = anchor.dimensions["缺失感"]
		_raise(anchor, "缺失感", actual)
		_raise(anchor, "恐惧", actual * 0.8)
		if "exposure" in event.tags:
			_raise(anchor, "羞耻", maxf(0, impact) * 0.7)
		if "rejection" in event.tags:
			_raise(anchor, "怨恨", maxf(0, impact) * 0.4)
		if soothing.count > 2 and soothing.count < 18:
			_raise(anchor, "羞耻", 1.2)
		if "ambiguous" in event.tags and anchor.dimensions["恐惧"] >= 55 and npc.emotion != "numb":
			_raise(anchor, "恐惧", 5)
			distortions.append("把尚未确定的话读成疏远")
		changes[id] = anchor.dimensions["缺失感"] - before
	if "rejection" in event.tags or "departure" in event.tags:
		rel.unfinished = event.content
		rel.last_hurt = state.minute
	if "return" in event.tags:
		rel.unfinished = ""
	if event.id in ["tea", "npc_care"]:
		npc.fatigue = maxf(0, npc.fatigue - 4)
	attention(npc, event.impacts)
	emotion(npc)
	var structure: Dictionary = compose(npc, event, rel, recalled)
	if soothing.count >= 6:
		structure.behavior = "approach_avoid"
		structure.counter_pull = "不愿被照顾变成欠债，想把对方推开一点"
		structure.contradiction = "仍需要陪伴，却因反复安抚感到被怜悯，开始拒绝"
	var output: Dictionary = express(npc, structure, event)
	if soothing.count >= 6:
		output.action = "把递来的东西推回去，却没有把旁边的椅子收走。"
	npc.behavior = structure.behavior
	npc.count += 1
	if structure.behavior == "please" and not npc.focus.is_empty():
		_raise(npc.anchors[npc.focus], "羞耻", 2)
		rel.old_count = minf(30, rel.old_count + 0.1)
	if structure.behavior in ["create", "humor"] and not npc.focus.is_empty():
		_raise(npc.anchors[npc.focus], "缺失感", -3)
	if event.actor != "world" or structure.behavior == "create" or event.id == "letter":
		npc.memories.append({"actor": event.actor, "role": "user" if event.actor == "player" else "system" if event.actor == "world" else "assistant", "event": event.id, "minute": state.minute, "content": event.content, "observed_action": output.action, "weight": 0.85 if "exposure" in event.tags else 0.55, "distortions": []})
		if npc.memories.size() > 48:
			npc.memories.pop_front()
	var trace = {"id": state.next_id, "npc": target, "minute": state.minute, "event": event.content, "event_id": event.id, "actor": event.actor, "focus": npc.focus, "structure": structure, "soothing": soothing, "changes": changes, "distortions": distortions, "output": output, "fragment": "", "context": event.content}
	state.next_id += 1
	state.traces.append(trace)
	if state.traces.size() > 180:
		state.traces.pop_front()
	if visible:
		publish_trace(trace)
	return trace

func publish_trace(trace: Dictionary) -> void:
	var entry = log_event("npc", "", trace.npc, trace.output.action, "等待表达")
	entry.recipient = trace.actor
	entry.trace_id = trace.id
	trace.entry_id = entry.id

func fallback_dialogue(trace: Dictionary) -> String:
	# A failed expression must not introduce a different conversational claim.
	if not trace.fragment.is_empty():
		return story.fragments[trace.fragment].quote
	return ""

func compose(npc: Dictionary, event: Dictionary, rel: Dictionary, recalled: String) -> Dictionary:
	var active = 0
	var vulnerable = false
	for a in npc.anchors.values():
		active += int(a.gradient != "latent")
		vulnerable = vulnerable or a.dimensions["恐惧"] >= 50
	var stress: bool = npc.emotion in ["flooded", "numb"] or npc.fatigue > 72
	var new_familiarity: float = rel.new_count * 0.6
	var inhibition: float = new_familiarity / (new_familiarity + rel.old_count * 0.8)
	var context = {"stress": stress, "alone": not state.present and event.actor == "world", "active": active > 0, "rested": npc.fatigue < 65, "learned": new_familiarity >= 1.8 and inhibition > 0.18, "safe": "safe" in event.tags, "ambiguous": "ambiguous" in event.tags, "vulnerable": vulnerable, "rejected": "rejection" in event.tags, "constrained": state.present, "exposed": "exposure" in event.tags, "secret": npc.anchors.has("secret"), "multiple": active >= 2}
	var selected: Array = []
	var tier = 999
	for op in data.OPERATORS:
		var matches = true
		for key in op.when:
			if context.get(key) != op.when[key]:
				matches = false
		if matches and op.tier <= tier:
			if op.tier < tier:
				selected.clear()
			tier = op.tier
			selected.append(op)
	var defenses: Array = []
	var operators: Array = []
	var contradictions: Array = []
	for op in selected:
		defenses.append(op.defense)
		operators.append(op.id)
		contradictions.append(op.contradiction)
	var behavior: String = selected[0].behavior if not selected.is_empty() else "routine"
	if npc.emotion == "numb":
		behavior = "evade"
	var anchor: Dictionary = data.ANCHORS.get(npc.focus, {})
	return {"pull": anchor.get("pull", "让日子平常地往下走"), "counter_pull": anchor.get("counter", "仍留着没有说出口的事"), "defenses": defenses, "operators": operators, "behavior": behavior, "contradiction": "；".join(contradictions) if not contradictions.is_empty() else "日常容纳缺口，没有填平它", "pattern": "压力下旧模式回归" if stress else "新经验暂时抑制旧模式" if context.learned and context.safe else "沿用熟悉模式", "history": recalled, "norm": "把直接需要藏进试探，把愤怒留给物件" if state.present else "不必维持待客的体面", "body": "疲惫" if npc.fatigue > 65 else "尚有余力"}

func express(npc: Dictionary, structure: Dictionary, event: Dictionary) -> Dictionary:
	var p: Dictionary = person(npc.id)
	var lines: Array = data.LINES[npc.id].get(structure.behavior, data.LINES[npc.id].routine)
	var text: String = lines[(npc.count + int(state.minute / 7)) % lines.size()]
	var actions = {"routine": p.routine[(npc.count + int(state.minute / 4)) % p.routine.size()], "approach_avoid": "把话说得疏远，却将身旁的椅子拉开了一点。", "indirect": "推来一只杯子，手还停在桌子另一侧。", "test": "看向门口，又悄悄移回视线。", "displace": "手上的动作重了一下，碰到杯沿时又放轻。", "evade": "手指收紧，话停在半途，却没有走开。", "please": "往前半步，又把伸出的手收回去。", "humor": "笑了一下，给沉默留出一点位置。", "create": p.creative}
	var action: String = actions[structure.behavior]
	if event.id in ["tea", "npc_care"]:
		action = "接过热茶，把杯子握在掌心。" + action
	if not state.present and event.actor == "world":
		text = ""
	return {"dialogue": text, "action": action, "expression": "目光有些失焦。" if npc.emotion == "numb" else "像有另一句话没有说出口。", "subtext": structure.contradiction}

func advance(minutes: int, allow_speech: bool = true) -> Array:
	var candidates: Array = []
	for _step in range(clampi(minutes, 0, 180)):
		state.minute += 1
		for npc in state.npcs.values():
			var sleeping: bool = int(18 + state.minute / 60) % 24 in [2, 3, 4, 5, 6]
			npc.fatigue = clampf(npc.fatigue + (-4 if sleeping else 0.25), 0, 100)
			npc.hunger = clampf(npc.hunger + 0.7, 0, 100)
			for anchor in npc.anchors.values():
				for dim in DIMENSIONS:
					_raise(anchor, dim, (anchor.baseline[dim] - anchor.dimensions[dim]) * 0.025 - (1.0 if sleeping else 0.0))
			for memory in npc.memories:
				memory.weight = maxf(0.1, memory.weight - 0.001)
			attention(npc, {})
			emotion(npc)
		candidates.append_array(life.tick(self))
		state.ambiguity = state.ambiguity.filter(func(e): return state.minute - e.minute < 12)
	if not allow_speech or candidates.is_empty() or state.minute - last_spoken_minute < 4:
		return []
	var chosen: Dictionary = candidates.back()
	# Off-screen solitary activity has no listener, but NPCs can address each other.
	if not state.present and chosen.actor == "world":
		return []
	publish_trace(chosen)
	last_spoken_minute = int(state.minute)
	return [chosen]

func inspect(object_id: String) -> Dictionary:
	if not story.objects.has(object_id) or not state.present:
		return {}
	if not object_id in state.objects:
		state.objects.append(object_id)
		log_event("discovery", story.objects[object_id].text, "world", "", story.objects[object_id].title)
	return story.objects[object_id]

func talk_about(target: String, object_id: String) -> Dictionary:
	if not object_id in state.objects:
		return {}
	var topic_key: String = target + "_" + object_id
	state.topics[topic_key] = int(state.topics.get(topic_key, 0)) + 1
	var title: String = story.objects[object_id].title
	var trace = act(target, "memory", "我想问问「" + title + "」。你记得什么？")
	if trace.is_empty():
		return trace
	var npc: Dictionary = state.npcs[target]
	var fragment: Dictionary = story.fragments.get(topic_key, {})
	var can_share: bool = not fragment.is_empty() and not topic_key in state.fragments
	# Disclosure is gated by relational room and current defenses, not a quest score.
	can_share = can_share and npc.emotion not in ["flooded", "numb"] and (npc.relationships.player.safe >= 1 or state.minute >= 8)
	if can_share:
		discover(topic_key)
		trace.fragment = topic_key
		trace.output.dialogue = fragment.quote
		trace.output.action = "低声说出这一段，手却仍搭在杯沿，像随时会停下来。"
		update_entry(trace, fragment.quote, "本地叙事")
	elif not fragment.is_empty() and not topic_key in state.fragments:
		trace.output.dialogue = "我记得。只是现在，先让我缓一会儿。"
		update_entry(trace, trace.output.dialogue, "本地叙事")
	elif topic_key in state.fragments:
		trace.fragment = topic_key
		trace.output.dialogue = fragment.quote
		update_entry(trace, fragment.quote, "本地叙事")
	else:
		trace.output.dialogue = "这件事我知道的不多。你可以问问别人，我不想替他们说。"
		update_entry(trace, trace.output.dialogue, "本地叙事")
	return trace

func discover(id: String) -> void:
	if id in state.fragments:
		return
	state.fragments.append(id)
	var fragment: Dictionary = story.fragments[id]
	log_event("discovery", fragment.echo, "world", "", fragment.title)

func can_open_letter() -> bool:
	return "shen_envelope" in state.fragments and "zhou_clock" in state.fragments

func open_letter() -> bool:
	if not can_open_letter() or "letter" in state.fragments:
		return false
	discover("letter")
	log_event("letter", story.fragments.letter.quote, "world", "", "晚晴留给知微的信")
	return true

func update_entry(trace: Dictionary, dialogue: String, source: String) -> void:
	for entry in state.log:
		if entry.id == trace.get("entry_id", -1):
			entry.text = dialogue
			entry.action = trace.output.action
			entry.source = source
			break

func model_input(trace: Dictionary) -> Dictionary:
	var npc: Dictionary = state.npcs[trace.npc]
	var known: Array = []
	for id in state.fragments:
		if story.fragments[id].npc == trace.npc or id == "letter":
			known.append(story.fragments[id].fact)
	var recent: Array = []
	for entry in state.log:
		if entry.id == trace.get("entry_id", -1):
			continue
		if entry.get("source", "") in ["等待表达", "正在回应"]:
			continue
		if entry.kind in ["player", "npc", "world", "discovery", "letter", "life"]:
			recent.append({"speaker": entry.actor, "recipient": entry.get("recipient", "scene"), "kind": entry.kind, "content": entry.text, "action": entry.action, "minute": entry.minute})
	recent = recent.slice(maxi(0, recent.size() - 20))
	var anchor_states: Dictionary = {}
	for id in npc.anchors:
		anchor_states[data.ANCHORS[id].name] = data.GRADIENTS[npc.anchors[id].gradient]
	return {"character": story.characters[trace.npc], "world": story.world, "player": story.player, "scene": {"minute": state.minute, "player_present": state.present, "characters": ["shen:沈砚", "lin:林遥", "zhou:周叔", "player:许知微"], "objects": state.objects, "player_response": state.player_response}, "trigger": {"actor": trace.actor, "event": trace.context, "recipient": trace.actor if trace.actor != "world" else "scene", "mode": "reply" if trace.actor == "player" else "social" if trace.actor != "world" else "spontaneous"}, "known_facts": known, "player_said": trace.context if trace.actor == "player" else "", "recent_dialogue": recent, "anchor_state": anchor_states, "contradiction": trace.structure, "observable": trace.output, "required_fact": story.fragments[trace.fragment].fact if not trace.fragment.is_empty() else "", "signature": story.fragments[trace.fragment].signature if not trace.fragment.is_empty() else ""}

func save_game(path: String = "user://evening.json") -> Error:
	state.saved_at = Time.get_unix_time_from_system()
	var file = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(state))
	file.close()
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(path, path + ".bak")
	return DirAccess.rename_absolute(path + ".tmp", path)

func load_game(path: String = "user://evening.json") -> bool:
	if not FileAccess.file_exists(path):
		return false
	var loaded = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not valid_save(loaded):
		return false
	state = loaded
	life.ensure(self)
	last_spoken_minute = int(state.minute)
	for entry in state.log:
		if entry.get("source", "") in ["等待表达", "正在回应"]:
			entry.text = ""
			entry.source = "动作 · 上次表达中断"
	state.minute = int(state.minute)
	state.next_id = int(state.next_id)
	for npc in state.npcs.values():
		npc.count = int(npc.count)
		npc.emotion_since = int(npc.emotion_since)
	if not state.paused and state.started:
		var elapsed: int = clampi(int((Time.get_unix_time_from_system() - state.saved_at) / 15.0), 0, 120)
		if elapsed > 0:
			var presence: bool = state.present
			state.present = false
			advance(elapsed, false)
			state.present = presence
			log_event("world", "你不在的这段时间，酒馆又度过了 %d 分钟。" % elapsed)
	return true

func valid_save(value: Variant) -> bool:
	if not value is Dictionary or value.get("version") != 2:
		return false
	for key in ["npcs", "log", "traces", "objects", "fragments", "topics", "minute", "next_id", "saved_at", "paused", "present", "selected", "started", "ambiguity"]:
		if not value.has(key):
			return false
	if not value.npcs is Dictionary or not value.log is Array or not value.traces is Array or not value.fragments is Array or not value.objects is Array:
		return false
	if not value.selected in ["shen", "lin", "zhou"] or not value.minute is float and not value.minute is int:
		return false
	for p in data.PEOPLE:
		if not value.npcs.has(p.id):
			return false
		var npc = value.npcs[p.id]
		for key in ["anchors", "relationships", "memories", "emotion", "emotion_since", "count", "focus", "fatigue", "hunger", "narrative"]:
			if not npc.has(key):
				return false
		for id in p.anchors:
			if not npc.anchors.has(id):
				return false
			for field in ["dimensions", "floor", "baseline"]:
				if not npc.anchors[id].has(field):
					return false
				for dim in DIMENSIONS:
					var n = npc.anchors[id][field].get(dim)
					if not (n is float or n is int) or not is_finite(float(n)) or n < 0 or n > 100:
						return false
	return true
