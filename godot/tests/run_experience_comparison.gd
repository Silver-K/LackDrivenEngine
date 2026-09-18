extends SceneTree
const Comparison=preload("res://scripts/experience_comparison.gd")
const DIRECTORY="res://../artifacts/experience-comparison"
func _initialize() -> void:
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIRECTORY))
 var run=Comparison.new()
 if "--resume" in OS.get_cmdline_user_args():
  if not run.load_file(DIRECTORY+"/branches.bin"):
   push_error("Cannot restore experience comparison")
   quit(1)
   return
  run.running=not run.completed and run.error.is_empty()
 else: run.begin()
 var previous_phase=run.phase
 while run.running:
  run.advance(60)
  if run.phase!=previous_phase:
   if not run.save_file(DIRECTORY+"/branches.bin"):
    push_error("Cannot save experience branches")
    quit(1)
    return
   print("EXPERIENCE_PHASE_COMPLETE ",run.phase)
   previous_phase=run.phase
 if not run.error.is_empty():
  push_error(run.error)
  quit(1)
  return
 if not run.completed:
  quit(1)
  return
 if not run.export_report(DIRECTORY+"/report.txt"):
  quit(1)
  return
 var report=run.snapshot()
 FileAccess.open(DIRECTORY+"/records.json",FileAccess.WRITE).store_string(JSON.stringify(report))
 print(run.summary())
 print("EXPERIENCE_COMPARISON_RESULT completed=",run.completed)
 quit(0)
