extends SceneTree
const Psychology = preload("res://scripts/psychology.gd")
const Client = preload("res://scripts/llm_client.gd")
const Director = preload("res://scripts/expression_director.gd")
class RecordingClient:
	extends RefCounted
	var inputs: Array = []
	var fail: bool = false
	func generate(input: Dictionary) -> Dictionary:
		inputs.append(input)
		return {"ok": false, "error": "test unavailable"} if fail else {"ok": true, "dialogue": "这杯茶还有些烫，先放一会儿吧。", "model": "test"}
var failures = 0
var checks = 0

func check(condition: bool, name: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", name)
	else:
		print("PASS: ", name)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var engine = Psychology.new()
	var twin = Psychology.new()
	for e in [engine, twin]:
		e.new_game(42)
		e.act("shen", "memory")
		e.advance(12)
		e.act("lin", "text", "我可能要走")
		e.advance(9)
	engine.state.erase("saved_at")
	twin.state.erase("saved_at")
	check(JSON.stringify(engine.state) == JSON.stringify(twin.state), "same history remains deterministic")
	engine.new_game()
	var factors: Array = []
	for action in ["company", "tea", "reassure", "company", "tea", "reassure"]:
		factors.append(engine.act("shen", action).soothing.factor)
	check(factors[0] == 1.0 and factors[5] < 0.2, "cross-action soothing diminishes")
	check(engine.state.npcs.shen.relationships.player.safe == 1, "spam cannot buy growth")
	for i in range(120):
		engine.act("shen", "tea")
	var channel: Dictionary = engine.state.npcs.shen.relationships.player.channels.attachment_security
	check(channel.dependency <= 40 and channel.shame <= 30 and channel.fear <= 50, "side effects capped")
	engine.advance(180)
	var floors_ok = true
	for npc in engine.state.npcs.values():
		for anchor in npc.anchors.values():
			for dim in engine.DIMENSIONS:
				floors_ok = floors_ok and anchor.dimensions[dim] >= anchor.floor[dim]
	check(floors_ok, "lack never disappears below floor")
	engine.new_game()
	for text in ["我可能要走", "如果我离开", "我不想离开", "我不会离开"]:
		engine.act("shen", "text", text)
		check(engine.state.present, "ambiguous or negated leaving: " + text)
	engine.act("shen", "leaving")
	engine.advance(30)
	var creative = false
	var social = false
	for trace in engine.state.traces:
		creative = creative or trace.structure.behavior == "create"
		social = social or trace.actor in ["shen", "lin", "zhou"]
	check(creative and social, "NPC creative and social life continues when absent")
	engine.new_game()
	var npc: Dictionary = engine.state.npcs.shen
	for anchor in npc.anchors.values():
		for dim in engine.DIMENSIONS:
			anchor.dimensions[dim] = 60.0
	var trace: Dictionary = engine.act("shen", "memory")
	check(trace.structure.operators.size() >= 2, "same-tier contradiction retained")
	var input = engine.model_input(trace)
	check(not input.has("dimensions") and not input.has("soothing") and not input.has("score"), "model receives categorical structure only")
	var client = Client.new()
	root.add_child(client)
	check(client.is_official_endpoint("https://api.openai.com/v1"), "official endpoint permits environment credential")
	check(not client.is_official_endpoint("https://api.openai.com.example.test/v1") and not client.is_official_endpoint("https://api.openai.com@example.test/v1"), "lookalike endpoints cannot receive environment credential")
	check(client.validate({"dialogue":"我记得那场雨，只是现在还说不清。"}, input), "valid Chinese dialogue accepted")
	check(not client.validate({"dialogue":"我终于释怀，不再害怕。"}, input), "reconciliation rejected")
	check(not client.validate({"dialogue":"这是秘密。", "memory":"changed"}, input), "model state mutation rejected")
	check(not client.validate({"dialogue":"沈砚说道：信还在。玩家回答：我知道了。"}, input), "NPC cannot narrate or speak for player")
	var copied_input = input.duplicate(true)
	copied_input.player_said = "你画的这条街很好看，可我担心搬走后没人记得它。"
	check(not client.validate({"dialogue": copied_input.player_said}, copied_input), "NPC cannot repeat player statement as its own")
	engine.new_game()
	engine.inspect("envelope")
	engine.talk_about("shen", "envelope")
	check(not "shen_envelope" in engine.state.fragments, "initial defensive response does not disclose secret")
	engine.new_game()
	engine.inspect("envelope")
	engine.act("shen", "company")
	trace = engine.talk_about("shen", "envelope")
	check("shen_envelope" in engine.state.fragments, "relational room allows story disclosure")
	check(trace.fragment == "shen_envelope" and "铁盒" in trace.output.dialogue, "story fact stays engine-owned")
	engine.inspect("clock")
	engine.act("zhou", "tea")
	engine.talk_about("zhou", "clock")
	check(engine.can_open_letter(), "clock and envelope history opens letter")
	check(engine.open_letter(), "letter is readable")
	check(not engine.open_letter(), "letter cannot be duplicated")
	check(not engine.state.npcs.shen.anchors.is_empty(), "story revelation never completes NPC lack")
	engine.state.paused = true
	engine.state.started = true
	check(engine.save_game("user://test_evening.json") == OK, "atomic save succeeds")
	var loaded = Psychology.new()
	check(loaded.load_game("user://test_evening.json"), "save reload succeeds")
	check(loaded.state.fragments == engine.state.fragments, "story choices survive reload")
	loaded.advance(5)
	loaded.act("shen", "tea")
	check(loaded.state.minute == engine.state.minute + 5, "JSON numeric restoration supports ticks and actions")
	check(not loaded.valid_save({"version": 2}), "malformed save rejected")
	var facts = engine.model_input(trace)
	check(not JSON.stringify(facts).contains("api_key"), "no credentials in expression input")
	engine.new_game()
	var recorder = RecordingClient.new()
	var director = Director.new()
	trace = engine.act("shen", "company")
	var before_npcs = JSON.stringify(engine.state.npcs)
	await director.deliver(engine, recorder, trace)
	check(JSON.stringify(engine.state.npcs) == before_npcs, "expression director never mutates psychological state")
	check(engine.state.log.back().text == "这杯茶还有些烫，先放一会儿吧。", "player response committed to shared scene")
	check(engine.advance(2).is_empty(), "autonomous speech respects conversation cooldown")
	var autonomous = engine.advance(3)
	check(autonomous.size() == 1, "time advance presents at most one utterance")
	await director.deliver(engine, recorder, autonomous[0])
	check(recorder.inputs.size() == 2 and recorder.inputs[1].trigger.mode != "reply", "NPC autonomous reaction uses same director as player response")
	check(recorder.inputs[1].player_said.is_empty() and recorder.inputs[1].trigger.actor != "player", "social event is not misattributed to player")
	check(JSON.stringify(recorder.inputs[1].recent_dialogue).contains("这杯茶还有些烫"), "autonomous dialogue sees committed model speech")
	check(not JSON.stringify(recorder.inputs[1].recent_dialogue).contains("等待表达"), "pending expressions excluded from context")
	trace = engine.act("lin", "text", "刚才那杯茶闻起来不错。")
	var shared = engine.model_input(trace)
	check(JSON.stringify(shared.recent_dialogue).contains('"speaker":"shen"'), "switching NPC preserves attributed public conversation")
	check(not client.validate({"dialogue": "这杯茶还有些烫，先放一会儿吧。"}, shared), "exact repeated NPC utterance rejected")
	recorder.fail = true
	await director.deliver(engine, recorder, trace)
	check(engine.state.log.back().text.is_empty() and not engine.state.log.back().action.is_empty(), "failed generation falls back to action instead of unrelated stock line")
	engine.new_game()
	engine.act("shen", "company")
	engine.inspect("envelope")
	trace = engine.talk_about("shen", "envelope")
	await director.deliver(engine, recorder, trace)
	var fact_entries = engine.state.log.filter(func(entry): return entry.id == trace.entry_id)
	check("铁盒" in fact_entries[0].text, "story fallback retains engine-owned fact")
	var fact_input = engine.model_input(trace)
	fact_input.fact_quote = engine.story.fragments[trace.fragment].quote
	check(not client.validate({"dialogue": "她让你烧掉信纸，你没有烧，铁盒还在。"}, fact_input), "keyword alone cannot authorize changed factual pronouns")
	check(engine.advance(60, false).is_empty(), "offline advance does not enqueue stale speech")
	engine.new_game()
	var spontaneous = engine.advance(8)
	check(spontaneous.size() <= 1, "life events respect single spoken response limit")
	engine.new_game()
	engine.state.present = false
	var away_social: Array = []
	for step in range(30):
		away_social = engine.advance(1)
		if not away_social.is_empty():
			break
	check(away_social.size() == 1 and not engine.model_input(away_social[0]).scene.player_present and away_social[0].actor != "player", "offscreen social expression targets NPC instead of absent player")
	var guarded_input = engine.model_input(away_social[0])
	check(not client.validate({"dialogue": "信纸还在铁盒里面。"}, guarded_input), "social reply cannot jump to unrelated secret")
	check(not client.validate({"dialogue": guarded_input.observable.action}, guarded_input), "engine stage directions cannot masquerade as speech")
	engine.new_game()
	trace = engine.act("shen", "company")
	engine.update_entry(trace, "", "正在回应")
	engine.state.paused = true
	engine.save_game("user://test_interrupted.json")
	loaded.load_game("user://test_interrupted.json")
	check(loaded.state.log.back().source == "动作 · 上次表达中断", "interrupted generation recovers as action after reload")
	print("TEST_RESULT checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
