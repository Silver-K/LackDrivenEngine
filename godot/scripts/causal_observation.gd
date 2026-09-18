extends RefCounted
## Formatting a committed snapshot only. No simulation callbacks.
func numbers(values: Array) -> String:
 var parts=PackedStringArray()
 for value in values: parts.append("%+.4f" % value)
 return "["+", ".join(parts)+"]"
func describe(body: Dictionary) -> String:
 var text="当步感受（推进前采样） → 模式 → 已学向量 → 独立贡献 → 身体

"
 for sample in body.get("sensory_snapshot",[]):
  text+="感受 来源%d  数值%s  方向%s
" % [sample.origin,numbers(sample.signal),str(sample.axis)]
 text+="
活跃模式（键即数值特征身份）
"
 for pattern in body.get("pattern_samples",[]):
  text+="%s  幅度%.4f  %s
" % [pattern.pattern,pattern.strength,"新上升沿" if pattern.rising else "持续"]
 text+="
已学变化向量（本步反馈后的记忆；贡献使用反馈前权重）
"
 for item in body.memory:
  text+="%s
  变化%s  激活%.3f  痕迹%.3f  更新%d
" % [str(item.get("pattern",item.signature)),numbers(item.effect),item.activation,item.trace,item.updates]
 var net=Vector2.ZERO
 var torque=0.0
 text+="
独立贡献（未合并，零值省略）
来源：1关联逐维作用 / 4张力逐维推进 / 5张力变化逐维转向
"
 for c in body.contributions:
  if c.channel==0: net+=c.value
  else: torque+=c.value
  if (c.value.length() if c.channel==0 else absf(c.value))<0.000001: continue
  text+="来源%s  通道%d  作用%s
" % [str(c.source),c.channel,str(c.value)]
 text+="
身体合成：平移%s  转向%+.4f
对抗负荷%.4f  适应负荷%.4f  执行幅度%.4f
速度%s  内部状态%s
" % [str(net),torque,body.load,body.strain,body.activation,str(body.velocity),numbers(body.x)]
 return text
