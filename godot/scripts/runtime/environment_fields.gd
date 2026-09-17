extends RefCounted
## Geometry and propagation only; shared by sensing and physical contact.
static func visible(a: Vector2, b: Vector2, surfaces: Array) -> bool:
 for o in surfaces:
  if not o.get("active",true): continue
  if o.opacity > 0.5 and Geometry2D.get_closest_point_to_segment(o.position,a,b).distance_to(o.position) < o.radius: return false
 return true

static func amplitude(position: Vector2, source: Dictionary, surfaces: Array) -> float:
 if not source.get("active",true) or not visible(position,source.position,surfaces): return 0.0
 return pow(maxf(0.0,1.0-position.distance_to(source.position)/source.get("field_radius",1.0)),2)
