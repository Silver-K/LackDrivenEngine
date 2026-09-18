extends RefCounted
## Isolated longitudinal protocol. Training changes physical apparatus only.
const Experiment = preload("res://scripts/room_experiment.gd")
const Probe = preload("res://scripts/experiment_probe.gd")
const Fields = preload("res://scripts/runtime/environment_fields.gd")
const DT = 1.0 / 60.0
const CYCLE_TICKS = 1440
const FEATURES = [0.8, 0.0, 0.8]
const IDS = ["paired", "delayed", "cue_only"]
const NAMES = ["短间隔经历", "长间隔经历", "仅信号经历"]
const PHASES = ["形成不同经历", "进入相同环境", "撤去机械扰动", "恢复机械扰动"]
const DEFAULT_TICKS = [14400, 7200, 14400, 7200]
var durations: Array = DEFAULT_TICKS.duplicate()
var branches: Array = []
var phase = 0
var phase_tick = 0
var completed = false
var running = false
var error = ""

func begin(ticks: Array = DEFAULT_TICKS) -> bool:
 if ticks.size() != PHASES.size() or ticks.any(func(v): return not (v is int) or v <= 0 or v > 216000): return false
 durations = ticks.duplicate()
 branches.clear()
 phase = 0
 phase_tick = 0
 completed = false
 error = ""
 for i in range(IDS.size()):
  var lab = Experiment.new()
  if not lab.simulation.last_error.is_empty():
   error = lab.simulation.last_error
   running = false
   return false
  branches.append({"id":IDS[i],"name":NAMES[i],"lab":lab,"stats":new_stats(),"samples":[],"checkpoints":[]})
 running = true
 return true

func new_stats() -> Dictionary:
 return {"seconds":0.0,"signal_dose":0.0,"mechanical_dose":0.0,"contact_impulse":0.0,"low_seconds":0.0,"path_length":0.0,"load_integral":0.0,"strain_integral":0.0}

func configure(world, branch_id: String, phase_index: int, tick: int) -> void:
 for surface in world.surfaces: surface.active = false
 var source: Dictionary = world.surfaces[5]
 source.active = true
 source.position = Vector2(600,430)
 source.exchange_enabled = false
 var cycle_tick = tick % CYCLE_TICKS
 source.emission = FEATURES.duplicate() if cycle_tick < 90 else [0.0,0.0,0.0]
 var delayed = phase_index == 0 and branch_id == "delayed"
 var onset = 720 if delayed else 90
 var effect = phase_index != 2 and (phase_index != 0 or branch_id != "cue_only")
 source.field_strength = 2.0 if effect and cycle_tick >= onset and cycle_tick < onset + 120 else 0.0

func sample(world) -> Dictionary:
 var b: Dictionary = world.bodies[0]
 return {"time":world.time,"position":b.position,"speed":b.velocity.length(),"activation":b.activation,"strain":b.strain,"load":b.load,"x":b.x.duplicate(),"memory_strength":world.association_strength(0)}

func advance(budget_ticks: int = 60) -> void:
 if not running or completed or not error.is_empty(): return
 for _tick in range(maxi(0, budget_ticks)):
  for branch in branches:
   var world = branch.lab.simulation
   configure(world, branch.id, phase, phase_tick)
   var before: Vector2 = world.bodies[0].position
   var source: Dictionary = world.surfaces[5]
   var sensed = 0.0
   for s in world.sense(0):
    if s.get("origin",0) != 0: continue
    for value in s.signal: sensed += value * value
   branch.stats.signal_dose += sqrt(sensed) * DT
   branch.stats.mechanical_dose += absf(source.field_strength) * Fields.amplitude(before,source,world.surfaces) * DT
   world.step(DT)
   if not world.last_error.is_empty():
    error = world.last_error
    running = false
    return
   var b: Dictionary = world.bodies[0]
   if not b.position.is_finite() or not b.velocity.is_finite() or not is_finite(b.strain) or not b.x.all(func(v): return is_finite(v)):
    error = "分支出现非有限状态，实验已停止。"
    running = false
    return
   branch.lab.apparatus_time += DT
   branch.stats.seconds += DT
   branch.stats.path_length += before.distance_to(b.position)
   branch.stats.load_integral += b.load * DT
   branch.stats.strain_integral += b.strain * DT
   branch.stats.contact_impulse += b.contact_pressure
   if b.velocity.length() < 1.0: branch.stats.low_seconds += DT
   if (phase_tick + 1) % 60 == 0: branch.samples.append(sample(world))
  phase_tick += 1
  if phase_tick == durations[phase]:
   if not finish_phase(): return
   phase += 1
   phase_tick = 0
   if phase == PHASES.size():
    completed = true
    running = false
    return

func permanent(memory: Array) -> Array:
 return memory.map(func(m): return [m.get("pattern",""),m.get("signature",[]).duplicate(),m.effect.duplicate(),m.exposure,m.updates])

func probe_memory(definition: Dictionary, memory: Array) -> Dictionary:
 var probe = Probe.new()
 var world = probe.build(definition,memory,FEATURES)
 var initial: Vector2 = world.bodies[0].position
 var saved: Array = permanent(world.bodies[0].memory)
 world.step(DT)
 var first: Dictionary = world.observe(0)
 for tick in range(119): world.step(DT)
 return {"first":first,"last":world.observe(0),"first_learned_force":probe.learned_force(first),"displacement":world.bodies[0].position-initial,"permanent_unchanged":saved == permanent(world.bodies[0].memory)}

func finish_phase() -> bool:
 var reference_sensation: Array = []
 for branch in branches:
  var snapshot: Dictionary = branch.lab.snapshot()
  var result = probe_memory(snapshot.parameters[0],snapshot.bodies[0].memory)
  if reference_sensation.is_empty(): reference_sensation = result.first.sensory_snapshot.duplicate(true)
  if not result.permanent_unchanged or result.first.sensory_snapshot != reference_sensation:
   error = "冻结探测未保持长期记忆或同首步感受，已停止比较。"
   running = false
   return false
  branch.checkpoints.append({"phase":phase,"stats":branch.stats.duplicate(true),"snapshot":snapshot,"probe":result})
  branch.stats = new_stats()
 return true

func snapshot() -> Dictionary:
 var saved: Array = []
 for b in branches:
  saved.append({"id":b.id,"name":b.name,"room":b.lab.snapshot(),"stats":b.stats.duplicate(true),"samples":b.samples.duplicate(true),"checkpoints":b.checkpoints.duplicate(true)})
 return {"format":"tension-experience-comparison","version":1,"durations":durations.duplicate(),"phase":phase,"phase_tick":phase_tick,"completed":completed,"running":running,"error":error,"branches":saved}

func valid_stats(value) -> bool:
 if not value is Dictionary or not value.has_all(new_stats().keys()): return false
 for key in new_stats():
  if not (value[key] is float or value[key] is int) or not is_finite(value[key]) or value[key] < 0: return false
 return true

func valid_checkpoint(value, index: int, definition: String) -> bool:
 if not value is Dictionary or not value.has_all(["phase","stats","snapshot","probe"]): return false
 if value.phase != index or not valid_stats(value.stats) or not value.snapshot is Dictionary: return false
 var lab = Experiment.new()
 if not lab.restore(value.snapshot) or var_to_str(lab.simulation.parameters) != definition: return false
 var probe = value.probe
 if not probe is Dictionary or not probe.has_all(["first","last","first_learned_force","displacement","permanent_unchanged"]): return false
 if not probe.first_learned_force is Vector2 or not probe.displacement is Vector2 or probe.permanent_unchanged != true: return false
 for state in [probe.first,probe.last]:
  if not state is Dictionary or not state.has_all(["memory","contributions","sensory_snapshot","position","velocity"]): return false
  if not state.memory is Array or not state.contributions is Array or not state.sensory_snapshot is Array: return false
 return true

func restore(data: Dictionary) -> bool:
 if data.get("format","") != "tension-experience-comparison" or data.get("version",0) != 1: return false
 if not data.has_all(["durations","phase","phase_tick","completed","running","error","branches"]): return false
 if not data.completed is bool or not data.running is bool or not data.error is String: return false
 if not data.durations is Array or data.durations.size() != PHASES.size(): return false
 if data.durations.any(func(v): return not (v is int) or v <= 0 or v > 216000): return false
 if not data.phase is int or data.phase < 0 or data.phase > PHASES.size(): return false
 if not data.phase_tick is int or data.phase_tick < 0: return false
 if data.completed != (data.phase == PHASES.size()): return false
 if data.completed:
  if data.phase_tick != 0 or data.running: return false
 elif data.phase_tick >= data.durations[data.phase]: return false
 if not data.branches is Array or data.branches.size() != IDS.size(): return false
 var restored: Array = []
 var definition = ""
 for i in range(IDS.size()):
  var b = data.branches[i]
  if not b is Dictionary or not b.has_all(["id","room","stats","samples","checkpoints"]): return false
  if b.id != IDS[i] or not b.stats is Dictionary or not b.samples is Array or not b.checkpoints is Array: return false
  if b.checkpoints.size() != data.phase: return false
  if not valid_stats(b.stats): return false
  var lab = Experiment.new()
  if not b.room is Dictionary or not lab.restore(b.room): return false
  var current_definition = var_to_str(lab.simulation.parameters)
  if i == 0: definition = current_definition
  elif current_definition != definition: return false
  for checkpoint_index in range(b.checkpoints.size()):
   if not valid_checkpoint(b.checkpoints[checkpoint_index],checkpoint_index,definition): return false
  restored.append({"id":IDS[i],"name":NAMES[i],"lab":lab,"stats":b.stats.duplicate(true),"samples":b.samples.duplicate(true),"checkpoints":b.checkpoints.duplicate(true)})
 durations = data.durations.duplicate()
 phase = data.phase
 phase_tick = data.phase_tick
 completed = data.completed
 running = data.running
 error = data.error
 branches = restored
 return true

func save_file(path: String) -> bool:
 if branches.is_empty(): return false
 var file = FileAccess.open(path + ".tmp",FileAccess.WRITE)
 if file == null: return false
 file.store_var(snapshot())
 file.close()
 return DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"),ProjectSettings.globalize_path(path)) == OK

func load_file(path: String) -> bool:
 var file = FileAccess.open(path,FileAccess.READ)
 if file == null: return false
 var data = file.get_var()
 return data is Dictionary and restore(data)

func progress() -> String:
 if branches.is_empty(): return "尚未开始"
 if not error.is_empty(): return "实验停止：" + error
 if completed: return "四段经历对照已完成"
 return "%s · %.1f / %.1f 秒 · %s" % [PHASES[phase],phase_tick*DT,durations[phase]*DT,"运行中" if running else "已暂停"]

func memory_distance(a: Array, b: Array) -> float:
 var effects = {}
 for item in a: effects[item.get("pattern",str(item.signature))] = item.effect.duplicate()
 var distance = 0.0
 for item in b:
  var key = item.get("pattern",str(item.signature))
  var left: Array = effects.get(key,[])
  for j in range(item.effect.size()): distance += absf(item.effect[j] - (left[j] if j < left.size() else 0.0))
  effects.erase(key)
 for values in effects.values():
  for value in values: distance += absf(value)
 return distance

func change_sentence(index: int) -> String:
 var weaker = 0
 var stronger = 0
 for branch in branches:
  var before: float = branch.checkpoints[index-1].probe.first_learned_force.length()
  var after: float = branch.checkpoints[index].probe.first_learned_force.length()
  if after < before - 0.00001: weaker += 1
  elif after > before + 0.00001: stronger += 1
 var condition = "撤去扰动后" if index == 2 else "恢复扰动后"
 if weaker == branches.size(): return condition + "，三个分支在同初态探测中的关联作用都减弱了。"
 if stronger == branches.size(): return condition + "，三个分支在同初态探测中的关联作用都增强了。"
 return condition + "，%d个分支的关联作用减弱，%d个增强，其余变化很小。" % [weaker,stronger]

func summary() -> String:
 var text = "经历对照\n" + progress() + "\n\n"
 text += "三个独立副本从相同初态开始。原现场保留，身体全程自由活动。\n先形成不同经历，再进入相同环境，撤去扰动，最后恢复扰动。\n\n"
 if branches.is_empty():
  return text + "点“开始实验”运行完整流程；可以暂停、保存，之后读取继续。\n结果会直接说明经历是否改变响应，无需解读因果面板。"
 if phase > 0:
  text += "目前的发现\n"
  var trained_left: Dictionary = branches[0].checkpoints[0]
  var trained_right: Dictionary = branches[1].checkpoints[0]
  var initial_gap = memory_distance(trained_left.snapshot.bodies[0].memory,trained_right.snapshot.bodies[0].memory)
  if initial_gap > 0.00001:
   text += "• 不同经历留下了不同记忆。\n"
   if trained_left.probe.first_learned_force.distance_to(trained_right.probe.first_learned_force) > 0.00001:
    text += "• 换成相同身体初态后，对同一信号的关联作用仍不同，说明记忆确实参与了响应。\n"
  else: text += "• 目前尚未检测到两种时序经历之间的明显记忆差异。\n"
  if phase > 1:
   var left: Dictionary = branches[0].checkpoints[1]
   var right: Dictionary = branches[1].checkpoints[1]
   text += "• 进入相同环境后，两种经历的记忆仍有差异。\n" if memory_distance(left.snapshot.bodies[0].memory,right.snapshot.bodies[0].memory)>0.00001 else "• 进入相同环境后，两种经历的记忆差异已很小。\n"
  if phase > 2: text += "• " + change_sentence(2) + "\n"
  if phase > 3: text += "• " + change_sentence(3) + "\n"
  text += "\n各副本走的位置不同，因此这里比较的是完整经历的影响，不能全部归因于时间间隔。\n\n以下是测量记录，可按需查看。\n\n"
 for index in range(phase):
  text += PHASES[index] + "\n"
  var left: Dictionary = branches[0].checkpoints[index]
  var right: Dictionary = branches[1].checkpoints[index]
  var memory_gap = memory_distance(left.snapshot.bodies[0].memory,right.snapshot.bodies[0].memory)
  var force_gap: float = left.probe.first_learned_force.distance_to(right.probe.first_learned_force)
  var motion_gap: float = left.probe.displacement.distance_to(right.probe.displacement)
  if memory_gap <= 0.00001:
   text += "短、长间隔经历之间暂未检测到明显记忆差异。\n"
  elif force_gap <= 0.00001:
   text += "两种经历留下了不同记忆，但本次信号下的首步关联合力接近。\n"
  else:
   text += "两种经历留下了不同记忆；在相同身体初态和首步感受下，关联作用也不同。\n"
  text += "冻结探测中，2秒后的位移相差 %.2f 像素。后续感受会随运动分化。\n" % motion_gap
  for branch in branches:
   var checkpoint: Dictionary = branch.checkpoints[index]
   var stats: Dictionary = checkpoint.stats
   text += "  %s：低活动 %.1f / %.1f 秒；探测位移 %.2f 像素。\n" % [branch.name,stats.low_seconds,stats.seconds,checkpoint.probe.displacement.length()]
   if index > 0:
    var earlier: Dictionary = branch.checkpoints[index-1]
    var before: float = earlier.probe.first_learned_force.length()
    var after: float = checkpoint.probe.first_learned_force.length()
    text += "    同初态探测的首步关联合力幅度：%.5f → %.5f。\n" % [before,after]
  text += "\n"
 text += "解释边界\n相同装置时序不保证相同实际暴露：各副本的位置会分化。\n仅信号分支也可能经历墙面碰撞，不能预设它没有学习。\n撤去扰动后仍有真实接触和身体反馈，不保证所有关联都消失。\n首步探测区分记忆影响；自由活动的差异同时包含身体状态与经历。\n低活动按速度小于1像素/秒统计，只用于观察。\n"
 return text

func export_report(path: String) -> bool:
 var file = FileAccess.open(path,FileAccess.WRITE)
 if file == null: return false
 file.store_string(summary())
 return true
