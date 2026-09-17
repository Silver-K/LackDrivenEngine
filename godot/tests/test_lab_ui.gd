extends SceneTree
const View = preload("res://scripts/room_view.gd")
var failures=0
var checks=0
func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok: failures+=1
 print("PASS " if ok else "FAIL ",message)
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var view=View.new()
 root.add_child(view)
 view.size=Vector2(1440,900)
 view.paused=true
 await process_frame
 await process_frame
 var click=InputEventMouseButton.new()
 click.button_index=MOUSE_BUTTON_LEFT
 click.pressed=true
 click.position=Vector2(900,155)
 view._gui_input(click)
 check(view.experiment.stage==3 and view.experiment.simulation.surfaces.all(func(o):return o.active),"fourth stage enables both exchanges cover and apparatus")
 view.size=Vector2(1180,760)
 click.position=Vector2(80,155)*view.canvas_scale()
 view._gui_input(click)
 check(view.experiment.stage==0,"scaled window hit testing selects the visible stage")
 var state=var_to_str(view.experiment.simulation.bodies)
 for action in ["cue","exchange","move","source","vectors"]: view.handle_action(action)
 check(view.experiment.cue_only and not view.experiment.exchange_enabled and view.experiment.relocated and not view.experiment.moving_source and not view.show_vectors,"experiment switches route to actual apparatus state")
 check(var_to_str(view.experiment.simulation.bodies)==state,"UI controls never inject a psychological state")
 view.handle_action("speed")
 check(view.speed==4,"simulation speed changes to four times")
 view.experiment.step(0.1)
 view.handle_action("reset")
 check(view.experiment.simulation.time==0 and view.experiment.simulation.bodies[0].memory.is_empty(),"UI resets experience")
 view.handle_action("pause")
 check(not view.paused,"pause control resumes time")
 view.queue_free()
 print("UI_RESULT checks=",checks," failures=",failures)
 quit(1 if failures else 0)
