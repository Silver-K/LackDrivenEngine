extends SceneTree
const World=preload("res://scripts/physical_world.gd")
var checks=0
var failures=0
func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok: failures+=1
 print("PASS " if ok else "FAIL ",message)
func _initialize() -> void:
 var current=World.new()
 var p: Dictionary=current.parameters[0]
 current.surfaces=[]
 current.bodies[0].velocity=Vector2(36,0)
 current.bodies[0].angular_velocity=1.5
 current.bodies[0].activation=.7
 current.bodies[0].strain=.4
 var samples=current.sense(0)
 check(samples.size()==1 and samples[0].origin==1,"current subject explicitly enables a body-origin sample")
 check(not samples[0].plastic,"current subject senses continuous body values without automatically registering them as associations")
 check(samples[0].signal.size()==8 and samples[0].signal.slice(0,4).all(func(v):return v==0),"body sample occupies configured inputs without fabricating external signal")
 check(samples[0].signal.slice(4,8).all(func(v):return v>0),"configured body quantities map into independent numeric inputs")
 var no_self=World.new()
 no_self.surfaces=[]
 no_self.parameters[0].self_sense.enabled=false
 no_self.bodies[0].velocity=Vector2(36,0)
 no_self.bodies[0].angular_velocity=1.5
 no_self.bodies[0].activation=.7
 no_self.bodies[0].strain=.4
 check(no_self.sense(0).is_empty(),"a subject without self mapping receives no body sample")
 var from_self=current.core.advance(current.structure,p,current.bodies[0].duplicate(true),samples,.1)
 var absent=current.core.advance(current.structure,no_self.parameters[0],no_self.bodies[0].duplicate(true),no_self.sense(0),.1)
 check(from_self.state.x!=absent.state.x,"self mapping changes tension only through subject-supplied sensation")
 var shifted=World.new()
 shifted.surfaces=[]
 shifted.bodies[0].position+=Vector2(1900,-900)
 shifted.bodies[0].velocity=Vector2(36,0)
 shifted.bodies[0].angular_velocity=1.5
 shifted.bodies[0].activation=.7
 shifted.bodies[0].strain=.4
 check(shifted.sense(0)[0].signal==samples[0].signal,"self mapping has no absolute world-position input")
 var invalid=p.duplicate(true)
 invalid.self_sense.channels[0].input=20
 check(not current.core.validate(current.structure,invalid).is_empty(),"invalid self mapping rejected by subject structure")
 var sensory_snapshot=current.sense(0).duplicate(true)
 var body_before=current.bodies[0].duplicate(true)
 current.core.advance(current.structure,p,current.bodies[0].duplicate(true),sensory_snapshot,.1)
 check(current.bodies[0]==body_before,"sensing and engine advance do not mutate the body's physical snapshot")
 var lab_state=World.new()
 lab_state.surfaces=[]
 lab_state.bodies[0].velocity=Vector2(30,0)
 lab_state.bodies[0].activation=.8
 lab_state.step(.1)
 check(lab_state.bodies[0].memory.is_empty(),"non-plastic body samples do not crowd environmental association history")
 lab_state.parameters[0].self_sense.plasticity=true
 lab_state.step(.1)
 check(lab_state.bodies[0].memory.size()>0,"a subject can explicitly permit body samples into its association history")
 print("SELF_SENSE_RESULT checks=",checks," failures=",failures)
 quit(1 if failures else 0)
