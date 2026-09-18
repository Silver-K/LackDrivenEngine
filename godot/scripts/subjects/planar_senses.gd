extends RefCounted
const Fields = preload("res://scripts/runtime/environment_fields.gd")
func visible(a: Vector2, b: Vector2, surfaces: Array) -> bool:
 return Fields.visible(a,b,surfaces)
func blank_input(p: Dictionary) -> Array:
 var value: Array=[]
 value.resize(p.receptor[0].size())
 value.fill(0.0)
 return value
func sense(index: int, bodies: Array, parameters: Array, surfaces: Array) -> Array:
 var a: Dictionary = bodies[index]
 var p: Dictionary = parameters[index]
 var samples: Array = []
 for o in surfaces:
  if not o.get("active",true): continue
  if not visible(a.position,o.position,surfaces): continue
  var delta: Vector2 = o.position-a.position
  if delta.length() > p.range: continue
  var amplitude: float = pow(1.0-delta.length()/p.range,2)
  if o.reservoir == 0: amplitude *= 0.05
  if o.gate and not o.open: amplitude *= 0.15
  if amplitude*(absf(o.emission[0])+absf(o.emission[1])+absf(o.emission[2]))<0.000001: continue
  var observed=blank_input(p)
  observed[0]=o.emission[0]*amplitude
  observed[1]=o.emission[1]*amplitude
  observed[2]=o.emission[2]*amplitude
  samples.append({"origin":0,"plastic":false,"axis":delta.normalized(),"signal":observed,"geometry":Vector2.ZERO})
 for j in range(bodies.size()):
  if j==index: continue
  var b: Dictionary = bodies[j]
  if not visible(a.position,b.position,surfaces): continue
  var delta: Vector2 = b.position-a.position
  if delta.length()>p.range: continue
  var amplitude: float = pow(1.0-delta.length()/p.range,2)
  var closing: float = maxf(0,-b.velocity.dot(delta.normalized()))/100.0
  var ratio: float = parameters[j].radius/p.radius
  var geometry: Vector2 = Vector2(maxf(0,1-ratio),maxf(0,ratio-0.6))*amplitude
  var observed=blank_input(p)
  observed[0]=parameters[j].emission[0]*amplitude
  observed[1]=parameters[j].emission[1]*amplitude
  observed[2]=parameters[j].emission[2]*amplitude
  observed[3]=(b.velocity.length()/100.0+closing)*amplitude
  samples.append({"origin":0,"plastic":false,"axis":delta.normalized(),"signal":observed,"geometry":geometry})
 return samples
