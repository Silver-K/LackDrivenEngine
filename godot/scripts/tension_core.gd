extends RefCounted
## Stateless executor. The supplied structure owns every evolution/learning equation.
func validate(structure, definition: Dictionary) -> String:
 for method in ["validate", "advance", "emit", "receive"]:
  if not structure.has_method(method): return "Missing structure method: " + method
 return structure.validate(definition)

func advance(structure, definition: Dictionary, state: Dictionary, sensation: Array, dt: float) -> Dictionary:
 if dt <= 0 or not is_finite(dt): return {"error":"Invalid time step"}
 var error: String = validate(structure,definition)
 if not error.is_empty(): return {"error":error}
 # Mutable runtime values and immutable definitions are separated by copies.
 var local_definition: Dictionary = definition.duplicate(true)
 var next: Dictionary = structure.advance(local_definition,state.duplicate(true),sensation.duplicate(true),dt)
 var contributions: Array = structure.emit(local_definition,next.duplicate(true),sensation.duplicate(true))
 for contribution in contributions:
  if not contribution is Dictionary or not contribution.has_all(["source","channel","value"]):
   return {"error":"Incomplete contribution"}
  if not definition.channels.any(func(channel): return channel == contribution.channel):
   return {"error":"Undeclared body channel"}
 return {"state":next,"contributions":contributions.duplicate(true)}

func receive(structure, definition: Dictionary, state: Dictionary, feedback: Dictionary, dt: float) -> Dictionary:
 return structure.receive(definition.duplicate(true),state.duplicate(true),feedback.duplicate(true),dt)
