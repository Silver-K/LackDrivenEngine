extends SceneTree
const Experiment = preload("res://scripts/room_experiment.gd")
const Fields = preload("res://scripts/runtime/environment_fields.gd")
var checks=0
var failures=0
func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok: failures+=1
 print("PASS " if ok else "FAIL ",message)
func _initialize() -> void:
 var lab=Experiment.new()
 var world=lab.simulation
 check(world.bodies.size()==1 and world.parameters[0].associations.is_empty() and world.bodies[0].memory.is_empty(),"one body has no initial environmental associations")
 check(not world.parameters[0].has("motor"),"no direct receptor to environmental approach mapping")
 lab.set_stage(0)
 check(world.sense(0).filter(func(sample):return sample.origin==0).is_empty(),"empty room contains no external sensory objects")
 lab.set_stage(2)
 check(world.surfaces[5].emission[2]>0 and world.surfaces[5].field_strength==0,"cue precedes mechanical effect")
 lab.apparatus_time=2
 lab.configure()
 check(world.surfaces[5].emission[2]==0 and world.surfaces[5].field_strength>0,"effect follows cue without continuing cue signal")
 lab.cue_only=true
 lab.configure()
 check(world.surfaces[5].field_strength==0,"cue-only control physically removes effect")
 var silent_world=Experiment.new()
 silent_world.set_stage(2)
 silent_world.apparatus_time=5
 silent_world.configure()
 check(silent_world.simulation.sense(0).filter(func(sample):return sample.origin==0).size()==1,"silent apparatus adds no location sample beyond the active exchange zone")
 lab.set_stage(3)
 lab.cue_only=false
 lab.apparatus_time=2
 lab.configure()
 var source=world.surfaces[5]
 var covered=Vector2(875,555)
 check(Fields.amplitude(covered,source,world.surfaces)==0,"physical cover blocks propagation")
 for i in range(2,5): world.surfaces[i].active=false
 check(Fields.amplitude(covered,source,world.surfaces)>0,"same location receives field when cover removed")
 lab.set_stage(1)
 world.bodies[0].position=world.surfaces[0].position
 world.bodies[0].velocity=Vector2.ZERO
 var feedback=world.physics.step(world.bodies[0],world.parameters[0],world.surfaces,[],0.1)
 check(feedback.exchange[0]<0 and feedback.exchange[1]>0,"A contact produces mixed physical exchange")
 lab.exchange_enabled=false
 lab.configure()
 feedback=world.physics.step(world.bodies[0],world.parameters[0],world.surfaces,[],0.1)
 check(feedback.exchange.all(func(v):return v==0) and not world.sense(0).is_empty(),"disabling exchange preserves sensory signals without relief")
 lab.reset()
 check(world!=lab.simulation and lab.simulation.bodies[0].memory.is_empty() and lab.simulation.time==0,"reset reconstructs the same untrained body")
 lab.set_stage(3)
 lab.exchange_enabled=true
 for i in range(300): lab.step(1.0/60.0)
 var snapshot=lab.snapshot()
 var copy=Experiment.new()
 check(copy.restore(snapshot),"complete experiment snapshot restores")
 for i in range(300):
  lab.step(1.0/60.0)
  copy.step(1.0/60.0)
 check(var_to_str(lab.snapshot())==var_to_str(copy.snapshot()),"restored world apparatus and history continue identically")
 check(lab.save_history("user://test-room.bin") and copy.load_history("user://test-room.bin"),"disk history round trip")
 check(var_to_str(lab.snapshot())==var_to_str(copy.snapshot()),"disk history preserves numerical state and source records")
 var state_before=var_to_str(lab.simulation.bodies)
 lab.set_stage(0)
 check(var_to_str(lab.simulation.bodies)==state_before,"stage selection changes environment not learned state")
 check(not copy.restore({"version":4}),"old scene saves explicitly rejected")
 var legacy=lab.snapshot()
 legacy.version=1
 check(not copy.restore(legacy),"old phase-driven motor snapshots cannot enter the new dynamics")
 var plain=Experiment.new()
 var renamed=Experiment.new()
 for object in renamed.simulation.surfaces: object.display_name="arbitrary observer label"
 for i in range(180):
  plain.step(1.0/60.0)
  renamed.step(1.0/60.0)
 check(var_to_str(plain.simulation.bodies)==var_to_str(renamed.simulation.bodies),"observer labels cannot change physical or psychological evolution")
 var run=Experiment.new()
 run.set_stage(3)
 var contacts={}
 var extent=Rect2(run.simulation.bodies[0].position,Vector2.ZERO)
 var max_load=0.0
 for i in range(6000):
  run.step(0.05)
  var body=run.simulation.bodies[0]
  extent=extent.expand(body.position)
  if body.touch>=0: contacts[body.touch]=true
  max_load=maxf(max_load,body.load)
 var body=run.simulation.bodies[0]
 check(body.x.all(func(v):return is_finite(v) and absf(v)<=1.5) and body.position.is_finite(),"five-minute free run remains finite and bounded")
 check(run.simulation.association_strength(0)>0 and max_load>0,"free experience forms association and simultaneous opposing load")
 # Geometric access is tested by contact, not a required itinerary in a free run.
 var access=Experiment.new()
 access.set_stage(3)
 var accessed=[]
 for index in [0,1]:
  var state=access.simulation.structure.initial(access.simulation.parameters[0])
  state.position=access.simulation.surfaces[index].position
  var result=access.simulation.physics.step(state,access.simulation.parameters[0],access.simulation.surfaces,[],.1,access.simulation.room)
  accessed.append(state.touch==index and result.exchange.any(func(v):return v!=0))
 check(accessed.all(func(v):return v),"both exchange zones remain physically accessible without imposing visits")
 print("FREE_RUN extent=",extent," contacts=",contacts," memory=",run.simulation.association_strength(0)," max_load=",max_load)
 print("FIELD_RESULT checks=",checks," failures=",failures)
 quit(1 if failures else 0)
