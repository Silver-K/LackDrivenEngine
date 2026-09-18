extends SceneTree
const World=preload("res://scripts/physical_world.gd")
var checks=0
var failures=0
func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok: failures+=1
 print("PASS " if ok else "FAIL ",message)
func cue() -> Array:
 return [{"origin":0,"plastic":false,"axis":Vector2.RIGHT,"signal":[.8,.8,0,0,0,0,0,0],"geometry":Vector2.ZERO}]
func train(w, p: Dictionary, state: Dictionary, mode: String, trials: int) -> Dictionary:
 for trial in range(trials):
  for tick in range(120):
   var samples: Array=cue() if tick<10 else []
   var start=12 if mode=="paired" else 80
   var effect=mode!="cue_only" and tick>=start and tick<start+10
   var advanced=w.core.advance(w.structure,p,state,samples,.1)
   state=w.core.receive(w.structure,p,advanced.state,{"exchange":[-3.0,1.0,-1.5,.5] if effect else [0,0,0,0],"load":0.0},.1)
 return state
func probe(w, p: Dictionary, trained: Dictionary) -> Dictionary:
 var definition=p.duplicate(true)
 definition.plasticity_enabled=false
 var state=w.structure.initial(definition)
 state.x=[.8,.1,.5,.2]
 state.memory=trained.memory.duplicate(true)
 for item in state.memory:
  item.trace=0.0
  item.activation=0.0
 return w.core.advance(w.structure,definition,state,cue(),.1)
func force(result: Dictionary) -> float:
 var value=0.0
 for c in result.contributions:
  if c.source[0]==1: value+=c.value.x
 return value
func _initialize() -> void:
 var w=World.new()
 var p=w.parameters[0].duplicate(true)
 p.event_sense.external=[]
 p.event_sense.self=[]
 for features in [[0],[1],[0,1]]:
  p.event_sense.external.append({"features":features,"threshold":.2,"release":.1,"plasticity":true})
 var frozen=p.duplicate(true)
 frozen.plasticity_enabled=false
 var paired=train(w,p,w.structure.initial(p),"paired",20)
 var delayed=train(w,p,w.structure.initial(p),"delayed",20)
 var disabled=train(w,frozen,w.structure.initial(frozen),"paired",20)
 var blank=train(w,p,w.structure.initial(p),"cue_only",20)
 var paired_probe=probe(w,p,paired)
 var delayed_probe=probe(w,p,delayed)
 check(paired.memory.size()==3 and disabled.memory.is_empty(),"identical training replay differs only by plasticity permission")
 check(force(paired_probe)>force(delayed_probe)*2 and force(paired_probe)>.02,"within-window pairing exceeds delayed control at equal-state frozen probe")
 check(force(probe(w,p,disabled))==0,"frozen training creates no learned motor contribution")
 check(w.association_strength(0)==0 and w.structure.policy(p).magnitude(blank.memory)==0,"cue-only training on blank memory is not extinction or invented outcome")
 var snapshot=var_to_str(paired)
 probe(w,p,paired)
 probe(w,p,paired)
 check(var_to_str(paired)==snapshot,"each probe starts from an independent training snapshot")
 var extinct=train(w,p,paired.duplicate(true),"cue_only",40)
 check(absf(force(probe(w,p,extinct)))<absf(force(paired_probe))*.3,"cue-only repetition with learning enabled extinguishes prior association")
 var physical_a=paired_probe.state.duplicate(true)
 var physical_b=probe(w,p,disabled).state.duplicate(true)
 w.physics.step(physical_a,p,[],paired_probe.contributions,.1)
 var disabled_probe=probe(w,p,disabled)
 w.physics.step(physical_b,p,[],disabled_probe.contributions,.1)
 check(physical_a.velocity!=physical_b.velocity,"learned contributions change body motion under identical physical probe state")
 print("PROTOCOL paired=",force(paired_probe)," delayed=",force(delayed_probe)," extinguished=",force(probe(w,p,extinct)))
 print("LEARNING_PROTOCOL_RESULT checks=",checks," failures=",failures)
 quit(1 if failures else 0)
