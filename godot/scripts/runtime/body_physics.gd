extends RefCounted
## This body model, not the engine, combines channel 0 and bears opposition.
func step(a: Dictionary, p: Dictionary, surfaces: Array, contributions: Array, dt: float) -> Dictionary:
 var force = Vector2.ZERO
 var total = 0.0
 for contribution in contributions:
  if contribution.channel != 0: continue
  var vector: Vector2 = contribution.value
  force += vector
  total += vector.length()
 var environmental: Vector2 = Vector2(maxf(0,(115-a.position.x)/43)-maxf(0,(a.position.x-980)/45),maxf(0,(275-a.position.y)/35)-maxf(0,(a.position.y-570)/35))*1.5
 var opposed: float = maxf(0, total - force.length())
 a.load = opposed
 a.effort = total
 var settings: Dictionary = p.get("body_response", {})
 a.strain = maxf(0, a.get("strain",0.0) + dt * (opposed * settings.get("load_gain",0.15) - a.get("strain",0.0) * settings.get("recovery",0.4)))
 var desired: Vector2 = (force+environmental).limit_length(settings.get("limit",1.5))*p.speed/(1.0+opposed*settings.get("resistance",0.15))
 var velocity: Vector2 = a.velocity.lerp(desired,1-exp(-dt*settings.get("response",4.0)))
 var before: Vector2 = a.position
 for o in surfaces:
  if o.opacity<0.5 and p.radius<=o.aperture: continue
  var away: Vector2 = a.position-o.position
  if away.length()<o.radius+p.radius+45 and velocity.dot(away)<0:
   var tangent=Vector2(-away.y,away.x).normalized()
   if tangent.dot(velocity)<0: tangent=-tangent
   velocity=velocity.lerp(tangent*velocity.length(),0.85)
 a.position=(a.position+velocity*dt).clamp(Vector2(72,240),Vector2(1025,605))
 for o in surfaces:
  if o.opacity<0.5 and p.radius<=o.aperture: continue
  var away: Vector2 = a.position-o.position
  var minimum: float = o.radius+p.radius
  if away.length()<minimum: a.position=o.position+(away.normalized() if away.length()>0 else Vector2.RIGHT)*minimum
 a.velocity=(a.position-before)/dt
 a.flux=0.0; a.touch=-1
 var exchange: Array = []
 exchange.resize(p.exchange_channels)
 exchange.fill(0.0)
 a.age += dt
 for k in range(surfaces.size()):
  var o: Dictionary = surfaces[k]
  if a.position.distance_to(o.position)>o.radius+p.radius*0.35 or p.radius>o.aperture or o.opacity>0.5: continue
  a.touch=k
  var amount: float = dt*1.5/(1+a.velocity.length()/30.0)
  if o.reservoir>=0:
   amount=minf(amount,o.reservoir); o.reservoir-=amount
  a.flux+=amount
  for j in range(exchange.size()):
   var change: float = o.exchange[j]*amount
   exchange[j] += change / dt

  a.velocity *= exp(-dt*o.compliance)
  if o.movable: o.position=(o.position+a.velocity*dt*0.3).clamp(Vector2(90,260),Vector2(990,590))
 return {"exchange":exchange,"load":opposed,"strain":a.strain}
