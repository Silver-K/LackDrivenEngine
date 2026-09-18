extends SceneTree
## One physical schedule change per variant; all forks preserve complete experience.
const Comparison=preload("res://scripts/experience_comparison.gd")
const BASE="res://../artifacts/experience-comparison"
const OUTPUT="res://../artifacts/experience-schedule-control"
const VARIANTS=[
 {"id":"early_withdrawal","fork_after":0,"ticks":[14400,2880,14400,7200]},
 {"id":"long_withdrawal","fork_after":1,"ticks":[14400,7200,28800,7200]},
 {"id":"long_recovery","fork_after":2,"ticks":[14400,7200,14400,14400]}
]
var failures: Array=[]
func check(ok: bool, message: String) -> void:
 if not ok: failures.append(message)

func same_sources() -> bool:
 var manifest=JSON.parse_string(FileAccess.get_file_as_string(BASE+"/manifest.json"))
 if not manifest is Dictionary or not manifest.get("sources") is Array: return false
 for item in manifest.sources:
  if FileAccess.get_sha256("res://../"+item.path).to_lower()!=item.sha256.to_lower():
   push_error("Source differs from reference: "+item.path)
   return false
 return true

func fork(reference, variant: Dictionary):
 var data=reference.snapshot()
 data.durations=variant.ticks.duplicate()
 data.phase=variant.fork_after+1
 data.phase_tick=0
 data.completed=false
 data.running=true
 data.error=""
 for b in data.branches:
  b.room=b.checkpoints[variant.fork_after].snapshot.duplicate(true)
  b.checkpoints=b.checkpoints.slice(0,variant.fork_after+1)
  b.stats=reference.new_stats()
  b.samples=b.samples.filter(func(s): return s.time<=b.room.time+0.000001)
 var run=Comparison.new()
 if not run.restore(data): return null
 for index in range(run.branches.size()):
  check(var_to_str(run.branches[index].lab.snapshot())==var_to_str(reference.branches[index].checkpoints[variant.fork_after].snapshot),variant.id+" exact full-state fork")
 return run

func rows(run, reference) -> Array:
 var result: Array=[]
 for branch_index in range(run.branches.size()):
  var b: Dictionary=run.branches[branch_index]
  var phases: Array=[]
  for phase_index in range(b.checkpoints.size()):
   var cp: Dictionary=b.checkpoints[phase_index]
   var original: Dictionary=reference.branches[branch_index].checkpoints[phase_index]
   phases.append({"phase":phase_index,"time":cp.snapshot.time,"force":cp.probe.first_learned_force,"force_magnitude":cp.probe.first_learned_force.length(),"probe_displacement":cp.probe.displacement,"memory_distance_from_reference":run.memory_distance(cp.snapshot.bodies[0].memory,original.snapshot.bodies[0].memory),"stats":cp.stats.duplicate(true)})
  result.append({"branch":b.id,"phases":phases})
 return result

func _initialize() -> void:
 if not same_sources():
  push_error("Reference no longer matches current implementation; regenerate the reference first.")
  quit(1)
  return
 var reference=Comparison.new()
 if not reference.load_file(BASE+"/branches.bin") or not reference.completed:
  push_error("Cannot load completed reference")
  quit(1)
  return
 var original=var_to_str(reference.snapshot())
 for b in reference.branches:
  for cp in b.checkpoints:
   check(reference.probe_memory(cp.snapshot.parameters[0],cp.snapshot.bodies[0].memory)==cp.probe,"reference probe recomputes exactly")
 if not failures.is_empty():
  push_error(str(failures))
  quit(1)
  return
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
 var report={"reference_sources_verified":true,"reference_probes_recomputed":12,"reference_ticks":reference.durations.duplicate(),"reference":rows(reference,reference),"variants":[]}
 for variant in VARIANTS:
  var run=fork(reference,variant)
  if run==null:
   push_error("Cannot fork "+variant.id)
   quit(1)
   return
  var directory=OUTPUT+"/"+variant.id
  DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
  var previous_phase: int=run.phase
  var matching_samples=0
  while run.running:
   run.advance(60)
   # At the old phase duration, the extended phase must still match its original full body.
   if variant.id in ["long_withdrawal","long_recovery"] and run.phase==variant.fork_after+1 and run.phase_tick==reference.durations[run.phase]:
    for index in range(run.branches.size()):
     check(var_to_str(run.branches[index].lab.snapshot())==var_to_str(reference.branches[index].checkpoints[run.phase].snapshot),variant.id+" unchanged prefix matches reference")
   if run.phase!=previous_phase:
    check(run.save_file(directory+"/branches.bin"),variant.id+" checkpoint saves")
    print("SCHEDULE_PHASE ",variant.id," ",run.phase)
    previous_phase=run.phase
  check(run.completed and run.error.is_empty(),variant.id+" completes")
  # Before the changed schedule can have an effect, each one-second sample is identical.
  var shared_seconds=0.0
  for p in range(variant.fork_after+1): shared_seconds+=variant.ticks[p]/60.0
  shared_seconds+=minf(variant.ticks[variant.fork_after+1],reference.durations[variant.fork_after+1])/60.0
  for index in range(run.branches.size()):
   for s in range(int(shared_seconds)):
    check(run.branches[index].samples[s]==reference.branches[index].samples[s],variant.id+" identical observed prefix")
    matching_samples+=1
  var reloaded=Comparison.new()
  check(reloaded.load_file(directory+"/branches.bin") and var_to_str(reloaded.snapshot())==var_to_str(run.snapshot()),variant.id+" disk round trip")
  check(run.export_report(directory+"/report.txt"),variant.id+" summary exports")
  var record_file=FileAccess.open(directory+"/records.json",FileAccess.WRITE)
  if record_file==null:
   push_error("Cannot write records")
   quit(1)
   return
  record_file.store_string(JSON.stringify(run.snapshot()))
  record_file.close()
  report.variants.append({"id":variant.id,"fork_after":variant.fork_after,"ticks":variant.ticks,"matching_prefix_samples":matching_samples,"rows":rows(run,reference)})
  print("SCHEDULE_COMPLETE ",variant.id," ",JSON.stringify(report.variants[-1]))
 check(original==var_to_str(reference.snapshot()),"reference history remains unchanged")
 report.failures=failures
 var file=FileAccess.open(OUTPUT+"/comparison.json",FileAccess.WRITE)
 if file==null:
  quit(1)
  return
 file.store_string(JSON.stringify(report,"  "))
 print("SCHEDULE_CONTROL_RESULT failures=",failures.size())
 quit(0 if failures.is_empty() else 1)
