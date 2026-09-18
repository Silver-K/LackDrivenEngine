extends RefCounted
## Subject-defined event extraction from physical samples. This is not engine policy.
func validate(spec: Dictionary, input_count: int) -> String:
 if not spec.get("enabled",false): return ""
 for key in ["external","self"]:
  for rule in spec.get(key,[]):
   if rule.get("threshold",0.0)<=0 or rule.get("release",0.0)<0 or rule.release>rule.threshold: return "Invalid event threshold"
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
 if not spec.get("enabled",false): return []
 var state: Dictionary=body.event_state
 var events: Array=[]
 for sample_index in range(samples.size()):
  var sample: Dictionary=samples[sample_index]
  if sample.origin!=0: continue
  var value=magnitude(sample.signal)
  for rule_index in range(spec.get("external",[]).size()):
   var rule: Dictionary=spec.external[rule_index]
   if crossing(state,"external:%d:%d" % [rule_index,sample_index],value,rule):
    var event=sample.duplicate(true)
    event.origin=2
    event.event_from=0
    event.event_rule=rule_index
    event.plastic=rule.get("plasticity",true)
    events.append(event)
 for rule_index in range(spec.get("self",[]).size()):
  var rule: Dictionary=spec.self[rule_index]
  var value=body_value(body,rule.measure)*rule.gain
  if not crossing(state,"self:%d" % rule_index,value,rule): continue
  var sensed: Array=[]
  sensed.resize(input_count)
  sensed.fill(0.0)
  sensed[rule.input]=clampf(value,0.0,rule.get("limit",1.0))
  events.append({"origin":2,"event_from":1,"event_rule":rule_index,"plastic":rule.get("plasticity",true),"axis":Vector2.from_angle(body.heading),"signal":sensed,"geometry":Vector2.ZERO})
 return events
