extends RefCounted
## Every live utterance uses the same context and commits only presentation text.

func deliver(engine, client, trace: Dictionary) -> Dictionary:
	var input: Dictionary = engine.model_input(trace)
	input.fact_quote = engine.story.fragments[trace.fragment].quote if not trace.fragment.is_empty() else ""
	engine.update_entry(trace, "", "正在回应")
	var result: Dictionary = await client.generate(input)
	if result.ok:
		engine.update_entry(trace, result.dialogue, "LLM · " + str(result.model))
	else:
		var fallback: String = engine.fallback_dialogue(trace)
		engine.update_entry(trace, fallback, "已知事实 · 本地回退" if not fallback.is_empty() else "动作 · 本地回退")
	return result
