extends SceneTree
const Psychology = preload("res://scripts/psychology.gd")
const Client = preload("res://scripts/llm_client.gd")
const Director = preload("res://scripts/expression_director.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var engine = Psychology.new()
	engine.new_game(42)
	var client = Client.new()
	var director = Director.new()
	root.add_child(client)
	client.settings.provider = "ollama"
	client.settings.url = "http://127.0.0.1:11434"
	client.settings.model = OS.get_environment("TEST_LLM_MODEL") if not OS.get_environment("TEST_LLM_MODEL").is_empty() else "llama3.1:8b"
	client.settings.enabled = true
	var connection = await client.test_connection()
	print("CONNECTION ", JSON.stringify(connection))
	if not connection.ok:
		quit(1)
		return
	engine.inspect("envelope")
	engine.act("shen", "company")
	var trace = engine.talk_about("shen", "envelope")
	var before = JSON.stringify(engine.state.npcs)
	var result = await director.deliver(engine, client, trace)
	print("GENERATION ", JSON.stringify(result))
	print("CANDIDATE ", JSON.stringify(client.last_candidate))
	print("STATE_UNCHANGED ", before == JSON.stringify(engine.state.npcs))
	var state_unchanged: bool = before == JSON.stringify(engine.state.npcs)
	var story_entry = engine.state.log.filter(func(entry): return entry.id == trace.entry_id)[0]
	var story_preserved: bool = "铁盒" in story_entry.text
	var chat_trace = engine.act("lin", "text", "你画的这条街很好看，可我担心搬走后没人记得它。")
	var chat = await director.deliver(engine, client, chat_trace)
	print("FREE_DIALOGUE ", JSON.stringify(chat))
	var autonomous = engine.advance(5)
	var social: Dictionary = await director.deliver(engine, client, autonomous[0])
	print("AUTONOMOUS_DIALOGUE ", JSON.stringify(social))
	var quiet_engine = Psychology.new()
	quiet_engine.new_game(43)
	var ambient_traces = quiet_engine.advance(8)
	var ambient: Dictionary = await director.deliver(quiet_engine, client, ambient_traces[0])
	print("SPONTANEOUS_DIALOGUE ", JSON.stringify(ambient))
	client.settings.provider = "compatible"
	client.settings.url = "http://127.0.0.1:11434/v1"
	client.api_key = ""
	var compatible = await client.test_connection()
	print("COMPATIBLE ", JSON.stringify(compatible))
	var report = {"connection": connection, "generation": result, "story_fact_preserved": story_preserved, "free_dialogue": chat, "autonomous_dialogue": social, "spontaneous_dialogue": ambient, "compatible": compatible, "state_unchanged": state_unchanged, "model": client.settings.model}
	var file = FileAccess.open("res://../artifacts/llm-test.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	var safe_results = safe_delivery(engine, chat_trace, chat) and safe_delivery(engine, autonomous[0], social) and safe_delivery(quiet_engine, ambient_traces[0], ambient)
	quit(0 if story_preserved and safe_results and compatible.ok and state_unchanged else 1)

func safe_delivery(engine, trace: Dictionary, result: Dictionary) -> bool:
	var entry = engine.state.log.filter(func(item): return item.id == trace.entry_id)[0]
	return entry.text == result.dialogue if result.ok else entry.text.is_empty() and entry.source == "动作 · 本地回退"
