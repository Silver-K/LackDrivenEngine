extends RefCounted
func visible(a: Vector2, b: Vector2, surfaces: Array) -> bool:
 for o in surfaces:
  if o.opacity > 0.5 and Geometry2D.get_closest_point_to_segment(o.position,a,b).distance_to(o.position) < o.radius: return false
 return true
func sense(index: int, bodies: Array, parameters: Array, surfaces: Array) -> Array:
 var a: Dictionary = bodies[index]
 var p: Dictionary = parameters[index]
 var samples: Array = []
 for o in surfaces:
  if not visible(a.position,o.position,surfaces): continue
  var delta: Vector2 = o.position-a.position
  if delta.length() > p.range: continue
  var amplitude: float = pow(1.0-delta.length()/p.range,2)
  if o.reservoir == 0: amplitude *= 0.05
  if o.gate and not o.open: amplitude *= 0.15
  samples.append({"axis":delta.normalized(),"signal":[o.emission[0]*amplitude,o.emission[1]*amplitude,o.emission[2]*amplitude,0.0],"geometry":Vector2.ZERO})
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
  samples.append({"axis":delta.normalized(),"signal":[parameters[j].emission[0]*amplitude,parameters[j].emission[1]*amplitude,parameters[j].emission[2]*amplitude,(b.velocity.length()/100.0+closing)*amplitude],"geometry":geometry})
 return samples
