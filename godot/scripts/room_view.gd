extends Control
## Read-only presentation of states and physical apparatus controls.
const Experiment = preload("res://scripts/room_experiment.gd")
var experiment = Experiment.new()
var font = SystemFont.new()
var paused = false
var speed = 1
var accumulator = 0.0
var buttons: Array = []
var show_vectors = true
var status = "从接触与时间中形成关联。没有目的地，没有任务队列。"
var frames = 0
const INK = Color("dae7e8")
const MUTED = Color("849a9e")
const GREEN = Color("80dfba")
const BLUE = Color("82baf5")
const ORANGE = Color("eab789")
const COLORS = [Color("80dfba"),Color("82baf5"),Color("d5a2d8"),Color("eab789")]
const SAVE_PATH = "user://room-history-v5.bin"

func _ready() -> void:
 font.font_names = PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei"])
 if "--lab-smoke" in OS.get_cmdline_user_args():
  experiment.set_stage(3)
  for i in range(1200): experiment.step(1.0/60.0)
  paused = true
 queue_redraw()

func _process(dt: float) -> void:
 frames += 1
 if not paused:
  accumulator += minf(dt,0.1)*speed
  while accumulator>=1.0/60.0:
   experiment.step(1.0/60.0)
   accumulator-=1.0/60.0
 queue_redraw()
 if frames==4 and "--lab-smoke" in OS.get_cmdline_user_args():
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../artifacts/minimal-room.png"))
  get_tree().quit()

func handle_action(action: String) -> void:
 if action.begins_with("stage"):
  experiment.set_stage(int(action.right(1)))
 elif action=="pause": paused = not paused
 elif action=="speed": speed = 4 if speed==1 else 1
 elif action=="reset":
  experiment.reset()
  accumulator = 0.0
  status = "已回到相同初始身体与空白关联；保留当前环境开关。"
 elif action=="cue":
  experiment.cue_only = not experiment.cue_only
  experiment.configure()
 elif action=="exchange":
  experiment.exchange_enabled = not experiment.exchange_enabled
  experiment.configure()
 elif action=="move":
  experiment.relocated = not experiment.relocated
  experiment.configure()
 elif action=="source":
  experiment.moving_source = not experiment.moving_source
  experiment.configure()
 elif action=="vectors": show_vectors = not show_vectors
 elif action=="save": status = "已保存完整经历与装置时钟。" if experiment.save_history(SAVE_PATH) else "保存失败。"
 elif action=="load":
  var restored = experiment.load_history(SAVE_PATH)
  if restored: accumulator = 0.0
  status = "已恢复经历，可继续同一条时间线。" if restored else "未找到兼容的房间记录。"
 queue_redraw()

func _gui_input(event: InputEvent) -> void:
 if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
  var point: Vector2 = event.position / canvas_scale()
  for button in buttons:
   if button.rect.has_point(point):
    handle_action(button.action)
    accept_event()
    return

func _unhandled_key_input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_SPACE:
  handle_action("pause")

func canvas_scale() -> float:
 return minf(size.x/1440.0,size.y/900.0)

func label_at(value: String, point: Vector2, font_size: int = 16, color: Color = INK) -> void:
 draw_string(font,point,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func panel(rect: Rect2, color: Color = Color("15272e"), border: Color = Color("2a4047"), radius: int = 12) -> void:
 var style = StyleBoxFlat.new()
 style.bg_color = color
 style.border_color = border
 style.set_border_width_all(1)
 style.set_corner_radius_all(radius)
 draw_style_box(style,rect)

func button_at(action: String, text: String, rect: Rect2, selected: bool = false) -> void:
 panel(rect,Color("254a46") if selected else Color("1a2d34"),GREEN.darkened(0.4) if selected else Color("334950"),7)
 label_at(text,rect.position+Vector2(12,rect.size.y*0.5+6),15,GREEN if selected else INK)
 buttons.append({"action":action,"rect":rect})

func arrow(origin: Vector2, vector: Vector2, color: Color, width: float = 1.0) -> void:
 if vector.length()<1: return
 var tip=origin+vector
 draw_line(origin,tip,color,width,true)
 var direction=vector.normalized()
 draw_line(tip,tip-direction.rotated(0.45)*6,color,width,true)
 draw_line(tip,tip-direction.rotated(-0.45)*6,color,width,true)

func _draw() -> void:
 buttons.clear()
 draw_set_transform(Vector2.ZERO,0,Vector2.ONE*canvas_scale())
 draw_rect(Rect2(0,0,1440,900),Color("0d1b22"))
 label_at("TENSION / LIFE LAB",Vector2(40,38),14,GREEN)
 label_at("一个身体，一段经历",Vector2(40,84),32)
 label_at("最小耦合实验  /  01",Vector2(1110,45),18)
 label_at("无环境先验 · 连续作用 · 时序关联",Vector2(40,110),16,MUTED)
 var sim = experiment.simulation
 label_at("%07.1f s   /   %s   /   %d×" % [sim.time,"暂停" if paused else "运行中",speed],Vector2(1110,80),17,GREEN)
 var stages=["01  空房间","02  加入交换 A","03  线索 → 扰动","04  B 与遮蔽"]
 for i in range(4): button_at("stage%d" % i,stages[i],Rect2(40+i*260,134,246,42),experiment.stage==i)
 label_at("阶段只改变环境，保留身体与经历。重置可从空白关联重新开始。",Vector2(42,199),15,MUTED)
 draw_room()
 draw_observation()
 draw_graphs()
 var actions=["pause","speed","cue","exchange","move","source","vectors","save","load","reset"]
 var names=["继续" if paused else "暂停  Space","速度  %d×" % speed,"仅线索" if experiment.cue_only else "配对扰动","交换  开" if experiment.exchange_enabled else "交换  关","恢复位置" if experiment.relocated else "交换区换位","源  移动" if experiment.moving_source else "源  固定","贡献  显示" if show_vectors else "贡献  隐藏","保存经历","读取经历","重置身体"]
 for i in range(actions.size()):
  button_at(actions[i],names[i],Rect2(40+i*137,823,126,38),actions[i]=="cue" and experiment.cue_only)
 label_at(status,Vector2(42,887),14,MUTED)
 if not sim.last_error.is_empty(): label_at(sim.last_error,Vector2(40,810),16,Color.RED)

func draw_room() -> void:
 var sim = experiment.simulation
 panel(Rect2(40,215,1030,410),Color("12252b"))
 for x in range(75,1040,35):
  for y in range(240,610,35): draw_circle(Vector2(x,y),1,Color("284048"))
 label_at("物理房间",Vector2(62,242),14,MUTED)
 label_at("轨迹  /  最近 100 s",Vector2(863,242),13,MUTED)
 for i in range(1,experiment.path.size()):
  draw_line(experiment.path[i-1],experiment.path[i],Color(0.5,0.88,0.73,0.05+0.28*float(i)/experiment.path.size()),1.5,true)
 for i in range(sim.surfaces.size()):
  var o: Dictionary = sim.surfaces[i]
  if not o.active: continue
  if i<2:
   var color: Color = GREEN if i==0 else BLUE
   draw_circle(o.position,o.radius,color*Color(1,1,1,0.08))
   draw_arc(o.position,o.radius,0,TAU,80,color*Color(1,1,1,0.65),1.5,true)
   draw_arc(o.position,o.radius-7,0,TAU,80,color*Color(1,1,1,0.12),1,true)
   label_at("A" if i==0 else "B",o.position+Vector2(-9,7),24,color)
   label_at("接触交换" if experiment.exchange_enabled else "仅有信号",o.position+Vector2(-31,o.radius+23),13,color)
  elif i<5:
   draw_circle(o.position,o.radius,Color("3b4d53"))
   draw_arc(o.position,o.radius,0,TAU,64,Color("6d8388"),2,true)
  else:
   var active: bool = o.field_strength>0
   var cue: bool = o.emission[2]>0
   var color: Color = ORANGE if active else Color("a499c5")
   for ring in range(3):
    var radius: float = 24+fmod(experiment.apparatus_time*28+ring*24,80)
    draw_arc(o.position,radius,0,TAU,64,color*Color(1,1,1,(0.4 if active or cue else 0.05)*(1-radius/120)),1,true)
   draw_circle(o.position,9,color)
   label_at("扰动" if active else ("线索" if cue else "间歇"),o.position+Vector2(18,-16),14,color)
 if experiment.stage>=3: label_at("遮蔽 · 仅改变传播与通行",Vector2(786,565),13,MUTED)
 var body: Dictionary = sim.bodies[0]
 if show_vectors:
  for contribution in body.contributions:
   if contribution.channel==1:
    var turn: float=clampf(contribution.value,-2.0,2.0)
    if absf(turn)>0.01:
     draw_arc(body.position,25,body.heading,body.heading+turn,16,ORANGE*Color(1,1,1,0.6),1.5,true)
    continue
   var value: Vector2 = contribution.value
   var source: int = contribution.source[0]
   arrow(body.position,value.limit_length(2)*66,COLORS[source%4]*Color(1,1,1,0.3),1)
  arrow(body.position,body.velocity*1.3,INK*Color(1,1,1,0.8),2)
 var heading: float = body.heading
 var outline=PackedVector2Array()
 var squeeze: float = 1.0/(1.0+minf(body.load,5)*0.05)
 for i in range(64):
  var angle = TAU*i/64.0
  var radius = 16*(1+sin(angle*3+sim.time*3)*0.04+minf(body.flux*18,0.2))
  outline.append(body.position+Vector2(cos(angle)*radius*(1+body.velocity.length()/180)*squeeze,sin(angle)*radius/squeeze).rotated(heading))
 draw_circle(body.position+Vector2(2,5),19,Color(0,0,0,0.2))
 draw_colored_polygon(outline,GREEN)
 outline.append(outline[0])
 draw_polyline(outline,Color("c7ffe6"),1.5,true)
 draw_circle(body.position+Vector2(9,0).rotated(heading),3,Color("204d47"))
 label_at("01",body.position+Vector2(-9,-28),13,GREEN)
 label_at("角速度 %+.3f   接触冲量 %.3f   运动波动 %+.3f   执行幅度 %.3f" % [body.angular_velocity,body.contact_pressure,body.motor_state.fluctuation,body.activation],Vector2(62,638),11,MUTED)

func draw_observation() -> void:
 panel(Rect2(1090,134,310,664))
 var sim = experiment.simulation
 var body: Dictionary = sim.bodies[0]
 label_at("主体 01",Vector2(1110,165),20)
 label_at("空白关联起步 / 四维结构",Vector2(1110,192),14,MUTED)
 for i in range(body.x.size()):
  var y=225+i*38
  label_at("x%d" % i,Vector2(1110,y),15,COLORS[i%4])
  draw_line(Vector2(1150,y-5),Vector2(1310,y-5),Color("35484d"),4)
  draw_line(Vector2(1230,y-12),Vector2(1230,y+2),MUTED,1)
  draw_line(Vector2(1230,y-5),Vector2(1230+body.x[i]/1.5*80,y-5),COLORS[i%4],4)
  label_at("%+.3f" % body.x[i],Vector2(1325,y),14)
 label_at("速度                 %7.2f" % body.velocity.length(),Vector2(1110,388),15)
 label_at("对抗负荷          %7.3f" % body.load,Vector2(1110,417),15,ORANGE)
 label_at("适应负荷          %7.3f" % body.strain,Vector2(1110,446),15)
 label_at("关联幅度          %7.4f" % sim.association_strength(0),Vector2(1110,475),15,GREEN)
 label_at("关联条目          %7d" % body.memory.size(),Vector2(1110,504),15)
 label_at("原始贡献          %7d" % body.contributions.size(),Vector2(1110,533),15)
 draw_line(Vector2(1110,553),Vector2(1380,553),Color("334950"),1)
 label_at("接触与装置记录",Vector2(1110,584),16)
 for i in range(experiment.events.size()): label_at(experiment.events[i],Vector2(1110,616+i*25),12,MUTED)
 label_at("颜色表示数值来源，不是情绪。",Vector2(1110,779),13,MUTED)

func draw_graphs() -> void:
 for g in range(3):
  var rect=Rect2(40+g*350,643,330,155)
  panel(rect)
  label_at(["内部维度 / x0 … x3","对抗负荷 / 合力之外","关联幅度 / 经历形成"][g],rect.position+Vector2(16,27),15)
  var plot=Rect2(rect.position+Vector2(16,46),Vector2(297,90))
  draw_line(plot.position+Vector2(0,45),plot.position+Vector2(297,45),Color("30434a"),1)
  if experiment.samples.size()<2: continue
  var count=4 if g==0 else 1
  var ceiling=1.5 if g==0 else 0.01
  if g>0:
   for sample in experiment.samples: ceiling=maxf(ceiling,float(sample.load if g==1 else sample.memory)*1.1)
  for channel in range(count):
   var line=PackedVector2Array()
   for i in range(experiment.samples.size()):
    var sample: Dictionary = experiment.samples[i]
    var value: float = sample.x[channel] if g==0 else (sample.load if g==1 else sample.memory)
    var y: float = 0.5-value/(ceiling*2) if g==0 else 1-value/ceiling
    line.append(plot.position+Vector2(i/239.0*plot.size.x,y*plot.size.y))
   draw_polyline(line,COLORS[channel] if g==0 else (ORANGE if g==1 else GREEN),1.5,true)
  label_at("±1.5" if g==0 else "上限 %.3f" % ceiling,rect.position+Vector2(222,27),12,MUTED)
