extends RefCounted
## Isolated measurement protocol. Never writes the live experiment.
const World=preload("res://scripts/physical_world.gd")
const INPUTS=[[0.8,0.0,0.0],[0.0,0.0,0.8],[0.8,0.0,0.8],[0.0,0.8,0.8]]
const NAMES=["P · 输入0","Q · 输入2","P+Q · 输入0、2","R+Q · 输入1、2"]
var reference_snapshot: Dictionary={}
var results: Array=[]
var captured_time=0.0
func capture(experiment) -> void:
 reference_snapshot=experiment.snapshot()
 captured_time=experiment.simulation.time
 results.clear()
func build(definition: Dictionary, memory: Array, features: Array):
 var world=World.new()
 world.parameters=[definition.duplicate(true)]
 world.parameters[0].plasticity_enabled=false
 world.bodies=[world.structure.initial(world.parameters[0])]
 world.bodies[0].memory=memory.duplicate(true)
 for item in world.bodies[0].memory:
  item.trace=0.0
  item.activation=0.0
 for surface in world.surfaces: surface.active=false
 var source=world.surfaces[5]
 source.active=true
 source.position=world.bodies[0].position+Vector2(150,0)
 source.emission=features.duplicate()
 source.field_strength=0.0
 return world
func run(experiment) -> bool:
 if reference_snapshot.is_empty(): return false
 if var_to_str(reference_snapshot.parameters)!=var_to_str(experiment.simulation.parameters): return false
 results.clear()
 var definition: Dictionary=reference_snapshot.parameters[0]
 for i in range(INPUTS.size()):
  var pair=[]
  for memory in [reference_snapshot.bodies[0].memory,experiment.simulation.bodies[0].memory]:
   var world=build(definition,memory,INPUTS[i])
   world.step(1.0/60.0)
   var first=world.observe(0)
   for tick in range(119): world.step(1.0/60.0)
   pair.append({"first":first,"last":world.observe(0)})
  results.append({"name":NAMES[i],"pair":pair})
 return true
func learned_force(body: Dictionary) -> Vector2:
 var total=Vector2.ZERO
 for c in body.contributions:
  if c.channel==0 and c.source[0]==1: total+=c.value
 return total
func summary() -> String:
 var text="冻结探测 · 参考状态 %.1fs
同一结构初态，只携带各自记忆；信号持续2秒，无机械场。
首步输入完全相同；随后自由运动可能使感受分化。
P/Q/R是显示名称，分别对应输入0/2/1，不是房间交换区A/B。

" % captured_time
 for row in results:
  text+=row.name+"
"
  for i in range(2):
   var state: Dictionary=row.pair[i].first
   var last: Dictionary=row.pair[i].last
   text+="  %s：首步关联合力 %s；首步速度 %.4f；2秒速度 %.3f；位置 %s
" % ["参考状态" if i==0 else "当前",str(learned_force(state)),state.velocity.length(),last.velocity.length(),str(last.position)]
 text+="
合力仅供比较；下面保留每项原始贡献。相同合力不代表相同记忆。
"
 return text
