extends RefCounted
## This family's persistent motor state. No destination, coordinates or coverage input.
func initial(settings: Dictionary) -> Dictionary:
 return {"seed":int(settings.seed),"clock":0.0,"sample":0.0,"fluctuation":0.0,"change":[]}

func advance(settings: Dictionary, state: Dictionary, before: Array, after: Array, dt: float) -> void:
 state.clock -= dt
 while state.clock<=0:
  # Per-body PRNG state is saved with experience, never shared across subjects.
  state.seed=(int(state.seed)*48271)%2147483647
  state.sample=float(state.seed)/2147483647.0*2.0-1.0
  state.clock+=settings.sample_interval
 state.fluctuation=lerpf(state.fluctuation,state.sample,1-exp(-dt/settings.correlation_time))
 state.change=[]
 for j in range(after.size()): state.change.append((after[j]-before[j])/dt)

func emit(settings: Dictionary, a: Dictionary) -> Array:
 var output: Array=[]
 var forward=Vector2.from_angle(a.heading)
 for j in range(a.x.size()):
  output.append({"source":[4,j],"channel":0,"value":forward*settings.gain*settings.propulsion[j]*tanh(a.x[j])})
  output.append({"source":[5,j],"channel":1,"value":settings.gain*settings.turn[j]*a.motor_state.change[j]})
 output.append({"source":[6],"channel":1,"value":settings.gain*settings.fluctuation_gain*a.motor_state.fluctuation})
 return output
