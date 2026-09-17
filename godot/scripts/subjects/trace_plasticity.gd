extends RefCounted
## Numeric cue -> delayed physical response. No entity IDs or semantic categories.
## Estimates are vector-valued expected changes, not selected destinations or rewards.
var window = 2.5
var dimension = 4
func _init(size: int = 4, duration: float = 2.5) -> void:
 dimension = size
 window = duration
func zeros() -> Array:
 var result: Array = []
 result.resize(dimension)
 result.fill(0.0)
 return result

func unit(values: Array) -> Array:
 var length = 0.0
 for value in values: length += value * value
 length = sqrt(length)
 var result: Array = []
 for value in values: result.append(value / maxf(length, 0.00001))
 return result

func similarity(left: Array, right: Array) -> float:
 var distance = 0.0
 for i in range(left.size()): distance += pow(left[i] - right[i], 2)
 return exp(-distance * 18.0)

func create(priors: Array) -> Array:
 var memory: Array = []
 for prior in priors:
  memory.append({"signature":unit(prior.signature), "effect":prior.effect.duplicate(), "trace":0.0, "activation":0.0, "exposure":0.0, "updates":0})
 return memory

func perceive(memory: Array, samples: Array, dt: float) -> void:
 for item in memory: item.activation = 0.0
 for sample in samples:
  var strength = 0.0
  for value in sample.signal: strength += value * value
  if strength < 0.00001: continue
  var signature: Array = unit(sample.signal)
  var found = false
  for item in memory:
   if similarity(signature, item.signature) > 0.85: found = true
  if not found and memory.size() < 32:
   memory.append({"signature":signature, "effect":zeros(), "trace":0.0, "activation":0.0, "exposure":0.0, "updates":0})
  for item in memory:
   item.activation = maxf(item.activation, similarity(signature, item.signature) * minf(1.0, sqrt(strength) * 2.0))
 for item in memory:
  # Trace follows a cue but survives its disappearance: temporal pairing is causal.
  item.trace = maxf(item.trace * exp(-dt / window), item.activation)
  item.exposure += item.activation * dt

func learn(memory: Array, outcome: Array, dt: float, rate: float) -> void:
 var predicted = zeros()
 var normalization = 1.0
 for item in memory:
  normalization += item.trace * item.trace
  for j in range(dimension): predicted[j] += item.effect[j] * item.trace
 for item in memory:
  if item.trace < 0.02: continue
  for j in range(dimension):
   item.effect[j] = clampf(item.effect[j] + rate * dt * item.trace * (outcome[j] - predicted[j]) / normalization, -0.3, 0.3)
  item.updates += 1

func response(memory: Array, stimulus: Array, state: Array) -> float:
 var signature: Array = unit(stimulus)
 var response_value = 0.0
 for item in memory:
  var overlap: float = similarity(signature, item.signature)
  for j in range(dimension): response_value -= state[j] * item.effect[j] * overlap * 12.0
 return clampf(response_value, -1.5, 1.5)

func magnitude(memory: Array) -> float:
 var total = 0.0
 for item in memory:
  for value in item.effect: total += value * value
 return sqrt(total)
