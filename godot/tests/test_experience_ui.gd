extends SceneTree
const View=preload("res://scripts/room_view.gd")
var checks=0
var failures=0
func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok: failures+=1
 print("PASS " if ok else "FAIL ",message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var view=View.new()
 root.add_child(view)
 view.set_process(false)
 view.size=Vector2(1440,900)
 view.comparison_path="user://test-experience-ui.bin"
 view.comparison_report="user://test-experience-ui.txt"
 await process_frame
 var initial=var_to_str(view.experiment.snapshot())
 var click=InputEventMouseButton.new()
 click.button_index=MOUSE_BUTTON_LEFT
 click.pressed=true
 click.position=Vector2(780,100)
 view._gui_input(click)
 check(view.detail_mode=="experience" and view.paused and view.details.visible,"experience entry opens isolated panel and pauses live room")
 view.handle_action("experience_start")
 check(view.comparison.running and view.comparison.branches.size()==3,"start control creates three histories")
 view._process(1.0/60.0)
 check(view.comparison.phase_tick>0,"UI advances isolated histories in bounded frame work")
 for action in ["reset","stage3","load","probe","case0"]: view.handle_action(action)
 check(initial==var_to_str(view.experiment.snapshot()) and view.detail_mode=="experience","live controls and other detail routes cannot mutate the room during comparison")
 view.handle_action("experience_pause")
 var paused=var_to_str(view.comparison.snapshot())
 view._process(1.0/60.0)
 check(paused==var_to_str(view.comparison.snapshot()),"comparison pause freezes all branch clocks")
 view.handle_action("experience_save")
 view.handle_action("experience_start")
 view.handle_action("experience_load")
 check(paused==var_to_str(view.comparison.snapshot()) and not view.comparison.running,"load restores saved histories and remains paused")
 view.handle_action("experience_export")
 check(FileAccess.get_file_as_string(view.comparison_report).contains("解释边界"),"export contains readable conclusions and limitations")
 view.handle_action("experience_pause")
 view.handle_action("close_details")
 check(view.detail_mode.is_empty() and not view.paused and not view.comparison.running,"return restores original live pause state and stops hidden comparison")
 check(initial==var_to_str(view.experiment.snapshot()),"whole interaction preserves live history exactly")
 view.handle_action("experience")
 view.comparison.begin([60,60,60,60])
 while view.comparison.running: view.comparison.advance(60)
 view.refresh_details()
 check(view.details.text.contains("四段经历对照已完成") and view.details.text.contains("恢复机械扰动"),"completed report is available in the in-app panel")
 view.queue_free()
 print("EXPERIENCE_UI_RESULT checks=",checks," failures=",failures)
 quit(1 if failures else 0)
