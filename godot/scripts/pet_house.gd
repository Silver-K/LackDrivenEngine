extends Control
## Native animated sandbox. Fixed simulation ticks; rendering never mutates the world.
const World = preload("res://scripts/animal_world.gd")
var world = World.new()
var selected = "miso"
var paused = false
var speed = 1.0
var accumulator = 0.0
var elapsed = 0.0
var font: Font
var buttons: Array = []
var hovered = ""
var smoke = false
var show_senses = false

func _ready() -> void:
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"])
	smoke = "--pet-smoke" in OS.get_cmdline_user_args()
	if smoke:
		for i in range(400): world.step(0.1)
		selected = "seed_a"
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	if not paused:
		accumulator += minf(delta, 0.2) * speed
		while accumulator >= 0.1:
			world.step(0.1)
			accumulator -= 0.1
	queue_redraw()
	if smoke and elapsed > 1:
		smoke = false
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://../artifacts/pet-house.png")
		get_tree().quit()

func design_point(point: Vector2) -> Vector2:
	var scale_factor: float = minf(size.x / 1440, size.y / 900)
	return (point - (size - Vector2(1440, 900) * scale_factor) / 2) / scale_factor

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var point = design_point(event.position)
		hovered = ""
		for o in world.objects.values():
			if point.distance_to(o.position) < 48: hovered = o.id
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not hovered.is_empty() else Control.CURSOR_ARROW
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var point = design_point(event.position)
		for b in buttons:
			if b.rect.has_point(point):
				command(b.id)
				return
		for a in world.animals.values():
			if point.distance_to(a.position + Vector2(0, -15)) < 36:
				selected = a.id
				return
		for o in world.objects.values():
			if point.distance_to(o.position) < 48:
				world.interact(o.id)
				return

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		paused = not paused

func command(id: String) -> void:
	match id:
		"pause": paused = not paused
		"senses": show_senses = not show_senses
		"save":
			world.events.push_front({"time":world.time,"text":"经历已保存。" if world.save_history() else "保存失败。"})
		"load":
			world.events.push_front({"time":world.time,"text":"继续此前的生活。" if world.load_history() else "没有可读取的成长记录。"})
		"speed": speed = 3.0 if speed == 1 else 1.0
		"reset":
			world = World.new()
			accumulator = 0
		"care": world.care(selected)
		"fill":
			for o in world.objects.values():
				if o.has("stock"): world.interact(o.id)
		_:
			if world.animals.has(id): selected = id

func box(rect: Rect2, color: String, radius: int = 12, border: String = "") -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(color)
	style.set_corner_radius_all(radius)
	if not border.is_empty():
		style.border_color = Color(border)
		style.set_border_width_all(2)
	draw_style_box(style, rect)

func text_at(pos: Vector2, text: String, color: String = "334c46", font_size: int = 18) -> void:
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(color))

func ellipse(center: Vector2, radius: Vector2, color: String) -> void:
	var points = PackedVector2Array()
	for i in range(40):
		var angle = TAU * i / 40
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, Color(color))

func button(id: String, label: String, rect: Rect2, active: bool = false) -> void:
	buttons.append({"id":id, "rect":rect})
	box(rect, "426c58" if active else "ecefe6", 10)
	text_at(rect.position + Vector2(14, 27), label, "ffffff" if active else "3d594c", 17)

func _draw() -> void:
	if font == null: return
	buttons.clear()
	var factor = minf(size.x / 1440, size.y / 900)
	draw_set_transform((size - Vector2(1440, 900) * factor) / 2, 0, Vector2.ONE * factor)
	draw_rect(Rect2(0, 0, 1440, 900), Color("f4f3eb"))
	text_at(Vector2(38, 51), "同一屋檐下", "294e40", 31)
	text_at(Vector2(40, 79), "三个母体，三个幼体。相同的结构，不同的经历。", "7b887e", 16)
	button("pause", "继续" if paused else "暂停", Rect2(1050, 30, 88, 40), paused)
	button("speed", "速度 ×" + str(int(speed)), Rect2(1148, 30, 110, 40), speed > 1)
	button("reset", "重新开始", Rect2(1268, 30, 130, 40))
	button("senses", "感知范围", Rect2(925, 30, 115, 40), show_senses)
	button("save", "保存经历", Rect2(685, 30, 110, 40))
	button("load", "继续生活", Rect2(805, 30, 110, 40))
	draw_room()
	if show_senses:
		var subject: Dictionary = world.animals[selected]
		var radius: float = subject.range
		draw_arc(subject.position, radius, 0, TAU, 100, Color(0.3, 0.5, 0.5, 0.3), 2, true)
		# Display a bounded sample; the complete contribution set stays in simulation state.
		for vector in subject.vectors.slice(0,128):
			draw_line(subject.position, subject.position + vector * 55, Color("518e8b"), 2, true)
	var sorted: Array = world.animals.values().duplicate()
	sorted.sort_custom(func(a, b): return a.position.y < b.position.y)
	for a in sorted: draw_animal(a)
	draw_panel()
	draw_footer()

func draw_room() -> void:
	box(Rect2(30, 104, 1040, 565), "e6ddc8", 22)
	box(Rect2(50, 123, 1000, 120), "c4d2bc", 10)
	draw_rect(Rect2(50, 225, 1000, 423), Color("e8cda7"))
	for y in range(240, 648, 50):
		draw_line(Vector2(50, y), Vector2(1050, y), Color("d7b88f"), 2)
		for x in range(90 + (y % 100) * 3, 1030, 160):
				draw_line(Vector2(x, y), Vector2(x, mini(y + 49, 648)), Color("ddbf98"), 1)
	# Window and sunlit floor.
	box(Rect2(385, 130, 225, 90), "f9f4df", 8)
	box(Rect2(394, 139, 207, 72), "a8c7c7", 3)
	draw_line(Vector2(498, 139), Vector2(498, 211), Color("faf6e8"), 6)
	draw_line(Vector2(394, 175), Vector2(601, 175), Color("faf6e8"), 5)
	draw_circle(Vector2(565, 158), 12, Color("fff0b5"))
	draw_colored_polygon(PackedVector2Array([Vector2(410, 245), Vector2(590, 245), Vector2(730, 520), Vector2(475, 520)]), Color(1, 0.94, 0.73, 0.25))
	box(Rect2(345, 330, 335, 220), "b5c0a0", 65)
	box(Rect2(363, 347, 300, 185), "c5cfb0", 58, "dce0c8")
	# Low shelf, plants, wall decorations.
	box(Rect2(660, 166, 300, 28), "947c5e", 4)
	for i in range(5): box(Rect2(677 + i * 22, 132 + i % 2 * 6, 17, 34 - i % 2 * 6), ["c79176", "849d8e", "eadcb9"][i % 3], 2)
	box(Rect2(910, 130, 29, 35), "d4b393", 6)
	for i in range(4): ellipse(Vector2(923 + (i - 2) * 9, 123 - (i % 2) * 9), Vector2(10, 18), "719677")
	text_at(Vector2(72, 158), "PET HOUSE", "64836d", 16)
	text_at(Vector2(72, 188), "慢慢靠近，自在生活", "64836d", 14)
	for o in world.objects.values(): draw_object(o)
	text_at(Vector2(58, 644), "点击物品：补粮 / 加水 / 开关门 / 拨动绒球    ·    点击动物查看此刻", "7e715c", 15)

func draw_object(o: Dictionary) -> void:
	var p: Vector2 = o.position
	if hovered == o.id:
		draw_arc(p, 43, 0, TAU, 40, Color("f8fff0"), 3, true)
	match o.kind:
		"food", "water":
			ellipse(p + Vector2(0, 9), Vector2(36, 12), "b59c7b")
			ellipse(p, Vector2(33, 20), "f3efe3" if o.kind == "food" else "7eaaa9")
			ellipse(p + Vector2(0, -3), Vector2(26, 13), "c3ae94" if o.kind == "food" else "c4e1dd")
			if o.stock > 0:
				if o.kind == "food":
					for i in range(int(o.stock / 8) + 1):
						draw_circle(p + Vector2(sin(i * 2.4) * 19, cos(i * 2.4) * 8 - 3), 3.5, Color("8c6347"))
				else:
					draw_arc(p + Vector2(0, -3), 16, 0, PI, 24, Color("e7f7ee"), 2)
			box(Rect2(p.x - 26, p.y + 24, 52, 4), "c7b595", 2)
			if o.stock > 0: box(Rect2(p.x - 26, p.y + 24, 52 * o.stock / o.capacity, 4), "719c88", 2)
		"bed":
			ellipse(p + Vector2(0, 5), Vector2(65, 38), "ad967f")
			ellipse(p, Vector2(62, 36), "a3b6ad" if "cat" in o.species else "c4967e")
			ellipse(p + Vector2(0, -2), Vector2(45, 23), "d6dfcd" if "cat" in o.species else "e4c8a9")
			for i in range(3): draw_arc(p, 49 + i * 2, 0.1, PI - 0.1, 25, Color("eee3ce"), 1)
		"shelter":
			box(Rect2(p.x - 43, p.y - 35, 86, 62), "c49160", 10)
			draw_colored_polygon(PackedVector2Array([p + Vector2(-54,-30), p + Vector2(0,-72), p + Vector2(54,-30)]), Color("759887"))
			box(Rect2(p.x - 16, p.y - 12, 32, 39), "685244", 15)
			text_at(p + Vector2(-30, -37), "芝麻的家", "fff2d5", 12)
		"cover":
			ellipse(p + Vector2(0, 16), Vector2(48, 20), "b59c7b")
			box(Rect2(p.x - 38, p.y - 54, 76, 67), "759887", 8, "e0d7b9")
			for i in range(5):
				draw_line(p + Vector2(-27 + i * 13, -44), p + Vector2(-27 + i * 13, 5), Color("b5c6aa"), 3)
		"toy":
			ellipse(p + Vector2(2, 12), Vector2(19, 7), "acaa86")
			draw_circle(p, 17, Color("d88470"))
			draw_arc(p, 13, -1.2, 1.9, 24, Color("f4c2a3"), 3)
			draw_line(p + Vector2(-14,-7), p + Vector2(12,10), Color("f4c2a3"), 3)
		"door":
			box(Rect2(p.x - 30, p.y - 93, 61, 160), "8a8067", 5)
			box(Rect2(p.x - 24, p.y - 87, 49, 148), "a5c2a2" if o.open else "c6b394", 3)
			if o.open:
				box(Rect2(p.x - 26, p.y - 86, 14, 148), "aa8b68", 2)
				text_at(p + Vector2(-20,-42), "阳台", "eef5da", 15)
			else:
				draw_circle(p + Vector2(13,0), 4, Color("7a6e55"))
		"view": return
	text_at(p + Vector2(-32, 48 if o.kind != "door" else 89), o.label + (" · 开" if o.kind == "door" and o.open else ""), "796d58", 14)

func draw_animal(a: Dictionary) -> void:
	var profile: Dictionary = world.profiles[a.id]
	var p: Vector2 = a.position
	var watching: bool = a.posture in ["停顿试探", "缩身警戒", "等对方回应", "弓背嘶叫", "站定低吠"]
	var moving: bool = a.phase == "moving" and not watching
	var resting: bool = a.phase == "acting" and a.action in ["rest", "hide"] and not watching
	var eating: bool = a.phase == "acting" and a.action in ["eat", "drink"] and not watching
	var playing: bool = a.phase == "acting" and a.action == "play"
	var bob: float = absf(sin(a.motion)) * 4 if moving else sin(elapsed * 2) * 0.6
	if playing: bob += absf(sin(elapsed * 7)) * 12
	var scale_a: float = profile.size
	var face: float = a.direction
	var color: String = profile.color
	ellipse(p + Vector2(0, 9), Vector2(32, 11) * scale_a, "b6a989")
	if a.id == selected: draw_arc(p + Vector2(0, 6), 35 * scale_a, 0, TAU, 40, Color("f8fff0"), 2.5, true)
	var center: Vector2 = p + Vector2(0, -12 - bob)
	if a.action == "chase": center.y += 5
	if a.posture == "弓背嘶叫": center.y -= 7
	var head: Vector2 = center + Vector2(face * 22, -10 + (9 + sin(elapsed * 7) * 3 if eating else -6 if watching else 0)) * scale_a
	if resting:
		ellipse(center, Vector2(30, 19) * scale_a, color)
		draw_arc(center + Vector2(face * 12, -4), 7 * scale_a, 0, PI, 12, Color("584f47"), 2)
		text_at(center + Vector2(12, -30 - fmod(elapsed * 8, 12)), "z Z", "729a8a", 19)
	else:
		var tail_start: Vector2 = center + Vector2(-face * 24, -3) * scale_a
		var tail_end: Vector2 = tail_start + Vector2(-face * 23, -20 + sin(elapsed * 6) * 8) * scale_a
		draw_line(tail_start, tail_end, Color("ceaaa0" if profile.species == "mouse" else color), 3 if profile.species == "mouse" else 8, true)
		for leg in range(4):
			var x = -17 + (leg % 2) * 32
			var step_offset: float = sin(a.motion + leg * PI) * 7 if moving else 0
			draw_line(center + Vector2(x, 8) * scale_a, center + Vector2(x + step_offset, 24) * scale_a, Color(color), 7 * scale_a, true)
		ellipse(center, Vector2(30, 19) * scale_a, color)
		if profile.species == "cat":
			for stripe in range(3): draw_line(center + Vector2(-14 + stripe * 10, -15) * scale_a, center + Vector2(-18 + stripe * 10, -3) * scale_a, Color("b67c45"), 4 * scale_a, true)
		draw_circle(head, 18 * scale_a, Color(color))
		if profile.species == "cat":
			for ear in [-1, 1]:
				var ep: Vector2 = head + Vector2(ear * 10, -12) * scale_a
				draw_colored_polygon(PackedVector2Array([ep + Vector2(-7,3)*scale_a, ep + Vector2(0,-15)*scale_a, ep + Vector2(7,3)*scale_a]), Color(color))
				text_at(ep + Vector2(-3,-1), "·", "d08c8d", 16)
		elif profile.species == "mouse":
			for ear in [-1, 1]:
				draw_circle(head + Vector2(ear * 12,-14)*scale_a, 11 * scale_a, Color("a9a0a1"))
				draw_circle(head + Vector2(ear * 12,-14)*scale_a, 7 * scale_a, Color("dcb5ad"))
		else:
			ellipse(head + Vector2(-face * 10, 0) * scale_a, Vector2(9, 20) * scale_a, "866149")
			ellipse(head + Vector2(face * 10, 8) * scale_a, Vector2(12, 9) * scale_a, "e7d3b3")
		draw_circle(head + Vector2(face * 7, -3)*scale_a, 2.4 * scale_a, Color("384840"))
		draw_circle(head + Vector2(face * 18, 5)*scale_a, 2.8 * scale_a, Color("745b55"))
		if profile.species in ["cat", "mouse"]:
			for j in [-1, 1]: draw_line(head + Vector2(face*10,7)*scale_a, head + Vector2(face*30,7+j*5)*scale_a, Color("766856"), 1, true)
		if profile.species == "dog": draw_line(head + Vector2(-6,13)*scale_a, head + Vector2(6,16)*scale_a, Color("729b88"), 5, true)
		if a.posture in ["弓背嘶叫", "站定低吠", "前爪扑探"]:
			for i in range(3):
				draw_line(head + Vector2(face * 25, (i - 1) * 9), head + Vector2(face * (32 + sin(elapsed * 12) * 4), (i - 1) * 14), Color("af654b"), 2, true)
	text_at(p + Vector2(-20, -57 * scale_a - bob), profile.name, "3c5747", 16)
	var status: String = a.posture
	if a.id == selected:
		text_at(p + Vector2(-30, -76 * scale_a - bob), status, "725e49", 13)

func draw_panel() -> void:
	box(Rect2(1090, 104, 320, 565), "fffef8", 20)
	text_at(Vector2(1112, 138), "小住客的此刻", "345847", 21)
	var index = 0
	for id in world.animals:
		button(id, world.profiles[id].name, Rect2(1110 + (index % 3) * 94, 151 + (index / 3) * 41, 86, 36), id == selected)
		index += 1
	var a: Dictionary = world.animals[selected]
	var p: Dictionary = world.profiles[selected]
	text_at(Vector2(1112, 255), p.name + "  /  " + p.cohort, "345847", 23)
	text_at(Vector2(1112, 280), "此刻 · " + a.posture, "859082", 16)
	for row in range(4):
		var y = 311 + row * 32
		text_at(Vector2(1112, y), "X%d" % row, "6f7b70", 15)
		box(Rect2(1167, y - 12, 176, 8), "eceee3", 4)
		var value: float = (a.x[row] + 1.5) / 3.0
		box(Rect2(1167, y - 12, maxf(1, value * 176), 8), "91b09a", 4)
		text_at(Vector2(1348, y), "%.2f" % a.x[row], "788777", 12)
	text_at(Vector2(1112, 451), "经历留下的关联", "345847", 18)
	text_at(Vector2(1112, 478), "生活时间  %.1f 分钟" % (a.age / 60.0), "7c887b", 15)
	text_at(Vector2(1112, 502), "感知痕迹  %d  /  32" % a.memory_count, "7c887b", 15)
	text_at(Vector2(1112, 526), "关联幅度  %.4f" % a.association_strength, "7c887b", 15)
	text_at(Vector2(1112, 551), "对抗负荷 %.2f · 身体余波 %.2f" % [a.load,a.strain], "7b877b", 13)
	button("care", "轻轻陪伴", Rect2(1112, 579, 128, 41))
	button("fill", "补满食水", Rect2(1251, 579, 133, 41))
	text_at(Vector2(1112, 646), "维度无心理命名 · 文字仅为外部观察", "9aa293", 13)

func draw_footer() -> void:
	box(Rect2(30, 690, 1380, 175), "e9ecdf", 18)
	text_at(Vector2(52, 724), "屋内见闻", "3d604c", 20)
	text_at(Vector2(1190, 724), "%02d:%02d  ·  %s" % [int(world.time) / 60, int(world.time) % 60, "已暂停" if paused else "生活继续"], "7d8c79", 15)
	for i in range(mini(4, world.events.size())):
		var e: Dictionary = world.events[i]
		text_at(Vector2(55, 754 + i * 26), "%02d:%02d" % [int(e.time) / 60, int(e.time) % 60], "94a18d", 14)
		text_at(Vector2(114, 754 + i * 26), e.text, "566d56" if i == 0 else "84917f", 16)
	text_at(Vector2(39, 889), "SPACE 暂停  ·  猫鼠追逐不会造成伤害；鼠屋为独立安全区  ·  无需联网或语言模型", "929987", 13)
