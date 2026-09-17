extends SceneTree
const Assoc = preload("res://scripts/subjects/trace_plasticity.gd")
const Model = preload("res://scripts/physical_world.gd")
const View = preload("res://scripts/animal_world.gd")
var count = 0
var failures = 0
func check(ok: bool, label: String) -> void:
	count += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)
func cycle(a, memory: Array, paired: bool, enabled: bool = true) -> void:
	for tick in range(100):
		var cue: bool = tick < 10
		var effect: bool = tick >= (12 if paired else 70) and tick < (22 if paired else 80)
		a.perceive(memory,[{"signal":[1.0,0.0,0.0,0.0]}] if cue else [],0.1)
		a.learn(memory,[-0.15,0.04,-0.06,0.02] if effect else [0.0,0.0,0.0,0.0],0.1,0.85 if enabled else 0)
func _initialize() -> void:
	var assoc = Assoc.new()
	var paired: Array = []
	var unpaired: Array = []
	var frozen: Array = []
	for i in range(20):
		cycle(assoc,paired,true)
		cycle(assoc,unpaired,false)
		cycle(assoc,frozen,true,false)
	var x = [0.8,0.1,0.5,0.2]
	var response: float = assoc.response(paired,[1.0,0.0,0.0,0.0],x)
	var unrelated: float = assoc.response(unpaired,[1.0,0.0,0.0,0.0],x)
	print("PAIRED ", response, " UNPAIRED ", unrelated)
	check(response > 0.02 and response > unrelated * 2, "forward pairing produces stronger cue response than delayed control")
	check(assoc.magnitude(frozen) == 0, "same age and experience without plasticity produce no learned association")
	check(assoc.response(paired,[0.0,1.0,0.0,0.0],x) < response * 0.1, "response is selective to experienced cue rather than all stimuli")
	for i in range(600):
		assoc.perceive(paired,[{"signal":[1.0,0.0,0.0,0.0]}],0.1)
		assoc.learn(paired,[0.0,0.0,0.0,0.0],0.1,0.85)
	check(assoc.response(paired,[1.0,0.0,0.0,0.0],x) < response * 0.2, "unfulfilled cue presentations extinguish acquired response")
	var w = Model.new()
	check(w.bodies.size()==6, "three initialized bodies and three untrained bodies coexist")
	for i in range(3,6):
		check(assoc.magnitude(w.bodies[i].memory)==0 and w.parameters[i].associations.is_empty() and w.parameters[i].motor.all(func(v):return v==0), "untrained body %d starts without release mapping" % i)
	check(assoc.magnitude(w.bodies[0].memory)>0, "initialized body retains configured associations")
	# With equal state and a single numerical cue, association alone changes motion.
	var left = Model.new()
	var right = Model.new()
	for sim in [left,right]:
		sim.bodies= [sim.bodies[3]]
		sim.parameters= [sim.parameters[3]]
		sim.bodies[0].position=Vector2(500,450)
		sim.bodies[0].x=x.duplicate()
		sim.surfaces=[sim.surfaces[0]]
		sim.surfaces[0].position=Vector2(580,450)
		sim.surfaces[0].emission=[1,0,0]
		sim.surfaces[0].exchange=[0,0,0,0]
	var learned: Array = []
	for i in range(20): cycle(assoc,learned,true)
	left.bodies[0].memory=learned
	left.step(0.1)
	right.step(0.1)
	check(left.bodies[0].velocity.x > right.bodies[0].velocity.x + 0.1, "learned cue changes live movement with identical physical state")
	var view = View.new()
	for i in range(150): view.step(0.1)
	check(view.save_history("user://test_development.bin"), "experience snapshot saves")
	var loaded = View.new()
	check(loaded.load_history("user://test_development.bin"), "experience snapshot restores")
	for i in range(20):
		view.step(0.1)
		loaded.step(0.1)
	check(var_to_str(view.simulation.bodies)==var_to_str(loaded.simulation.bodies), "restored history continues identically including eligibility and plasticity")
	var report = "# 关联学习对照\n\n相同数值线索、相同变化量与次数，20轮。每轮线索1秒，前向配对延迟0.2秒；错时对照延迟6秒。\n\n- 前向配对响应：%.6f\n- 错时配对响应：%.6f\n- 冻结可塑性关联幅度：%.6f\n- 消退后响应：%.6f\n\n该对照验证简化时序关联机制，不证明个体形成真实意识或完整动物心理。\n" % [response, unrelated, assoc.magnitude(frozen),assoc.response(paired,[1.0,0.0,0.0,0.0],x)]
	FileAccess.open("res://../artifacts/development-comparison.md",FileAccess.WRITE).store_string(report)
	print("DEVELOPMENT_RESULT checks=",count," failures=",failures)
	quit(1 if failures else 0)
