extends SceneTree
const View=preload("res://scripts/room_view.gd")
var checks=0
var failures=0
func check(ok: bool, label: String) -> void:
 checks+=1
 if not ok: failures+=1
 print("PASS " if ok else "FAIL ",label)
func permanent(memory: Array) -> Array:
 return memory.map(func(v):return [v.get("pattern",""),v.effect,v.exposure,v.updates])
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var view=View.new()
 root.add_child(view)
 view.paused=true
 await process_frame
 view.handle_action("checkpoint")
 var initial=var_to_str(view.experiment.simulation.bodies)
 view.handle_action("train_pair")
 check(initial==var_to_str(view.experiment.simulation.bodies),"combination preset changes physical apparatus only")
 check(view.experiment.simulation.surfaces.slice(0,5).all(func(o):return not o.active) and view.experiment.simulation.surfaces[5].emission==[0.8,0.0,0.8],"isolated compound training disables exchange sources")
 for tick in range(3600): view.experiment.step(1.0/60.0)
 var scene=var_to_str(view.experiment.snapshot())
 view.handle_action("inspect")
 view.refresh_details()
 check(view.details.text.contains("独立贡献") and var_to_str(view.experiment.snapshot())==scene,"causal inspection reads committed snapshots without mutation")
 view.handle_action("close_details")
 view.handle_action("probe")
 check(view.probe.results.size()==4 and view.paused,"four frozen feature probes run in isolated worlds")
 check(var_to_str(view.experiment.snapshot())==scene,"probing preserves complete live state and apparatus history")
 var first_results=var_to_str(view.probe.results)
 var expected=permanent(view.experiment.simulation.bodies[0].memory)
 var frozen=true
 for row in view.probe.results:
  frozen=frozen and permanent(row.pair[1].last.memory)==expected
  frozen=frozen and row.pair[0].first.sensory_snapshot==row.pair[1].first.sensory_snapshot
 check(frozen,"probes preserve long-term memory and receive equal first-step sensation")
 var keys=[]
 for row in view.probe.results:
  keys.append(row.pair[1].first.pattern_samples.map(func(v):return v.pattern))
 check(keys[0].size()==1 and keys[1].size()==1 and keys[2].size()==3 and keys[3].size()==2,"simple and compound tests select permitted patterns without inventing R+Q conjunction")
 view.handle_action("case0")
 check(view.details.text.contains("当前记忆 · P ·"),"case controls select detailed causal record")
 view.handle_action("reset")
 check(var_to_str(view.experiment.snapshot())==scene,"live controls cannot mutate scene while probing")
 view.handle_action("close_details")
 check(view.paused and not view.details.visible,"return restores original pause state")
 view.handle_action("probe")
 check(var_to_str(view.probe.results)==first_results,"repeat probes restart identical short-term and physical state")
 view.handle_action("close_details")
 var stored=view.experiment.snapshot()
 check(view.experiment.restore(stored) and var_to_str(view.experiment.snapshot())==scene,"save schema preserves compound apparatus setting")
 view.handle_action("stage3")
 check(not view.experiment.combination_training and view.experiment.simulation.surfaces.all(func(o):return o.active),"return to free environment restores exchange and occlusion")
 var report=view.probe.summary()
 FileAccess.open("res://../artifacts/probe-comparison.txt",FileAccess.WRITE).store_string(report)
 print(report)
 view.queue_free()
 print("PROBE_UI_RESULT checks=",checks," failures=",failures)
 quit(1 if failures else 0)

