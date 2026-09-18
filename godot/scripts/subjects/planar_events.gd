extends RefCounted
## Subject-defined event extraction from physical samples. This is not engine policy.
func validate(spec: Dictionary, input_count: int) -> String:
 if not spec.get("enabled",false): return ""
 for key in ["external","self"]:
  for rule in spec.get(key,[]):
   for feature in rule.get("features",[]):
    if feature<0 or feature>=input_count: return "Invalid feature projection"
   if not rule.has_all(["threshold","release"]) or rule.threshold<=0 or rule.release<0 or rule.release>=rule.threshold: return "Invalid event threshold"
   if rule.get("resolution",16.0)<=0: return "Invalid feature resolution"
   if key=="self":
    if not rule.has_all(["measure","input","gain"]) or rule.input<0 or rule.input>=input_count: return "Invalid self event mapping"
    if not rule.measure in ["contact_pressure","strain","activation","speed","angular_velocity"]: return "Unsupported self event measure"
 return ""

func magnitude(values: Array) -> float:
 var total=0.0
 for value in values: total+=value*value
 return sqrt(total)

func body_value(body: Dictionary, measure: String) -> float:
 match measure:
  "contact_pressure": return body.contact_pressure
  "strain": return body.strain
  "activation": return body.activation
  "speed": return body.velocity.length()
  "angular_velocity": return absf(body.angular_velocity)
 return 0.0

func crossing(state: Dictionary, key: String, value: float, rule: Dictionary) -> bool:
 var held: bool=state.get(key,false)
 if held and value<=rule.release:
  state[key]=false
 elif not held and value>=rule.threshold:
  state[key]=true
  return true
 return false

func sense(definition: Dictionary, body: Dictionary, samples: Array, input_count: int) -> Array:
 var spec: Dictionary=definition.get("event_sense",{})
 var candidates: Dictionary={}
 var output: Array=[]
 if not spec.get("enabled",false):
  body.event_state.clear()
  return output
 for sample in samples:
  if sample.get("origin",0)!=0: continue
  for rule in spec.get("external",[]):
   var mask: Array=rule.get("features",[]).duplicate()
   if mask.is_empty():
    for k in range(input_count): mask.append(k)
   mask.sort()
   var projected: Array=[]
   projected.resize(input_count)
   projected.fill(0.0)
   var strength=INF if rule.get("features",[]).size()>0 else magnitude(sample.signal)
   for k in mask:
    projected[k]=sample.signal[k]
    if rule.get("features",[]).size()>0: strength=minf(strength,absf(sample.signal[k]))
   var norm=magnitude(projected)
   if norm<0.000001: continue
   var shape: Array=[]
   for value in projected: shape.append(roundf(value/norm*rule.get("resolution",16.0))/rule.get("resolution",16.0))
   var key="external:"+JSON.stringify(mask)+":"+JSON.stringify(shape)
   var entry={"pattern":key,"origin":2,"event_from":0,"axis":sample.axis,"signal":projected,"geometry":Vector2.ZERO,"strength":strength,"rule":rule}
   # Share feature identity and hysteresis, but retain every spatial contribution.
   var supports: Array=candidates[key].supports if candidates.has(key) else []
   supports.append({"axis":sample.axis,"strength":strength})
   if not candidates.has(key) or strength>candidates[key].strength or (strength==candidates[key].strength and sample.axis.angle()<candidates[key].axis.angle()): candidates[key]=entry
   candidates[key].supports=supports
 for rule in spec.get("self",[]):
  var key="self:"+rule.measure+":"+str(rule.input)
  var projected: Array=[]
  projected.resize(input_count)
  projected.fill(0.0)
  var strength=body_value(body,rule.measure)*rule.gain
  projected[rule.input]=clampf(strength,0.0,rule.get("limit",1.0))
  candidates[key]={"pattern":key,"origin":2,"event_from":1,"axis":Vector2.from_angle(body.heading),"signal":projected,"geometry":Vector2.ZERO,"strength":strength,"rule":rule}
 var keys=candidates.keys()
 keys.sort()
 # Missing patterns release even when no sample remains in the list.
 for key in body.event_state.keys():
  if not candidates.has(key): body.event_state.erase(key)
 for key in keys:
  var entry: Dictionary=candidates[key]
  if entry.has("supports"):
   entry.supports.sort_custom(func(a,b):return a.axis.angle()<b.axis.angle() if a.axis.angle()!=b.axis.angle() else a.strength<b.strength)
  var rising=crossing(body.event_state,key,entry.strength,entry.rule)
  entry.plastic=rising and entry.rule.get("plasticity",false)
  entry.rising=rising
  entry.active=body.event_state.get(key,false)
  entry.erase("rule")
  if entry.active: output.append(entry)
 return output
