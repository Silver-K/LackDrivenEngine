extends SceneTree
const Comparison=preload("res://scripts/experience_comparison.gd")
var checks=0
var failures=0
func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok: failures+=1
 print("PASS " if ok else "FAIL ",message)
func _initialize() -> void:
 var run=Comparison.new()
 check(run.begin([1440,180,180,180]),"experience protocol starts with bounded integer durations")
 var initial=var_to_str(run.branches[0].lab.simulation.bodies)
 check(run.branches.all(func(b):return var_to_str(b.lab.simulation.bodies)==initial and b.lab.simulation.bodies[0].memory.is_empty()),"three branches share the same initial body and blank associations")
 var state=var_to_str(run.branches[0].lab.snapshot())
 run.branches[1].lab.simulation.surfaces[5].field_strength=8.0
 check(var_to_str(run.branches[0].lab.snapshot())==state,"branches have independent physical and subject state")
 for branch in run.branches:
  var world=branch.lab.simulation
  var body=var_to_str(world.bodies)
  var definition=var_to_str(world.parameters)
  run.configure(world,branch.id,0,0)
  check(world.surfaces[5].emission==run.FEATURES and world.surfaces[5].field_strength==0,"each history starts with the same physical cue")
  run.configure(world,branch.id,0,90)
  check(world.surfaces[5].field_strength==(2.0 if branch.id=="paired" else 0.0),"short interval changes apparatus timing only")
  run.configure(world,branch.id,0,720)
  check(world.surfaces[5].field_strength==(2.0 if branch.id=="delayed" else 0.0),"long interval exceeds the subject trace window")
  run.configure(world,branch.id,1,90)
  check(world.surfaces[5].field_strength==2.0,"all histories enter the same later physical schedule")
  run.configure(world,branch.id,2,90)
  check(world.surfaces[5].field_strength==0.0,"changed relation removes mechanical field")
  check(body==var_to_str(world.bodies) and definition==var_to_str(world.parameters),"apparatus never injects tension memory position velocity or learning permissions")
 run.advance(1379)
 run.running=false
 var paused=var_to_str(run.snapshot())
 run.advance(60)
 check(paused==var_to_str(run.snapshot()),"paused protocol does not advance")
 run.running=true
 check(run.save_file("user://test-experience-comparison.bin"),"complete branch state saves to disk")
 var restored=Comparison.new()
 check(restored.load_file("user://test-experience-comparison.bin"),"complete branch state loads from disk")
 check(var_to_str(run.snapshot())==var_to_str(restored.snapshot()),"saved body memory apparatus and protocol clocks restore exactly")
 while run.running: run.advance(71)
 while restored.running: restored.advance(133)
 check(run.completed and run.error.is_empty(),"all four protocol phases complete without body errors")
 check(var_to_str(run.snapshot())==var_to_str(restored.snapshot()),"resumed history is identical across phase boundaries and different frame batches")
 check(run.save_file("user://test-experience-comparison.bin") and restored.load_file("user://test-experience-comparison.bin") and restored.completed,"atomic save replaces an earlier checkpoint and restores a completed run")
 var frozen=true
 var equal_input=true
 var raw_contributions=true
 for index in range(4):
  for branch in run.branches:
   var cp=branch.checkpoints[index]
   frozen=frozen and run.permanent(cp.snapshot.bodies[0].memory)==run.permanent(cp.probe.last.memory) and cp.probe.permanent_unchanged
   equal_input=equal_input and cp.probe.first.sensory_snapshot==run.branches[0].checkpoints[index].probe.first.sensory_snapshot
   raw_contributions=raw_contributions and not cp.probe.first.contributions.is_empty() and cp.snapshot.bodies[0].has("contributions")
 check(frozen,"every phase probe preserves permanent trained memory")
 check(equal_input,"each equal-state probe receives identical first-step sensation")
 check(raw_contributions,"checkpoints and probes retain unmerged source contributions")
 var saved=var_to_str(run.snapshot())
 var text=run.summary()
 check(text.contains("解释边界") and text.contains("形成不同经历") and text.contains("恢复机械扰动"),"plain summary describes observations and their limits")
 check(saved==var_to_str(run.snapshot()),"reading the summary has no state effects")
 var invalid=run.snapshot()
 invalid.version=0
 check(not restored.restore(invalid),"incompatible protocol version rejected")
 invalid=run.snapshot()
 invalid.phase_tick=2
 check(not restored.restore(invalid),"inconsistent completed clock rejected")
 invalid=run.snapshot()
 invalid.branches.pop_back()
 check(not restored.restore(invalid),"missing history branch rejected")
 invalid=run.snapshot()
 invalid.branches[1].room.parameters[0].speed+=1
 check(not restored.restore(invalid),"incompatible subject definitions cannot masquerade as history-only comparison")
 invalid=run.snapshot()
 invalid.running="yes"
 check(not restored.restore(invalid),"invalid execution flag rejected")
 invalid=run.snapshot()
 invalid.branches[0].checkpoints[0].probe={}
 check(not restored.restore(invalid),"incomplete stored probe rejected before displaying conclusions")
 invalid=run.snapshot()
 invalid.branches[0].stats.signal_dose=NAN
 check(not restored.restore(invalid),"nonfinite stored measurements rejected")
 check(saved==var_to_str(restored.snapshot()),"failed restore preserves the loaded experiment")
 check(not run.begin([0,180,180,180]) and saved==var_to_str(run.snapshot()),"invalid restart leaves existing history intact")
 print("EXPERIENCE_TEST_RESULT checks=",checks," failures=",failures)
 quit(1 if failures else 0)
