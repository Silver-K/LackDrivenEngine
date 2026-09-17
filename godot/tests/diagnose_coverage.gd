extends SceneTree
## Diagnostic ablations, not a requirement to visit every part of the room.
const Experiment = preload("res://scripts/room_experiment.gd")
func _initialize() -> void:
 var results: Array = []
 for variant in ["empty", "A", "paired", "full", "empty_center", "A_frozen", "empty_no_exploration"]:
  var lab=Experiment.new()
  lab.set_stage({"empty":0,"A":1,"paired":2,"full":3,"empty_center":0,"A_frozen":1,"empty_no_exploration":0}[variant])
  if variant=="empty_center": lab.simulation.bodies[0].position=Vector2(548.5,430)
  if variant=="A_frozen": lab.simulation.parameters[0].plasticity_enabled=false
  if variant=="empty_no_exploration": lab.simulation.parameters[0].locomotion.gain=0.0
  var minimum=INF
  var maximum=-INF
  var right_ticks=0
  var bins=[0,0,0,0,0,0,0,0]
  var contacts={}
  var checkpoints: Array=[]
  for tick in range(18000):
   lab.step(1.0/60.0)
   var body: Dictionary=lab.simulation.bodies[0]
   minimum=minf(minimum,body.position.x)
   maximum=maxf(maximum,body.position.x)
   if body.position.x>548.5: right_ticks+=1
   var bin_index=clampi(int((body.position.x-72)/953.0*8),0,7)
   bins[bin_index]+=1
   if body.touch>=0: contacts[body.touch]=true
   if (tick+1)%3600==0: checkpoints.append({"seconds":(tick+1)/60,"min_x":minimum,"max_x":maximum,"right_fraction":float(right_ticks)/(tick+1)})
  var result={"variant":variant,"min_x":minimum,"max_x":maximum,"right_fraction":float(right_ticks)/18000,"horizontal_bins":bins,"contacts":contacts,"checkpoints":checkpoints}
  results.append(result)
  print(JSON.stringify(result))
 FileAccess.open("res://../artifacts/coverage-after.json",FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
 quit()
