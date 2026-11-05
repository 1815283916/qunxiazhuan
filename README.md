# 群侠传

Godot 4.7 的武侠战棋项目，入口为 `群侠传/project.godot`，主场景为 `scenes/main_menu.tscn`。

## 存档与设置

- 四个手动档保留原文件名；自动档独立为 `user://qunxia_auto.cfg`，可在存读档页面单独读取。
- 开启自动存档后，返回大地图、完成剧情和战斗结算时自动保存；浏览设置不会覆盖手动档。
- “继续游戏”按保存时间寻找最新可读档，跳过损坏档或未来版本档。读取失败时保留当前进度；缺少字段的旧档使用新游戏默认值。
- 偏好独立保存为 `user://preferences.cfg`。音乐、音效、血条和中毒状态显示开关均接入实际功能；加载进度不会覆盖当前偏好。
- 新存档版本为 4，按稳定 ID 独立保存已学技能和已装备技能，调整人物顺序或修改名称后仍能恢复对应进度。读取版本 0/1/2/3 的旧档时，从已有技能和等级记录恢复已学列表；再次保存会升级为版本 4。覆盖旧档前自动保留 `.v0.bak` / `.v1.bak` / `.v2.bak` / `.v3.bak` 原档备份，已有备份不覆盖。
- 剧情进度保存为稳定节点 ID，包含尚未完成的剧情战斗。旧版演示主线不映射到新主线：保留物品、装备和养成，从少林醒来重新开始；日志注明迁移。
- 已删除的装备、武学 ID 在加载时清理；缺失的心法使用当前配置中的可用心法。ID 本身不能随名称更改。药品、秘籍的 ID 统一由物品表维护，原有物品沿用旧 ID，兼容已有版本 3 存档。
- 音频为项目内生成的简易五声音阶配乐和操作提示音，可运行 `python tools/generate_audio.py` 重新生成，后续可替换为正式素材。

## 配置维护

在 `群侠传` 目录执行：

```powershell
python tools/export_config.py
python tools/export_config.py --check
python tools/export_story.py
python tools/export_story.py --check
```

`配置表/剧情配置.json` 管理场所、事件顺序、原稿分段绑定、剧情奖励、临时同伴和初始状态。`tools/story_source.py` 直接读取 `剧情.txt` 后半扩写剧本的【说话人】格式；`source_span` 将原稿记录绑定到各节点，导出会检查 484 段记录恰好使用一次，缺漏或重复会报错。原稿对白文字修改后重新运行 `export_story.py` 即可同步；增加或删除对白记录时也须调整分段绑定。原始 `剧情.txt` 保持不变。

游戏读取生成的 `data/configuration.json` 和 `data/story.json`，无需手工同步脚本中的属性与技能定义。配置导出还会检查概率上限、成长公式适用对象、心法成长一致性及多余技能引用；具体表结构和限制见 `群侠传/配置表/README.md`。打包时需将 `data/*.json` 纳入导出内容。

`群侠传/配置表` 中的武学、心法和物品工作簿统一维护招式范围、冷却、状态、心法被动、图标、药效、价格和秘籍引用。修改后运行 `python tools/export_config.py` 更新游戏数据。出售仅消耗背包里的数量，同名已穿戴装备保留。

## 验证

首次打开项目时先让 Godot 完成资源导入。在 `群侠传` 目录执行（将 `godot` 替换为本机引擎路径）：

```powershell
godot --headless --path . --script res://tests/test_runner.gd
godot --headless --path . --script res://tests/test_progression.gd
godot --headless --path . --script res://tests/test_skill_loadouts.gd
godot --headless --path . --script res://tests/test_polish.gd
godot --headless --path . --script res://tests/test_narrative.gd
python tests/test_exports.py
```

原有测试覆盖装备、成长、范围、时序、自动战斗、存档迁移及任务流程；技能测试验证学习与装备分离；完善测试覆盖出战提示、同名装备出售、表驱动药效、秘籍购买与存档、隐藏天赋、武学直接替换和心法预览。剧情测试从少林跑到华山，实战验证三场自动战斗、区域与下级场所的分层导航、独立解锁、临时同伴、续脉奖励、战败重试、剧情读档、旧档迁移与备份。机制回归通过独立测试夹具验证，不依赖剧情解锁进度。Python 测试覆盖 16 项导出校验，新增原稿全覆盖与缺段检测。测试将存档写入项目内测试目录或已忽略的检查目录，不修改玩家存档。

`tests/capture_progression.gd` 用于本地界面检查，默认截图集中输出到 Godot 项目内已忽略的 `.review_artifacts` 目录；可通过 `QUNXIA_CAPTURE_DIR` 指定输出目录，需图形环境运行。

大地图、区域页与场所页使用统一的不透明深色顶栏，地点、剧情进度、银两、声望分列显示；战斗顶栏同样加深底色。长对白逐屏显示，提供上一页、继续与页码，分屏不改写原文。
