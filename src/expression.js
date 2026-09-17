// A deliberately conservative boundary: external language never chooses actions.
const forbidden = /彻底(?:释怀|放下|安心)|终于(?:释怀|放下|决定)|不再(?:害怕|孤独|需要)|矛盾.*(?:消失|解决)|内心挣扎后|从此|治愈|完成任务/u;
export function validateExpression(value, input) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return false;
  if (Object.keys(value).some(key => !['dialogue', 'action', 'expression', 'subtext'].includes(key))) return false;
  if (typeof value.dialogue !== 'string' || value.dialogue.length < 2 || value.dialogue.length > 240 || forbidden.test(value.dialogue)) return false;
  // Preserve the exact observable action and face: the model cannot resolve a conflict through movement.
  if (value.action !== input.observable.action || value.expression !== input.observable.expression) return false;
  const structure = input.contradiction_structure;
  if (structure.defenses.length && !/但|又|只是|不过|不用|不必|别|随你|也|……|算了/u.test(value.dialogue)) return false;
  return true;
}

export function validExpressionInput(input) {
  const allowed = ['character', 'anchor_state', 'contradiction_structure', 'observable'];
  if (!input || Object.keys(input).some(key => !allowed.includes(key))) return false;
  if (typeof input.character !== 'string' || input.character.length > 30 || !input.anchor_state || !input.contradiction_structure || !input.observable) return false;
  if (!Array.isArray(input.contradiction_structure.defenses) || !Array.isArray(input.contradiction_structure.constraints)) return false;
  if (!['dialogue', 'action', 'expression'].every(key => typeof input.observable[key] === 'string' && input.observable[key].length < 600)) return false;
  function categorical(value) {
    if (typeof value === 'number' || typeof value === 'boolean' || value == null) return false;
    if (typeof value === 'string') return value.length < 2000;
    if (Array.isArray(value)) return value.length < 30 && value.every(categorical);
    return typeof value === 'object' && Object.keys(value).length < 30 && Object.values(value).every(categorical);
  }
  return categorical(input);
}
