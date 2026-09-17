extends Control

const Psychology = preload("res://scripts/psychology.gd")
const ModelClient = preload("res://scripts/llm_client.gd")
const Tavern = preload("res://scripts/tavern.gd")
const Director = preload("res://scripts/expression_director.gd")
const TEXT = Color("edf2f4")
const MUTED = Color("b4c6d0")
const GOLD = Color("f3cf86")
const BG = Color("0e1c28")
var engine = Psychology.new()
var llm: Node
var scene_art: Control
var journal: RichTextLabel
var notebook: RichTextLabel
var status: Label
var clock_label: Label
var player_note: Label
var current_name: Label
var input: LineEdit
var send_button: Button
var leave_button: Button
var pause_button: Button
var object_buttons: HFlowContainer
var talk_buttons: HFlowContainer
var actions: Array[Button] = []
var person_buttons: Dictionary = {}
var inspect_dialog: Window
var intro_dialog: Window
var settings_dialog: Window
var modal_open: bool = false
var dialogue_busy: bool = false
var active_tab: String = "此刻"
var inspected_object: String = "envelope"
var font_size: int = 22
var model_status: String = "本地模型 · llama3.1:8b"
var timer: Timer
var ui_root: VBoxContainer
var base_theme: Theme
var toast_timer: Timer
var saved_message: Label
var screenshot_mode: bool = false
var model_controls: Dictionary = {}
var director = Director.new()
var quiet_until_ms: int = 0

func _ready() -> void:
	llm = ModelClient.new()
	add_child(llm)
	llm.status_changed.connect(_model_status)
	font_size = int(llm.settings.get("font_size", 22))
	model_status = "LLM · " + str(llm.settings.model) if llm.settings.enabled else "本地叙事 · 模型已关闭"
	screenshot_mode = "--smoke" in OS.get_cmdline_user_args()
	if not screenshot_mode:
		engine.load_game()
	_build_theme()
	_build_ui()
	get_window().min_size = Vector2i(1180, 760)
	timer = Timer.new()
	timer.wait_time = 15
	timer.timeout.connect(_world_tick)
	add_child(timer)
	timer.start()
	toast_timer = Timer.new()
	toast_timer.one_shot = true
	toast_timer.wait_time = 4
	toast_timer.timeout.connect(func(): saved_message.text = "进度自动保存")
	add_child(toast_timer)
	refresh()
	if not engine.state.started:
		call_deferred("_show_intro")
	get_tree().auto_accept_quit = false
	if "--smoke" in OS.get_cmdline_user_args():
		call_deferred("_smoke")

func _build_theme() -> void:
	base_theme = Theme.new()
	var font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"])
	font.allow_system_fallback = true
	base_theme.default_font = font
	base_theme.default_font_size = font_size
	for type in ["Label", "Button", "LineEdit", "CheckButton", "OptionButton", "RichTextLabel"]:
		base_theme.set_color("font_color", type, TEXT)
	base_theme.set_color("default_color", "RichTextLabel", TEXT)
	base_theme.set_color("font_placeholder_color", "LineEdit", MUTED)
	base_theme.set_color("font_hover_color", "Button", Color("ffffff"))
	base_theme.set_color("font_disabled_color", "Button", Color("7e939f"))
	base_theme.set_color("font_color", "PopupMenu", TEXT)
	base_theme.set_stylebox("normal", "Button", _box("223c4d", "496678", 7, 12))
	base_theme.set_stylebox("hover", "Button", _box("365a6d", "d8bb80", 7, 12))
	base_theme.set_stylebox("pressed", "Button", _box("71603c", "f3cf86", 7, 12))
	base_theme.set_stylebox("disabled", "Button", _box("1a2c39", "314b5c", 7, 12))
	base_theme.set_stylebox("focus", "Button", _box("284657", "f3cf86", 7, 12, false))
	base_theme.set_stylebox("normal", "LineEdit", _box("101f2c", "678798", 7, 12))
	base_theme.set_stylebox("focus", "LineEdit", _box("172c3b", "f3cf86", 7, 12))
	base_theme.set_stylebox("panel", "PopupMenu", _box("172c3b", "6e8996", 6, 12))
	base_theme.set_stylebox("normal", "OptionButton", _box("223c4d", "648193", 6, 12))
	base_theme.set_stylebox("hover", "OptionButton", _box("365a6d", "f3cf86", 6, 12))
	base_theme.set_stylebox("grabber", "VScrollBar", _box("698999", "698999", 4, 2))
	base_theme.set_stylebox("grabber_highlight", "VScrollBar", _box("d0b778", "d0b778", 4, 2))
	base_theme.set_constant("separation", "VBoxContainer", 12)
	base_theme.set_constant("separation", "HBoxContainer", 12)
	base_theme.set_constant("h_separation", "HFlowContainer", 8)
	base_theme.set_constant("v_separation", "HFlowContainer", 8)
	theme = base_theme

func _box(bg: String, border: String, radius: int = 8, margin: int = 16, fill: bool = true) -> StyleBoxFlat:
	var box = StyleBoxFlat.new()
	box.bg_color = Color(bg)
	box.draw_center = fill
	box.border_color = Color(border)
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(margin)
	return box

func _label(text: String, size_value: int = 20, color: Color = TEXT) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size_value)
	label.add_theme_color_override("font_color", color)
	return label

func _paragraph(text: String, size_value: int = 20, color: Color = TEXT) -> Label:
	var label = _label(text, size_value, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

func _button(text: String, callback: Callable, min_width: float = 0) -> Button:
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(min_width, 44)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(callback)
	return button

func _panel(parent: Node, color: String = "182d3c") -> VBoxContainer:
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _box(color, "37576a", 10, 18))
	parent.add_child(panel)
	var box = VBoxContainer.new()
	panel.add_child(box)
	return box

func _build_ui() -> void:
	var background = ColorRect.new()
	background.color = BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	add_child(margin)
	ui_root = VBoxContainer.new()
	margin.add_child(ui_root)
	var header = HBoxContainer.new()
	ui_root.add_child(header)
	var title = VBoxContainer.new()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_constant_override("separation", 0)
	header.add_child(title)
	title.add_child(_label("雨停之前", 32, GOLD))
	title.add_child(_label("第一章  /  空信封", 18, MUTED))
	clock_label = _label("18:00  ·  初秋，雨夜", 22)
	header.add_child(clock_label)
	header.add_child(_button("故事与手记", _show_story))
	header.add_child(_button("模型与显示", _show_settings))
	var body = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ui_root.add_child(body)
	var left = VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 0.95
	body.add_child(left)
	var stage_box = _panel(left, "132935")
	var stage_head = HBoxContainer.new()
	stage_box.add_child(stage_head)
	var place = _label("雨停酒馆", 23, GOLD)
	place.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_head.add_child(place)
	stage_head.add_child(_label("青石巷 · 临河镇", 17, MUTED))
	scene_art = Tavern.new()
	scene_art.person_selected.connect(_select_person)
	stage_box.add_child(scene_art)
	var people = HBoxContainer.new()
	stage_box.add_child(people)
	for id in ["shen", "lin", "zhou"]:
		var button = _button(engine.story.characters[id].name + " · " + engine.story.characters[id].role, _select_person.bind(id))
		button.add_theme_font_size_override("font_size", 17)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		people.add_child(button)
		person_buttons[id] = button
	var object_head = HBoxContainer.new()
	stage_box.add_child(object_head)
	object_head.add_child(_label("看看周围", 18, MUTED))
	object_buttons = HFlowContainer.new()
	stage_box.add_child(object_buttons)
	for item in [["envelope", "空信封"], ["photo", "旧合影"], ["clock", "停钟"], ["notice", "搬迁通知"]]:
		var button = _button(item[1], _inspect.bind(item[0]))
		button.add_theme_font_size_override("font_size", 18)
		object_buttons.add_child(button)
	var notes_box = _panel(left)
	notes_box.get_parent().size_flags_vertical = Control.SIZE_EXPAND_FILL
	var tabs = HBoxContainer.new()
	notes_box.add_child(tabs)
	for text in ["此刻", "记忆", "因果"]:
		var button = _button(text, _set_tab.bind(text))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(button)
	notebook = RichTextLabel.new()
	notebook.bbcode_enabled = true
	notebook.size_flags_vertical = Control.SIZE_EXPAND_FILL
	notebook.custom_minimum_size.y = 125
	notebook.add_theme_font_size_override("normal_font_size", 18)
	notebook.add_theme_color_override("default_color", TEXT)
	notes_box.add_child(notebook)
	var right = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.05
	body.add_child(right)
	var player_box = _panel(right, "263746")
	player_box.add_child(_label("许知微  /  你带来的空缺", 21, GOLD))
	player_note = _paragraph(engine.story.player.question, 21)
	player_box.add_child(player_note)
	var dialog_box = _panel(right, "152938")
	dialog_box.get_parent().size_flags_vertical = Control.SIZE_EXPAND_FILL
	var dialog_head = HBoxContainer.new()
	dialog_box.add_child(dialog_head)
	current_name = _label("沈砚", 24, GOLD)
	current_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dialog_head.add_child(current_name)
	dialog_head.add_child(_label("说出口的 / 没说完的", 16, MUTED))
	journal = RichTextLabel.new()
	journal.bbcode_enabled = true
	journal.scroll_following = true
	journal.size_flags_vertical = Control.SIZE_EXPAND_FILL
	journal.custom_minimum_size.y = 150
	journal.add_theme_font_size_override("normal_font_size", font_size)
	journal.add_theme_font_size_override("bold_font_size", font_size)
	journal.add_theme_constant_override("line_separation", 7)
	dialog_box.add_child(journal)
	talk_buttons = HFlowContainer.new()
	dialog_box.add_child(talk_buttons)
	var action_grid = GridContainer.new()
	action_grid.columns = 3
	for item in [["company", "陪他坐一会"], ["tea", "递一杯热茶"], ["listen", "听听今天的事"], ["boundary", "不急着追问"], ["joke", "开个小玩笑"], ["silence", "暂时不说话"]]:
		var button = _button(item[1], _act.bind(item[0]))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 18)
		action_grid.add_child(button)
		actions.append(button)
	dialog_box.add_child(action_grid)
	var input_row = HBoxContainer.new()
	dialog_box.add_child(input_row)
	input = LineEdit.new()
	input.placeholder_text = "说点什么，或问问那段往事……"
	input.max_length = 500
	input.custom_minimum_size.y = 50
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.text_submitted.connect(_send)
	input_row.add_child(input)
	send_button = _button("说出来", func(): _send(input.text))
	input_row.add_child(send_button)
	status = _paragraph("正在准备本地模型连接", 16, MUTED)
	status.custom_minimum_size.y = 27
	dialog_box.add_child(status)
	var footer = HBoxContainer.new()
	ui_root.add_child(footer)
	pause_button = _button("暂停时间", _pause)
	footer.add_child(pause_button)
	footer.add_child(_button("静坐五分钟", _wait))
	leave_button = _button("去檐下走走", _leave)
	footer.add_child(leave_button)
	saved_message = _label("进度自动保存", 16, MUTED)
	saved_message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	saved_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	footer.add_child(saved_message)

func _safe(text: Variant) -> String:
	return str(text).replace("[", "［").replace("]", "］")

func _clock() -> String:
	var minute: int = engine.state.minute + 18 * 60
	return "%02d:%02d" % [int(minute / 60) % 24, minute % 60]

func refresh() -> void:
	var state: Dictionary = engine.state
	var id: String = state.selected
	var npc: Dictionary = state.npcs[id]
	current_name.text = engine.story.characters[id].name + "  /  " + engine.story.characters[id].role
	clock_label.text = _clock() + ("  ·  暂停" if state.paused else "  ·  檐下听雨" if not state.present else "  ·  雨夜")
	pause_button.text = "继续时间" if state.paused else "暂停时间"
	leave_button.text = "推门回去" if not state.present else "去檐下走走"
	scene_art.selected = id
	scene_art.away = not state.present
	scene_art.living = state.npcs
	for pid in person_buttons:
		person_buttons[pid].add_theme_stylebox_override("normal", _box("655538" if pid == id else "223c4d", "e4c182" if pid == id else "496678", 6, 10))
	player_note.text = "今晚可以先留下，也可以带着这封信离开。" if "letter" in state.fragments else "铁盒和钥匙都在这里了。你想现在打开那封信吗？" if engine.can_open_letter() else "照片里那个孩子，原来是我。还有谁记得那一晚？" if "zhou_photo" in state.fragments else engine.story.player.question
	var content = ""
	for entry in state.log.slice(maxi(0, state.log.size() - 45)):
		if entry.kind == "player":
			content += "[color=#a8d4e9]你[/color]  " + _safe(entry.text) + "\n\n"
		elif entry.kind == "npc":
			var name_text: String = engine.story.characters.get(entry.actor, {}).get("name", "某人")
			content += "[color=#f3cf86]" + name_text + "[/color]  [font_size=15][color=#a6bdcb]" + _safe(entry.source) + "[/color][/font_size]\n"
			if not str(entry.text).is_empty():
				content += "“" + _safe(entry.text) + "”\n"
			content += "[font_size=17][color=#b4c6d0]" + _safe(entry.action) + "[/color][/font_size]\n\n"
		else:
			content += "[font_size=18][color=#b9d3d9]" + ("「" + _safe(entry.source) + "」\n" if entry.kind == "discovery" else "") + _safe(entry.text) + "[/color][/font_size]\n\n"
	journal.text = content
	for button in actions:
		button.disabled = dialogue_busy or not state.present
	input.editable = state.present and not dialogue_busy
	send_button.disabled = not state.present or dialogue_busy
	leave_button.disabled = dialogue_busy
	for button in object_buttons.get_children():
		button.disabled = not state.present or dialogue_busy
	status.text = model_status
	_update_notebook(npc)
	for child in talk_buttons.get_children():
		talk_buttons.remove_child(child)
		child.queue_free()
	if state.present:
		for object_id in state.objects:
			var short: String = {"envelope":"信封", "photo":"合影", "clock":"停钟", "notice":"搬迁"}[object_id]
			var button = _button("问起" + short, _talk_about.bind(object_id))
			button.add_theme_font_size_override("font_size", 16)
			button.disabled = dialogue_busy
			talk_buttons.add_child(button)
		if engine.can_open_letter() and not "letter" in state.fragments:
			var open_button = _button("打开铁盒里的信", _open_letter)
			open_button.disabled = dialogue_busy
			open_button.add_theme_color_override("font_color", GOLD)
			talk_buttons.add_child(open_button)

func _update_notebook(npc: Dictionary) -> void:
	var text = ""
	if active_tab == "此刻":
		text = "[color=#f3cf86]" + engine.story.characters[npc.id].line + "[/color]\n\n"
		text += "正在做：" + _safe(npc.life.activity) + "\n\n"
		text += "情绪：" + engine.data.EMOTIONS[npc.emotion] + "   ·   " + ("肩上积着疲惫" if npc.fatigue > 65 else "还有一点余力") + "\n"
		for id in npc.anchors:
			text += "\n" + engine.data.ANCHORS[id].name + "   [color=#f3cf86]" + engine.data.GRADIENTS[npc.anchors[id].gradient] + "[/color]"
		text += "\n\n[color=#b4c6d0]他对自己的解释：" + _safe(npc.narrative) + "[/color]"
	elif active_tab == "记忆":
		if npc.memories.is_empty():
			text = "相处刚开始。有些片刻还没成为记忆。"
		for i in range(npc.memories.size() - 1, maxi(-1, npc.memories.size() - 8), -1):
			var memory: Dictionary = npc.memories[i]
			var who = "你" if memory.actor == "player" else "酒馆" if memory.actor == "world" else engine.person(memory.actor).name
			text += "[color=#f3cf86]" + who + "留下的片刻[/color]\n" + _safe(memory.content) + "\n"
			if not memory.distortions.is_empty():
				text += "[color=#b4c6d0]" + _safe(memory.distortions.back()) + "[/color]\n"
			text += "\n"
	else:
		var trace: Dictionary = {}
		for i in range(engine.state.traces.size() - 1, -1, -1):
			if engine.state.traces[i].npc == npc.id:
				trace = engine.state.traces[i]
				break
		if trace.is_empty():
			text = "交谈之后，这里会呈现他为何如此反应。"
		else:
			text = "[color=#f3cf86]感知[/color]  " + _safe(trace.event) + "\n\n"
			text += "[color=#f3cf86]注意力[/color]  " + str(engine.data.ANCHORS.get(trace.focus, {}).get("name", "日常与背景")) + "\n"
			text += "[color=#f3cf86]应对[/color]  " + ("、".join(trace.structure.defenses) if not trace.structure.defenses.is_empty() else "习惯的小动作") + "\n\n"
			text += _safe(trace.structure.contradiction) + "\n\n[color=#b4c6d0]" + _safe(trace.structure.pattern) + "[/color]"
			if trace.soothing.count > 1:
				text += "\n同一安抚通道的重复，让缓解逐渐变弱。"
		if not npc.life.history.is_empty():
			var latest: Dictionary = npc.life.history.back()
			text += "\n\n[color=#f3cf86]自己的生活[/color]\n" + _safe(latest.text) + "\n[color=#b4c6d0]" + _safe(latest.cause) + "[/color]"
	notebook.text = text

func _select_person(id: String) -> void:
	if dialogue_busy:
		return
	engine.state.selected = id
	refresh()
	_save()

func _set_tab(tab: String) -> void:
	active_tab = tab
	refresh()

func _model_status(message: String) -> void:
	model_status = message
	if is_instance_valid(status):
		status.text = message

func _act(action: String) -> void:
	if dialogue_busy:
		return
	var trace = engine.act(engine.state.selected, action)
	if not trace.is_empty():
		await _express(trace)

func _send(text: String) -> void:
	if text.strip_edges().is_empty() or dialogue_busy:
		return
	input.text = ""
	var trace = engine.act(engine.state.selected, "text", text.strip_edges())
	if not trace.is_empty():
		await _express(trace)

func _express(trace: Dictionary) -> void:
	dialogue_busy = true
	engine.update_entry(trace, "", "正在回应")
	refresh()
	var result: Dictionary = await director.deliver(engine, llm, trace)
	if not result.ok and llm.settings.enabled:
		_toast(result.error)
	quiet_until_ms = Time.get_ticks_msec() + 30000
	dialogue_busy = false
	refresh()
	_save()

func _world_tick() -> void:
	if engine.state.paused or not engine.state.started or modal_open:
		return
	var replies = engine.advance(1, not dialogue_busy and Time.get_ticks_msec() >= quiet_until_ms and input.text.strip_edges().is_empty())
	for trace in replies:
		await _express(trace)
	refresh()
	_save()

func _pause() -> void:
	engine.state.paused = not engine.state.paused
	refresh()
	_save()

func _wait() -> void:
	if dialogue_busy:
		_toast("等这句话说完，再让时间往前走。")
		return
	var replies = engine.advance(5)
	for trace in replies:
		await _express(trace)
	refresh()
	_save()

func _leave() -> void:
	await _act("return" if not engine.state.present else "leaving")

func _save() -> void:
	if screenshot_mode:
		return
	if engine.save_game() != OK:
		_toast("自动保存失败，请检查本机存储空间。")

func _toast(message: String) -> void:
	saved_message.text = message.left(48)
	toast_timer.start()

func _window(title: String, window_size: Vector2i) -> Window:
	var window = Window.new()
	window.title = title
	window.size = window_size
	window.size = Vector2i(mini(window_size.x, int(size.x) - 80), mini(window_size.y, int(size.y) - 80))
	window.min_size = Vector2i(500, 240)
	window.exclusive = true
	window.transient = true
	window.unresizable = true
	window.wrap_controls = false
	window.theme = base_theme
	add_child(window)
	window.close_requested.connect(func(): _close_window(window))
	var panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", _box("162c3d", "7994a3", 0, 26))
	window.add_child(panel)
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)
	var box = VBoxContainer.new()
	box.name = "Content"
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	modal_open = true
	window.popup_centered()
	return window

func _content(window: Window) -> VBoxContainer:
	return window.get_child(0).get_child(0).get_child(0)

func _close_window(window: Window) -> void:
	if window == settings_dialog and llm.busy:
		return
	window.hide()
	window.queue_free()
	modal_open = false
	if not engine.state.started and window == intro_dialog:
		engine.state.started = true
		_save()

func _show_intro() -> void:
	intro_dialog = _window("雨停之前 · 第一章", Vector2i(870, 720))
	var box = _content(intro_dialog)
	box.add_child(_label("空信封", 38, GOLD))
	box.add_child(_label("有些地方，你忘记了。它们却还记得你。", 22, MUTED))
	var prose = RichTextLabel.new()
	prose.size_flags_vertical = Control.SIZE_EXPAND_FILL
	prose.custom_minimum_size.y = 420
	prose.add_theme_font_size_override("normal_font_size", 23)
	prose.add_theme_constant_override("line_separation", 8)
	prose.text = "\n\n".join(engine.story.prologue)
	box.add_child(prose)
	box.add_child(_paragraph("你可以从看看信封开始。这里的人不会一次说出全部，你也不必今晚就问清一切。", 19, MUTED))
	box.add_child(_button("把信封放到桌上，坐下来", func(): _close_window(intro_dialog); _inspect("envelope")))

func _inspect(id: String) -> void:
	var object = engine.inspect(id)
	if object.is_empty():
		return
	inspected_object = id
	inspect_dialog = _window(object.title, Vector2i(760, 430))
	var box = _content(inspect_dialog)
	box.add_child(_label(object.title, 29, GOLD))
	box.add_child(_paragraph(object.text, 24))
	box.add_child(_paragraph("你心里的问题：" + object.question, 21, Color("acd8ea")))
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	var row = HBoxContainer.new()
	box.add_child(row)
	for target in ["shen", "lin", "zhou"]:
		row.add_child(_button("问问" + engine.person(target).name, func():
			_close_window(inspect_dialog)
			_select_person(target)
			_talk_about(id)))
	box.add_child(_button("先记在心里，不急着问", func(): _close_window(inspect_dialog)))
	refresh()
	_save()

func _talk_about(id: String) -> void:
	if dialogue_busy:
		return
	var trace = engine.talk_about(engine.state.selected, id)
	if not trace.is_empty():
		await _express(trace)

func _open_letter() -> void:
	if not engine.open_letter():
		return
	_save()
	refresh()
	var window = _window("晚晴留给知微的信", Vector2i(830, 620))
	var box = _content(window)
	box.add_child(_label("你可以想念，也可以走。", 31, GOLD))
	box.add_child(_paragraph(engine.story.fragments.letter.quote, 25))
	box.add_child(_paragraph(engine.story.reflection, 21, MUTED))
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	for answer in ["我想今晚先留下。", "我还没想好，但明天想再来。", "把信带走，也把地址留下。"]:
		box.add_child(_button(answer, func():
			engine.state.player_response = answer
			engine.log_event("player", answer, "player")
			engine.log_event("world", "沈砚点点头，没问你会留多久。周叔把一只木鸟放在桌上，林遥翻开一张新的画纸。")
			_close_window(window)
			refresh()
			_save()))

func _show_story() -> void:
	var window = _window("你随身的手记", Vector2i(880, 710))
	var box = _content(window)
	box.add_child(_label("不是待办，是你开始在意的事。", 28, GOLD))
	var notes = RichTextLabel.new()
	notes.bbcode_enabled = true
	notes.size_flags_vertical = Control.SIZE_EXPAND_FILL
	notes.custom_minimum_size.y = 450
	notes.add_theme_font_size_override("normal_font_size", 22)
	notes.add_theme_constant_override("line_separation", 7)
	var text = "[color=#f3cf86]许知微 · " + engine.story.player.identity + "[/color]\n" + engine.story.player.lack + "\n\n"
	text += engine.story.world + "\n\n[color=#f3cf86]眼前牵挂[/color]\n" + player_note.text + "\n\n"
	if engine.state.fragments.is_empty():
		text += "信封、合影、停钟、搬迁通知，都可以拿起来看看。也许有人愿意说说它们。\n"
	for id in engine.state.fragments:
		var fragment: Dictionary = engine.story.fragments[id]
		text += "[color=#f3cf86]" + fragment.title + "[/color]\n" + fragment.fact + "\n" + fragment.echo + "\n\n"
	if "letter" in engine.state.fragments:
		text += "[color=#acd8ea]" + engine.story.reflection + "[/color]\n"
	notes.text = text
	box.add_child(notes)
	box.add_child(_button("合上手记，回到他们身边", func(): _close_window(window)))

func _show_settings() -> void:
	if dialogue_busy:
		_toast("请等当前这句话说完再切换模型。")
		return
	settings_dialog = _window("模型与显示", Vector2i(880, 760))
	var box = _content(settings_dialog)
	box.add_child(_label("真正听见你说的话", 29, GOLD))
	box.add_child(_paragraph("模型读取角色背景、对话和心理冲突，只生成台词。行为、记忆和往事的揭示仍由游戏决定。", 18, MUTED))
	var provider_row = HBoxContainer.new()
	box.add_child(provider_row)
	provider_row.add_child(_label("服务方式", 19))
	var provider = OptionButton.new()
	provider.add_item("Ollama · 本机模型")
	provider.add_item("兼容 OpenAI 的 API")
	provider.selected = 0 if llm.settings.provider == "ollama" else 1
	provider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	provider.custom_minimum_size.y = 44
	provider_row.add_child(provider)
	var url = _setting_line(box, "服务地址", str(llm.settings.url))
	var model = _setting_line(box, "模型名称", str(llm.settings.model))
	var key = _setting_line(box, "API 密钥", llm.api_key)
	key.secret = true
	key.placeholder_text = "本地 Ollama 不需要；也可读取环境变量"
	var enabled = CheckButton.new()
	enabled.text = "启用真实模型对话"
	enabled.button_pressed = llm.settings.enabled
	box.add_child(enabled)
	var remember = CheckButton.new()
	remember.text = "在本机保存密钥（默认仅本次运行使用）"
	remember.button_pressed = llm.settings.remember_key
	remember.add_theme_font_size_override("font_size", 17)
	box.add_child(remember)
	box.add_child(_paragraph("使用远端 API 时，当前对话与虚构角色背景会发送到你填写的服务。密钥不进入存档或因果记录。", 16, MUTED))
	var display_row = HBoxContainer.new()
	box.add_child(display_row)
	display_row.add_child(_label("对话字号", 19))
	var font_option = OptionButton.new()
	for size_value in [20, 22, 24, 26]:
		font_option.add_item(str(size_value) + " px", size_value)
	font_option.select([20, 22, 24, 26].find(font_size))
	font_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	display_row.add_child(font_option)
	model_controls = {"provider": provider, "url": url, "model": model, "key": key, "enabled": enabled, "remember": remember, "font": font_option}
	provider.item_selected.connect(func(index):
		if index == 0:
			url.text = "http://127.0.0.1:11434"
			model.text = "llama3.1:8b"
		else:
			url.text = "https://api.openai.com/v1"
			model.text = ""
			model.placeholder_text = "填写你的服务提供的模型名称")
	var test_result = _paragraph("尚未测试。点击下方按钮将发送一次真实生成请求。", 18, MUTED)
	test_result.custom_minimum_size.y = 70
	box.add_child(test_result)
	var test_button = _button("测试真实模型连接", func():
		_apply_model_settings()
		test_result.text = "正在加载模型并生成测试回复，首次加载可能较慢……"
		var result: Dictionary = await llm.test_connection()
		if is_instance_valid(test_result):
			test_result.text = "连接成功：" + result.dialogue if result.ok else result.error)
	box.add_child(test_button)
	var row = HBoxContainer.new()
	box.add_child(row)
	row.add_child(_button("保存设置，回到酒馆", func():
		if llm.busy:
			return
		_apply_model_settings()
		if llm.save_settings() != OK:
			test_result.text = "设置保存失败，请检查目录权限。"
			return
		_close_window(settings_dialog)
		refresh()))
	row.add_child(_button("打开存档目录", func(): OS.shell_open(ProjectSettings.globalize_path("user://"))))
	row.add_child(_button("重新开始", func():
		if llm.busy:
			return
		_close_window(settings_dialog)
		_confirm_restart()))

func _setting_line(box: VBoxContainer, title: String, value: String) -> LineEdit:
	var row = HBoxContainer.new()
	box.add_child(row)
	var label = _label(title, 19)
	label.custom_minimum_size.x = 95
	row.add_child(label)
	var field = LineEdit.new()
	field.text = value
	field.custom_minimum_size.y = 45
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(field)
	return field

func _apply_model_settings() -> void:
	llm.settings.provider = "ollama" if model_controls.provider.selected == 0 else "compatible"
	llm.settings.url = model_controls.url.text.strip_edges()
	llm.settings.model = model_controls.model.text.strip_edges()
	llm.settings.enabled = model_controls.enabled.button_pressed
	llm.settings.remember_key = model_controls.remember.button_pressed
	llm.api_key = model_controls.key.text.strip_edges()
	font_size = model_controls.font.get_selected_id()
	llm.settings.font_size = font_size
	journal.add_theme_font_size_override("normal_font_size", font_size)
	journal.add_theme_font_size_override("bold_font_size", font_size)
	model_status = ("LLM · " + str(llm.settings.model)) if llm.settings.enabled else "本地叙事 · 模型已关闭"

func _confirm_restart() -> void:
	var window = _window("重新开始一晚", Vector2i(620, 270))
	var box = _content(window)
	box.add_child(_paragraph("当前进度会先保留一份备份，再开启新的夜晚。要重新把那封信带进酒馆吗？", 23))
	box.add_child(_button("保留备份，重新开始", func():
		engine.save_game("user://before_restart.json")
		engine.new_game()
		_close_window(window)
		refresh()
		_save()
		_show_intro()))
	box.add_child(_button("继续这一晚", func(): _close_window(window)))

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save()
		get_tree().quit()

func _smoke() -> void:
	# Real rendered game smoke path, isolated save handling is done by the test launcher.
	await get_tree().create_timer(1.0).timeout
	if is_instance_valid(intro_dialog):
		_close_window(intro_dialog)
	engine.state.paused = true
	llm.settings.enabled = false
	engine.inspect("envelope")
	engine.act("shen", "company")
	engine.talk_about("shen", "envelope")
	engine.advance(10, false)
	refresh()
	await RenderingServer.frame_post_draw
	var output = ProjectSettings.globalize_path("res://../artifacts/godot-desktop.png")
	get_viewport().get_texture().get_image().save_png(output)
	_show_settings()
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../artifacts/godot-settings.png"))
	_close_window(settings_dialog)
	get_window().size = Vector2i(1180, 760)
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../artifacts/godot-small-window.png"))
	get_window().size = Vector2i(1440, 900)
	_show_intro()
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../artifacts/godot-prologue.png"))
	print("SMOKE_UI_OK ", output)
	get_tree().quit()
