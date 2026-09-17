extends RefCounted
## Optional body-to-sample mapping for this subject family, not an engine facility.
func validate(spec: Dictionary, input_count: int) -> String:
 if not spec.get("enabled",false): return ""
 if not spec.has("channels") or spec.channels.is_empty(): return "Missing self sense channels"
 for channel in spec.channels:
  if not channel.has_all(["input","measure","gain"]) or channel.input<0 or channel.input>=input_count: return "Invalid self sense channel"
  if not channel.measure in ["speed","angular_velocity","activation","strain"]: return "Unsupported body measure"
 return ""

func value(body: Dictionary, measure: String) -> float:
 match measure:
  "speed": return body.velocity.length()
  "angular_velocity": return absf(body.angular_velocity)
  "activation": return body.activation
  "strain": return body.strain
 return 0.0

func sense(body: Dictionary, definition: Dictionary, input_count: int) -> Array:
 var spec: Dictionary=definition.get("self_sense",{})
 if not spec.get("enabled",false): return []
 var sensed: Array=[]
 sensed.resize(input_count)
 sensed.fill(0.0)
 for channel in spec.channels:
  sensed[channel.input]=clampf(value(body,channel.measure)*channel.gain,0.0,channel.get("limit",1.0))
 var magnitude=0.0
 for item in sensed: magnitude+=item*item
 if magnitude<0.000001: return []
 return [{"origin":1,"plastic":spec.get("plasticity",false),"axis":Vector2.from_angle(body.heading),"signal":sensed,"geometry":Vector2.ZERO}]
