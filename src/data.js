export const GRADIENTS = { latent: '潜伏', activated: '浮现', focused: '牵动', flooded: '淹没' };
export const EMOTIONS = { calm: '松弛', reactive: '敏感', flooded: '难以承受', numb: '有些麻木' };
export const ANCHORS = {
  attachment: { name: '怕被留下', pull: '想让对方留下', counter: '又怕自己的需要成为负担', floor: 18, baseline: 42 },
  pride: { name: '不愿示弱', pull: '想被认真看待', counter: '又不肯承认自己在意', floor: 14, baseline: 38 },
  secret: { name: '不敢说的往事', pull: '想让某个人知道过去', counter: '又害怕坦白之后失去容身之处', floor: 20, baseline: 44 },
  belonging: { name: '无处安放', pull: '想在人群里占一个位置', counter: '又怕停下来便无法离开', floor: 18, baseline: 43 },
  worth: { name: '怕自己无用', pull: '想替别人做点什么', counter: '又厌倦只有有用时才被需要', floor: 16, baseline: 40 },
  freedom: { name: '怕被束缚', pull: '想按自己的节奏生活', counter: '又舍不得有人等待的地方', floor: 17, baseline: 39 }
};
export const PEOPLE = [
  { id: 'shen', name: '沈砚', role: '守着酒馆的人', age: '三十七岁', color: '#b99161', initials: '砚', anchors: ['attachment', 'pride', 'secret'], values: [53, 47, 44], habit: 'attachment', intro: '他把每一只杯子擦得很亮，却很少直视进门的人。', detail: '雨停酒馆的老板。会认得熟客喝什么，却说那只是做生意。吧台下有一封没有寄出的信。', routine: ['把已经干净的杯子又擦了一遍。', '试了试汤的温度，往炉里添了一小块木柴。', '听了一阵屋檐落水，忘了手里的抹布。', '把门口歪了的伞靠正。'], creative: '在旧酒单的背面写下两行字，又把纸折了起来。', narrative: '留着灯，只是怕客人看不清路。' },
  { id: 'lin', name: '林遥', role: '暂住的旅人', age: '二十六岁', color: '#87aaa0', initials: '遥', anchors: ['belonging', 'freedom', 'pride'], values: [47, 54, 38], habit: 'freedom', intro: '她的行李始终没有完全打开，窗边却已经有了她养的植物。', detail: '说自己只是路过。借住楼上已经二十七天，画册里全是这条街。她不喜欢别人问归期。', routine: ['把窗边的小植物转了一个方向。', '在画册上描了一段屋檐的轮廓。', '用指尖接了一滴窗缝漏进来的雨。', '看着远处，轻轻哼了半句歌。'], creative: '把画里通向远方的路涂掉，重新画成一扇亮着灯的窗。', narrative: '画这条街，只是因为它恰好在窗外。' },
  { id: 'zhou', name: '周叔', role: '下工后的木匠', age: '五十八岁', color: '#bd896f', initials: '周', anchors: ['worth', 'attachment', 'pride'], values: [55, 41, 49], habit: 'worth', intro: '他总能发现哪张椅子松了，自己的那杯茶却经常放凉。', detail: '做了半辈子木工，近来活儿少了。每天坐在炉边，随身带着一小块尚未成形的木头。', routine: ['晃了晃桌脚，垫进一片折好的纸。', '捧起杯子才发现茶已经凉了。', '把木屑一点一点拢进手心。', '靠着椅背打了个很短的盹。'], creative: '没有再修那张椅子，低下头，慢慢雕出一只不太像鸟的木鸟。', narrative: '闲着也是闲着，顺手的事。' }
];
// Event interpretation is data, separate from both expression and psychological decisions.
export const EVENTS = {
  company: { label: '安静陪一会儿', text: '我在这里坐一会儿。', category: 'relationship', tags: ['safe', 'company'], channel: 'attachment_security', impacts: { attachment: -14, belonging: -12, worth: -5 }, patterns: ['陪你', '陪着', '坐一会', '在这里', '不走', '不会走', '不离开', '不会离开'] },
  reassure: { label: '说句宽心的话', text: '你不用一个人撑着。', category: 'relationship', tags: ['safe', 'reassurance'], channel: 'attachment_security', impacts: { attachment: -14, belonging: -12, pride: 3 }, patterns: ['不用一个人', '关心你', '理解你', '别担心', '没关系', '放心', '在乎你'] },
  tea: { label: '递一杯热茶', text: '茶还热着，给你。', category: 'relationship', tags: ['safe', 'care'], channel: 'attachment_security', impacts: { attachment: -10, belonging: -10, worth: -5 }, patterns: ['热茶', '喝茶', '给你茶'] },
  listen: { label: '听听今天的事', text: '今天过得怎么样？不想说也没关系。', category: 'expression', tags: ['safe', 'listen'], channel: 'validation', impacts: { pride: -9, worth: -9, secret: 5 }, patterns: ['今天', '听你', '愿意听', '想聊', '过得'] },
  boundary: { label: '留一点空间', text: '你不必回答，我不会追问。', category: 'relationship', tags: ['safe', 'boundary'], channel: 'validation', impacts: { freedom: -12, secret: -10, pride: -5 }, patterns: ['不必回答', '不追问', '你的选择', '自己决定', '不勉强'] },
  memory: { label: '问起那段往事', text: '你以前的生活，是什么样的？', category: 'expression', tags: ['exposure', 'question'], impacts: { secret: 19, pride: 10, belonging: 8, freedom: 7 }, patterns: ['往事', '过去', '秘密', '那封信', '以前', '为什么留下'] },
  joke: { label: '讲个不太好的笑话', text: '这雨是不是也赊了账，才一直不肯走。', category: 'expression', tags: ['safe', 'humor'], channel: 'distraction', impacts: { pride: -6, worth: -7, freedom: -7 }, patterns: ['笑话', '哈哈', '赊了账'] },
  reject: { label: '冷淡地拒绝', text: '不用管我，我想自己待着。', category: 'relationship', tags: ['rejection'], impacts: { attachment: 17, worth: 14, pride: 12, belonging: 15 }, patterns: ['别烦', '不用管我', '讨厌', '不需要你', '自己待着'] },
  leaving: { label: '起身告别', text: '我先走了。', category: 'existential', tags: ['departure'], impacts: { attachment: 20, belonging: 15, freedom: -5, worth: 8 }, patterns: ['要走', '先走', '再见', '离开', '回去了', '告别'] },
  return: { label: '推门回来', text: '我回来了。', category: 'existential', tags: ['safe', 'return'], impacts: { attachment: -10, belonging: -8, pride: 4 }, patterns: ['回来了', '又来了'] },
  silence: { label: '听一会儿雨', text: '', category: 'expression', tags: ['ambiguous', 'silence'], impacts: {}, patterns: ['……', '...', '沉默'] },
  ambiguous: { label: '尚不确定的话', category: 'expression', tags: ['ambiguous'], impacts: {}, patterns: [] },
  rain: { label: '雨打在窗上', category: 'environment', tags: ['weather'], impacts: { attachment: 3, belonging: 4 }, patterns: [] },
  quiet: { label: '炉火轻响', category: 'environment', tags: ['quiet'], impacts: {}, patterns: [] },
  letter: { label: '一阵风掀起吧台下的信角', category: 'environment', tags: ['exposure'], impacts: { secret: 9 }, patterns: [] },
  closing: { label: '街上的灯一盏盏熄灭', category: 'environment', tags: ['departure'], impacts: { attachment: 5, belonging: 5 }, patterns: [] },
  npc_care: { label: '留了一杯热茶', category: 'relationship', tags: ['safe', 'care'], channel: 'attachment_security', impacts: { attachment: -7, belonging: -7, worth: -5 }, patterns: [] },
  npc_distance: { label: '把椅子挪远了一点', category: 'relationship', tags: ['rejection'], impacts: { attachment: 5, belonging: 5, pride: 4 }, patterns: [] }
};
export const ACTIONS = ['company', 'tea', 'listen', 'boundary', 'joke', 'memory', 'reassure', 'reject'];
export const OPERATORS = [
  { id: 'regression', name: '退行', tier: 0, when: { stress: true }, defense: '退回熟悉的应对方式', behavior: 'please', contradiction: '想抓住眼前的人，同时恨自己又变得如此需要' },
  { id: 'symbolization', name: '象征化', tier: 1, when: { alone: true, active: true, rested: true }, defense: '升华', behavior: 'create', contradiction: '把无法对人说的需要留在物件里，仍然不肯承认它' },
  { id: 'new_pattern', name: '新模式覆盖', tier: 1, when: { learned: true, safe: true, stress: false }, defense: '幽默与承受', behavior: 'humor', contradiction: '允许自己靠近一点，仍为可能的离别留着退路' },
  { id: 'projection', name: '投射', tier: 2, when: { ambiguous: true, vulnerable: true }, defense: '读心与投射', behavior: 'test', contradiction: '把自己的不安读成对方的疏远，一边试探一边否认在意' },
  { id: 'displacement', name: '置换', tier: 2, when: { rejected: true, constrained: true }, defense: '置换', behavior: 'displace', contradiction: '不愿对人发火，把受伤发泄在无辜的物件上' },
  { id: 'isolation', name: '隔离', tier: 2, when: { exposed: true, secret: true }, defense: '情感隔离', behavior: 'evade', contradiction: '渴望被了解，同时把最需要被了解的部分藏起来' },
  { id: 'compromise', name: '妥协形成', tier: 2, when: { active: true, multiple: true }, defense: '反向表达', behavior: 'approach_avoid', contradiction: '话里把人推远，动作却为对方留下位置' },
  { id: 'behavior_contradiction', name: '行为矛盾', tier: 2, when: { active: true, constrained: true }, defense: '压抑直接需要', behavior: 'indirect', contradiction: '语言遵守体面，身体泄露需要' }
];
export const LINES = {
  shen: {
    routine: ['雨小了一点。也可能只是听习惯了。', '今天的汤，盐好像又放少了。', '那把伞可以放门边，地板本来就湿。'],
    approach_avoid: ['不用特意陪着我。……那边漏雨，坐近一点。', '你有事就忙你的。茶凉了，我再给你续一点。', '这店少一个客人也照开。你的杯子先放这儿。'],
    indirect: ['我只是多烧了一壶水。你要不要，随你。', '门口风大。不是赶你，椅子往里挪。'],
    test: ['是不是这儿太闷了？没别的意思，随口问问。', '你刚才看门口了。……我说门没关紧。'],
    displace: ['这抽屉，怎么总是关不上。', '杯底又有水印。算了，你坐你的。'],
    evade: ['都是旧账，没什么好讲的。你……还想听哪一段？', '那封信不是给谁的。放着吧，别沾了水。'],
    please: ['再坐一下，汤马上就好。……不好喝也不用勉强。', '是不是哪里照顾不周？没有就好。别急着回答。'],
    humor: ['这杯算我的。别误会，我只是不想再洗一个杯子。', '今天不擦杯子了。你看，我也不是只能干这件事。'],
    create: ['写着玩。真有人看，我反而不自在。', '纸留着总会有用。上面的字不算数。']
  },
  lin: {
    routine: ['窗外那个招牌，雨天比晴天好看。', '这株草活得比我想的久。', '我画歪了吗？算了，街本来就不直。'],
    approach_avoid: ['我随时可能走。……明天你还坐这里吗？', '别把这儿当我的位置。画册先替我放着。', '只是借住而已。这盆草，记得别浇太多水。'],
    indirect: ['这一页还空着。你可以坐一会儿，我画得慢。', '窗边位置很多。你也不用坐那么远。'],
    test: ['你是不是也觉得我该走了？没事，我本来也没打算久留。', '刚才的话，是真的，还是怕冷场？'],
    displace: ['这支笔又断了。不是你的事。', '箱子的扣子真烦。好像非得关上不可。'],
    evade: ['以前的地方都差不多。至少……有些地方不一样。', '问归期的话，我答不上来。问天气倒是可以。'],
    please: ['要不我把画送你？也没画多久。你别马上收起来。', '我可以明天再走。只是雨还没停。'],
    humor: ['我这趟路过有点长。你先别笑，我自己会笑。', '今天先不研究去哪儿。窗外这滴雨还没落下来呢。'],
    create: ['画的是别处。也可能就是这里。', '留一道窗缝吧，画面才透气。']
  },
  zhou: {
    routine: ['木头逢雨就会涨，这椅子明天没准自己就稳了。', '茶凉得真快。人一走神就这样。', '这炉火不错，手背都暖了。'],
    approach_avoid: ['没什么需要我帮忙的？……没有也好，我坐会儿。', '我不爱闲聊。你接着说，我听得见。', '不用管我这老头。凳子不稳吧，换我这张。'],
    indirect: ['顺手给你垫一下。不是非得找点活儿。', '多雕了一块木头。你拿着，丑就别摆出来。'],
    test: ['是不是我话太多了？年轻人有自己的事。', '那张桌子修得还行吧？不是问你要谢。'],
    displace: ['现在这钉子也做得不实在。', '这木头的纹路，怎么偏跟人拧着来。'],
    evade: ['年轻时候有什么好说的。……那时候做的柜子，倒还在。', '不是没人找我干活。就是最近，想歇歇。'],
    please: ['等会儿，我把这个也修了。你不用这么快说不用。', '我手还稳着呢。真不用？……那我坐着。'],
    humor: ['这只鸟不用承重，也不必有用。像我今天似的。', '今天我不修东西了。要坏，就让它多坏一会儿。'],
    create: ['也不知道雕的是什么。反正不用交货。', '翅膀一大一小，也算只鸟。']
  }
};
