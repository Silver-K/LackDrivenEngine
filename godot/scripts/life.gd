extends RefCounted
## Situated impulses, not tasks: no success score, plan, or optimal next action.

func ensure(e) -> void:
	if not e.state.has("life_seed"):
		e.state.life_seed = int(Time.get_unix_time_from_system()) % 2147483647
	for n in e.state.npcs.values():
		if not n.has("life"):
			n.life = {"next": e.state.minute + 1 + roll(e, 4), "activity": "刚把手边的事放下", "place": "吧台" if n.id == "shen" else "窗边" if n.id == "lin" else "炉边", "rebound": [], "regret_at": -1, "repetitions": 0, "last_kind": "", "history": []}

func roll(e, count: int) -> int:
	e.state.life_seed = (int(e.state.life_seed) * 48271) % 2147483647
	return int(e.state.life_seed) % maxi(1, count)

func soothing(e, n: Dictionary, actor: String, count: int) -> void:
	ensure(e)
	if count == 1:
		n.life.rebound.append({"at": e.state.minute + 3 + roll(e, 4), "actor": actor})

func record(e, n: Dictionary, kind: String, text: String, cause: String) -> void:
	n.life.activity = text
	n.life.history.append({"minute": e.state.minute, "kind": kind, "text": text, "cause": cause})
	if n.life.history.size() > 24:
		n.life.history.pop_front()
	e.log_event("life", e.person(n.id).name + "：" + text, n.id, "", cause)

func tick(e) -> Array:
	ensure(e)
	var speech: Array = []
	for n in e.state.npcs.values():
		for pending in n.life.rebound.duplicate():
			if e.state.minute < pending.at:
				continue
			n.life.rebound.erase(pending)
			var anchor_id: String = "pride" if n.anchors.has("pride") else "freedom" if n.anchors.has("freedom") else "worth"
			if not n.anchors.has(anchor_id):
				anchor_id = n.anchors.keys()[0]
			e._raise(n.anchors[anchor_id], "羞耻", 9)
			e._raise(n.anchors[anchor_id], "恐惧", 6)
			record(e, n, "rebound", "肩膀刚松下来，又把别人替自己摆好的杯子挪回去。", "刚才的照顾让需要被看见，羞耻替代了短暂的轻松")
			n.life.next = mini(int(n.life.next), int(e.state.minute) + 1)
		if n.life.regret_at >= 0 and e.state.minute >= n.life.regret_at:
			n.life.regret_at = -1
			record(e, n, "regret", "看了一眼刚才碰响的杯子，轻轻扶正，却没把话收回来。", "旧应对留下后悔；熟悉感没有因此消失")
		if e.state.minute < n.life.next:
			continue
		n.life.next = e.state.minute + 2 + roll(e, 5)
		var anchor_id: String = n.focus if not str(n.focus).is_empty() else e.person(n.id).habit
		var pressure: float = e._strength(n.anchors[anchor_id])
		var kind = "ordinary"
		var text = ""
		var cause = "此刻张力容得下日常"
		if n.hunger > 48:
			kind = "eat"
			text = ["到炉边热了半碗饭，吃到一半望着窗外。", "掰了一块面包，站着吃了几口。 "][roll(e, 2)]
			n.hunger = maxf(0, n.hunger - 25)
			n.life.place = "炉边"
		elif n.fatigue > 66:
			kind = "rest"
			text = "挪到椅背旁歇了一会儿，手里的活没有做完。"
			n.fatigue = maxf(0, n.fatigue - 13)
		elif pressure > 61 and roll(e, 100) < 68:
			kind = "old_pattern"
			cause = e.data.ANCHORS[anchor_id].name + "被唤起；熟悉的应对先于反省"
			n.life.repetitions += 1
			n.life.regret_at = e.state.minute + 2 + roll(e, 3)
			text = {"shen": "又擦起早已干净的杯子，听见门响便停住，随后擦得更用力。", "lin": "把画册合上像要离开，手却一直压在留给别人的那张画上。", "zhou": "又去试那条已经修好的椅腿，别人没求他，他也没有停手。"}[n.id]
			e._raise(n.anchors[anchor_id], "羞耻", 2)
		else:
			var options: Array = e.person(n.id).routine.duplicate()
			options.append(e.person(n.id).creative)
			options.append("走到窗边看雨落在水沟里，忘了手里原本拿着什么。")
			text = options[roll(e, options.size())]
			if text == n.life.activity:
				text = "停下手里的事，安静听了一阵雨。"
			kind = "create" if text == e.person(n.id).creative else "ordinary"
			if kind == "create":
				e._raise(n.anchors[anchor_id], "缺失感", -2)
			n.life.place = ["窗边", "吧台", "炉边"][roll(e, 3)]
		n.life.last_kind = kind
		record(e, n, kind, text, cause)
		# Impulses meet other people; their response really changes their own anchors.
		if kind == "old_pattern" or (kind == "ordinary" and roll(e, 100) < 38):
			var others: Array = e.state.npcs.keys().filter(func(id): return id != n.id)
			var target: String = others[roll(e, others.size())]
			var eid = "npc_distance" if kind == "old_pattern" and n.id == "lin" else "npc_care"
			var event: Dictionary = e.data.EVENTS[eid].duplicate(true)
			var gesture = "避开了" + e.person(target).name + "的视线，把画册挪远一点，又没有起身。" if eid == "npc_distance" else "给" + e.person(target).name + "添了一点热茶，没等对方开口就把壶收回去。"
			event.merge({"id": eid, "actor": n.id, "content": e.person(n.id).name + gesture})
			var trace: Dictionary = e.react(target, event, false)
			record(e, e.state.npcs[target], "encounter", trace.output.action, "对方的靠近或退开触动了自己的缺口")
			if trace.soothing.count >= 6 or e.state.npcs[target].emotion == "numb":
				var rejection: Dictionary = e.data.EVENTS.reject.duplicate(true)
				rejection.merge({"id": "reject", "actor": target, "content": e.person(target).name + "没有接住这次好意。"})
				e.react(n.id, rejection, false)
				record(e, n, "rebuff", "把没被接过的杯子放回原处，过了一会儿仍朝那边看。", "好意落空加重了旧缺口，却没有教会自己立刻换一种办法")
			trace.output.action = event.content + trace.output.action
			speech.append(trace)
		else:
			var event: Dictionary = e.data.EVENTS.quiet.duplicate(true)
			event.merge({"id": "quiet", "actor": "world", "content": text})
			var trace: Dictionary = e.react(n.id, event, false)
			trace.output.action = text
			speech.append(trace)
	return speech
