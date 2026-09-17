extends SceneTree
const Executor = preload("res://scripts/tension_core.gd")
const World = preload("res://scripts/physical_world.gd")
const Body = preload("res://scripts/runtime/body_physics.gd")
class DifferentStructure:
	extends RefCounted
	func validate(definition: Dictionary) -> String:
		return "" if definition.has("dimensions") else "Missing dimensions"
	func advance(definition: Dictionary, state: Dictionary, _samples: Array, dt: float) -> Dictionary:
		for j in range(definition.dimensions): state.x[j] += dt * definition.rate
		definition.rate = 999 # Engine must isolate the definition too.
		return state
	func emit(_definition: Dictionary, _state: Dictionary, _samples: Array) -> Array:
		return [{"source":[0],"channel":7,"value":0.8},{"source":[1],"channel":7,"value":-0.8}]
	func receive(definition: Dictionary, state: Dictionary, feedback: Dictionary, dt: float) -> Dictionary:
		if definition.mutable: state.x[0] += feedback.amount * dt
		return state
var failures=0
var checks=0
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1
	print("PASS " if ok else "FAIL ",label)
func _initialize() -> void:
	var engine=Executor.new()
	var other=DifferentStructure.new()
	for n in [2,7]:
		var x: Array=[]
		x.resize(n); x.fill(0.0)
		var definition={"dimensions":n,"rate":0.5,"channels":[7],"mutable":false}
		var state={"x":x}
		var result=engine.advance(other,definition,state,[],0.1)
		check(result.state.x.size()==n and result.state.x[0]==0.05,"engine executes independent %d dimensional rule" % n)
		check(result.contributions.size()==2 and result.contributions[0].value==0.8 and result.contributions[1].value==-0.8,"opposed scalar contributions survive without summation")
		check(state.x[0]==0 and definition.rate==0.5,"state and structural definition not mutated by rule")
		var unchanged=engine.receive(other,definition,result.state,{"amount":3},0.1)
		definition.mutable=true
		var altered=engine.receive(other,definition,result.state,{"amount":3},0.1)
		check(unchanged.x[0]!=altered.x[0],"feedback update permission belongs to supplied structure")
	var world=World.new()
	check(world.last_error.is_empty(),"game definitions validate")
	var bad=world.parameters[0].duplicate(true)
	bad.coupling.pop_back()
	check(not engine.validate(world.structure,bad).is_empty(),"malformed topology rejected before execution")
	var a=world.structure.initial(world.parameters[0])
	a.position=Vector2(500,450)
	var quiet=a.duplicate(true)
	var opposed=a.duplicate(true)
	var contributions=[{"source":[0],"channel":0,"value":Vector2(0.8,0)},{"source":[1],"channel":0,"value":Vector2(-0.8,0)}]
	var copy=var_to_str(contributions)
	var physical=Body.new()
	var feedback=physical.step(opposed,world.parameters[0],[],contributions,0.1)
	physical.step(quiet,world.parameters[0],[],[],0.1)
	check(opposed.velocity==quiet.velocity and opposed.load>0 and quiet.load==0,"equal net movement differs in opposed load")
	check(opposed.strain>quiet.strain,"body retains the cost of simultaneous opposing contributions")
	check(var_to_str(contributions)==copy,"body projection leaves original source contributions intact")
	var state_before=a.x.duplicate()
	var after=engine.receive(world.structure,world.parameters[0],a,feedback,0.1)
	check(a.x==state_before and after.x!=state_before,"body feedback affects tension through subject mapping only")
	var disabled=world.parameters[0].duplicate(true)
	disabled.plasticity_enabled=false
	var sample=[{"axis":Vector2.RIGHT,"signal":[1.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0],"geometry":Vector2.ZERO}]
	var output=engine.advance(world.structure,disabled,a,sample,0.1)
	var memories=var_to_str(output.state.memory)
	var received=engine.receive(world.structure,disabled,output.state,{"exchange":[-1.0,0.0,0.0,0.0],"load":0.0},0.1)
	check(var_to_str(received.memory)==memories,"subject disables learning without changing the engine")
	check(output.contributions.size()>4 and output.contributions.all(func(c):return c.has_all(["source","channel","value"])),"actual game keeps every dimension and memory contribution")
	# This family can add an internal dimension without changing physical signal count.
	var extended=world.parameters[0].duplicate(true)
	extended.state.append(0.1)
	extended.locomotion.propulsion.append(0.1)
	extended.locomotion.turn.append(0.1)
	extended.drift.append(0.002)
	extended.motor.append(0.0)
	extended.feedback_load.append(0.0)
	extended.receptor.append([0.1,0.2,0.3,0.4,0.0,0.0,0.0,0.0])
	extended.feedback_exchange.append([0.01,0.02,-0.01,0.0])
	for row in extended.coupling: row.append(0.03)
	extended.coupling.append([0.01,0.02,0.03,0.04,0.0])
	var five=engine.advance(world.structure,extended,world.structure.initial(extended),sample,0.1)
	var five_feedback=engine.receive(world.structure,extended,five.state,{"exchange":[1.0,0.0,0.0,0.0],"load":0.0},0.1)
	check(five_feedback.x.size()==5 and five_feedback.x[4]!=five.state.x[4],"five internal dimensions can receive four physical exchange channels")
	var malformed_channels={"dimensions":2,"rate":0.5,"channels":[8],"mutable":false}
	check(engine.advance(other,malformed_channels,{"x":[0.0,0.0]},[],0.1).has("error"),"undeclared output channel rejected")
	print("MODULE_RESULT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
