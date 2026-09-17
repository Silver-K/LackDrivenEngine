extends SceneTree
const Experiment=preload("res://scripts/room_experiment.gd")
var checks=0
var failures=0
func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok: failures+=1
 print("PASS " if ok else "FAIL ",message)
func _initialize() -> void:
 var lab=Experiment.new()
 var w=lab.simulation
 var p=w.parameters[0]
 var zero=w.structure.initial(p)
 zero.x.fill(0.0)
 zero.motor_state.change=[0,0,0,0]
 var output=w.structure.motor_dynamics.emit(p.locomotion,zero)
 check(output.all(func(c):return c.value==Vector2.ZERO if c.channel==0 else c.value==0),"zero state has no tonic propulsion or independent turning")
 var sources=[{"source":[4,0],"channel":0,"value":Vector2(.4,0)}]
 var active=w.structure.initial(p)
 var disabled=active.duplicate(true)
 var no_adaptation=p.duplicate(true)
 no_adaptation.body_response.use_gain=0
 no_adaptation.body_response.load_gain=0
 var longest=0.0
 var duration=0.0
 var resumed=false
 var once_low=false
 for tick in range(18000):
  w.physics.step(active,p,[],sources,1.0/60.0)
  w.physics.step(disabled,no_adaptation,[],sources,1.0/60.0)
  if active.velocity.length()<1.0:
   duration+=1.0/60.0
   longest=maxf(longest,duration)
   once_low=true
  else:
   if once_low and active.velocity.length()>10: resumed=true
   duration=0.0
 check(longest>5 and resumed,"constant input produces sustained low activity and recovery without timers")
 check(disabled.velocity.length()>20 and disabled.strain==0,"removing use-dependent adaptation removes the pause under the same input")
 var quiet=w.structure.initial(p)
 quiet.activation=.01
 quiet.strain=.5
 var feedback=w.physics.step(quiet,p,[],[],.1)
 check(quiet.strain<.5 and quiet.velocity.length()==0,"no drive permits load recovery without creating motion")
 var pushed=quiet.duplicate(true)
 var source=w.surfaces[5].duplicate(true)
 source.position=pushed.position-Vector2(60,0)
 source.active=true
 source.field_strength=2
 w.physics.step(pushed,p,[source],[],.1)
 check(pushed.velocity.length()>1,"low motor activity does not block external physical displacement")
 var opposed=w.structure.initial(p)
 var calm=opposed.duplicate(true)
 var conflict=[{"source":[4,0],"channel":0,"value":Vector2(.4,0)},{"source":[4,1],"channel":0,"value":Vector2(-.4,0)}]
 w.physics.step(opposed,p,[],conflict,.1)
 w.physics.step(calm,p,[],[],.1)
 check(opposed.velocity==calm.velocity and opposed.load>calm.load and opposed.strain>calm.strain,"stillness from opposition differs from no-drive stillness")
 var checkpoint=Experiment.new()
 checkpoint.set_stage(0)
 for tick in range(3600): checkpoint.step(1.0/60.0)
 var copy=Experiment.new()
 check(copy.restore(checkpoint.snapshot()),"adaptation and execution state restore with history")
 for tick in range(1200):
  checkpoint.step(1.0/60.0)
  copy.step(1.0/60.0)
 check(var_to_str(copy.snapshot())==var_to_str(checkpoint.snapshot()),"adaptation history resumes exactly")
 var rows: Array=[]
 for stage in range(4):
  var run=Experiment.new()
  run.set_stage(stage)
  var low=0.0
  var maximum=0.0
  var total_low=0.0
  var extent=Rect2(run.simulation.bodies[0].position,Vector2.ZERO)
  for tick in range(3600):
   run.step(1.0/60.0)
   var body=run.simulation.bodies[0]
   extent=extent.expand(body.position)
   if body.velocity.length()<1:
    low+=1.0/60.0
    total_low+=1.0/60.0
    maximum=maxf(maximum,low)
   else: low=0
  rows.append({"stage":stage+1,"longest_below_1px_s":maximum,"total_below_1px_s":total_low,"extent":str(extent)})
  check(run.simulation.bodies[0].position.is_finite(),"stage %d remains finite" % (stage+1))
 print("OBSERVATIONS ",JSON.stringify(rows))
 FileAccess.open("res://../artifacts/quiescence-observations.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
 print("CONSTANT_INPUT longest_low=",longest)
 print("QUIESCENCE_RESULT checks=",checks," failures=",failures)
 quit(1 if failures else 0)
