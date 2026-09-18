extends SceneTree
const World=preload("res://scripts/physical_world.gd")
var checks=0
var failures=0
func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok: failures+=1
 print("PASS " if ok else "FAIL ",message)
func sample(x: float,y: float) -> Dictionary:
 return {"origin":0,"plastic":false,"axis":Vector2.RIGHT,"signal":[x,y,0,0,0,0,0,0],"geometry":Vector2.ZERO}
func rises(patterns: Array) -> int:
 return patterns.filter(func(v):return v.rising).size()
func _initialize() -> void:
 var w=World.new()
 var p=w.parameters[0].duplicate(true)
 p.event_sense.external=[]
 p.event_sense.self=[]
 for features in [[0],[1],[0,1]]:
  p.event_sense.external.append({"features":features,"threshold":.2,"release":.1,"plasticity":true})
 var body=w.structure.initial(p)
 var patterns=w.structure.events.sense(p,body,[sample(.8,.8)],8)
 check(patterns.size()==3 and rises(patterns)==3,"A B and conjunction register simultaneously")
 check(rises(w.structure.events.sense(p,body,[sample(.8,.8)],8))==0,"held patterns activate without registering again")
 check(w.structure.events.sense(p,body,[sample(.8,0)],8).size()==1,"loss of one feature releases its simple and compound patterns independently")
 check(rises(w.structure.events.sense(p,body,[sample(.8,.8)],8))==2,"remaining active pattern does not retrigger")
 w.structure.events.sense(p,body,[],8)
 check(rises(w.structure.events.sense(p,body,[sample(.8,.8)],8))==3,"complete disappearance releases all patterns")
 var separate=w.structure.initial(p)
 var split=w.structure.events.sense(p,separate,[sample(.8,0),sample(0,.8)],8)
 check(split.size()==2,"separate sources cannot fabricate conjunction")
 var flipped=w.structure.initial(p)
 var reverse=w.structure.events.sense(p,flipped,[sample(0,.8),sample(.8,0)],8)
 check(var_to_str(split)==var_to_str(reverse),"sample permutation leaves feature identities and output unchanged")
 check(rises(w.structure.events.sense(p,separate,[sample(.8,0),sample(.8,0)],8))==0,"another source sustaining a feature keeps its pattern active")
 var a=w.core.advance(w.structure,p,w.structure.initial(p),[sample(.8,.8)],.1)
 check(a.state.memory.size()==3,"each active pattern owns its learned vector")
 for item in a.state.memory: item.effect=[.1,-.1,.05,-.05]
 var frozen=p.duplicate(true)
 frozen.plasticity_enabled=false
 var before=a.state.memory.map(func(v):return [v.pattern,v.effect.duplicate(),v.exposure,v.updates])
 var probe=w.core.advance(w.structure,frozen,a.state,[sample(.8,.8),sample(.4,.8)],.1)
 var after=w.core.receive(w.structure,frozen,probe.state,{"exchange":[1,1,1,1],"load":1.0},.1)
 check(after.memory.map(func(v):return [v.pattern,v.effect,v.exposure,v.updates])==before,"probe freezes allocation weights exposure and update counts")
 var single_probe=w.core.advance(w.structure,frozen,a.state,[sample(.8,.8)],.1)
 check(single_probe.contributions.filter(func(c):return c.source[0]==1 and c.value.length()>0).size()==12,"all three learned patterns contribute all four dimensions separately")
 var opposite=sample(.8,.8)
 opposite.axis=Vector2.LEFT
 var conflict=w.core.advance(w.structure,frozen,a.state,[sample(.8,.8),opposite],.1)
 var learned=conflict.contributions.filter(func(c):return c.source[0]==1 and c.value.length()>0)
 var net=Vector2.ZERO
 var effort=0.0
 for c in learned:
  net+=c.value
  effort+=c.value.length()
 check(learned.size()==24 and net.length()<.00001 and effort>0,"same feature at opposite directions retains opposing forces under one memory identity")
 var plain=p.duplicate(true)
 plain.event_sense.enabled=false
 var no_events=w.core.advance(w.structure,plain,w.structure.initial(plain),[sample(.8,.8)],.1)
 check(no_events.state.memory.is_empty() and no_events.state.x!=p.state,"continuous sensation changes tension without automatic registration")
 var left=World.new()
 var right=World.new()
 for tick in range(180):
  var saved=var_to_str(left.bodies)
  for i in range(3):
   left.sense(0)
   var observed=left.observe(0)
   observed.event_state.clear()
   observed.x[0]=999
  check_reads(saved==var_to_str(left.bodies))
  left.step(1.0/60)
  right.step(1.0/60)
 check(var_to_str(left.bodies)==var_to_str(right.bodies),"arbitrary observation reads cannot consume events or change evolution")
 print("EVENT_SENSE_RESULT checks=",checks," failures=",failures)
 quit(1 if failures else 0)
func check_reads(ok: bool) -> void:
 if not ok: failures+=1
