extends SceneTree
const World=preload("res://scripts/physical_world.gd")
var checks=0
var failures=0
func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok: failures+=1
 print("PASS " if ok else "FAIL ",message)
func events(samples: Array) -> Array:
 return samples.filter(func(sample):return sample.origin==2)
func _initialize() -> void:
 var world=World.new()
 world.surfaces=[]
 var p=world.parameters[0]
 var continuous={"origin":0,"plastic":false,"axis":Vector2.RIGHT,"signal":[.2,0,0,0,0,0,0,0],"geometry":Vector2.ZERO}
 var first=world.structure.events.sense(p,world.bodies[0],[continuous],8)
 check(first.size()==1 and first[0].plastic and first[0].event_from==0,"external threshold crossing emits one plastic event")
 check(first[0].signal==continuous.signal,"external event preserves its physical signal shape")
 check(world.structure.events.sense(p,world.bodies[0],[continuous],8).is_empty(),"held external signal does not register every frame")
 var silence={"origin":0,"plastic":false,"axis":Vector2.RIGHT,"signal":[0,0,0,0,0,0,0,0],"geometry":Vector2.ZERO}
 world.structure.events.sense(p,world.bodies[0],[silence],8)
 check(world.structure.events.sense(p,world.bodies[0],[continuous],8).size()==1,"release permits a later external event")
 var body=world.bodies[0]
 body.contact_pressure=.1
 var body_events=world.structure.events.sense(p,body,[],8)
 check(body_events.size()==1 and body_events[0].event_from==1 and body_events[0].signal[7]>0,"configured contact impulse crossing emits a body event")
 check(world.structure.events.sense(p,body,[],8).is_empty(),"held body event is gated by hysteresis")
 body.contact_pressure=0
 world.structure.events.sense(p,body,[],8)
 body.contact_pressure=.1
 check(world.structure.events.sense(p,body,[],8).size()==1,"body event re-arms only after release")
 var disabled=World.new()
 disabled.surfaces=[]
 disabled.parameters[0].event_sense.enabled=false
 var plain={"origin":0,"plastic":false,"axis":Vector2.RIGHT,"signal":[.2,0,0,0,0,0,0,0],"geometry":Vector2.ZERO}
 check(disabled.structure.events.sense(disabled.parameters[0],disabled.bodies[0],[plain],8).is_empty(),"event extraction belongs to enabled subject structure")
 var no_event_state=world.structure.initial(p)
 var with_event=world.core.advance(world.structure,p,world.bodies[0].duplicate(true),[continuous,first[0]],.1)
 var without_event=world.core.advance(world.structure,p,no_event_state,[continuous],.1)
 var quiet=world.core.advance(world.structure,p,world.structure.initial(p),[],.1)
 check(without_event.state.x!=quiet.state.x,"continuous sample still changes tension without becoming an association")
 check(with_event.state.memory.size()>without_event.state.memory.size(),"continuous sample affects tension but only its event registers association")
 print("EVENT_SENSE_RESULT checks=",checks," failures=",failures)
 quit(1 if failures else 0)
