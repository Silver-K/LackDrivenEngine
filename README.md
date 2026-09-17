# 同一屋檐下 · 母体与幼体

双击 `开始游戏.cmd` 启动 Godot 动画沙盒。现在有三个带预设关联的母体，以及三个从零关联出发的幼体。幼体通过短时感知痕迹与后续身体变化学习，成长没有预定年龄脚本。猫、狗和鼠的外形属于表现层；内部仅处理物理信号、连续维度和历史耦合，没有饥饿、口渴、猎物或行为任务标签。

点击物件补充资源、开关门或拨球；点击动物查看 X0–X3 状态、生活时间和经验关联。「感知范围」显示视距与响应向量。支持暂停、三倍速及重新开始。

不同维度均为混合耦合，不对应命名需求。接触改变多个状态和历史响应。当前是手工参数的探索模型，并非经过动物行为验证的仿真；名称不决定动物必须做什么。详见 ARCHITECTURE.md；不可丢失的共识在 docs/CONSENSUS.md，模块接口在 docs/MODULES.md。

模块已分为通用执行器、主体结构、感受、可塑性、身体、环境与表现层。对抗贡献保留到身体层，界面显示对抗负荷及余波。

验证：
```powershell
& ./.tools/godot/Godot_v4.6-stable_win64_console.exe --headless --path godot --script tests/test_modules.gd
& ./.tools/godot/Godot_v4.6-stable_win64_console.exe --headless --path godot --script tests/test_field.gd
& ./.tools/godot/Godot_v4.6-stable_win64_console.exe --headless --path godot --script tests/test_development.gd
& ./.tools/godot/Godot_v4.6-stable_win64_console.exe --headless --path godot --script tests/test_pet_ui.gd
& ./.tools/godot/Godot_v4.6-stable_win64_console.exe --path godot -- --pet-smoke
```

可用“保存经历／继续生活”手动保存与延续成长；当前无自动存档。此前 artifacts 中的报告是历史版本记录，不适用于本次核心。

存档格式现为4，旧格式3不自动迁移；不会因启动而覆盖旧存档。
