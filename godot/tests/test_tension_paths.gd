extends SceneTree
const World=preload("res://scripts/physical_world.gd")
const Experiment=preload("res://scripts/room_experiment.gd")
var checks=0
var failures=0
func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok: failures+=1
 print("PASS " if ok else "FAIL ",message)
func sample(value: float, axis: Vector2=Vector2.RIGHT) -> Dictionary:
 return {"signal":[value,0.0,0.0,0.0,0.0,0.0,0.0,0.0],"axis":axis,"origin":0,"plastic":false}
func _initialize() -> void:
 var w=World.new()
 var p=w.parameters[0].duplicate(true)
 p.event_sense.enabled=false
 p.plasticity_enabled=false
 p.drift.fill(0.0)
 p.dynamics.decay=0.0
 for row in p.coupling: row.fill(0.0)
 var a=w.structure.initial(p)
 a.x.fill(0.0)
 a.motor_state.change=[0.0,0.0,0.0,0.0]
 var empty=w.structure.emit(p,a,[])
 check(w.structure.emit(p,a,[sample(1.0)])==empty,"unlearned signal cannot drive motion without a tension update")
 check(empty.all(func(c):return c.value==Vector2.ZERO if c.channel==0 else c.value==0),"zero tension and zero change produce no autonomous force")
 var positive=w.core.advance(w.structure,p,a,[sample(1.0)],0.1)
 var negative=w.core.advance(w.structure,p,a,[sample(-1.0)],0.1)
 var signed=true
 for j in range(a.x.size()):
  signed=signed and is_equal_approx(positive.state.x[j],-negative.state.x[j])
 check(signed and positive.state.x[0]>0,"sensory differences retain sign instead of absolute novelty")
 var split=w.core.advance(w.structure,p,a,[sample(0.25),sample(0.75,Vector2.LEFT)],0.1)
 check(split.state.x==positive.state.x and split.state.trace==positive.state.trace and split.contributions==positive.contributions,"equal total input gives equal unlearned tension and motion regardless of source partition")
 var steady=a.duplicate(true)
 for tick in range(400):
  steady=w.core.advance(w.structure,p,steady,[sample(0.25),sample(0.75,Vector2.LEFT)],0.1).state
 check(absf(steady.input[0]-steady.trace[0])<0.000001 and absf(steady.motor_state.change[0])<0.000001,"constant multisource input adapts without persistent per-source novelty")
 var removed=w.core.advance(w.structure,p,steady,[],0.1)
 check(removed.state.x[0]<steady.x[0],"signal removal produces the opposite signed transient")
 var changing=a.duplicate(true)
 changing.motor_state.change[0]=0.5
 var changing_output=w.structure.emit(p,changing,[])
 check(changing_output.any(func(c):return c.channel==1 and c.value!=0),"zero instantaneous tension may still turn when its derivative is nonzero")
 check(positive.contributions.all(func(c):return c.source[0] in [1,4,5]),"only tension and learned tension couplings emit autonomous contributions")
 var learned=a.duplicate(true)
 learned.x[0]=0.5
 learned.memory=w.structure.policy(p).create([{"signature":[1,0,0,0,0,0,0,0],"effect":[-1,0,0,0]}])
 var toward=w.structure.emit(p,learned,[sample(1.0)])
 var away=w.structure.emit(p,learned,[sample(1.0,Vector2.LEFT)])
 check(toward[0].source[0]==1 and toward[0].value==-away[0].value and toward[0].value.length()>0,"learned directional contributions remain independently traceable")
 var lab=Experiment.new()
 var legacy=lab.snapshot()
 legacy.version=8
 check(not lab.restore(legacy),"previous motor-history schema is rejected")
 print("TENSION_PATHS_RESULT checks=",checks," failures=",failures)
 quit(1 if failures else 0)
