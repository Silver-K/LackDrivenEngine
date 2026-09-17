# 模块地图与上下文恢复

先读 [CONSENSUS.md](CONSENSUS.md)。本文件说明落实位置，不修改共识。

| 模块 | 文件 | 输入/输出及边界 |
|---|---|---|
| 通用执行引擎 | `godot/scripts/tension_core.gd` | 结构实现、定义、状态、感受输入、dt -> 新状态与原样贡献；不导入主体或世界模块 |
| 主体结构 | `godot/scripts/subjects/planar_structure.gd` | 当前二维主体家族的公式、形状校验、状态初始化、张力/输出映射、物理反馈映射 |
| 主体感受 | `godot/scripts/subjects/planar_senses.gd` | 物理快照 -> 数值样本；物理尺寸与信号不等于心理标签 |
| 主体可塑性 | `godot/scripts/subjects/trace_plasticity.gd` | 本主体家族选择的痕迹条件化；引擎不自动使用它 |
| 身体与接触 | `godot/scripts/runtime/body_physics.gd` | 未合并贡献 -> 净作用、对抗负荷、物理运动、交换反馈；不修改张力或学习记忆 |
| 组装与环境 | `godot/scripts/physical_world.gd` | 装配一个结构家族，统一取样、计算、身体推进、反馈；不定义张力公式 |
| 表现/存档适配 | `animal_world.gd`、`pet_house.gd` | 只在此使用动物名称、动作描述；直接物理交互为输入事件 |
| 主体定义 | `godot/data/body_model.json` | 当前主体家族的矩阵、允许通道、先验、可塑性和身体规则参数 |
| 主体运行状态 | 世界的 `bodies` 数组 | 每主体独立快照：x、痕迹、关联、贡献、身体负荷；不保存在引擎对象中 |

## 接口

结构实现 `validate(definition)`、`advance(definition,state,sensation,dt)`、`emit(definition,state,sensation)`、`receive(definition,state,feedback,dt)`。其中 advance 返回独立状态；emit 返回 `{source, channel, value}` 数组。source 是数学来源索引，不是行为名。

引擎不知道维度数量、输出值类型或学习策略；本次身体适配器接受通道0的 Vector2。另一种结构/身体可声明不同通道。结构和状态以副本传入，模块不能借共享 Dictionary 偷改另一个主体。结构验证失败时世界报告 last_error 并停止推进，避免带错误形状运行。

## 贡献溯源

当前 planar_structure 的 source 第一项：0=几何耦合项，1=每条记忆的每维贡献，2=每个感受连接项，3=新异响应，4=探索耦合；其余项分别标识样本、记忆、维度/通道。编号含义只属于这个主体，通用引擎不解释它。

身体计算总作用量 `sum(length(value))` 与净作用 `sum(value)`；两者之差是本身体定义的对抗负荷，驱动身体阻尼和可恢复负荷状态。并非所有数字生命必须采用这个定义。反馈到张力的符号和强度由主体 `feedback_load` 定义。

## 共识保护测试

- `test_modules.gd`：通用引擎处理不同维数、不同规则；输出保留反向贡献；主体状态隔离；错误拓扑拒绝；对抗/无作用区分；学习开关由主体决定。
- `test_field.gd`：语义隔离、局部感知、自由生活状态有界。
- `test_development.gd`：关联配对/错时/冻结/消退、学习影响实际运动、独立成长及存档延续。
- `test_pet_ui.gd`：游戏交互与幼体选择。

## 边界与待办

当前游戏只装配一种二维身体家族。引擎的通用性由第二种独立测试结构验证，不表示游戏已有多种身体实现。感受维数当前仍为该主体的四通道，场景交换向量也为四维；改变游戏主体维度必须同时定义相容感受/交换映射。没有自动寻找“更优规则”。

存档格式升级为4，旧v3记录不自动迁移，原文件不会因启动而覆盖；新格式手动保存/读取。旧 artifacts 是历史证据，不可当本次实现结果。继续开发先阅读共识，再看本表和测试失败，不重复发明另一套目标架构。
