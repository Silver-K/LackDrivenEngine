extends RefCounted
## Presentation adapter only. Labels never enter physical_world or tension_core.
const Simulation = preload("res://scripts/physical_world.gd")
var simulation = Simulation.new()
var profiles = {}
var animals = {}
var objects = {}
var events = []
var time = 0.0
var visual: Dictionary
func _init(_seed: int = 42) -> void:
 visual=JSON.parse_string(FileAccess.get_file_as_string("res://data/animals.json"))
 for p in visual.subjects: profiles[p.id]=p.duplicate(true)
 sync()
 events.append({"time":0,"text":"观察运动与接触；名称只属于画面，不进入主体的感知。"})
func sync() -> void:
 time=simulation.time
 for i in range(visual.objects.size()):
  var o: Dictionary = visual.objects[i].duplicate(true)
  var body: Dictionary = simulation.surfaces[i]
  o.position=body.position
  o.open=body.open
  if body.reservoir>=0: o.stock=body.reservoir; o.capacity=100.0
  objects[o.id]=o
 for i in range(visual.subjects.size()):
  var p: Dictionary = visual.subjects[i]
  var b: Dictionary = simulation.bodies[i]
  var action="idle"
  var posture="停留观察"
  if b.velocity.length()>5: action="explore"; posture="缓缓移动"
  if b.touch>=0:
   var kind: String = visual.objects[b.touch].kind
   if b.flux>0 and kind=="food": action="eat"; posture="接触食盆"
   elif b.flux>0 and kind=="water": action="drink"; posture="接触水盆"
   elif kind in ["bed","shelter"] and b.velocity.length()<15: action="rest"; posture="伏下休息"
   elif kind=="toy": action="play"; posture="拨动物件"
  for j in range(simulation.bodies.size()):
   if i==j: continue
   var other: Dictionary = simulation.bodies[j]
   var delta: Vector2 = other.position-b.position
   if delta.length()<200 and b.velocity.dot(delta.normalized())>35 and other.velocity.dot(delta.normalized())>15:
    action="chase"; posture="同向追随"
  animals[p.id]={"id":p.id,"position":b.position,"velocity":b.velocity,"action":action,"posture":posture,"phase":"moving" if b.velocity.length()>5 else "acting","motion":b.phase*12,"direction":-1 if b.velocity.x<0 else 1,"x":b.x.duplicate(),"input":b.input.duplicate(),"vectors":b.vectors.duplicate(),"range":simulation.parameters[i].range}
  animals[p.id].load=b.load
  animals[p.id].strain=b.strain
  animals[p.id].effort=b.effort
  animals[p.id].age=b.age
  animals[p.id].association_strength=simulation.association_strength(i)
  animals[p.id].memory_count=b.memory.size()
func step(dt: float) -> void:
 simulation.step(dt)
 sync()
func interact(id: String) -> void:
 for i in range(visual.objects.size()):
  if visual.objects[i].id!=id: continue
  var o: Dictionary = simulation.surfaces[i]
  if o.reservoir>=0: o.reservoir=100.0
  elif o.gate: o.open=not o.open
  elif o.movable: o.position=Vector2(420+sin(time)*90,440+cos(time)*65)
  events.push_front({"time":time,"text":"你触碰了"+visual.objects[i].label+"。"})
  if events.size()>40: events.pop_back()
 sync()
func care(id: String) -> void:
 for i in range(visual.subjects.size()):
  if visual.subjects[i].id==id:
   # Physical touch impulse is spread across receptor channels, no emotional label.
   for j in range(4): simulation.bodies[i].trace[j]+=0.03
 sync()

func save_history(path: String = "user://development.bin") -> bool:
 var file = FileAccess.open(path + ".tmp", FileAccess.WRITE)
 if file == null: return false
 file.store_var({"version":4,"bodies":simulation.bodies,"surfaces":simulation.surfaces,"parameters":simulation.parameters,"time":simulation.time})
 file.close()
 return DirAccess.rename_absolute(path + ".tmp",path)==OK

func load_history(path: String = "user://development.bin") -> bool:
 if not FileAccess.file_exists(path): return false
 var file = FileAccess.open(path,FileAccess.READ)
 var data = file.get_var(false)
 if not data is Dictionary or data.get("version") != 4: return false
 if not data.get("bodies") is Array or data.bodies.size()!=visual.subjects.size(): return false
 if not data.get("surfaces") is Array or data.surfaces.size()!=visual.objects.size(): return false
 if not data.get("parameters") is Array or data.parameters.size()!=data.bodies.size(): return false
 for body in data.bodies:
  if not body is Dictionary or not body.get("position") is Vector2 or not body.get("memory") is Array or not body.get("x") is Array: return false
 for i in range(data.parameters.size()):
  if not simulation.core.validate(simulation.structure,data.parameters[i]).is_empty(): return false
  if data.bodies[i].x.size()!=data.parameters[i].state.size(): return false
  if not data.bodies[i].has_all(["velocity","trace","input","phase","load","strain","effort","age","outcome","contributions"]): return false
  for memory in data.bodies[i].memory:
   if not memory is Dictionary or not memory.has_all(["signature","effect","trace","activation","exposure","updates"]): return false
   if memory.effect.size()!=data.bodies[i].x.size(): return false
 simulation.bodies=data.bodies
 simulation.surfaces=data.surfaces
 simulation.parameters=data.parameters
 simulation.time=data.time
 sync()
 return true
