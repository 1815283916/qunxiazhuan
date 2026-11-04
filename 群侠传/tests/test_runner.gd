extends SceneTree
const Fixture = preload("res://tests/mechanics_fixture.gd")

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game_state := root.get_node("GameState")
	game_state.save_directory = "res://tests/.regression_runtime"
	DirAccess.make_dir_recursive_absolute(game_state.save_directory)
	game_state.settings.auto_save = false
	game_state.settings.auto_battle = false
	game_state.settings.battle_speed = 1.0
	Fixture.reset(game_state)
	_test_configuration_sync(game_state)
	_test_reusable_books(game_state)
	_test_equipment_flow(game_state)
	await _test_inventory_ui(game_state)
	await _test_empty_equipment_ui(game_state)
	await _test_character_equipment_menu(game_state)
	await _test_shop_sell_icons(game_state)
	_test_hero_growth(game_state)
	await _test_battle_range(game_state)
	await _test_party_turns(game_state)
	await _test_auto_battle(game_state)
	if failures == 0:
		print("TESTS PASSED: reusable books, hero growth, battle range, move undo, hover details, skill selection, action timeline")
	else:
		push_error("TESTS FAILED: %d assertion(s)" % failures)
	var preferences: String = game_state.save_directory.path_join("preferences.cfg")
	if FileAccess.file_exists(preferences): DirAccess.remove_absolute(preferences)
	DirAccess.remove_absolute(game_state.save_directory)
	quit(failures)

func _test_configuration_sync(game_state: Node) -> void:
	_expect(game_state.skill_library.has("打狗棒法") and game_state.skill_library.has("降龙十八掌"), "配置表新增和改名的武学应同步到游戏")
	var effect_paths := {
		"狂风刀法":"res://assets/Animations/e-feilong",
		"打狗棒法":"res://assets/Animations/e-liumai",
		"降龙十八掌":"res://assets/Animations/e-rulai",
		"独孤九剑":"res://assets/Animations/e-tianjian"
	}
	for skill_name in effect_paths:
		var effect_path: String = effect_paths[skill_name]
		var has_frames := ResourceLoader.exists(effect_path.path_join("1.png")) or ResourceLoader.exists(effect_path.path_join("01.png"))
		_expect(game_state.skill_library[skill_name].get("effect", "") == effect_path and has_frames, "%s特效资源应按配置表正确映射" % skill_name)
	_expect(not game_state.skill_library.has("太极剑法"), "配置表删除的武学应从游戏配置中移除")
	_expect(game_state.equipment_library.has("魔神拳套") and not game_state.equipment_library.has("玄铁剑"), "配置表改名的装备应使用新名称")
	game_state.inventory = ["玄铁剑"]
	game_state.hero_skills[0] = {"martial":["落英神剑掌", "太极剑法"], "internal":"九阳神功", "levels":{"落英神剑掌":2, "太极剑法":4, "九阳神功":3}, "exp":{}}
	game_state._synchronize_loaded_configuration()
	_expect(game_state.inventory == ["魔神拳套"], "旧存档中的装备名称应迁移到新名称")
	_expect(game_state.hero_skills[0].martial == ["降龙十八掌"], "旧存档中已删除的武学引用应移除，改名武学应迁移")
	Fixture.reset(game_state)

func _test_reusable_books(game_state: Node) -> void:
	var book_count: int = game_state.inventory.count("独孤九剑秘籍")
	var result: String = game_state.learn_from_book(1, "独孤九剑秘籍")
	_expect(result.contains("学会了独孤九剑"), "秘籍应能让新侠客学会武学")
	_expect(game_state.inventory.count("独孤九剑秘籍") == book_count, "秘籍研习后不应被消耗")

func _test_equipment_flow(game_state: Node) -> void:
	Fixture.reset(game_state)
	var hero_index := 0
	var equipped: Dictionary = game_state.hero_equipment[hero_index]
	_expect(equipped.is_empty(), "New games start with no equipment worn")
	var original_attack: int = game_state.get_hero_combat_stats(hero_index).attack
	var replacement := "魔神剑"
	_expect(game_state.inventory.has(replacement), "Replacement equipment is available in the inventory")
	var result: String = game_state.equip_item(hero_index, replacement)
	_expect(equipped.weapon == replacement and not game_state.inventory.has(replacement), "Equipping removes the item from the loose backpack and fills the slot")
	_expect(game_state.get_hero_combat_stats(hero_index).attack > original_attack, "Equipment bonuses affect combat attributes")
	result = game_state.unequip_item(hero_index, "weapon")
	_expect(equipped.weapon.is_empty() and game_state.inventory.has(replacement), "Unequipping returns the item to inventory and clears the slot")
	_expect(not game_state.unequip_item(hero_index, "bad_slot").is_empty(), "Invalid equipment slots are rejected")

func _test_inventory_ui(game_state: Node) -> void:
	Fixture.reset(game_state)
	var inventory: Node = load("res://scenes/inventory.tscn").instantiate()
	root.add_child(inventory)
	await process_frame
	_expect(inventory.get_node("ItemsScroll/Items").get_child_count() > 1, "Inventory creates visible item cells from the backpack")
	inventory._show_category("Equipment")
	var equipped_item := "魔神剑"
	game_state.equip_item(0, equipped_item)
	_expect(not inventory._owned_item_names().has(equipped_item), "Equipped items are hidden from the loose backpack")
	_expect(inventory.get_node("Title").text.contains("物品列表") and inventory.get_node("Empty").visible == false, "Equipment category displays a filtered inventory grid")
	inventory._show_category("Tasks")
	_expect(inventory.get_node("Empty").visible, "Empty categories show an explicit empty state")
	_expect(inventory.item_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO, "Inventory item list has a vertical scrollbar when it overflows")
	inventory.queue_free()
	await process_frame

func _test_empty_equipment_ui(game_state: Node) -> void:
	Fixture.reset(game_state)
	var character: Node = load("res://scenes/character.tscn").instantiate()
	root.add_child(character)
	await process_frame
	var weapon_path: String = character.get_node("Paper/EquipmentPanel/Weapon").texture_normal.resource_path
	var armor_path: String = character.get_node("Paper/EquipmentPanel/Armor").texture_normal.resource_path
	var accessory_path: String = character.get_node("Paper/EquipmentPanel/Accessory").texture_normal.resource_path
	_expect(weapon_path.ends_with("zbk_wuqi.png") and armor_path.ends_with("zbk_fangju.png") and accessory_path.ends_with("zbk_shipin.png"), "Empty equipment slots use dedicated slot icons")
	character.queue_free()
	await process_frame

func _test_character_equipment_menu(game_state: Node) -> void:
	Fixture.reset(game_state)
	var character: Node = load("res://scenes/character.tscn").instantiate()
	root.add_child(character)
	await process_frame
	character._show_equipment_choices("weapon")
	_expect(character.equipment_menu.item_count > 0, "Empty equipment slots offer available backpack equipment")
	character._on_equipment_choice(0)
	_expect(not str(game_state.hero_equipment[0].get("weapon", "")).is_empty(), "Choosing an item from an empty slot equips it immediately")
	var skills_tab: String = character.get_node("Paper/Tabs/Skills").tooltip_text
	character._show_tab(skills_tab)
	var martial_text: String = character.get_node("Paper/SkillsPanel/Scroll/Grid/Sword/Name").text
	var internal_button: Control = character.get_node("Paper/SkillsPanel/Scroll/Grid").get_child(game_state.hero_skills[0].martial.size())
	var internal_text: String = internal_button.get_node("Name").text
	_expect(not martial_text.contains("经验") and martial_text.contains("Lv."), "武学页只显示武学等级，不显示经验")
	_expect(not internal_text.contains("经验") and internal_text.contains("攻+") and internal_text.contains("防+"), "武学页显示心法攻防加成但不显示经验")
	game_state.selected_skill_name = str(game_state.hero_skills[0].internal)
	var skill_detail: Node = load("res://scenes/skill_detail.tscn").instantiate()
	root.add_child(skill_detail)
	await process_frame
	var skill_details: String = skill_detail.get_node("Paper/Description").text
	_expect(skill_details.contains("经验") and skill_details.contains("攻击 +6") and skill_details.contains("防御 +18"), "心法详情应显示经验和实际攻防加成")
	skill_detail.queue_free()
	await process_frame
	character.queue_free()
	await process_frame
	var reopened: Node = load("res://scenes/character.tscn").instantiate()
	root.add_child(reopened)
	await process_frame
	await process_frame
	_expect(reopened.current_tab == skills_tab, "Character page restores the last selected tab")
	reopened.queue_free()
	await process_frame

func _test_shop_sell_icons(game_state: Node) -> void:
	Fixture.reset(game_state)
	var shop: Node = load("res://scenes/shop.tscn").instantiate()
	root.add_child(shop)
	await process_frame
	shop._set_mode("sell")
	_expect(shop._icon_for("魔神剑", "res://assets/Items/caoyao.jpg").ends_with("moshenjian.jpg"), "Shop sell list uses the correct weapon icon")
	_expect(shop._icon_for("独孤九剑秘籍", "res://assets/Items/caoyao.jpg").ends_with("Bdugujiujianjianpu.jpg"), "Shop sell list uses the correct book icon")
	_expect(shop.goods_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO, "Shop goods list has a vertical scrollbar when it overflows")
	shop.queue_free()
	await process_frame

func _test_hero_growth(game_state: Node) -> void:
	Fixture.reset(game_state)
	var hero: Dictionary = game_state.heroes[0]
	var stats: Dictionary = game_state.hero_stats[0]
	var old_level: int = hero.level
	var old_stats := stats.duplicate(true)
	hero.exp = hero.level * 200 - 5
	game_state.gain_hero_experience(0, 8)
	_expect(hero.level == old_level + 1, "人物经验达到阈值后应升级")
	for attribute in ["strength", "agility", "insight", "luck", "constitution", "willpower"]:
		_expect(stats[attribute] == old_stats[attribute] + 1, "升级应提升基础属性：%s" % attribute)
	for technique in ["fist", "sword", "blade", "unorthodox"]:
		_expect(stats[technique] == old_stats[technique] + 2, "升级应提升武器技巧：%s" % technique)

func _test_battle_range(game_state: Node) -> void:
	Fixture.reset(game_state)
	_expect(game_state.heroes.size() == 6 and game_state.hero_stats.size() == 6 and game_state.hero_equipment.size() == 6 and game_state.hero_skills.size() == 6, "队伍资料应统一收敛为六名角色")
	_expect(game_state.heroes[0].model.ends_with("r-nan-jiangwei"), "主角应使用姜维模型")
	_expect(game_state.get_hero_model_path(1).ends_with("r-nv-duguyanran"), "第二名队友应使用独孤雁然模型")
	for hero_index in game_state.heroes.size():
		var model_unit: Node = load("res://scenes/battle_unit.tscn").instantiate()
		root.add_child(model_unit)
		await process_frame
		model_unit.configure(game_state.get_hero_model_path(hero_index), false)
		var frames: SpriteFrames = model_unit.get_node("Model").sprite_frames
		var model_sprite: AnimatedSprite2D = model_unit.get_node("Model")
		_expect(not frames.has_animation("skill"), "Combat model animations should expose attacks as attack, not skill")
		model_unit.play_action("skill")
		_expect(model_sprite.animation == "attack", "A skill action request should play the shared attack animation")
		model_unit.play_action("idle")
		if hero_index == 1: _expect(is_equal_approx(model_sprite.scale.x, 0.85 * 1.35), "Wang Chongyang model scale is enlarged")
		if hero_index == 3: _expect(is_equal_approx(model_sprite.scale.x, 0.85 * 0.72), "Xiao Longnu model scale is reduced")
		if hero_index == 4:
			_expect(frames.get_frame_count("idle") == 5 and frames.get_frame_count("attack") == 7, "Wang Yuyan stand3-7 and attack8-14 frames are bound by their source animation names")
			_expect(frames.get_frame_count("hurt") == 2 and frames.get_frame_count("walk") == 8 and not frames.has_animation("skill"), "Wang Yuyan beattack1-2 and move15-22 frames are bound by their source animation names")
		if hero_index == 5:
			_expect(frames.get_frame_count("idle") == 6 and frames.get_frame_count("attack") == 8, "Cheng Ying stand3-8 and attack9-16 frames are bound by their source animation names")
			_expect(frames.get_frame_count("hurt") == 2 and frames.get_frame_count("walk") == 8 and not frames.has_animation("skill"), "Cheng Ying beattack1-2 and move17-24 frames are bound by their source animation names")
		_expect(frames.has_animation("idle") and frames.get_frame_count("idle") > 0, "六名角色的模型都应至少加载待机帧")
		model_unit.show_floating_text("气血 +12", Color("#70e06d"))
		var popup: Label = model_unit.get_child(model_unit.get_child_count() - 1) as Label
		_expect(popup != null and popup.text == "气血 +12" and popup.get_theme_color("font_color") == Color("#70e06d") and popup.get_theme_font_size("font_size") >= 22, "战斗单位应以指定颜色和较大字号显示浮动提示")
		model_unit.show_floating_text("暴击 -99", Color("#ffe04b"), 30)
		var critical_popup: Label = model_unit.get_child(model_unit.get_child_count() - 1) as Label
		_expect(critical_popup != null and critical_popup.get_theme_color("font_color") == Color("#ffe04b") and critical_popup.get_theme_font_size("font_size") == 30, "暴击提示应使用黄色并额外放大字号")
		model_unit.queue_free()
		await process_frame
	game_state.selected_party.clear()
	game_state.selected_party.append(0)
	game_state.selected_party.append(1)
	game_state.heroes[0].erase("model")
	game_state.new_battle()
	_expect(not str(game_state.battle_allies[0].get("model", "")).is_empty(), "旧存档角色缺少模型字段时应自动使用兜底模型")
	game_state.battle_allies[0].erase("model")
	var battle: Node = load("res://scenes/battle.tscn").instantiate()
	root.add_child(battle)
	await process_frame
	var effect_offsets := {"狂风刀法":-38.0, "打狗棒法":-82.0, "降龙十八掌":-38.0, "独孤九剑":-88.0}
	for skill_name in effect_offsets:
		var effect: AnimatedSprite2D = battle._play_skill_effect(game_state.skill_library[skill_name], Vector2i(5, 3))
		var expected_y: float = battle._coord_to_board(Vector2i(5, 3)).y + battle.UNIT_FOOT_ANCHOR.y + float(effect_offsets[skill_name])
		_expect(effect != null and effect.is_playing() and effect.sprite_frames.get_frame_count("effect") > 1 and is_equal_approx(effect.position.y, expected_y) and effect.scale.x > 0.72, "%s应按素材构图上移并放大播放" % skill_name)
	var area_cells: Array[Vector2i] = [Vector2i(5, 3), Vector2i(6, 3), Vector2i(7, 3), Vector2i(8, 3)]
	var area_effects: Array[AnimatedSprite2D] = battle._play_skill_effects(game_state.skill_library["独孤九剑"], area_cells)
	_expect(area_effects.size() == area_cells.size(), "武学波及范围内的每个格子都应生成特效")
	_expect(battle.get_node("Board/Tiles").get_child_count() == 112, "战场应包含16×7共112个地块")
	_expect(battle.get_node("Board/Allies").mouse_filter == Control.MOUSE_FILTER_IGNORE, "我方单位层空白区域必须允许点击下层地块")
	_expect(battle.get_node("Board/Enemies").mouse_filter == Control.MOUSE_FILTER_IGNORE, "敌方单位层空白区域必须允许点击下层地块")
	var actor: Dictionary = game_state.battle_allies[0]
	var ally_model: AnimatedSprite2D = battle.get_node("Board/Allies/Ally1/Model")
	var enemy_model: AnimatedSprite2D = battle.get_node("Board/Enemies/Enemy1/Model")
	var walking_ally: AnimatedSprite2D = battle.get_node("Board/Allies/Ally2/Model")
	var facing_unit: Node = battle.get_node("Board/Allies/Ally1")
	facing_unit.call("face_toward", Vector2i.LEFT)
	_expect(ally_model.flip_h, "朝左释放招式后人物模型应转向左侧")
	battle._refresh_units()
	_expect(ally_model.flip_h, "刷新角色状态时应保留招式后的朝向")
	facing_unit.call("face_toward", Vector2i.RIGHT)
	_expect(not ally_model.flip_h, "朝右释放招式后人物模型应转向右侧")
	_expect(walking_ally.sprite_frames.has_animation("walk") and walking_ally.sprite_frames.get_frame_count("walk") == 8, "有移动帧的独孤雁然模型应加载真实走路动画")
	_expect(game_state.battle_enemies[0].model.ends_with("r-nan-zhoucang"), "敌人应统一使用周仓模型")
	_expect(ally_model.offset.y < 0.0 and is_equal_approx(ally_model.scale.x, 0.85), "妯″瀷搴斿澶у苟浠ヨ剼搴曞榻愭牸瀛愪腑蹇?")
	_expect(not battle.get_node("Board/Allies/Ally1").has_node("HPText"), "妫嬬洏涓嶅簲鏄剧ず姘旇鍏蜂綋鏁板€?")
	var hp_fill: StyleBoxFlat = battle.get_node("Board/Allies/Ally1/HP").get_theme_stylebox("fill")
	var mp_fill: StyleBoxFlat = battle.get_node("Board/Allies/Ally1/MP").get_theme_stylebox("fill")
	_expect(battle.get_node("Board/Allies/Ally1/HP").mouse_filter == Control.MOUSE_FILTER_IGNORE and battle.get_node("Board/Allies/Ally1/MP").mouse_filter == Control.MOUSE_FILTER_IGNORE, "Unit health and mana bars do not intercept board clicks")
	_expect(hp_fill.bg_color.r > hp_fill.bg_color.g and mp_fill.bg_color.b > mp_fill.bg_color.r, "姘旇鍜屽唴鍔涘簲鍒嗗埆浣跨敤绾㈣壊鍜岃摑鑹叉潯")
	_expect(ally_model.sprite_frames.get_frame_count("idle") > 1 and ally_model.is_playing(), "战斗中的我方人物应使用循环模型帧动画")
	_expect(enemy_model.sprite_frames.get_frame_count("idle") > 1 and enemy_model.flip_h, "敌方模型应播放待机帧并朝向我方")
	_expect(not battle.get_node("Board/Allies/Ally1").has_node("Portrait"), "棋盘战斗单位不应继续显示静态头像")
	_expect(battle.get_node("Rest").texture_normal.resource_path == "res://assets/UI/zhuangtai.png", "调息应使用打坐运功图标")
	_expect(battle.has_node("Top/Surrender") and battle.has_node("Top/RestartBattle"), "战斗界面应在右上角提供投降和重开按钮")
	battle._on_ally_hovered(0)
	_expect(battle.get_node("HoverInfo").visible and battle.get_node("HoverInfo/Kind").text == "我方状态", "悬停我方人物时应显示角色状态浮层")
	_expect(battle.get_node("HoverInfo/Details").text.contains("内力") and battle.get_node("HoverInfo/Details").text.contains("当前行动"), "我方详情应包含内力和行动时序")
	_expect(not battle.get_node("Top/Hint").text.contains("气血"), "角色详细数值不应在顶部重复显示")
	battle._on_unit_exited()
	battle._on_enemy_hovered(0)
	_expect(battle.get_node("HoverInfo").visible, "悬停敌人时应显示状态详情浮层")
	_expect(battle.get_node("HoverInfo/Details").text.contains("下次行动") and battle.get_node("HoverInfo/Details").text.contains("状态正常"), "敌人详情应包含时序和异常状态")
	battle._on_unit_exited()
	_expect(not battle.get_node("HoverInfo").visible, "移出敌人后应隐藏状态详情")
	var action_hint: String = battle.get_node("Top/Hint").text
	battle._on_skill_hovered(0)
	_expect(battle.get_node("HoverInfo").visible and battle.get_node("HoverInfo/Kind").text == "武学详情", "悬停武学时应显示武学详情浮层")
	_expect(battle.get_node("HoverInfo/Details").text.contains("预计伤害") and battle.get_node("HoverInfo/Details").text.contains("剑意纵横"), "武学详情应包含战斗数值和招式说明")
	_expect(battle.get_node("HoverInfo/Details").text.contains("经验"), "战斗武学悬浮详情应显示经验进度")
	var skill_button_rect: Rect2 = battle.get_node("Bottom/Skills").get_child(0).get_global_rect()
	_expect(battle.get_node("HoverInfo").position.y < skill_button_rect.position.y, "武学悬浮详情应显示在对应武学图标上方")
	_expect(battle.get_node("Top/Hint").text == action_hint, "武学详细数值不应在顶部重复显示")
	battle._on_hover_info_exited()
	var reachable: Array[Vector2i] = battle._reachable_tiles(actor)
	_expect(reachable.has(Vector2i(4, 3)), "人物应能在移动范围内移动两格")
	_expect(not reachable.has(Vector2i(8, 3)), "人物不能越过移动范围直接接近敌人")
	var move_tile: TextureButton = battle.get_node("Board/Tiles").get_child(1 * 16 + 4)
	var hidden_move_tile: TextureButton = battle.get_node("Board/Tiles").get_child(0)
	var move_style: StyleBoxFlat = move_tile.get_node("RangeOverlay").get_theme_stylebox("panel")
	_expect(move_style.bg_color.g > move_style.bg_color.r and move_style.bg_color.g > move_style.bg_color.b and move_style.border_width_left == 3, "可移动区域应使用醒目的绿色填充和边框")
	_expect(hidden_move_tile.modulate.a < 0.1, "移动时应隐藏不可移动的其他棋盘区域")
	battle._on_tile_hovered(3 * 16 + 4)
	_expect(battle.get_node("Top/Hint").text.contains("点击确认"), "悬停可移动地块时应显示操作提示")
	_expect(battle.get_node("Board/Tiles").get_child(1 * 16 + 4).modulate.r > 0.75 and battle.get_node("Board/Tiles").get_child(1 * 16 + 4).modulate.g > 0.75, "移动悬停应保留黄色方框提示")
	battle._on_tile_pressed(3 * 16 + 4)
	_expect(actor.coord == Vector2i(4, 3) and actor.moved, "点击蓝色地块后人物应移动到目标位置")
	var moving_model: AnimatedSprite2D = battle.get_node("Board/Allies/Ally1/Model")
	battle.get_node("Board/Allies/Ally1").call("face_toward", Vector2i.LEFT)
	battle._on_undo_move_pressed()
	await create_timer(0.25).timeout
	battle._on_tile_pressed(3 * 16 + 4)
	_expect(not moving_model.flip_h, "向右移动后人物模型应转向右侧")
	_expect(move_tile.modulate.a < 0.1, "本次移动完成后应隐藏已不可用的移动范围")
	_expect(not battle.get_node("UndoMove").disabled, "完成移动后应允许撤回本次移动")
	battle._select_skill(0)
	_expect(not battle.get_node("UndoMove").disabled, "移动后选中武学不应锁定撤回操作")
	battle._on_undo_move_pressed()
	_expect(actor.coord == Vector2i(2, 3) and not actor.moved, "撤回移动应恢复人物原坐标和可移动状态")
	_expect(move_tile.modulate.a == 1.0, "撤回移动后应重新显示可移动区域")
	_expect(battle.selected_skill == -1, "撤回移动时应同时取消已选武学，避免误施放")
	_expect(battle.get_node("UndoMove").disabled, "撤回后按钮应立即禁用，避免重复撤回")
	await create_timer(0.25).timeout
	_expect(battle.get_node("Board/Allies/Ally1").position.distance_to(battle._coord_to_board(Vector2i(2, 3))) < 1.0, "撤回动画结束后人物画面位置应回到起点")
	game_state.battle_enemies[0].coord = Vector2i(5, 3)
	battle._select_skill(0)
	battle._on_ally_hovered(1)
	var ally_foot_style: StyleBoxFlat = battle.get_node("Board/Tiles").get_child(2 * 16 + 2).get_node("RangeOverlay").get_theme_stylebox("panel")
	_expect(ally_foot_style.bg_color.g > ally_foot_style.bg_color.r, "悬停队友脚下格时应继续显示武学命中范围")
	battle._on_unit_exited()
	_expect(not battle.get_node("Bottom/Skills/Sword/Selection").visible, "选中武学不应再显示重复的金色面板边框")
	_expect(battle.get_node("Bottom/Skills/Sword/IconFrame").visible, "选中武学应显示框形图标")
	_expect(battle.get_node("Bottom/Skills/Sword/IconFrame").size == Vector2(120, 120) and battle.get_node("Bottom/Skills/Sword/IconFrame").position == Vector2(0, 14), "武学框形图标应贴合完整图标")
	_expect(battle.get_node("Board/Allies/Ally1").modulate == Color.WHITE, "行动中的人物模型不应整体染成黄色")
	_expect(not battle.has_node("Bottom/SelectedSkill"), "底部不应保留重复的最左侧武学面板")
	var release_tile: TextureButton = battle.get_node("Board/Tiles").get_child(1 * 16 + 3)
	var dim_tile: TextureButton = battle.get_node("Board/Tiles").get_child(0)
	var initial_release_style: StyleBoxFlat = release_tile.get_node("RangeOverlay").get_theme_stylebox("panel")
	_expect(initial_release_style.bg_color.r > initial_release_style.bg_color.g, "剑招相邻释放格应使用橙红色显示")
	for release_coord in [Vector2i(1, 3), Vector2i(3, 3), Vector2i(2, 2), Vector2i(2, 4)]:
		_expect(battle._can_target(release_coord), "剑招应允许在人物上下左右四格确定释放方向")
	_expect(not battle._can_target(Vector2i(4, 3)), "剑招不应把距离两格以上的位置作为释放点")
	_expect(not battle._can_target(Vector2i(3, 2)), "剑招不应允许斜向释放")
	var sword_releases := 0
	for y in 9:
		for x in 16:
			if battle._can_target(Vector2i(x, y)): sword_releases += 1
	_expect(sword_releases == 4, "剑招应恰好只有上下左右四个释放点")
	var sword_reach_style: StyleBoxFlat = battle.get_node("Board/Tiles").get_child(1 * 16 + 5).get_node("RangeOverlay").get_theme_stylebox("panel")
	_expect(absf(sword_reach_style.bg_color.r - sword_reach_style.bg_color.g) < 0.05, "剑招方向上的其余直线格应显示为可波及区域")
	_expect(dim_tile.modulate.a < 0.1, "技能范围外的棋盘格应隐藏")
	var caster_tile: TextureButton = battle.get_node("Board/Tiles").get_child(1 * 16 + 2)
	var caster_style: StyleBoxFlat = caster_tile.get_node("RangeOverlay").get_theme_stylebox("panel")
	_expect(caster_style.bg_color.a == 0.0, "施法者所在格不应误标为释放点")
	battle._on_tile_hovered(3 * 16 + 3)
	var release_style: StyleBoxFlat = release_tile.get_node("RangeOverlay").get_theme_stylebox("panel")
	var affected_style: StyleBoxFlat = battle.get_node("Board/Tiles").get_child(1 * 16 + 5).get_node("RangeOverlay").get_theme_stylebox("panel")
	_expect(release_style.bg_color.g > release_style.bg_color.r, "本次释放中心属于命中范围，应同样使用绿色显示")
	_expect(affected_style.bg_color.g > affected_style.bg_color.r and affected_style.border_color.g > 0.95, "剑招应高亮所选方向直线上的四格")
	battle._on_tile_exited()
	await process_frame
	var restored_release_style: StyleBoxFlat = release_tile.get_node("RangeOverlay").get_theme_stylebox("panel")
	_expect(restored_release_style.bg_color.r > restored_release_style.bg_color.g, "移开鼠标后应恢复橙红色合法释放区域")
	battle._on_tile_hovered(3 * 16 + 3)
	battle._on_tile_exited()
	battle._on_tile_hovered(3 * 16 + 1)
	var rapid_hover_tile: TextureButton = battle.get_node("Board/Tiles").get_child(1 * 16 + 1)
	var rapid_hover_style: StyleBoxFlat = rapid_hover_tile.get_node("RangeOverlay").get_theme_stylebox("panel")
	_expect(rapid_hover_style.bg_color.g > rapid_hover_style.bg_color.r, "快速切换悬停格时不应被旧格离开事件清除攻击范围")
	battle._select_skill(0)
	battle._select_skill(2)
	var potential_tile: TextureButton = battle.get_node("Board/Tiles").get_child(1 * 16 + 5)
	var cross_release_tile: TextureButton = battle.get_node("Board/Tiles").get_child(1 * 16 + 4)
	var potential_style: StyleBoxFlat = potential_tile.get_node("RangeOverlay").get_theme_stylebox("panel")
	var cross_release_style: StyleBoxFlat = cross_release_tile.get_node("RangeOverlay").get_theme_stylebox("panel")
	_expect(absf(potential_style.bg_color.r - potential_style.bg_color.g) < 0.05, "只能被武学波及、不能直接释放的区域应使用灰色显示")
	_expect(cross_release_style.bg_color.r > cross_release_style.bg_color.g, "十字武学的合法释放区域应使用橙红色显示")
	battle._on_tile_hovered(3 * 16 + 4)
	var cross_affected_style: StyleBoxFlat = potential_tile.get_node("RangeOverlay").get_theme_stylebox("panel")
	_expect(cross_affected_style.bg_color.g > cross_affected_style.bg_color.r, "十字武学当前会波及的灰色格应切换为绿色")
	battle._on_tile_exited()
	battle._select_skill(2)
	battle._select_skill(0)
	var affected_coords: Array[Vector2i] = battle._affected_coords(Vector2i(3, 3))
	_expect(not battle._can_target(Vector2i(2, 3)), "武学不能以施法者自身格为目标")
	_expect(affected_coords == [Vector2i(3, 3), Vector2i(4, 3), Vector2i(5, 3), Vector2i(6, 3)], "剑招应沿选定方向攻击直线上的四格")
	_expect(battle._affected_enemies(Vector2i(3, 3)) == [0], "剑招应命中所选方向四格直线上的敌人")
	battle._select_skill(0)
	battle._select_skill(1)
	_expect(battle._can_target(Vector2i(5, 3)) and not battle._can_target(Vector2i(6, 3)), "拳掌武学应可攻击三格内单体")
	_expect(battle._affected_coords(Vector2i(5, 3)) == [Vector2i(5, 3)], "拳掌武学应只命中选定单格")
	game_state.hero_skills[actor.hero_index].martial.append("狂风刀法")
	game_state.hero_skills[actor.hero_index].levels["狂风刀法"] = 1
	battle._refresh_skill_buttons()
	battle._select_skill(3)
	var blade_tiles: Array[Vector2i] = battle._affected_coords(Vector2i(3, 3))
	_expect(blade_tiles == [Vector2i(3, 2), Vector2i(4, 2), Vector2i(3, 3), Vector2i(4, 3), Vector2i(3, 4), Vector2i(4, 4)], "刀法应攻击前方3×2共六格")
	battle._select_skill(3)
	battle._select_skill(2)
	_expect(battle._affected_coords(Vector2i(4, 3)) == [Vector2i(4, 2), Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3), Vector2i(5, 3), Vector2i(6, 3), Vector2i(4, 4), Vector2i(4, 5)], "奇门应在两格内落点攻击十字九格，超出场地部分不计入")
	_expect(is_equal_approx(battle._skill_multiplier(1), 1.0) and is_equal_approx(battle._skill_multiplier(10), 1.9), "武学等级应提升基础伤害倍率")
	battle._select_skill(2)
	_expect(battle.selected_skill == -1 and not battle.get_node("Bottom/Skills/Sword/IconFrame").visible, "再次点击已选武学应取消选择框形图标")
	game_state.battle_enemies[0].coord = Vector2i(2, 5)
	var ally_block_test_hp: int = game_state.battle_enemies[0].hp
	battle._select_skill(0)
	await battle._on_ally_pressed(1)
	_expect(game_state.battle_enemies[0].hp < ally_block_test_hp, "点击占据释放格的队友时应仍可施放剑法并命中其后直线敌人")
	battle.queue_free()
	await process_frame

func _test_party_turns(game_state: Node) -> void:
	Fixture.reset(game_state)
	game_state.selected_party.clear()
	game_state.selected_party.append(0)
	game_state.selected_party.append(1)
	game_state.new_battle()
	var battle: Node = load("res://scenes/battle.tscn").instantiate()
	root.add_child(battle)
	await process_frame
	var first_actor: Dictionary = game_state.battle_allies[0]
	var second_actor: Dictionary = game_state.battle_allies[1]
	var first_action_time: int = game_state.turn
	var original_mp: int = first_actor.mp
	var original_enemy_hp: int = game_state.battle_enemies[0].hp
	_expect(first_actor.action_delay < second_actor.action_delay, "身法更高的侠客行动间隔应更短")
	_expect(battle.selected_actor == 0 and first_action_time == first_actor.next_action, "战斗应从最早时序的侠客开始")
	battle._select_skill(0)
	var empty_target: Vector2i = first_actor.coord + Vector2i.RIGHT
	var target_index: int = empty_target.y * 16 + empty_target.x
	var target_tile: TextureButton = battle.get_node("Board/Tiles").get_child((empty_target.y - 2) * 16 + empty_target.x)
	battle._on_tile_hovered(target_index)
	var target_overlay: Panel = target_tile.get_node("RangeOverlay")
	var target_style: StyleBoxFlat = target_overlay.get_theme_stylebox("panel")
	_expect(target_style.bg_color.g > target_style.bg_color.r, "悬停的武学释放中心应作为本次命中区域显示绿色")
	await battle._on_tile_pressed(target_index)
	_expect(first_actor.mp < original_mp, "武学应允许对空地施放并消耗内力")
	_expect(game_state.battle_enemies[0].hp == original_enemy_hp, "空地施法不应错误命中远处敌人")
	_expect(first_actor.next_action == first_action_time + first_actor.action_delay, "侠客行动后应按行动间隔重新排入时序")
	_expect(battle.selected_actor == 1 and game_state.turn == second_actor.next_action, "下一位应是时序值最小的侠客")
	battle._on_rest_pressed()
	await create_timer(2.0).timeout
	_expect(battle.selected_actor == 0 and game_state.turn == first_actor.next_action, "敌方时序自动结算后应回到下一名最早行动的侠客")
	_expect(battle.selected_skill == -1, "角色再次行动时不应自动选中上次释放的武学")
	_expect(game_state.turn > second_actor.action_delay, "时序应持续递增而非按固定轮次重置")
	battle.queue_free()
	await process_frame

func _test_auto_battle(game_state: Node) -> void:
	Fixture.reset(game_state)
	game_state.selected_party.clear()
	game_state.selected_party.append(0)
	game_state.new_battle()
	var battle: Node = load("res://scenes/battle.tscn").instantiate()
	root.add_child(battle)
	await process_frame
	var actor: Dictionary = game_state.battle_allies[battle.selected_actor]
	var initial_action_time: int = actor.next_action
	battle._on_battle_speed_pressed()
	_expect(is_equal_approx(battle.battle_speed, 2.0), "戰鬥加速按鈕應切換至2倍速度")
	_expect(battle.get_node("Top/BattleSpeed").text == "战斗 2倍", "战斗加速按钮应显示简体中文")
	battle._on_auto_battle_toggled(true)
	_expect(battle.get_node("Top/AutoBattle").text == "自动：开", "自动战斗按钮应显示简体中文")
	_expect(is_equal_approx(battle.get_node("Board/Tiles/Tile0").modulate.a, 0.0), "自动战斗开启时应隐藏棋盘范围提示")
	await create_timer(3.5).timeout
	_expect(actor.next_action > initial_action_time and game_state.turn > initial_action_time, "開啟自動戰鬥後应连续完成行动并推进时序")
	_expect(not battle.auto_action_running or not battle.is_player_turn or battle.selected_actor != 0, "自动战斗不应因已选武学或移动阶段而卡住")
	_expect(game_state.settings.auto_battle, "戰鬥中的自動戰鬥狀態應同步至系統設定")
	battle.queue_free()
	await process_frame

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error("ASSERTION FAILED: " + message)
