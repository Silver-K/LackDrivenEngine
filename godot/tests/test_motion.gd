extends SceneTree
const World=preload("res://scripts/physical_world.gd")
var checks=0
var failures=0
func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok: failures+=1
 print("PASS " if ok else "FAIL ",message)
func _initialize() -> void:
 var w=World.new()
 var p=w.parameters[0].duplicate(true)
 var a=w.structure.initial(p)
 a.position=Vector2(500,430)
 var opposite=a.duplicate(true)
 var quiet=a.duplicate(true)
 var sources=[{"source":[5,0],"channel":1,"value":0.8},{"source":[5,1],"channel":1,"value":-0.8}]
 w.physics.step(opposite,p,[],sources,0.1)
 w.physics.step(quiet,p,[],[],0.1)
 check(opposite.heading==quiet.heading and opposite.load>quiet.load,"opposing torques retain load despite equal orientation")
 var first=w.core.advance(w.structure,p,a,[],0.1)
 check(first.contributions.any(func(c):return c.channel==1) and first.contributions.any(func(c):return c.source==[4,0]),"turning and per-dimension propulsion remain distinct contributions")
 var room=Rect2(57,225,983,395)
 var near=a.duplicate(true)
 near.position=Vector2(100,430)
 w.physics.step(near,p,[],[],0.1,room)
 check(near.position==Vector2(100,430) and near.contact_pressure==0,"no invisible repulsion before wall contact")
 var hit=a.duplicate(true)
 hit.position=Vector2(72.1,430)
 hit.heading=PI
 hit.velocity=Vector2(-40,0)
 var feedback=w.physics.step(hit,p,[],[{"source":[4],"channel":0,"value":Vector2.LEFT}],0.1,room)
 check(hit.position.x>=72 and hit.velocity.x>0 and hit.contact_pressure>0,"wall blocks radius-aware body and applies normal impulse")
 var after=w.core.receive(w.structure,p,hit,feedback,0.1)
 check(after.x[3]>hit.x[3],"physical collision affects tension through subject exchange mapping")
 var room_shift=room
 room_shift.position+=Vector2(1700,-320)
 var shifted=a.duplicate(true)
 shifted.position=Vector2(72.1,430)+Vector2(1700,-320)
 shifted.heading=PI
 shifted.velocity=Vector2(-40,0)
 w.physics.step(shifted,p,[],[{"source":[4],"channel":0,"value":Vector2.LEFT}],0.1,room_shift)
 check((shifted.position-hit.position-Vector2(1700,-320)).length()<0.01,"collision follows supplied environment geometry")
 # Same history under rigid transformations: no absolute-coordinate steering.
 var base=World.new()
 var moved=World.new()
 var rotated=World.new()
 var offset=Vector2(1900,-830)
 var start=Vector2(500,430)
 for world in [base,moved,rotated]:
  world.surfaces=[]
  world.room=Rect2(-100000,-100000,200000,200000)
  world.bodies[0].position=start
 moved.bodies[0].position+=offset
 rotated.bodies[0].heading=PI/2
 for i in range(1200):
  for world in [base,moved,rotated]: world.step(1.0/60.0)
 var delta: Vector2=base.bodies[0].position-start
 check((moved.bodies[0].position-base.bodies[0].position-offset).length()<0.1,"translation leaves motor dynamics unchanged")
 check((rotated.bodies[0].position-start-delta.rotated(PI/2)).length()<0.1,"rotation rotates the trajectory without a privileged world axis")
 check(base.bodies[0].motor_state==moved.bodies[0].motor_state,"motor fluctuation stream belongs to each independent body")
 # Remove fluctuations and hold internal state constant; propulsion must persist,
 # rather than turn back because an elapsed phase changes sign.
 var straight=World.new()
 straight.surfaces=[]
 straight.parameters[0].self_sense.enabled=false
 straight.room=Rect2(-100000,-100000,200000,200000)
 var sp: Dictionary=straight.parameters[0]
 sp.locomotion.fluctuation_gain=0
 sp.body_response.use_gain=0
 sp.body_response.load_gain=0
 sp.drift.fill(0.0)
 for row in sp.coupling: row.fill(0.0)
 sp.dynamics.decay=0
 sp.feedback_load.fill(0.0)
 var initial: Vector2=straight.bodies[0].position
 for i in range(7200): straight.step(1.0/60.0)
 check(straight.bodies[0].position.x-initial.x>1000 and absf(straight.bodies[0].position.y-initial.y)<0.01,"steady internal state yields persistent motion without a periodic return")
 var no_motor=World.new()
 no_motor.surfaces=[]
 no_motor.parameters[0].self_sense.enabled=false
 no_motor.parameters[0].locomotion.gain=0
 var rest: Vector2=no_motor.bodies[0].position
 for i in range(60): no_motor.step(1.0/60.0)
 check(no_motor.bodies[0].position==rest,"removing motor drive does not activate hidden room exploration")
 print("MOTION_RESULT checks=",checks," failures=",failures)
 quit(1 if failures else 0)
