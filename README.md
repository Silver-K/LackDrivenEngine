# 张力 · 最小生命实验

双击 `开始游戏.cmd` 启动。当前只有一个会移动、转向、形变的主体。它从空白环境关联开始，在连续物理作用与接触中改变状态，形成时序关联。

房间可以逐步启用：

1. **空房间**：观察身体自身动力与边界作用。
2. **交换 A**：可感知的信号与接触后的混合交换。
3. **线索 → 扰动**：每 12 秒，先出现 1.5 秒信号，再发生 2 秒机械扰动。可切换为仅线索。
4. **B 与遮蔽**：加入不同交换关系与阻挡传播的实体遮蔽物。

阶段切换保留经历。可关闭交换但保留信号、交换 A/B 位置、固定或移动扰动源，观察相同结构如何随经历变化。暂停、四倍速、贡献箭头、轨迹和四维曲线用于观察；空格切换暂停。

“保存经历／读取经历”保存完整身体、关联痕迹、装置时钟和历史。“重置身体”返回相同初始状态和空白关联，保留环境开关。没有自动存档。新的 `tension-room` 格式版本 4 保存到 Godot 用户目录 `TensionRoom/room-history-v6.bin`，不迁移或覆盖旧版本记录（包括房间版本1、2、3、4、5）。

界面名称仅供观察。A、B 不代表固定需求；遮蔽物不直接降低张力。当前是手工结构参数的实验模型，并不保证形成特定行为或证明真实生物心理。

架构共识见 [docs/CONSENSUS.md](docs/CONSENSUS.md)，模块边界见 [docs/MODULES.md](docs/MODULES.md)，实验设置和限制见 [docs/MINIMAL_ROOM.md](docs/MINIMAL_ROOM.md)。旧动物、酒馆和网页场景源码已移除，历史 artifacts 保留为历史记录。

验证：

```powershell
& ./.tools/godot/Godot_v4.6-stable_win64_console.exe --headless --path godot --script tests/test_modules.gd
& ./.tools/godot/Godot_v4.6-stable_win64_console.exe --headless --path godot --script tests/test_field.gd
& ./.tools/godot/Godot_v4.6-stable_win64_console.exe --headless --path godot --script tests/test_development.gd
& ./.tools/godot/Godot_v4.6-stable_win64_console.exe --headless --path godot --script tests/test_lab_ui.gd
& ./.tools/godot/Godot_v4.6-stable_win64_console.exe --headless --path godot --script tests/test_motion.gd
& ./.tools/godot/Godot_v4.6-stable_win64_console.exe --headless --path godot --script tests/test_quiescence.gd
& ./.tools/godot/Godot_v4.6-stable_win64_console.exe --headless --path godot --script tests/test_self_sense.gd
& ./.tools/godot/Godot_v4.6-stable_win64_console.exe --headless --path godot --script tests/test_event_sense.gd
& ./.tools/godot/Godot_v4.6-stable_win64_console.exe --path godot -- --lab-smoke
```

最后一条生成 `artifacts/minimal-room.png` 并退出。

运动采用持续朝向、逐维推进与转向、可重放运动波动及实际碰撞反馈。修复前后对照见 [artifacts/motion-comparison.md](artifacts/motion-comparison.md)。不以走遍房间或左右均匀分布作为行为目标。

低活动由身体的连续执行幅度与使用适应反馈形成，已删除常量推进并保留逐维作用符号。没有休息目标或定时停留。界面显示执行幅度与适应负荷；旧运动覆盖对照是历史版本，当前观察见 `artifacts/quiescence-observations.json`。

当前二维主体选择感知速度、角速度、执行幅度和适应负荷；这是主体结构的可选自身感受映射。关闭该映射不改变身体物理，只会阻止这些量进入张力。当前连续自身样本不自动注册关联；主体结构可单独授予该权限。位置、目标和对象身份不在自身感受中。

连续外部与自身样本会推进张力，但不会自动创建关联。当前主体只将信号出现和接触冲量跨阈值生成可塑事件；阈值、迟滞和权限属于主体结构。
