extends RefCounted
const Fields = preload("res://scripts/runtime/environment_fields.gd")
## This body combines translation and rotation only after preserving their sources.
func step(a: Dictionary, p: Dictionary, surfaces: Array, contributions: Array, dt: float, room: Rect2 = Rect2(-100000,-100000,200000,200000)) -> Dictionary:
 var force=Vector2.ZERO
 var total=0.0
 var torque=0.0
 var angular_total=0.0
 for contribution in contributions:
  if contribution.channel==0:
   force+=contribution.value
   total+=contribution.value.length()
  elif contribution.channel==1:
   torque+=contribution.value
   angular_total+=absf(contribution.value)
 var settings: Dictionary=p.body_response
 var opposed: float=maxf(0,total-force.length())+maxf(0,angular_total-absf(torque))*settings.angular_load
 a.load=opposed
 a.effort=total+angular_total*settings.angular_load
 # Continuous excitable actuator with slow use-dependent adaptation.
 # No rest mode, duration, destination or elapsed-age input.
 var drive: float=force.length()+absf(torque)*settings.angular_load
 var activation_target: float=1.0/(1.0+exp(-settings.activation_slope*(drive+settings.self_excitation*a.activation-settings.activation_threshold-a.strain)))
 a.activation=lerpf(a.activation,activation_target,1-exp(-dt*settings.activation_rate))
 var exertion: float=a.effort*a.activation
 a.strain=maxf(0,a.strain+dt*(exertion*settings.use_gain+opposed*a.activation*settings.load_gain-a.strain*settings.recovery))
 a.angular_velocity=(a.angular_velocity+torque*a.activation*dt)/(1.0+settings.angular_drag*dt)
 a.heading=wrapf(a.heading+a.angular_velocity*dt,-PI,PI)
 var environmental=Vector2.ZERO
 var mechanical=0.0
 for o in surfaces:
  var strength: float=o.get("field_strength",0.0)*Fields.amplitude(a.position,o,surfaces)
  environmental+=(a.position-o.position).normalized()*strength
  mechanical+=strength
 var desired: Vector2=(force*a.activation+environmental).limit_length(settings.limit)*p.speed/(1.0+opposed*settings.resistance)
 var velocity: Vector2=a.velocity.lerp(desired,1-exp(-dt*settings.response))
 var position: Vector2=a.position+velocity*dt
 var pressure=0.0
 var hit=false
 # Contact projection and normal impulse only. No anticipatory tangent steering.
 for o in surfaces:
  if not o.get("active",true) or (o.opacity<0.5 and p.radius<=o.aperture): continue
  var away: Vector2=position-o.position
  var minimum: float=o.radius+p.radius
  if away.length()>=minimum: continue
  var normal: Vector2=away.normalized() if away.length()>0 else -Vector2.from_angle(a.heading)
  position=o.position+normal*minimum
  var incoming: float=minf(0.0,velocity.dot(normal))
  pressure-=incoming/maxf(1.0,p.speed)
  velocity-=normal*incoming*(1.0+settings.restitution)
  hit=true
 var low: Vector2=room.position+Vector2.ONE*p.radius
 var high: Vector2=room.end-Vector2.ONE*p.radius
 for axis in range(2):
  if position[axis]>=low[axis] and position[axis]<=high[axis]: continue
  var normal=Vector2.ZERO
  normal[axis]=1.0 if position[axis]<low[axis] else -1.0
  position[axis]=clampf(position[axis],low[axis],high[axis])
  var incoming: float=minf(0.0,velocity.dot(normal))
  pressure-=incoming/maxf(1.0,p.speed)
  velocity-=normal*incoming*(1.0+settings.restitution)
  hit=true
 a.position=position
 a.velocity=velocity
 if velocity.length()>0.01:
  # Collision reorients the compliant body; otherwise orientation follows motion gradually.
  a.heading=velocity.angle() if hit else lerp_angle(a.heading,velocity.angle(),1-exp(-dt*settings.heading_alignment))
 a.contact_pressure=pressure
 a.flux=0.0
 a.touch=-1
 a.age+=dt
 var exchange: Array=[]
 exchange.resize(p.exchange_channels)
 exchange.fill(0.0)
 if exchange.size()>0: exchange[exchange.size()-1]=mechanical+pressure/dt
 for k in range(surfaces.size()):
  var o: Dictionary=surfaces[k]
  if not o.get("active",true) or not o.get("exchange_enabled",true): continue
  if o.exchange.all(func(v):return v==0): continue
  if position.distance_to(o.position)>o.radius+p.radius*0.35 or p.radius>o.aperture or o.opacity>0.5: continue
  a.touch=k
  var amount: float=dt*1.5/(1+velocity.length()/30.0)
  if o.reservoir>=0:
   amount=minf(amount,o.reservoir)
   o.reservoir-=amount
  a.flux+=amount
  for j in range(exchange.size()): exchange[j]+=o.exchange[j]*amount/dt
  a.velocity*=exp(-dt*o.compliance)
  if o.movable: o.position=(o.position+a.velocity*dt*0.3).clamp(low,high)
 return {"exchange":exchange,"load":opposed,"strain":a.strain,"contact_pressure":pressure}
