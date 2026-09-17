extends RefCounted
## External apparatus and repeatable history. Never writes psychological state.
const World = preload("res://scripts/physical_world.gd")
var simulation = World.new()
var stage = 1
var apparatus_time = 0.0
var cue_only = false
var exchange_enabled = true
var relocated = false
var moving_source = true
var samples: Array = []
var path: Array = []
var events: Array = []
var sample_clock = 0.0
var previous_touch = -1

func _init() -> void:
 configure()

func configure() -> void:
 var objects: Array = simulation.surfaces
 objects[0].active = stage >= 1
 objects[1].active = stage >= 3
 for i in range(2,5): objects[i].active = stage >= 3
 objects[5].active = stage >= 2
 objects[0].exchange_enabled = exchange_enabled
 objects[1].exchange_enabled = exchange_enabled
 objects[0].position = Vector2(700,470) if relocated else Vector2(390,435)
 objects[1].position = Vector2(390,435) if relocated else Vector2(685,435)
 var source: Dictionary = objects[5]
 source.position = Vector2(760+sin(apparatus_time*0.13)*110,325+sin(apparatus_time*0.21)*45) if moving_source else Vector2(760,325)
 var phase = fmod(apparatus_time,12.0)
 source.emission = [0.08,0.08,1.0] if phase<1.5 else [0.0,0.0,0.0]
 source.field_strength = 2.0 if phase>=1.5 and phase<3.5 and not cue_only else 0.0

func set_stage(value: int) -> void:
 stage = clampi(value,0,3)
 apparatus_time = 0.0
 configure()
 log_event("切换阶段 %02d · 保留经历" % (stage+1))

func log_event(message: String) -> void:
 events.push_front("%6.1fs  %s" % [simulation.time,message])
 if events.size()>6: events.pop_back()

func step(dt: float) -> void:
 configure()
 simulation.step(dt)
 apparatus_time += dt
 var body: Dictionary = simulation.bodies[0]
 if body.touch != previous_touch:
  if body.touch>=0: log_event("接触 %s" % ("A" if body.touch==0 else "B"))
  previous_touch = body.touch
 sample_clock += dt
 if sample_clock >= 0.2:
  sample_clock -= 0.2
  samples.append({"x":body.x.duplicate(),"load":body.load,"memory":simulation.association_strength(0)})
  path.append(body.position)
  if samples.size()>240: samples.pop_front()
  if path.size()>500: path.pop_front()

func reset() -> void:
 simulation = World.new()
 apparatus_time = 0.0
 sample_clock = 0.0
 samples.clear()
 path.clear()
 events.clear()
 previous_touch = -1
 configure()
 log_event("初始状态重置 · 环境开关保留")

func snapshot() -> Dictionary:
 return {"format":"tension-room","version":5,"room":simulation.room,"bodies":simulation.bodies.duplicate(true),"surfaces":simulation.surfaces.duplicate(true),"parameters":simulation.parameters.duplicate(true),"time":simulation.time,"stage":stage,"apparatus_time":apparatus_time,"cue_only":cue_only,"exchange_enabled":exchange_enabled,"relocated":relocated,"moving_source":moving_source,"samples":samples.duplicate(true),"path":path.duplicate(),"events":events.duplicate(),"sample_clock":sample_clock,"previous_touch":previous_touch}

func restore(data: Dictionary) -> bool:
 if data.get("format","")!="tension-room" or data.get("version",0)!=5: return false
 for key in ["room","bodies","surfaces","parameters","time","stage","apparatus_time","cue_only","exchange_enabled","relocated","moving_source","samples","path","events","sample_clock","previous_touch"]:
  if not data.has(key): return false
 if data.bodies.size()!=1 or data.parameters.size()!=1 or data.surfaces.size()!=6: return false
 if not simulation.core.validate(simulation.structure,data.parameters[0]).is_empty(): return false
 simulation = World.new()
 simulation.room = data.room
 simulation.bodies = data.bodies.duplicate(true)
 simulation.surfaces = data.surfaces.duplicate(true)
 simulation.parameters = data.parameters.duplicate(true)
 simulation.time = data.time
 stage = data.stage
 apparatus_time = data.apparatus_time
 cue_only = data.cue_only
 exchange_enabled = data.exchange_enabled
 relocated = data.relocated
 moving_source = data.moving_source
 samples = data.samples.duplicate(true)
 path = data.path.duplicate()
 events = data.events.duplicate()
 sample_clock = data.sample_clock
 previous_touch = data.previous_touch
 return true

func save_history(file_path: String) -> bool:
 var file = FileAccess.open(file_path,FileAccess.WRITE)
 if file==null: return false
 file.store_var(snapshot())
 return true

func load_history(file_path: String) -> bool:
 if not FileAccess.file_exists(file_path): return false
 var file = FileAccess.open(file_path,FileAccess.READ)
 if file==null: return false
 var data = file.get_var()
 return data is Dictionary and restore(data)
