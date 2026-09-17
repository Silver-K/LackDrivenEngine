extends RefCounted
## Composition root, not a psychological model. Explicitly assembles one subject family.
const Executor = preload("res://scripts/tension_core.gd")
const Structure = preload("res://scripts/subjects/planar_structure.gd")
const Body = preload("res://scripts/runtime/body_physics.gd")
var core = Executor.new()
var structure = Structure.new()
var physics = Body.new()
var bodies: Array = []
var surfaces: Array = []
var parameters: Array = []
var time=0.0
var last_error=""
func _init(config: Dictionary = {}) -> void:
 var data: Dictionary = config if not config.is_empty() else JSON.parse_string(FileAccess.get_file_as_string("res://data/body_model.json"))
 parameters=data.bodies.duplicate(true)
 for p in parameters:
  last_error=core.validate(structure,p)
  if not last_error.is_empty(): return
  bodies.append(structure.initial(p))
 for item in data.surfaces:
  var o: Dictionary = item.duplicate(true)
  o.position=Vector2(item.position[0],item.position[1])
  surfaces.append(o)
func sense(index: int) -> Array:
 return structure.senses.sense(index,bodies,parameters,surfaces)
func association_strength(index: int) -> float:
 return structure.policy(parameters[index]).magnitude(bodies[index].memory)
func step(dt: float) -> void:
 if dt<=0 or not last_error.is_empty(): return
 var pending: Array = []
 for i in range(bodies.size()):
  # Previous output records are observations, not input state for the next frame.
  var frame_state: Dictionary = bodies[i].duplicate()
  frame_state.erase("contributions")
  frame_state.erase("vectors")
  var result: Dictionary = core.advance(structure,parameters[i],frame_state,sense(i),dt)
  if result.has("error"):
   last_error=result.error
   return
  pending.append(result)
 time+=dt
 for i in range(bodies.size()):
  bodies[i]=pending[i].state
  var feedback: Dictionary = physics.step(bodies[i],parameters[i],surfaces,pending[i].contributions,dt)
  bodies[i]=core.receive(structure,parameters[i],bodies[i],feedback,dt)
  bodies[i].contributions=pending[i].contributions
  bodies[i].vectors=pending[i].contributions.map(func(c):return c.value)
 for i in range(bodies.size()):
  for j in range(i+1,bodies.size()):
   var a: Dictionary = bodies[i]
   var b: Dictionary = bodies[j]
   var away: Vector2 = a.position-b.position
   var minimum: float = parameters[i].radius+parameters[j].radius
   if away.length()<minimum:
    var correction: Vector2 = (away.normalized() if away.length()>0 else Vector2.RIGHT)*(minimum-away.length())*0.5
    a.position=(a.position+correction).clamp(Vector2(72,240),Vector2(1025,605))
    b.position=(b.position-correction).clamp(Vector2(72,240),Vector2(1025,605))
