extends SceneTree
const Psychology = preload("res://scripts/psychology.gd")
var failures = 0
var rows: Array = []

func _initialize() -> void:
	call_deferred("run")

func verify(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
	print("PASS " if ok else "FAIL ", label)

func run() -> void:
	var evenings: Array = []
	for seed_value in range(1, 11):
		var e = Psychology.new()
		e.new_game(seed_value)
		var first = e.act("shen", "company")
		e.advance(8, false)
		var rebound = e.state.npcs.shen.life.history.filter(func(item): return item.kind == "rebound")
		verify(not rebound.is_empty(), "night %d reassurance shifts into shame" % seed_value)
		for action in ["company", "tea", "reassure"]:
			for repetition in range(10):
				first = e.act("shen", action)
		verify(first.soothing.factor < 0.01 and "推回去" in first.output.action, "night %d repeated reassurance produces refusal" % seed_value)
		e.act("shen", "leaving")
		var snapshot = e.state.log.size()
		e.advance(10, false)
		var life_events = e.state.log.slice(snapshot).filter(func(item): return item.kind == "life")
		verify(life_events.size() >= 3, "night %d life visible without player" % seed_value)
		var text = JSON.stringify(life_events)
		evenings.append(text)
		e.act("shen", "return")
		for id in ["shen", "lin", "zhou"]:
			for repetition in range(4):
				e.act(id, "reject")
		e.act("shen", "leaving")
		e.advance(30, false)
		var repeats = 0
		var regrets = 0
		var ordinary = 0
		for n in e.state.npcs.values():
			repeats += n.life.repetitions
			for event in n.life.history:
				regrets += int(event.kind == "regret")
				ordinary += int(event.kind in ["ordinary", "eat", "rest", "create"])
		verify(repeats > 0 and regrets > 0 and ordinary > 0, "night %d regression and regret coexist with ordinary life" % seed_value)
		rows.append("| %d | 陪伴后等待8分钟；三种安抚各10次；离开10分钟；回来冷淡拒绝三人各4次，再离开观察30分钟 | 转移%d次；离场生活%d条；旧应对%d次；后悔%d次；日常%d条 | %s |" % [seed_value, rebound.size(), life_events.size(), repeats, regrets, ordinary, "；".join(life_events.slice(0, 2).map(func(item): return item.text))])
	verify(evenings[0] != evenings[1], "different nights vary without changing lack mechanics")
	var file = FileAccess.open("res://../artifacts/life-playthrough.md", FileAccess.WRITE)
	file.store_string("# 实际操作记录\n\n以下是10个不同夜晚按实际交互入口产生的行为记录；不是玩家主观体验评分。是否令人惊讶仍需你亲自试玩。\n\n| 夜晚 | 操作 | 实际观察 | 离场后片段 |\n|---|---|---|---|\n" + "\n".join(rows))
	file.close()
	print("LIFE_RESULT failures=", failures)
	quit(1 if failures else 0)
