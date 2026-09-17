extends RefCounted
## One concrete subject family. None of these equations are universal engine policy.
const Plasticity = preload("res://scripts/subjects/trace_plasticity.gd")
const Senses = preload("res://scripts/subjects/planar_senses.gd")
var senses = Senses.new()
func validate(p: Dictionary) -> String:
 var n: int = p.get("state",[]).size()
 if n<3: return "This planar subject requires at least three dimensions"
 for key in ["receptor","coupling","drift","motor","feedback_load"]:
  if not p.has(key) or p[key].size()!=n: return "Invalid dimension: " + key
 var inputs: int = p.receptor[0].size()
 for i in range(n):
  if p.receptor[i].size()!=inputs or p.coupling[i].size()!=n: return "Invalid coupling shape"
 for prior in p.get("associations",[]):
  if prior.effect.size()!=n or prior.signature.size()!=inputs: return "Invalid prior shape"
 if p.get("feedback_exchange",[]).size()!=n: return "Invalid feedback mapping"
 for row in p.feedback_exchange:
  if row.size()!=p.exchange_channels: return "Invalid physical exchange channels"
 if p.get("channels",[]).size()!=1 or p.channels[0]!=0: return "Planar body exposes channel 0"
 return ""
func policy(p: Dictionary):
 return Plasticity.new(p.state.size(),p.get("trace_window",2.5))
func initial(p: Dictionary) -> Dictionary:
 var n: int = p.state.size()
 var zero: Array = []
 zero.resize(p.receptor[0].size()); zero.fill(0.0)
 return {"position":Vector2(p.position[0],p.position[1]),"velocity":Vector2.ZERO,"x":p.state.duplicate(),"trace":zero.duplicate(),"input":zero.duplicate(),"vectors":[],"contributions":[],"flux":0.0,"touch":-1,"phase":0.0,"memory":policy(p).create(p.get("associations",[])),"age":0.0,"outcome":policy(p).zeros(),"load":0.0,"effort":0.0,"strain":0.0}
func advance(p: Dictionary, a: Dictionary, samples: Array, dt: float) -> Dictionary:
 var learning = policy(p)
 learning.perceive(a.memory,samples,dt)
 var input: Array = []
 input.resize(p.receptor[0].size()); input.fill(0.0)
 for sample in samples:
  for k in range(input.size()): input[k]+=sample.signal[k]
 var next: Array = []
 for j in range(a.x.size()):
  var drive: float = p.drift[j]
  for k in range(input.size()): drive+=p.receptor[j][k]*(input[k]-a.trace[k])*p.dynamics.sensory_gain
  for k in range(a.x.size()): drive+=p.coupling[j][k]*tanh(a.x[k])*p.dynamics.coupling_gain
  next.append(clampf(a.x[j]+dt*(drive-a.x[j]*p.dynamics.decay),-p.dynamics.bound,p.dynamics.bound))
 a.x=next
 a.input=input
 # Preserve pre-update trace for attention calculation.
 a.previous_trace=a.trace.duplicate()
 for k in range(input.size()): a.trace[k]=lerpf(a.trace[k],input[k],1-exp(-dt*p.dynamics.trace_rate))
 a.phase+=dt*(p.dynamics.phase_rate+absf(a.x[1]))
 return a
func add(output: Array, source: Array, value: Vector2) -> void:
 output.append({"source":source,"channel":0,"value":value})
func emit(p: Dictionary, a: Dictionary, samples: Array) -> Array:
 var output: Array = []
 var learning=policy(p)
 for s in range(samples.size()):
  var sample: Dictionary = samples[s]
  # Preserve opposing geometry, each dimension, each memory and each receptor term.
  add(output,[0,s,0],sample.axis*sample.geometry.x*p.size_gain)
  add(output,[0,s,1],sample.axis*sample.geometry.y*p.mass_gain)
  var signature: Array = learning.unit(sample.signal)
  for m in range(a.memory.size()):
   var item: Dictionary = a.memory[m]
   var overlap: float = learning.similarity(signature,item.signature)
   for j in range(a.x.size()):
    add(output,[1,s,m,j],sample.axis*(-a.x[j]*item.effect[j]*overlap*p.dynamics.association_gain))
  for j in range(a.x.size()):
   for k in range(sample.signal.size()):
    add(output,[2,s,j,k],sample.axis*p.motor[j]*p.receptor[j][k]*sample.signal[k]*(p.dynamics.motor_offset+a.x[j])*p.dynamics.motor_gain)
  var novelty=0.0
  for k in range(sample.signal.size()): novelty+=absf(sample.signal[k]-a.previous_trace[k])
  add(output,[3,s],sample.axis*minf(p.dynamics.attention_limit,novelty*p.dynamics.attention_gain))
 add(output,[4],Vector2(cos(a.phase),sin(a.phase*0.73))*p.exploration*(0.3+absf(a.x[0]-a.x[2])))
 return output
func receive(p: Dictionary, a: Dictionary, physical: Dictionary, dt: float) -> Dictionary:
 var outcome: Array = []
 for j in range(a.x.size()):
  var change: float = p.feedback_load[j]*physical.load
  for k in range(physical.exchange.size()): change+=p.feedback_exchange[j][k]*physical.exchange[k]
  a.x[j]=clampf(a.x[j]+change*dt,-p.dynamics.bound,p.dynamics.bound)
  outcome.append(change)
 a.outcome=outcome
 if p.plasticity_enabled: policy(p).learn(a.memory,outcome,dt,p.learning_rate)
 return a
