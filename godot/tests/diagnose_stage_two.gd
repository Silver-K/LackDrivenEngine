extends SceneTree
## Measurement only: independent experiments, physical interventions, frozen probes.
const Experiment = preload("res://scripts/room_experiment.gd")
const Probe = preload("res://scripts/experiment_probe.gd")
const DT = 1.0 / 60.0
const OUTPUT = "res://../artifacts/stage-two-audit-2026-09-18.json"
var failures: Array = []

func check(ok: bool, message: String) -> void:
 if not ok: failures.append(message)

func vector(v: Vector2) -> Array:
 return [v.x, v.y]

func metrics() -> Dictionary:
 return {"seconds":0.0,"min_distance":INF,"max_distance":0.0,"low_seconds":0.0,"inside_seconds":0.0,"max_speed":0.0,"min_activation":1.0,"max_activation":0.0,"load_integral":0.0,"x0_lower_bound_seconds":0.0}

func measure(lab, row: Dictionary) -> void:
 var b: Dictionary = lab.simulation.bodies[0]
 var distance: float = b.position.distance_to(lab.simulation.surfaces[0].position)
 row.seconds += DT
 row.min_distance = minf(row.min_distance, distance)
 row.max_distance = maxf(row.max_distance, distance)
 row.max_speed = maxf(row.max_speed, b.velocity.length())
 row.min_activation = minf(row.min_activation, b.activation)
 row.max_activation = maxf(row.max_activation, b.activation)
 row.load_integral += b.load * DT
 if b.velocity.length() < 1.0: row.low_seconds += DT
 if distance <= 60.25: row.inside_seconds += DT
 if b.x[0] <= -1.5 + 0.000001: row.x0_lower_bound_seconds += DT
 check(b.position.is_finite() and b.velocity.is_finite() and is_finite(b.strain) and is_finite(b.activation), "nonfinite body")
 check(lab.simulation.last_error.is_empty(), "world error")

func sample(lab) -> Dictionary:
 var b: Dictionary = lab.simulation.bodies[0]
 var force = Vector2.ZERO
 var learned = Vector2.ZERO
 var intrinsic = Vector2.ZERO
 var torque = 0.0
 var contributions: Array = []
 for c in b.contributions:
  contributions.append({"source":c.source.duplicate(),"channel":c.channel,"value":vector(c.value) if c.channel == 0 else c.value})
  if c.channel == 0:
   force += c.value
   if c.source[0] == 1: learned += c.value
   if c.source[0] == 4: intrinsic += c.value
  else: torque += c.value
 return {"time":lab.simulation.time,"position":vector(b.position),"distance_A":b.position.distance_to(lab.simulation.surfaces[0].position),"speed":b.velocity.length(),"activation":b.activation,"strain":b.strain,"load":b.load,"effort":b.effort,"force":vector(force),"learned":vector(learned),"intrinsic":vector(intrinsic),"torque":torque,"x":b.x.duplicate(),"touch":b.touch,"flux":b.flux,"memory_strength":lab.simulation.association_strength(0),"contributions":contributions}

func physical_conditions(lab, mode: String, original: Dictionary, enabled: bool) -> void:
 var a: Dictionary = lab.simulation.surfaces[0]
 a.emission = [0.0,0.0,0.0] if enabled and mode == "signal_off" else original.emission.duplicate()
 a.compliance = 0.0 if enabled and mode in ["no_damping", "exchange_off"] else original.compliance
 lab.exchange_enabled = not (enabled and mode == "exchange_off")
 lab.relocated = enabled and mode == "relocated"
 lab.configure()

func branch(snapshot: Dictionary, mode: String) -> Dictionary:
 var lab = Experiment.new()
 check(lab.restore(snapshot), "branch restore " + mode)
 var original: Dictionary = lab.simulation.surfaces[0].duplicate(true)
 var before = var_to_str(lab.simulation.bodies)
 physical_conditions(lab, mode, original, true)
 check(before == var_to_str(lab.simulation.bodies), "physical intervention changed body " + mode)
 var phases = [metrics(), metrics()]
 var samples: Array = [sample(lab)]
 for tick in range(21600):
  if tick == 10800:
   before = var_to_str(lab.simulation.bodies)
   physical_conditions(lab, mode, original, false)
   check(before == var_to_str(lab.simulation.bodies), "apparatus restoration changed body " + mode)
  lab.step(DT)
  measure(lab, phases[0 if tick < 10800 else 1])
  if (tick + 1) % 60 == 0: samples.append(sample(lab))
 var result = {"mode":mode,"intervention":phases[0],"after_restoration":phases[1],"samples":samples}
 print("BRANCH ", mode, " ", JSON.stringify({"intervention":phases[0],"after_restoration":phases[1],"last":samples[-1]}))
 return result

func permanent(memory: Array) -> Array:
 return memory.map(func(m): return [m.get("pattern", ""),m.effect.duplicate(),m.exposure,m.updates])

func frozen_probe(snapshot: Dictionary) -> Dictionary:
 var probe = Probe.new()
 var definition: Dictionary = snapshot.parameters[0]
 var result: Array = []
 var first_samples: Array = []
 for memory in [[], snapshot.bodies[0].memory]:
  var world = probe.build(definition, memory, snapshot.surfaces[0].emission)
  var initial = world.bodies[0].position
  var saved_memory = permanent(world.bodies[0].memory)
  world.step(DT)
  first_samples.append(world.bodies[0].sensory_snapshot.duplicate(true))
  var learned: Vector2 = probe.learned_force(world.bodies[0])
  var first_speed: float = world.bodies[0].velocity.length()
  for tick in range(119): world.step(DT)
  check(permanent(world.bodies[0].memory) == saved_memory, "probe changed permanent memory")
  result.append({"memory_count":memory.size(),"memory_strength":world.structure.policy(definition).magnitude(memory),"first_learned_force":vector(learned),"first_speed":first_speed,"displacement_2s":vector(world.bodies[0].position-initial),"speed_2s":world.bodies[0].velocity.length()})
 check(first_samples[0] == first_samples[1], "probe first sensory inputs differ")
 check(result[0].first_learned_force == [0.0,0.0], "blank memory emits learned force")
 print("FROZEN_PROBE ", JSON.stringify(result))
 return {"blank":result[0],"experienced":result[1],"equal_first_sensation":first_samples[0] == first_samples[1]}

func _initialize() -> void:
 var lab = Experiment.new()
 lab.set_stage(1)
 var windows = [metrics(), metrics(), metrics()]
 var samples: Array = []
 var crossings: Array = []
 var checkpoint: Dictionary = {}
 var previous_inside = false
 for tick in range(108000):
  lab.step(DT)
  measure(lab, windows[mini(2, tick / 36000)])
  var b: Dictionary = lab.simulation.bodies[0]
  var inside: bool = b.touch == 0
  if inside != previous_inside: crossings.append({"time":lab.simulation.time,"enter":inside})
  previous_inside = inside
  if (tick + 1) % 60 == 0: samples.append(sample(lab))
  if tick + 1 == 36000: checkpoint = lab.snapshot()
  if (tick + 1) % 36000 == 0: print("BASELINE ", lab.simulation.time, " ", JSON.stringify(windows[mini(2, tick / 36000)]))
 var saved = var_to_str(checkpoint)
 var report = {"protocol":{"dt":DT,"baseline_seconds":1800,"branch_start_seconds":600,"intervention_seconds":180,"restoration_seconds":180,"exchange_control":"no_damping and exchange_off both use zero compliance; compare them to isolate exchange without damping","scope":"fresh stage two; independent copies; no changes to live room or model"},"baseline":{"windows":windows,"crossings":crossings,"samples":samples},"branches":[],"frozen_probe":frozen_probe(checkpoint)}
 for mode in ["reference", "signal_off", "no_damping", "exchange_off", "relocated"]:
  report.branches.append(branch(checkpoint, mode))
 check(saved == var_to_str(checkpoint), "diagnostics changed training snapshot")
 var repeated_probe = frozen_probe(checkpoint)
 check(repeated_probe == report.frozen_probe, "probe not reproducible")
 report.failures = failures
 var file = FileAccess.open(OUTPUT, FileAccess.WRITE)
 if file == null:
  push_error("Cannot write diagnostic report")
  quit(1)
  return
 file.store_string(JSON.stringify(report))
 print("STAGE_TWO_AUDIT_RESULT failures=", failures.size(), " output=", OUTPUT)
 quit(0 if failures.is_empty() else 1)
