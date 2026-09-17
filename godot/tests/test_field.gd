extends SceneTree
const Model = preload("res://scripts/physical_world.gd")
const View = preload("res://scripts/animal_world.gd")
var count=0
var failures=0
func check(ok: bool, message: String) -> void:
 count+=1
 if not ok: failures+=1
 print("PASS " if ok else "FAIL ", message)
func _initialize() -> void:
 var a=View.new()
 var b=View.new()
 for p in b.visual.subjects:
  p.name="random"; p.species="unrelated"; p.color="ffffff"
 for p in b.visual.objects:
  p.kind="arbitrary"; p.label="meaningless"
 for i in range(200): a.step(0.1); b.step(0.1)
 check(var_to_str(a.simulation.bodies)==var_to_str(b.simulation.bodies),"all visual names and categories can change without changing simulation")
 var bare=Model.new()
 for i in range(200): bare.step(0.1)
 check(var_to_str(a.simulation.bodies)==var_to_str(bare.bodies),"simulation identical with presentation layer absent")
 var source=FileAccess.get_file_as_string("res://scripts/physical_world.gd")+FileAccess.get_file_as_string("res://scripts/tension_core.gd")
 source="\n".join(Array(source.split("\n")).filter(func(line): return not line.strip_edges().begins_with("#")))
 var clean=true
 for token in ["hunger","thirst","prey","species","food","water","chase","action","target"]:
  clean=clean and not source.contains(token)
 check(clean,"causal modules contain no psychological or object category branches")
 var w=Model.new()
 var before=w.bodies[0].x.duplicate()
 var before_memory=var_to_str(w.bodies[0].memory)
 w.bodies[0].position=w.surfaces[0].position
 w.step(0.1)
 var changed=0
 for i in range(4): changed+=int(not is_equal_approx(before[i],w.bodies[0].x[i]))
 check(changed==4 and w.surfaces[0].reservoir<100,"one material exchange changes multiple coupled dimensions")
 check(var_to_str(w.bodies[0].memory)!=before_memory,"contact alters future receptor response history")
 var normal=Model.new()
 var variant=Model.new()
 variant.surfaces[0].emission=[0,0,0]
 normal.bodies[0].position=Vector2(680,265)
 variant.bodies[0].position=Vector2(680,265)
 normal.step(0.1);variant.step(0.1)
 check(normal.bodies[0].input!=variant.bodies[0].input,"physical signal change alters perception without any label change")
 var hidden=Model.new()
 hidden.bodies[0].position=Vector2(90,580)
 var initial=hidden.sense(0)
 hidden.surfaces[0].emission=[100,100,100]
 check(initial==hidden.sense(0),"out of range signal cannot affect receptor samples")
 var finite=true
 var maximum=0.0
 for i in range(3000):
  bare.step(0.1)
  for body in bare.bodies:
   finite=finite and body.position.is_finite() and body.velocity.is_finite()
   for x in body.x: finite=finite and is_finite(x) and absf(x)<=1.5
   maximum=maxf(maximum,body.velocity.length())
 check(finite and maximum>5,"five-minute coupled simulation is finite and generates movement")
 var rows=["# 自由生活观测\n\n相同初始结构，三个幼体均从零关联出发。仿真320秒，不额外补充资源。\n", "| 主体序号 | 位置 | 关联幅度 | 数值状态 |", "|---|---|---|---|"]
 for i in range(3,6):
  var body=bare.bodies[i]
  var strength=bare.association_strength(i)
  check(strength>0.00001,"untrained body %d acquires association through free contact" % i)
  rows.append("| %d | %s | %.6f | %s |" % [i,body.position,strength,body.x])
 FileAccess.open("res://../artifacts/development-free-life.md",FileAccess.WRITE).store_string("\n".join(rows))
 print("NUMERIC_RESULT checks=",count," failures=",failures)
 quit(1 if failures else 0)
