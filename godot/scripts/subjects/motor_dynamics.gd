extends RefCounted
## This family's persistent motor state. No destination, coordinates or coverage input.
func initial() -> Dictionary:
 return {"change":[]}

func advance(state: Dictionary, before: Array, after: Array, dt: float) -> void:
 state.change=[]
 for j in range(after.size()): state.change.append((after[j]-before[j])/dt)

func emit(settings: Dictionary, a: Dictionary) -> Array:
 var output: Array=[]
 var forward=Vector2.from_angle(a.heading)
 for j in range(a.x.size()):
  output.append({"source":[4,j],"channel":0,"value":forward*settings.gain*settings.propulsion[j]*tanh(a.x[j])})
  output.append({"source":[5,j],"channel":1,"value":settings.gain*settings.turn[j]*a.motor_state.change[j]})
 return output
