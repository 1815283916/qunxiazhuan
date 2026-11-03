extends Control

@onready var game_state := get_node("/root/GameState")

const BOARD_WIDTH := 16
const BOARD_HEIGHT := 7
const TILE_ROW_OFFSET := 2
const BOARD_ORIGIN := Vector2(15, 12)
const TILE_SIZE := Vector2(90, 62)
const TILE_STEP := Vector2(93, 65)
const UNIT_FOOT_ANCHOR := Vector2(45, 31)
const ATTACK_RANGE_COLOR := Color(0.08, 0.68, 0.18, 0.54)
const ATTACK_RANGE_BORDER := Color(0.24, 1.0, 0.35, 0.96)
const ATTACK_CONTEXT_COLOR := Color(0.22, 0.24, 0.27, 0.68)
const ATTACK_CONTEXT_BORDER := Color(0.66, 0.69, 0.73, 0.92)
const ATTACK_PREVIEW_COLOR := Color(0.94, 0.2, 0.06, 0.42)
const ATTACK_PREVIEW_BORDER := Color(1.0, 0.78, 0.16, 1.0)
const MOVE_RANGE_COLOR := Color(0.08, 0.68, 0.18, 0.56)
const MOVE_RANGE_BORDER := Color(0.32, 1.0, 0.42, 1.0)

var selected_skill := -1
var selected_actor := 0
var current_skills: Array[String] = []
var battle_finished := false
var is_player_turn := false
var move_origin := Vector2i(-1, -1)
var move_actor_index := -1
var movement_tween: Tween
var range_clear_style: StyleBoxFlat
var range_context_style: StyleBoxFlat
var range_valid_style: StyleBoxFlat
var range_preview_style: StyleBoxFlat
var move_range_style: StyleBoxFlat
var move_hover_style: StyleBoxFlat
var auto_battle_enabled := false
var auto_action_running := false
var automation_command := false
var battle_speed := 1.0
var range_hover_revision := 0
var player_action_resolving := false
var last_used_skill_name := ""

func _ready() -> void:
	if game_state.battle_allies.is_empty(): game_state.new_battle()
	auto_battle_enabled = bool(game_state.settings.get("auto_battle", false))
	$Top/AutoBattle.button_pressed = auto_battle_enabled
	_update_auto_button()
	$Top/AutoBattle.text = "自动：开" if auto_battle_enabled else "自动：关"
	_update_speed_button()
	$Top/BattleSpeed.text = "战斗 1倍"
	$Top/AutoBattle.toggled.connect(_on_auto_battle_toggled)
	$Top/BattleSpeed.pressed.connect(_on_battle_speed_pressed)
	$Top/Surrender.pressed.connect(_on_surrender_pressed)
	$Top/RestartBattle.pressed.connect(_on_restart_battle_pressed)
	_prepare_range_styles()
	_prepare_board()
	for i in $Board/Tiles.get_child_count():
		var tile := $Board/Tiles.get_child(i)
		tile.pressed.connect(_on_board_tile_pressed.bind(i))
		tile.mouse_entered.connect(_on_board_tile_hovered.bind(i))
		tile.mouse_exited.connect(_on_tile_exited)
	for i in $Bottom/Skills.get_child_count():
		var skill_button := $Bottom/Skills.get_child(i)
		skill_button.pressed.connect(_select_skill.bind(i))
		skill_button.mouse_entered.connect(_on_skill_hovered.bind(i))
		skill_button.mouse_exited.connect(_on_hover_info_exited)
		_prepare_skill_button_frame(skill_button)
	for i in $Board/Allies.get_child_count():
		var ally_button := $Board/Allies.get_child(i)
		ally_button.pressed.connect(_on_ally_pressed.bind(i))
		ally_button.mouse_entered.connect(_on_ally_hovered.bind(i))
		ally_button.mouse_exited.connect(_on_unit_exited)
	for i in $Board/Enemies.get_child_count():
		var enemy_button := $Board/Enemies.get_child(i)
		enemy_button.pressed.connect(_on_enemy_pressed.bind(i))
		enemy_button.mouse_entered.connect(_on_enemy_hovered.bind(i))
		enemy_button.mouse_exited.connect(_on_unit_exited)
	$Rest.mouse_entered.connect(_show_operation_hint.bind("调息：恢复12点气血和15点内力，并结束本回合"))
	$Rest.mouse_exited.connect(_restore_action_hint)
	$Items.mouse_entered.connect(_show_operation_hint.bind("物品：使用疗伤药或大还丹，并结束本回合"))
	$Items.mouse_exited.connect(_restore_action_hint)
	$UndoMove.mouse_entered.connect(_show_operation_hint.bind("撤回移动：返回本次移动前的位置，不消耗行动时序"))
	$UndoMove.mouse_exited.connect(_restore_action_hint)
	$ItemPanel/Healing.pressed.connect(_use_item.bind("疗伤药"))
	$ItemPanel/Great.pressed.connect(_use_item.bind("大还丹"))
	_refresh_units()
	_apply_battle_speed()
	_start_timeline()

func _prepare_board() -> void:
	$Board/Tiles.columns = BOARD_WIDTH
	$Board/Tiles.position = BOARD_ORIGIN + Vector2(0, TILE_STEP.y * TILE_ROW_OFFSET)
	var target_tile_count := BOARD_WIDTH * BOARD_HEIGHT
	while $Board/Tiles.get_child_count() > target_tile_count:
		var extra_tile := $Board/Tiles.get_child(0)
		$Board/Tiles.remove_child(extra_tile)
		extra_tile.queue_free()
	var template := $Board/Tiles.get_child(0) as TextureButton
	while $Board/Tiles.get_child_count() < target_tile_count:
		var tile := template.duplicate() as TextureButton
		tile.name = "Tile%d" % $Board/Tiles.get_child_count()
		$Board/Tiles.add_child(tile)
	for tile in $Board/Tiles.get_children():
		tile.custom_minimum_size = TILE_SIZE
		var overlay := Panel.new()
		overlay.name = "RangeOverlay"
		overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.add_theme_stylebox_override("panel", range_clear_style)
		tile.add_child(overlay)

func _prepare_range_styles() -> void:
	range_clear_style = _make_range_style(Color.TRANSPARENT, Color.TRANSPARENT, 0)
	range_context_style = _make_range_style(ATTACK_CONTEXT_COLOR, ATTACK_CONTEXT_BORDER, 1)
	range_valid_style = _make_range_style(ATTACK_RANGE_COLOR, ATTACK_RANGE_BORDER, 2)
	range_preview_style = _make_range_style(ATTACK_PREVIEW_COLOR, ATTACK_PREVIEW_BORDER, 3)
	move_range_style = _make_range_style(MOVE_RANGE_COLOR, MOVE_RANGE_BORDER, 3)
	move_hover_style = _make_range_style(Color(0.12, 0.8, 0.24, 0.82), Color(0.62, 1.0, 0.68, 1.0), 4)

func _make_range_style(background: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.border_width_left = width
	style.border_width_top = width
	style.border_width_right = width
	style.border_width_bottom = width
	return style

func _set_range_tile(tile: TextureButton, style: StyleBoxFlat, tile_modulate: Color) -> void:
	tile.modulate = tile_modulate
	(tile.get_node("RangeOverlay") as Panel).add_theme_stylebox_override("panel", style)

func _select_actor(index: int) -> void:
	if index >= game_state.battle_allies.size() or not game_state.battle_allies[index].alive: return
	if not is_player_turn or index != selected_actor:
		var waiting_actor: Dictionary = game_state.battle_allies[index]
		$Top/Hint.text = "%s的行动时序尚未到达（下次行动：%d）" % [waiting_actor.name, waiting_actor.next_action]
		return
	selected_skill = -1
	var actor: Dictionary = game_state.battle_allies[index]
	$Top/Hint.text = "%s行动中：可移动到蓝色地块，或选择武学" % actor.name
	_highlight_move_tiles()
	_refresh_units()
	_refresh_skill_buttons()

func _select_skill(index: int) -> void:
	if auto_action_running and not automation_command: return
	if not _active_actor_valid(): return
	if index < 0 or index >= current_skills.size(): return
	var actor: Dictionary = game_state.battle_allies[selected_actor]
	var skill: Dictionary = game_state.skill_library[current_skills[index]]
	if actor.mp < skill.cost:
		$Top/Hint.text = "内力不足，无法施放该武学"
		return
	if selected_skill == index:
		selected_skill = -1
		$Top/Hint.text = "已取消武学，点击蓝色地块移动或重新选择招式"
		_highlight_move_tiles()
		_update_skill_selection_visuals()
		return
	selected_skill = index
	$ItemPanel.visible = false
	if auto_battle_enabled: $Top/Hint.text = "自动战斗：正在行动"
	$Top/Hint.text = "%s：选择橙红色地块释放；悬停时绿色显示本次攻击范围" % actor.name
	_highlight_attack_tiles()
	_update_skill_selection_visuals()

func _on_tile_pressed(index: int) -> void:
	if auto_action_running and not automation_command: return
	if not _active_actor_valid(): return
	var coord := _coord_from_index(index)
	var actor: Dictionary = game_state.battle_allies[selected_actor]
	if selected_skill < 0:
		if actor.moved:
			$Top/Hint.text = "本次移动已完成，可撤回移动、选择武学或调息"
		elif _reachable_tiles(actor).has(coord):
			var unit_node := $Board/Allies.get_child(selected_actor) as Control
			move_origin = actor.coord
			move_actor_index = selected_actor
			unit_node.face_toward(coord - actor.coord)
			actor.coord = coord
			actor.moved = true
			game_state.battle_log.append("%s移动至（%d，%d）" % [actor.name, coord.x + 1, coord.y + 1])
			$Top/Hint.text = "移动完成，可撤回移动，或继续选择武学、物品和调息"
			_stop_movement_tween()
			var move_duration := maxf(0.28, float(_distance(move_origin, coord)) * 0.3) / battle_speed
			movement_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			unit_node.start_walk_animation()
			movement_tween.finished.connect(unit_node.stop_walk_animation, CONNECT_ONE_SHOT)
			movement_tween.tween_property(unit_node, "position", _coord_to_board(coord), move_duration)
			_highlight_move_tiles()
			_update_undo_button()
		else:
			$Top/Hint.text = "该地块不可到达，请选择蓝色地块"
		return
	if not _can_target(coord):
		$Top/Hint.text = "该地块不在武学攻击范围内"
		return
	var affected := _affected_enemies(coord)
	var skill_name: String = current_skills[selected_skill]
	var skill: Dictionary = game_state.skill_library[skill_name]
	last_used_skill_name = skill_name
	player_action_resolving = true
	_clear_range_display()
	var actor_node := $Board/Allies.get_child(selected_actor) as Control
	actor_node.face_toward(coord - actor.coord)
	actor_node.play_action("attack")
	var loadout: Dictionary = game_state.hero_skills[actor.hero_index]
	var skill_level: int = int(loadout.levels.get(skill_name, 1))
	var technique: int = actor.sword if skill.school == "剑系" else actor.fist if skill.school == "拳掌" else actor.unorthodox if skill.school == "奇门" else actor.blade
	var damage: int = _skill_damage(actor, skill, skill_level)
	var critical: bool = randf() * 100.0 < actor.crit
	if critical: damage = int(damage * actor.crit_damage / 100.0)
	actor.mp -= skill.cost
	var hurt_enemy_nodes: Array[Control] = []
	if affected.is_empty():
		game_state.battle_log.append("%s对（%d，%d）施放%s" % [actor.name, coord.x + 1, coord.y + 1, skill_name])
	for enemy_index in affected:
		var enemy: Dictionary = game_state.battle_enemies[enemy_index]
		var enemy_node := $Board/Enemies.get_child(enemy_index) as Control
		enemy_node.play_action("hurt")
		hurt_enemy_nodes.append(enemy_node)
		var actual_damage: int = maxi(1, damage - int(enemy.defense / 4.0))
		enemy.hp = maxi(0, enemy.hp - actual_damage)
		game_state.battle_log.append("%s%s对%s造成%d点伤害" % ["暴击！" if critical else "", actor.name, enemy.name, actual_damage])
		if actor.poison > 0 and randf() * 100.0 < actor.poison:
			enemy.poison_turns = 3
			game_state.battle_log.append("%s中毒，持续3回合" % enemy.name)
		if enemy.hp <= 0:
			enemy.alive = false
			game_state.battle_log.append("%s退场" % enemy.name)
	await actor_node.wait_for_action("attack")
	for enemy_node in hurt_enemy_nodes:
		await enemy_node.wait_for_action("hurt")
	selected_skill = -1
	_clear_move_undo()
	game_state.gain_hero_experience(actor.hero_index, 8)
	game_state.gain_skill_experience(actor.hero_index, skill_name)
	game_state.gain_skill_experience(actor.hero_index, loadout.internal, 6)
	_refresh_units()
	player_action_resolving = false
	if _all_enemies_defeated():
		_finish_battle(true)
	else:
		_complete_actor_action()

func _on_board_tile_pressed(index: int) -> void:
	_on_tile_pressed(_board_coord_from_index(index).y * BOARD_WIDTH + _board_coord_from_index(index).x)

func _restore_last_skill_selection() -> void:
	if last_used_skill_name.is_empty() or not _active_actor_valid(): return
	var skill_index := current_skills.find(last_used_skill_name)
	if skill_index < 0: return
	var actor: Dictionary = game_state.battle_allies[selected_actor]
	var skill: Dictionary = game_state.skill_library[last_used_skill_name]
	if actor.mp < skill.cost: return
	selected_skill = skill_index
	_highlight_attack_tiles()
	_update_skill_selection_visuals()

func _on_surrender_pressed() -> void:
	if battle_finished: return
	_clear_range_display()
	_finish_battle(false)

func _on_restart_battle_pressed() -> void:
	if battle_finished: return
	game_state.new_battle()
	get_tree().reload_current_scene()

func _on_enemy_pressed(enemy_index: int) -> void:
	if enemy_index >= game_state.battle_enemies.size(): return
	var enemy: Dictionary = game_state.battle_enemies[enemy_index]
	if not enemy.alive: return
	await _on_tile_pressed(enemy.coord.y * BOARD_WIDTH + enemy.coord.x)

func _on_ally_pressed(ally_index: int) -> void:
	if selected_skill >= 0:
		if ally_index < 0 or ally_index >= game_state.battle_allies.size(): return
		var ally: Dictionary = game_state.battle_allies[ally_index]
		if ally.alive:
			await _on_tile_pressed(ally.coord.y * BOARD_WIDTH + ally.coord.x)
		return
	_select_actor(ally_index)

func _on_tile_hovered(index: int) -> void:
	range_hover_revision += 1
	if auto_battle_enabled or not _active_actor_valid():
		_clear_range_display()
		return
	var target := _coord_from_index(index)
	if selected_skill >= 0:
		if not _can_target(target):
			$Top/Hint.text = "该地块超出武学范围"
			return
		_preview_attack_tiles(target)
		var skill: Dictionary = game_state.skill_library[current_skills[selected_skill]]
		$Top/Hint.text = "%s：基础伤害%d，预计影响%d名敌人；点击施放" % [current_skills[selected_skill], skill.damage, _affected_enemies(target).size()]
		return
	var actor: Dictionary = game_state.battle_allies[selected_actor]
	if actor.moved:
		$Top/Hint.text = "%s本回合已经移动，可选择武学、物品或调息" % actor.name
	elif _reachable_tiles(actor).has(target):
		var visual_index := (target.y - TILE_ROW_OFFSET) * BOARD_WIDTH + target.x
		if visual_index >= 0 and visual_index < $Board/Tiles.get_child_count():
			_set_range_tile($Board/Tiles.get_child(visual_index) as TextureButton, move_hover_style, Color("#d9e86f"))
		$Top/Hint.text = "移动至（%d，%d），距离%d格；点击确认" % [target.x + 1, target.y + 1, _distance(actor.coord, target)]
	else:
		$Top/Hint.text = "（%d，%d）不可到达：超出移动范围或路径受阻" % [target.x + 1, target.y + 1]

func _on_board_tile_hovered(index: int) -> void:
	_on_tile_hovered(_board_coord_from_index(index).y * BOARD_WIDTH + _board_coord_from_index(index).x)

func _on_tile_exited() -> void:
	if auto_battle_enabled:
		_clear_range_display()
		return
	range_hover_revision += 1
	if selected_skill >= 0:
		_restore_attack_range_after_hover(range_hover_revision)
	else:
		_highlight_move_tiles()
	_restore_action_hint()

func _restore_attack_range_after_hover(revision: int) -> void:
	await get_tree().create_timer(0.15).timeout
	if revision != range_hover_revision or auto_battle_enabled: return
	if selected_skill >= 0:
		_highlight_attack_tiles()
	else:
		_highlight_move_tiles()
	_restore_action_hint()

func _on_skill_hovered(index: int) -> void:
	if index < 0 or index >= current_skills.size() or not _active_actor_valid(): return
	var actor: Dictionary = game_state.battle_allies[selected_actor]
	var skill_name: String = current_skills[index]
	var skill: Dictionary = game_state.skill_library[skill_name]
	var level: int = game_state.hero_skills[actor.hero_index].levels.get(skill_name, 1)
	var estimated_damage: int = _skill_damage(actor, skill, level)
	var shape_text: String = str(skill.get("pattern", "单体"))
	_show_hover_info(
		"武学详情",
		skill_name,
		"%s  Lv.%d\n威力 %d    预计伤害 %d\n内力 %d    射程 %d格\n范围 %s\n%s" % [skill.school, level, skill.damage, estimated_damage, skill.cost, skill.range, shape_text, skill.description],
		load(skill.icon),
		Color("#f2c75c")
	)

func _on_ally_hovered(index: int) -> void:
	if index < 0 or index >= game_state.battle_allies.size(): return
	var actor: Dictionary = game_state.battle_allies[index]
	var action_text := "当前行动" if is_player_turn and index == selected_actor else "下次行动 %d" % actor.next_action
	_show_hover_info(
		"我方状态",
		actor.name,
		"气血 %d / %d\n内力 %d / %d\n攻击 %d    防御 %d\n身法 %d    移动 %d格\n%s" % [actor.hp, actor.max_hp, actor.mp, actor.max_mp, actor.attack, actor.defense, actor.speed, actor.move_range, action_text],
		load(actor.head),
		Color("#67b9f2")
	)
	if selected_skill >= 0 and index != selected_actor:
		_on_tile_hovered(actor.coord.y * BOARD_WIDTH + actor.coord.x)

func _on_enemy_hovered(index: int) -> void:
	if index < 0 or index >= game_state.battle_enemies.size(): return
	var enemy: Dictionary = game_state.battle_enemies[index]
	var status_text := "中毒（剩余%d次行动）" % enemy.poison_turns if enemy.poison_turns > 0 else "状态正常"
	_show_hover_info(
		"敌方状态",
		enemy.name,
		"气血 %d / %d\n攻击 %d    防御 %d\n身法 %d    移动 %d格\n下次行动 %d\n%s" % [enemy.hp, enemy.max_hp, enemy.attack, enemy.defense, enemy.speed, enemy.move_range, enemy.next_action, status_text],
		load(enemy.head),
		Color("#ee6b5f") if enemy.poison_turns <= 0 else Color("#83d46b")
	)
	if selected_skill >= 0 and _can_target(enemy.coord):
		_preview_attack_tiles(enemy.coord)

func _on_unit_exited() -> void:
	_hide_hover_info()
	if selected_skill >= 0:
		_highlight_attack_tiles()
	_restore_action_hint()

func _on_hover_info_exited() -> void:
	_hide_hover_info()
	_restore_action_hint()

func _show_hover_info(kind: String, title: String, details: String, icon: Texture2D, accent: Color) -> void:
	$HoverInfo.visible = true
	$HoverInfo/Kind.text = kind
	$HoverInfo/Kind.add_theme_color_override("font_color", accent)
	$HoverInfo/Title.text = title
	$HoverInfo/Icon.texture = icon
	$HoverInfo/Details.text = details

func _hide_hover_info() -> void:
	$HoverInfo.visible = false

func _show_operation_hint(message: String) -> void:
	$Top/Hint.text = message

func _restore_action_hint() -> void:
	if not _active_actor_valid(): return
	var actor: Dictionary = game_state.battle_allies[selected_actor]
	if selected_skill >= 0 and selected_skill < current_skills.size():
		$Top/Hint.text = "%s：选择橙红色地块释放；悬停时绿色显示本次攻击范围" % current_skills[selected_skill]
	elif actor.moved:
		$Top/Hint.text = "%s已完成移动，可撤回移动，或选择武学、物品和调息" % actor.name
	else:
		$Top/Hint.text = "%s行动中：点击蓝色地块移动，或选择武学" % actor.name

func _on_rest_pressed() -> void:
	if auto_action_running and not automation_command: return
	if not _active_actor_valid(): return
	var actor: Dictionary = game_state.battle_allies[selected_actor]
	actor.hp = mini(actor.max_hp, actor.hp + 12)
	actor.mp = mini(actor.max_mp, actor.mp + 15)
	game_state.battle_log.append("%s调息，恢复气血与内力" % actor.name)
	selected_skill = -1
	_complete_actor_action()

func _on_undo_move_pressed() -> void:
	if not _active_actor_valid() or move_actor_index != selected_actor: return
	var actor: Dictionary = game_state.battle_allies[selected_actor]
	if not actor.moved or move_origin.x < 0: return
	var origin := move_origin
	_stop_movement_tween()
	actor.coord = origin
	actor.moved = false
	selected_skill = -1
	$ItemPanel.visible = false
	game_state.battle_log.append("%s撤回本次移动" % actor.name)
	var unit_node := $Board/Allies.get_child(selected_actor) as Control
	movement_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	movement_tween.tween_property(unit_node, "position", _coord_to_board(origin), 0.18)
	move_origin = Vector2i(-1, -1)
	move_actor_index = -1
	$Top/Hint.text = "已撤回移动，可重新选择蓝色地块或武学"
	_highlight_move_tiles()
	_update_undo_button()
	_update_skill_selection_visuals()

func _on_items_pressed() -> void:
	$ItemPanel.visible = not $ItemPanel.visible
	$ItemPanel/Healing.text = "疗伤药 × %d\n恢复35气血" % game_state.inventory.count("疗伤药")
	$ItemPanel/Great.text = "大还丹 × %d\n恢复60气血、30内力" % game_state.inventory.count("大还丹")
	$ItemPanel/Healing.disabled = not game_state.inventory.has("疗伤药")
	$ItemPanel/Great.disabled = not game_state.inventory.has("大还丹")

func _use_item(item_name: String) -> void:
	if auto_action_running and not automation_command: return
	if not _active_actor_valid() or not game_state.inventory.has(item_name): return
	var actor: Dictionary = game_state.battle_allies[selected_actor]
	game_state.inventory.erase(item_name)
	if item_name == "大还丹":
		actor.hp = mini(actor.max_hp, actor.hp + 60)
		actor.mp = mini(actor.max_mp, actor.mp + 30)
	else:
		actor.hp = mini(actor.max_hp, actor.hp + 35)
	game_state.battle_log.append("%s使用%s" % [actor.name, item_name])
	$ItemPanel.visible = false
	_complete_actor_action()

func _complete_actor_action() -> void:
	if selected_actor < 0 or selected_actor >= game_state.battle_allies.size(): return
	var actor: Dictionary = game_state.battle_allies[selected_actor]
	actor.next_action = game_state.turn + actor.action_delay
	actor.moved = false
	selected_skill = -1
	_clear_range_display()
	_clear_move_undo()
	is_player_turn = false
	auto_action_running = false
	automation_command = false
	_advance_timeline()

func _on_auto_battle_toggled(enabled: bool) -> void:
	auto_battle_enabled = enabled
	game_state.settings["auto_battle"] = enabled
	_update_auto_button()
	$Top/AutoBattle.text = "自动：开" if enabled else "自动：关"
	if enabled:
		_clear_range_display()
	else:
		if selected_skill >= 0: _highlight_attack_tiles()
		else: _highlight_move_tiles()
	if enabled and _active_actor_valid() and not auto_action_running:
		call_deferred("_run_auto_turn", selected_actor)

func _update_auto_button() -> void:
	if not is_node_ready(): return
	$Top/AutoBattle.text = "自动：开" if auto_battle_enabled else "自动：关"

func _on_battle_speed_pressed() -> void:
	battle_speed = 2.0 if battle_speed == 1.0 else 1.0
	_update_speed_button()
	$Top/BattleSpeed.text = "战斗 %d倍" % int(battle_speed)
	_apply_battle_speed()

func _apply_battle_speed() -> void:
	for side in [$Board/Allies, $Board/Enemies]:
		for unit in side.get_children():
			var model := unit.get_node_or_null("Model") as AnimatedSprite2D
			if model != null: model.speed_scale = battle_speed

func _update_speed_button() -> void:
	if not is_node_ready(): return
	$Top/BattleSpeed.text = "战斗 %d倍" % int(battle_speed)

func _run_auto_turn(actor_index: int) -> void:
	if not auto_battle_enabled or not _active_actor_valid() or actor_index != selected_actor or auto_action_running: return
	auto_action_running = true
	await get_tree().create_timer(0.12 / battle_speed).timeout
	if not auto_battle_enabled or not _active_actor_valid() or actor_index != selected_actor:
		auto_action_running = false
		return
	var actor: Dictionary = game_state.battle_allies[actor_index]
	if actor.hp <= actor.max_hp * 0.4 and game_state.inventory.has("大还丹"):
		automation_command = true
		_use_item("大还丹")
		automation_command = false
		auto_action_running = false
		return
	if actor.hp <= actor.max_hp * 0.55 and game_state.inventory.has("疗伤药"):
		automation_command = true
		_use_item("疗伤药")
		automation_command = false
		auto_action_running = false
		return
	var skill_index := current_skills.find(last_used_skill_name)
	if skill_index < 0 or actor.mp < game_state.skill_library[last_used_skill_name].cost:
		skill_index = _best_auto_skill()
	if skill_index >= 0:
		# Finish the movement phase first. The weapon is selected only afterwards.
		selected_skill = -1
		_update_skill_selection_visuals()
		if not actor.moved:
			var approach := _auto_approach_tile(actor)
			if approach.x >= 0:
				automation_command = true
				_on_tile_pressed(approach.y * BOARD_WIDTH + approach.x)
				automation_command = false
				if movement_tween and movement_tween.is_valid(): await movement_tween.finished
			if not auto_battle_enabled or not _active_actor_valid() or actor_index != selected_actor:
				auto_action_running = false
				return
		# Attack phase begins after movement; restore the previous weapon when possible.
		selected_skill = -1
		_update_skill_selection_visuals()
		automation_command = true
		_select_skill(skill_index)
		automation_command = false
		var target := _best_auto_target()
		if target.x >= 0:
			await get_tree().create_timer(0.12 / battle_speed).timeout
			if auto_battle_enabled and _active_actor_valid() and actor_index == selected_actor:
				automation_command = true
				await _on_tile_pressed(target.y * BOARD_WIDTH + target.x)
				automation_command = false
			else:
				auto_action_running = false
				return
		else:
			automation_command = true
			_on_rest_pressed()
			automation_command = false
		auto_action_running = false
		return
	automation_command = true
	_on_rest_pressed()
	automation_command = false
	auto_action_running = false

func _best_auto_skill() -> int:
	var actor: Dictionary = game_state.battle_allies[selected_actor]
	var loadout: Dictionary = game_state.hero_skills[actor.hero_index]
	var best_index := -1
	var best_score := -1.0
	for i in current_skills.size():
		var skill: Dictionary = game_state.skill_library[current_skills[i]]
		if actor.mp < skill.cost: continue
		var score := float(skill.damage) / maxf(1.0, float(skill.cost))
		if skill.cost == 0: score = float(skill.damage)
		if int(loadout.levels.get(current_skills[i], 1)) > 1: score += 0.1
		if score > best_score:
			best_score = score
			best_index = i
	return best_index

func _best_auto_target() -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_score := 0
	for y in range(TILE_ROW_OFFSET, TILE_ROW_OFFSET + BOARD_HEIGHT):
		for x in BOARD_WIDTH:
			var coord := Vector2i(x, y)
			var hit_count := _affected_enemies(coord).size()
			if hit_count > best_score:
				best_score = hit_count
				best = coord
	return best

func _auto_approach_tile(actor: Dictionary) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_distance := 999
	for coord in _reachable_tiles(actor):
		var nearest := 999
		for enemy in game_state.battle_enemies:
			if enemy.alive: nearest = mini(nearest, _distance(coord, enemy.coord))
		if nearest < best_distance:
			best_distance = nearest
			best = coord
	return best

func _start_timeline() -> void:
	game_state.turn = 0
	is_player_turn = false
	_advance_timeline()

func _advance_timeline() -> void:
	if battle_finished: return
	while true:
		var next_combatant := _find_next_combatant()
		if next_combatant.is_empty(): return
		game_state.turn = int(next_combatant.time)
		if game_state.turn > 4200:
			_finish_battle(false)
			return
		if next_combatant.side == "ally":
			_clear_move_undo()
			selected_actor = int(next_combatant.index)
			var next_actor: Dictionary = game_state.battle_allies[selected_actor]
			next_actor.moved = false
			is_player_turn = true
			selected_skill = -1
			$Top/Hint.text = "时序%d：%s行动，可先移动再选择招式" % [game_state.turn, next_actor.name]
			_refresh_units()
			_refresh()
			if not auto_battle_enabled: _restore_last_skill_selection()
			if auto_battle_enabled: call_deferred("_run_auto_turn", selected_actor)
			return
		await _enemy_take_action(int(next_combatant.index))
		if battle_finished: return

func _find_next_combatant() -> Dictionary:
	var result: Dictionary = {}
	var earliest := 999999
	for i in game_state.battle_allies.size():
		var actor: Dictionary = game_state.battle_allies[i]
		if actor.alive and int(actor.next_action) < earliest:
			earliest = int(actor.next_action)
			result = {"side":"ally", "index":i, "time":earliest}
	for i in game_state.battle_enemies.size():
		var enemy: Dictionary = game_state.battle_enemies[i]
		if enemy.alive and int(enemy.next_action) < earliest:
			earliest = int(enemy.next_action)
			result = {"side":"enemy", "index":i, "time":earliest}
	return result

func _enemy_take_action(enemy_index: int) -> void:
	var enemy: Dictionary = game_state.battle_enemies[enemy_index]
	if not enemy.alive: return
	if enemy.poison_turns > 0:
		enemy.hp = maxi(0, enemy.hp - 8)
		enemy.poison_turns -= 1
		game_state.battle_log.append("%s受到8点毒素伤害" % enemy.name)
		if enemy.hp <= 0:
			enemy.alive = false
			game_state.battle_log.append("%s毒发退场" % enemy.name)
			if _all_enemies_defeated(): _finish_battle(true)
			return
	var target_index := _nearest_alive_ally(enemy.coord)
	if target_index < 0:
		_finish_battle(false)
		return
	var target: Dictionary = game_state.battle_allies[target_index]
	var enemy_node := $Board/Enemies.get_child(enemy_index) as Control
	if _distance(enemy.coord, target.coord) > 1:
		var movement_path: Array[Vector2i] = []
		for move_step in int(enemy.move_range):
			if _distance(enemy.coord, target.coord) <= 1: break
			var step := _enemy_step_toward(enemy.coord, target.coord)
			if step == enemy.coord: break
			enemy.coord = step
			movement_path.append(step)
		if not movement_path.is_empty():
			enemy_node.start_walk_animation()
			var move_tween := create_tween().set_trans(Tween.TRANS_LINEAR)
			for step in movement_path:
				move_tween.tween_property(enemy_node, "position", _coord_to_board(step), 0.3 / battle_speed)
			await move_tween.finished
			enemy_node.stop_walk_animation()
		game_state.battle_log.append("时序%d：%s向%s移动" % [game_state.turn, enemy.name, target.name])
	if _distance(enemy.coord, target.coord) <= 1:
		var target_node := $Board/Allies.get_child(target_index)
		enemy_node.face_toward(target.coord - enemy.coord)
		enemy_node.play_action("attack")
		await get_tree().create_timer(0.28 / battle_speed).timeout
		target_node.play_action("hurt")
		await enemy_node.wait_for_action("attack")
		await target_node.wait_for_action("hurt")
		var actual_damage: int = maxi(1, enemy.attack - int(target.defense / 8.0))
		target.hp = maxi(0, target.hp - actual_damage)
		game_state.battle_log.append("时序%d：%s攻击，%s受到%d点伤害" % [game_state.turn, enemy.name, target.name, actual_damage])
		if target.hp <= 0:
			target.alive = false
			game_state.battle_log.append("%s退场" % target.name)
			if _first_alive_ally() < 0:
				_finish_battle(false)
				return
	enemy.next_action = game_state.turn + enemy.action_delay
	_refresh_units()

func _finish_battle(victory: bool) -> void:
	if battle_finished: return
	_clear_move_undo()
	battle_finished = true
	game_state.battle_outcome = "胜利" if victory else "失败"
	if victory:
		game_state.money += game_state.reward_money
		game_state.inventory.append("疗伤药")
		game_state.grant_battle_experience()
		game_state.journal.append("华山论剑初战告捷，获得银两 %d。" % game_state.reward_money)
	else:
		game_state.journal.append("华山论剑初战失利，暂退江湖养精蓄锐。")
	game_state.goto("res://scenes/battle_result.tscn")

func _refresh_units() -> void:
	for i in $Board/Allies.get_child_count():
		var node := $Board/Allies.get_child(i)
		node.visible = i < game_state.battle_allies.size()
		if not node.visible: continue
		var actor: Dictionary = game_state.battle_allies[i]
		node.position = _coord_to_board(actor.coord)
		var hero_index := int(actor.get("hero_index", i))
		node.configure(str(actor.get("model", game_state.get_hero_model_path(hero_index))), false)
		node.modulate = Color.WHITE
		node.get_node("Name").text = actor.name
		node.get_node("HP").value = actor.hp
		node.get_node("HP").max_value = actor.max_hp
		node.get_node("MP").value = actor.mp
		node.get_node("MP").max_value = actor.max_mp
		node.get_node("MP").visible = true
	for i in $Board/Enemies.get_child_count():
		var node := $Board/Enemies.get_child(i)
		node.visible = i < game_state.battle_enemies.size() and game_state.battle_enemies[i].alive
		if not node.visible: continue
		var enemy: Dictionary = game_state.battle_enemies[i]
		node.position = _coord_to_board(enemy.coord)
		node.configure(str(enemy.get("model", game_state.MALE_BATTLE_MODEL)), true)
		node.get_node("Name").text = enemy.name
		node.get_node("HP").value = enemy.hp
		node.get_node("HP").max_value = enemy.max_hp
		node.get_node("MP").value = float(enemy.get("mp", 0))
		node.get_node("MP").max_value = float(enemy.get("max_mp", 1))
		node.get_node("MP").visible = enemy.has("mp")

func _refresh() -> void:
	var active_index := _first_alive_ally()
	if active_index < 0: return
	var actor: Dictionary = game_state.battle_allies[selected_actor]
	game_state.player_hp = actor.hp
	game_state.player_mp = actor.mp
	game_state.enemy_hp = 0
	for enemy in game_state.battle_enemies: game_state.enemy_hp += enemy.hp
	$Top/Time.text = "当前时序  %d/4200" % game_state.turn
	$Bottom/Portrait/Image.texture = load(actor.head)
	$Bottom/Portrait/Name.text = actor.name
	$Bottom/Portrait/HP.text = "%d/%d" % [actor.hp, actor.max_hp]
	$Bottom/Portrait/MP.text = "%d/%d" % [actor.mp, actor.max_mp]
	_refresh_timeline_preview()
	_refresh_skill_buttons()
	if selected_skill < 0:
		_highlight_move_tiles()

func _refresh_timeline_preview() -> void:
	var entries: Array[Dictionary] = []
	for i in game_state.battle_allies.size():
		var actor: Dictionary = game_state.battle_allies[i]
		if not actor.alive or is_player_turn and i == selected_actor: continue
		entries.append({"name":actor.name, "time":int(actor.next_action)})
	for enemy in game_state.battle_enemies:
		if enemy.alive: entries.append({"name":enemy.name, "time":int(enemy.next_action)})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.time < b.time)
	var preview: Array[String] = []
	for i in mini(4, entries.size()):
		preview.append("%s %d" % [entries[i].name, entries[i].time])
	$Top/ActionOrder.text = "  >  ".join(preview)

func _refresh_skill_buttons() -> void:
	if not _active_actor_valid(): return
	var actor: Dictionary = game_state.battle_allies[selected_actor]
	var loadout: Dictionary = game_state.hero_skills[actor.hero_index]
	current_skills.clear()
	for skill_name in loadout.martial: current_skills.append(str(skill_name))
	for i in $Bottom/Skills.get_child_count():
		var button := $Bottom/Skills.get_child(i)
		button.visible = i < current_skills.size()
		if not button.visible: continue
		var skill_name: String = current_skills[i]
		var skill: Dictionary = game_state.skill_library[skill_name]
		button.texture_normal = load(skill.icon)
		button.tooltip_text = "%s Lv.%d · 内力%d" % [skill_name, loadout.levels.get(skill_name, 1), skill.cost]
		button.get_node("Name").text = skill_name
	_update_skill_selection_visuals()
	_update_undo_button()

func _update_skill_selection_visuals() -> void:
	for i in $Bottom/Skills.get_child_count():
		var button := $Bottom/Skills.get_child(i)
		var is_selected: bool = i == selected_skill and button.visible
		button.get_node("Selection").visible = false
		var frame := button.get_node_or_null("IconFrame") as Control
		if frame != null: frame.visible = is_selected
		button.modulate = Color.WHITE

func _prepare_skill_button_frame(button: Control) -> void:
	var selection := button.get_node_or_null("Selection") as Panel
	if selection != null:
		selection.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		selection.position = Vector2.ZERO
		selection.size = Vector2(120, 120)
	var frame := TextureRect.new()
	frame.name = "IconFrame"
	var frame_atlas := AtlasTexture.new()
	frame_atlas.atlas = load("res://assets/UI/skill_bg.png")
	frame_atlas.region = Rect2(1, 4, 89, 90)
	frame.texture = frame_atlas
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.position = Vector2(0, 14)
	frame.size = Vector2(120, 120)
	frame.z_index = 10
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.visible = false
	button.add_child(frame)
	button.move_child(frame, 0)

func _update_undo_button() -> void:
	var enabled: bool = _active_actor_valid() and move_actor_index == selected_actor and bool(game_state.battle_allies[selected_actor].moved)
	$UndoMove.disabled = not enabled
	$UndoMove.modulate = Color.WHITE if enabled else Color(1, 1, 1, 0.45)

func _stop_movement_tween() -> void:
	if movement_tween and movement_tween.is_valid():
		movement_tween.kill()
	movement_tween = null

func _clear_move_undo() -> void:
	_stop_movement_tween()
	move_origin = Vector2i(-1, -1)
	move_actor_index = -1
	if is_node_ready():
		_update_undo_button()

func _highlight_move_tiles() -> void:
	if auto_battle_enabled or not _active_actor_valid():
		_clear_range_display()
		$Top/Hint.text = "自动战斗：正在行动"
		return
	var actor: Dictionary = game_state.battle_allies[selected_actor]
	var reachable := _reachable_tiles(actor)
	for i in $Board/Tiles.get_child_count():
		var coord := _board_coord_from_index(i)
		var valid: bool = not actor.moved and reachable.has(coord)
		var tile := $Board/Tiles.get_child(i) as TextureButton
		_set_range_tile(tile, move_range_style if valid else range_clear_style, Color.WHITE if valid else Color(1, 1, 1, 0))

func _reachable_tiles(actor: Dictionary) -> Array[Vector2i]:
	var reachable: Array[Vector2i] = []
	if actor.moved: return reachable
	var distances := {actor.coord: 0}
	var frontier: Array[Vector2i] = [actor.coord]
	var directions: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		var distance: int = distances[current]
		if distance >= actor.move_range: continue
		for direction in directions:
			var next := current + direction
			if not _is_inside_board(next) or distances.has(next): continue
			if _unit_at(next) != null: continue
			distances[next] = distance + 1
			frontier.append(next)
			reachable.append(next)
	return reachable

func _highlight_attack_tiles() -> void:
	if auto_battle_enabled or not _active_actor_valid():
		_clear_range_display()
		$Top/Hint.text = "自动战斗：正在行动"
		return
	var actor: Dictionary = game_state.battle_allies[selected_actor]
	var potential_attack_coords := _all_potential_attack_coords()
	for i in $Board/Tiles.get_child_count():
		var coord := _board_coord_from_index(i)
		var tile := $Board/Tiles.get_child(i) as TextureButton
		if coord == actor.coord:
			_set_range_tile(tile, range_clear_style, Color(1, 1, 1, 0))
		elif _can_target(coord):
			_set_range_tile(tile, range_preview_style, Color.WHITE)
		elif potential_attack_coords.has(coord):
			_set_range_tile(tile, range_context_style, Color(0.78, 0.78, 0.78, 0.82))
		else:
			_set_range_tile(tile, range_clear_style, Color(1, 1, 1, 0))

func _preview_attack_tiles(target: Vector2i) -> void:
	if auto_battle_enabled or not _active_actor_valid():
		_clear_range_display()
		return
	_highlight_attack_tiles()
	for coord in _affected_coords(target):
		var index := (coord.y - TILE_ROW_OFFSET) * BOARD_WIDTH + coord.x
		if index >= 0 and index < $Board/Tiles.get_child_count():
			var tile := $Board/Tiles.get_child(index) as TextureButton
			_set_range_tile(tile, range_valid_style, Color.WHITE)

func _clear_range_display() -> void:
	if not is_node_ready(): return
	for tile in $Board/Tiles.get_children():
		_set_range_tile(tile as TextureButton, range_clear_style, Color(1, 1, 1, 0))

func _all_potential_attack_coords() -> Array[Vector2i]:
	var potential: Array[Vector2i] = []
	for y in range(TILE_ROW_OFFSET, TILE_ROW_OFFSET + BOARD_HEIGHT):
		for x in BOARD_WIDTH:
			var target := Vector2i(x, y)
			if not _can_target(target): continue
			for coord in _affected_coords(target):
				if coord != game_state.battle_allies[selected_actor].coord and not potential.has(coord): potential.append(coord)
	return potential

func _can_target(coord: Vector2i) -> bool:
	if not _is_inside_board(coord): return false
	var actor: Dictionary = game_state.battle_allies[selected_actor]
	var delta: Vector2i = coord - actor.coord
	if delta == Vector2i.ZERO: return false
	var skill: Dictionary = game_state.skill_library[current_skills[selected_skill]]
	if skill.school == "剑系" or skill.shape == "fan":
		return _distance(actor.coord, coord) == 1
	if skill.shape == "line":
		return (delta.x == 0 or delta.y == 0) and _distance(actor.coord, coord) <= skill.range
	return _distance(actor.coord, coord) <= skill.range

func _affected_enemies(target: Vector2i) -> Array[int]:
	var affected: Array[int] = []
	if not _can_target(target): return affected
	var affected_coords := _affected_coords(target)
	for i in game_state.battle_enemies.size():
		var enemy: Dictionary = game_state.battle_enemies[i]
		if enemy.alive and affected_coords.has(enemy.coord): affected.append(i)
	return affected

func _affected_coords(target: Vector2i) -> Array[Vector2i]:
	var affected: Array[Vector2i] = []
	if not _can_target(target): return affected
	var actor: Dictionary = game_state.battle_allies[selected_actor]
	var skill: Dictionary = game_state.skill_library[current_skills[selected_skill]]
	var direction := Vector2i(signi(target.x - actor.coord.x), signi(target.y - actor.coord.y))
	for y in range(TILE_ROW_OFFSET, TILE_ROW_OFFSET + BOARD_HEIGHT):
		for x in BOARD_WIDTH:
			var coord := Vector2i(x, y)
			var include := false
			if skill.shape == "line":
				var offset: Vector2i = coord - actor.coord
				include = (direction.x != 0 and offset.y == 0 and signi(offset.x) == direction.x) or (direction.y != 0 and offset.x == 0 and signi(offset.y) == direction.y)
				include = include and _distance(actor.coord, coord) <= skill.range
			elif skill.shape == "fan":
				var offset: Vector2i = coord - actor.coord
				var depth: int = offset.x * direction.x + offset.y * direction.y
				var width: int = offset.x * direction.y - offset.y * direction.x
				include = depth >= 1 and depth <= 2 and absi(width) <= 1
			elif skill.shape == "cross":
				include = coord == target or ((coord.x == target.x or coord.y == target.y) and _distance(coord, target) <= 2)
			else:
				include = coord == target
			if include: affected.append(coord)
	return affected

func _skill_multiplier(level: int) -> float:
	return 1.0 + float(maxi(0, level - 1)) * 0.1

func _skill_damage(actor: Dictionary, skill: Dictionary, level: int) -> int:
	var technique: int = actor.sword if skill.school == "剑系" else actor.fist if skill.school == "拳掌" else actor.unorthodox if skill.school == "奇门" else actor.blade
	return int(round(float(skill.damage) * _skill_multiplier(level))) + int(actor.attack / 8.0) + int(technique / 20.0)

func _active_actor_valid() -> bool:
	return is_player_turn and not player_action_resolving and selected_actor >= 0 and selected_actor < game_state.battle_allies.size() and game_state.battle_allies[selected_actor].alive

func _enemy_at_any() -> int:
	for i in game_state.battle_enemies.size():
		if game_state.battle_enemies[i].alive: return i
	return -1

func _enemy_at(coord: Vector2i) -> int:
	for i in game_state.battle_enemies.size():
		var enemy: Dictionary = game_state.battle_enemies[i]
		if enemy.alive and enemy.coord == coord: return i
	return -1

func _unit_at(coord: Vector2i) -> Variant:
	for ally in game_state.battle_allies:
		if ally.alive and ally.coord == coord: return ally
	for enemy in game_state.battle_enemies:
		if enemy.alive and enemy.coord == coord: return enemy
	return null

func _first_alive_ally() -> int:
	for i in game_state.battle_allies.size():
		if game_state.battle_allies[i].alive: return i
	return -1

func _nearest_alive_ally(from: Vector2i) -> int:
	var nearest := -1
	var nearest_distance := 999
	for i in game_state.battle_allies.size():
		var ally: Dictionary = game_state.battle_allies[i]
		if not ally.alive: continue
		var distance := _distance(from, ally.coord)
		if distance < nearest_distance:
			nearest = i
			nearest_distance = distance
	return nearest

func _enemy_step_toward(from: Vector2i, target: Vector2i) -> Vector2i:
	var candidates := [from + Vector2i(signi(target.x - from.x), 0), from + Vector2i(0, signi(target.y - from.y))]
	for candidate in candidates:
		if not _is_inside_board(candidate): continue
		if _unit_at(candidate) == null: return candidate
	return from

func _is_inside_board(coord: Vector2i) -> bool:
	return coord.x >= 0 and coord.x < BOARD_WIDTH and coord.y >= TILE_ROW_OFFSET and coord.y < TILE_ROW_OFFSET + BOARD_HEIGHT

func _all_enemies_defeated() -> bool:
	for enemy in game_state.battle_enemies:
		if enemy.alive: return false
	return true

func _coord_from_index(index: int) -> Vector2i:
	return Vector2i(index % BOARD_WIDTH, floori(float(index) / BOARD_WIDTH))

func _board_coord_from_index(index: int) -> Vector2i:
	return _coord_from_index(index) + Vector2i(0, TILE_ROW_OFFSET)

func _coord_to_board(coord: Vector2i) -> Vector2:
	var tile_center := BOARD_ORIGIN + Vector2(coord) * TILE_STEP + TILE_SIZE * 0.5
	return tile_center - UNIT_FOOT_ANCHOR

func _distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

func _on_result_continue_pressed() -> void:
	game_state.goto("res://scenes/world_map.tscn")
