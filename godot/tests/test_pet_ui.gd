extends SceneTree
const House = preload("res://scripts/pet_house.gd")
var failures = 0
func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok: failures += 1
func click(ui, point: Vector2) -> void:
	var event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = point
	ui._gui_input(event)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var ui = House.new()
	root.add_child(ui)
	ui.size = Vector2(1440, 900)
	await process_frame
	await process_frame
	click(ui, Vector2(1020, 365))
	check(ui.world.objects.door.open, "door responds to scene click")
	ui.world.objects.water.stock = 0
	click(ui, Vector2(790, 450))
	check(ui.world.objects.water.stock == 100, "water click refills bowl")
	click(ui, ui.world.animals.bao.position + Vector2(0, -15))
	check(ui.selected == "bao", "animal click selects subject")
	click(ui, Vector2(1070, 50))
	var before: float = ui.world.time
	ui._process(0.2)
	check(ui.paused and ui.world.time == before, "pause button freezes simulation")
	click(ui, Vector2(1180, 50))
	check(ui.speed == 3, "speed button changes simulation rate")
	click(ui, Vector2(1150, 210))
	check(ui.selected == "seed_a", "second row selects untrained subject")
	ui.size = Vector2(1180, 760)
	var factor: float = 1180.0 / 1440.0
	var screen: Vector2 = Vector2(1020, 365) * factor + (ui.size - Vector2(1440, 900) * factor) / 2
	click(ui, screen)
	check(not ui.world.objects.door.open, "resized viewport preserves hit testing")
	print("UI_RESULT checks=7 failures=", failures)
	quit(1 if failures else 0)
