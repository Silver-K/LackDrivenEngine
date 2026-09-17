extends Control
## Resolution-independent native CanvasItem illustration, no blurred web texture.
signal person_selected(id: String)
var selected: String = "shen"
var elapsed: float = 0
var away: bool = false
var living: Dictionary = {}
var font: Font

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(0, 260)
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"])
	set_process(true)

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()

func rect(x: float, y: float, w: float, h: float, color: String) -> void:
	draw_rect(Rect2(x, y, w, h), Color(color))

func line(a: Vector2, b: Vector2, color: String, width: float = 2) -> void:
	draw_line(a, b, Color(color), width, true)

func _draw() -> void:
	var sx = size.x / 1000.0
	var sy = size.y / 350.0
	draw_set_transform(Vector2.ZERO, 0, Vector2(sx, sy))
	rect(0, 0, 1000, 350, "21343c")
	rect(0, 275, 1000, 75, "594b3a")
	for i in range(5):
		line(Vector2(0, 281 + i * 18), Vector2(1000, 275 + i * 18), "776047", 1)
	for x in [25, 360, 805, 975]:
		rect(x, 0, 12, 280, "142731")
	# Rain window, enough contrast to read silhouettes and props.
	rect(55, 31, 280, 190, "b2986c")
	rect(62, 38, 266, 176, "355970")
	for i in range(6):
		rect(64 + i * 46, 128 + (i % 3) * 13, 35, 84, "253d50")
		rect(74 + i * 46, 147 + (i % 3) * 13, 8, 15, "d7ba7b")
	for i in range(30):
		var rx: float = 68 + fmod(i * 59, 250)
		var ry: float = 42 + fmod(i * 33 + elapsed * 53, 164)
		line(Vector2(rx, ry), Vector2(rx - 3, minf(211, ry + 13)), "8eafb9", 1)
	rect(190, 36, 7, 180, "9b825b")
	rect(58, 115, 274, 6, "9b825b")
	rect(48, 219, 295, 9, "b79c6b")
	# Shelf and bottles.
	for shelf_y in [83, 143]:
		rect(428, shelf_y, 297, 8, "c09b63")
		for i in range(8):
			var bx: float = 438 + i * 34
			rect(bx + 5, shelf_y - 42, 8, 12, "b0c7aa")
			rect(bx, shelf_y - 31, 19, 31, "739b88" if i % 2 == 0 else "b78c55")
			rect(bx + 2, shelf_y - 17, 15, 9, "e8d8ab")
	# Pendant lamp.
	line(Vector2(568, 0), Vector2(568, 28), "d2b884", 3)
	draw_colored_polygon(PackedVector2Array([Vector2(545, 28), Vector2(593, 28), Vector2(608, 53), Vector2(530, 53)]), Color("bf9960"))
	rect(537, 53, 63, 5, "ffe3a2")
	# Stopped clock.
	draw_circle(Vector2(769, 67), 31, Color("ac8c5c"), true, -1, true)
	draw_circle(Vector2(769, 67), 25, Color("e5d9b8"), true, -1, true)
	line(Vector2(769, 67), Vector2(754, 63), "354045", 3)
	line(Vector2(769, 67), Vector2(787, 70), "354045", 2)
	# Native portraits and body silhouettes.
	_person(Vector2(574, 172), "shen", "6f8d89", "263d43")
	_person(Vector2(206, 218), "lin", "9bbbaa", "233d46")
	_person(Vector2(833, 224), "zhou", "b59a72", "cbd2c4")
	# Bar and foreground table.
	rect(403, 217, 350, 13, "d2ae76")
	rect(414, 230, 329, 78, "785d40")
	for x in [431, 535, 639]:
		draw_rect(Rect2(x, 243, 86, 50), Color("aa8557"), false, 2)
	rect(406, 304, 342, 9, "372f29")
	draw_ellipse_custom(Vector2(207, 278), Vector2(110, 20), Color("c49e69"))
	line(Vector2(144, 284), Vector2(136, 344), "967243", 8)
	line(Vector2(263, 284), Vector2(272, 344), "967243", 8)
	draw_colored_polygon(PackedVector2Array([Vector2(199, 263), Vector2(240, 259), Vector2(267, 277), Vector2(221, 283)]), Color("e5dbc0"))
	line(Vector2(221, 266), Vector2(249, 276), "667c78", 2)
	for pos in [Vector2(473, 205), Vector2(652, 205), Vector2(162, 259)]:
		rect(pos.x, pos.y, 17, 16, "efe5c9")
		line(pos + Vector2(5, -3), pos + Vector2(4 + sin(elapsed) * 2, -16), "c0cdbb", 1)
	# Fireplace and glow.
	rect(902, 173, 82, 134, "8e8e79")
	rect(913, 194, 60, 103, "182833")
	var flicker: float = sin(elapsed * 4) * 5
	draw_colored_polygon(PackedVector2Array([Vector2(920, 291), Vector2(924, 246 + flicker), Vector2(939, 262), Vector2(950, 220 - flicker), Vector2(964, 274), Vector2(958, 294)]), Color("edab50"))
	draw_colored_polygon(PackedVector2Array([Vector2(931, 292), Vector2(940, 263), Vector2(947, 279), Vector2(952, 266), Vector2(958, 294)]), Color("ffe6a0"))
	rect(893, 166, 96, 10, "c7b17e")
	rect(896, 301, 92, 12, "b4a17a")
	# Wooden chair and white envelope make story objects visible.
	rect(535, 208, 31, 10, "eee0b8")
	line(Vector2(535, 208), Vector2(550, 216), "a5906e", 1)
	line(Vector2(566, 208), Vector2(550, 216), "a5906e", 1)
	if away:
		draw_rect(Rect2(0, 0, 1000, 350), Color(0.1, 0.2, 0.3, 0.25))
	draw_set_transform(Vector2.ZERO)
	var labels = [["lin", "林遥 · 窗边", 0.205], ["shen", "沈砚 · 吧台", 0.575], ["zhou", "周叔 · 炉边", 0.832]]
	for item in labels:
		var pos = Vector2(size.x * item[2] - 61, size.y - 37)
		var box = Rect2(pos, Vector2(122, 29))
		draw_style_box(_tag(item[0] == selected), box)
		draw_string(font, pos + Vector2(12, 21), (item[1].split(" · ")[0] + " · " + str(living.get(item[0], {}).get("life", {}).get("place", item[1].split(" · ")[1]))), HORIZONTAL_ALIGNMENT_LEFT, 108, 16, Color("fff0c6") if item[0] == selected else Color("e7eef0"))

func draw_ellipse_custom(center: Vector2, radius: Vector2, color: Color) -> void:
	var points = PackedVector2Array()
	for i in range(48):
		var angle: float = TAU * i / 48.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(points, color)

func _person(pos: Vector2, id: String, shirt: String, hair: String) -> void:
	var location = living.get(id, {}).get("life", {}).get("place", "")
	if not location.is_empty():
		var destination = {"窗边": Vector2(206, 218), "吧台": Vector2(574, 172), "炉边": Vector2(760, 224)}.get(location, pos)
		pos = destination + Vector2({"shen": -66, "lin": 0, "zhou": 66}[id], 0)
	var breath = sin(elapsed * 1.5 + pos.x) * 1.3
	pos.y += breath
	draw_colored_polygon(PackedVector2Array([pos + Vector2(-40, 55), pos + Vector2(-34, 8), pos + Vector2(-19, -2), pos + Vector2(21, -2), pos + Vector2(37, 12), pos + Vector2(43, 57)]), Color(shirt))
	rect(pos.x - 9, pos.y - 11, 18, 20, "caa886")
	draw_ellipse_custom(pos + Vector2(0, -29), Vector2(23, 31), Color("d9b795"))
	draw_colored_polygon(PackedVector2Array([pos + Vector2(-24, -23), pos + Vector2(-25, -49), pos + Vector2(-10, -62), pos + Vector2(14, -60), pos + Vector2(25, -44), pos + Vector2(24, -24), pos + Vector2(15, -44), pos + Vector2(-14, -40), pos + Vector2(-15, -22)]), Color(hair))
	line(pos + Vector2(-13, -27), pos + Vector2(-6, -27), "454b49", 2)
	line(pos + Vector2(6, -27), pos + Vector2(13, -27), "454b49", 2)
	line(pos + Vector2(-4, -12), pos + Vector2(7, -12), "98795f", 2)
	if id == "shen":
		draw_colored_polygon(PackedVector2Array([pos + Vector2(-20, 13), pos + Vector2(20, 13), pos + Vector2(25, 56), pos + Vector2(-25, 56)]), Color("b49a6a"))
	if id == "zhou":
		line(pos + Vector2(-9, -14), pos + Vector2(9, -11), "bfc5ad", 3)
	line(pos + Vector2(-28, 15), pos + Vector2(-36, 41), shirt, 13)
	line(pos + Vector2(-36, 41), pos + Vector2(2, 50), "d9b795", 9)
	line(pos + Vector2(30, 15), pos + Vector2(39, 41), shirt, 13)
	line(pos + Vector2(39, 41), pos + Vector2(7, 50), "d9b795", 9)

func _tag(active: bool) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color("635536") if active else Color("172c38")
	style.border_color = Color("e9c57b") if active else Color("718c98")
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	return style

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var x: float = event.position.x / size.x
		person_selected.emit("lin" if x < 0.38 else "shen" if x < 0.72 else "zhou")
