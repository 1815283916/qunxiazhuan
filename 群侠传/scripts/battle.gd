extends Control

@onready var game_state := get_node("/root/GameState")

const Rules = preload("res://scripts/combat_rules.gd")

const BOARD_WIDTH := 16
const BOARD_HEIGHT := 7
const TILE_ROW_OFFSET := 2
const TILE_SIZE := Vector2(121, 93)
const TILE_STEP := TILE_SIZE + Vector2(3, 3)
const UNIT_FOOT_ANCHOR := Vector2(45, 31)
const UNIT_STANCE_IN_TILE := Vector2(TILE_SIZE.x * 0.5, 74.0)
const ATTACK_RANGE_COLOR := Color(0.08, 0.68, 0.18, 0.54)
const ATTACK_RANGE_BORDER := Color(0.24, 1.0, 0.35, 0.96)
const ATTACK_CONTEXT_COLOR := Color(0.22, 0.24, 0.27, 0.68)
const ATTACK_CONTEXT_BORDER := Color(0.66, 0.69, 0.73, 0.92)
const ATTACK_PREVIEW_COLOR := Color(0.94, 0.2, 0.06, 0.42)
const ATTACK_PREVIEW_BORDER := Color(1.0, 0.78, 0.16, 1.0)
const MOVE_RANGE_COLOR := Color(0.08, 0.68, 0.18, 0.56)
const MOVE_RANGE_BORDER := Color(0.32, 1.0, 0.42, 1.0)
const HOVER_INFO_DEFAULT_POSITION := Vector2(1165, 88)

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
var hover_hide_revision := 0
var hovered_unit: Control
var hovered_move_tile: TextureButton
var skill_effect_frames_cache: Dictionary = {}

func _ready() -> void:
	preload("res://scripts/top_bar.gd").apply($Top, "battle")
	if game_state.battle_allies.is_empty(): game_state.new_battle()
	if game_state.story_data.encounters.has(game_state.current_encounter):
		$Background.texture = load(game_state.story_data.encounters[game_state.current_encounter].background)
	while $Board/Enemies.get_child_count() < game_state.battle_enemies.size():
		var unit := preload("res://scenes/battle_unit.tscn").instantiate()
		$Board/Enemies.add_child(unit)
	auto_battle_enabled = bool(game_state.settings.get("auto_battle", false))
	battle_speed = float(game_state.settings.get("battle_speed", 1.0))
	if battle_speed != 2.0: battle_speed = 1.0
	$Top/AutoBattle.button_pressed = auto_battle_enabled
	_update_auto_button()
	$Top/AutoBattle.text = "自动：开" if auto_battle_enabled else "自动：关"
	_update_speed_button()
	$Top/AutoBattle.toggled.connect(_on_auto_battle_toggled)
	$Top/BattleSpeed.pressed.connect(_on_battle_speed_pressed)
	$Top/Surrender.pressed.connect(_on_surrender_pressed)
	$Top/RestartBattle.pressed.connect(_on_restart_battle_pressed)
	$Bottom/Portrait.pressed.connect(_open_unit_overview)
	$HoverInfo.mouse_filter = Control.MOUSE_FILTER_STOP
	$HoverInfo.mouse_entered.connect(_on_hover_info_entered)
	$HoverInfo.mouse_exited.connect(_on_hover_info_exited)
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
	var tiles := $Board/Tiles as GridContainer
	tiles.columns = BOARD_WIDTH
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
	var hover_cell := Rect2(UNIT_FOOT_ANCHOR - UNIT_STANCE_IN_TILE, TILE_SIZE)
	for side in [$Board/Allies, $Board/Enemies]:
		for unit in side.get_children():
			unit.set_hover_cell(hover_cell)

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
	$Top/Hint.text = "%s行动中：可移动到绿色地块，或选择武学" % actor.name
	_highlight_move_tiles()
	_refresh_units()
	_refresh_skill_buttons()

func _skill_name(index: int) -> String:
	return current_skills[index]

func _select_skill(index: int) -> void:
	if auto_action_running and not automation_command: return
	if not _active_actor_valid(): return
	if index < 0 or index >= current_skills.size(): return
	var actor: Dictionary = game_state.battle_allies[selected_actor]
	var skill_name := _skill_name(index)
	var skill: Dictionary = game_state.skill_library[skill_name]
	if not Rules.can_use(actor, skill_name, skill):
		$Top/Hint.text = "当前无法施展：请查看冷却、内力或连击限制"
		return
	if selected_skill == index:
		selected_skill = -1
		$Top/Hint.text = "已取消武学，点击绿色地块移动或重新选择招式"
		_highlight_move_tiles()
		_update_skill_selection_visuals()
		return
	selected_skill = index
	$ItemPanel.visible = false
	if auto_battle_enabled: $Top/Hint.text = "自动战斗：正在行动"
	_show_cast_hint(skill_name)
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
			$Top/Hint.text = "该地块不可到达，请选择绿色地块"
		return
	if not _can_target(coord):
		_show_cast_hint(_skill_name(selected_skill))
		return
	var skill_name := _skill_name(selected_skill)
	var skill: Dictionary = game_state.skill_library[skill_name]
	if not Rules.can_use(actor, skill_name, skill): return
	var affected := _targets_in_area(actor, skill, coord, game_state.battle_enemies)
	player_action_resolving = true
	_clear_range_display()
	var loadout: Dictionary = game_state.hero_skills[actor.hero_index]
	var dealt_damage := await _cast_martial(actor, skill_name, coord, affected)
	selected_skill = -1
	_clear_move_undo()
	var leveling_actor_node := $Board/Allies.get_child(selected_actor) as Control
	var gains_experience: bool = actor.alive and not affected.is_empty()
	var hero_levels_gained: int = game_state.gain_hero_experience(actor.hero_index, 8) if gains_experience else 0
	if hero_levels_gained > 0:
		_show_unit_float(leveling_actor_node, "人物升级 Lv.%d" % game_state.heroes[actor.hero_index].level, Color("#70e06d"))
	var skill_experience := _skill_experience_reward(actor)
	var martial_levels_gained: int = game_state.gain_skill_experience(actor.hero_index, skill_name, skill_experience) if gains_experience else 0
	if martial_levels_gained > 0:
		_show_unit_float(leveling_actor_node, "武学升级 %s Lv.%d" % [skill_name, loadout.levels[skill_name]], Color("#70e06d"))
	var internal_name: String = str(loadout.internal)
	var internal_levels_gained: int = game_state.gain_skill_experience(actor.hero_index, internal_name, maxi(1, int(game_state.growth.battle_internal_exp) * int(actor.insight))) if gains_experience else 0
	if internal_levels_gained > 0:
		_show_unit_float(leveling_actor_node, "心法升级 %s Lv.%d" % [internal_name, loadout.levels[internal_name]], Color("#70e06d"))
	if actor.alive: _sync_actor_growth(actor)
	_refresh_units()
	player_action_resolving = false
	if not _check_defeated(): _complete_actor_action(dealt_damage)

func _unit_skill_level(actor: Dictionary, skill_name: String) -> int:
	if actor.has("hero_index"):
		return int(game_state.hero_skills[actor.hero_index].levels.get(skill_name, 1))
	return 1

func _unit_control(actor: Dictionary) -> Control:
	if actor.has("hero_index"):
		return $Board/Allies.get_child(game_state.battle_allies.find(actor))
	return $Board/Enemies.get_child(game_state.battle_enemies.find(actor))

func _cast_martial(actor: Dictionary, name: String, coord: Vector2i, targets: Array[Dictionary]) -> bool:
	var skill: Dictionary = game_state.skill_library[name]
	var node := _unit_control(actor)
	node.face_toward(coord - actor.coord)
	node.play_action("attack")
	Rules.spend(actor, name, skill)
	var damage := _skill_damage(actor, skill, _unit_skill_level(actor, name))
	var focused := Rules.focused(actor)
	Rules.consume_focus(actor)
	_play_skill_effects(skill, _hit_coords(actor, skill, coord))
	_apply_skill_effects(actor, skill, "self")
	get_node("/root/AudioManager").play_effect("attack")
	game_state.battle_log.append("%s施展%s%s" % [actor.name, name, "（空放）" if targets.is_empty() else ""])
	await node.wait_for_action("attack")
	var dealt_damage := false
	for target in targets:
		if not actor.alive: break
		var target_node := _unit_control(target)
		var hostile := actor.has("hero_index") != target.has("hero_index")
		var lost := Rules.strike(actor, target, damage, focused, hostile, game_state.battle_log)
		if lost <= 0: continue
		dealt_damage = true
		target_node.play_action("hurt")
		_show_unit_float(target_node, "-%d" % lost, Color("#f5f3ed"))
		if target.alive:
			_apply_skill_effects(target, skill, "hit")
			var poison_chance := _poison_chance(actor, target)
			if poison_chance > 0 and randf() * 100.0 < poison_chance:
				_apply_status(target, "poison", 1, 3)
		else:
			game_state.battle_log.append("%s退场" % target.name)
		_refresh_unit_status(target_node, target)
	if dealt_damage: _apply_skill_effects(actor, skill, "self_on_hit")
	return dealt_damage

func _apply_skill_effects(unit: Dictionary, skill: Dictionary, phase: String) -> void:
	for effect in skill.get("effects", []):
		if effect[0] == phase: _apply_status(unit, effect[1], effect[2], effect[3])

func _apply_status(unit: Dictionary, id: String, stacks: int, duration: int) -> void:
	if Rules.apply(unit, id, stacks, duration, game_state.turn):
		game_state.battle_log.append("%s获得%s" % [unit.name, Rules.status_label(Rules.LABELS[id], Rules.layers(unit, id), unit.statuses[id].duration)])
	else:
		game_state.battle_log.append("%s免疫%s" % [unit.name, Rules.LABELS[id]])

func _check_defeated() -> bool:
	if _first_alive_ally() < 0:
		_finish_battle(false)
		return true
	if _all_enemies_defeated():
		_finish_battle(true)
		return true
	return false

func _on_board_tile_pressed(index: int) -> void:
	_on_tile_pressed(_board_coord_from_index(index).y * BOARD_WIDTH + _board_coord_from_index(index).x)

func _on_surrender_pressed() -> void:
	if battle_finished or player_action_resolving or not is_player_turn: return
	_clear_range_display()
	_finish_battle(false)

func _on_restart_battle_pressed() -> void:
	if battle_finished or player_action_resolving or not is_player_turn: return
	battle_finished = true
	_clear_move_undo()
	game_state.new_battle()
	get_tree().reload_current_scene()

func _on_enemy_pressed(enemy_index: int) -> void:
	if enemy_index >= game_state.battle_enemies.size(): return
	var enemy: Dictionary = game_state.battle_enemies[enemy_index]
	if not enemy.alive: return
	var unit_node := $Board/Enemies.get_child(enemy_index) as Control
	var target := _unit_click_coord(unit_node, enemy.coord)
	await _on_tile_pressed(target.y * BOARD_WIDTH + target.x)

func _on_ally_pressed(ally_index: int) -> void:
	if ally_index < 0 or ally_index >= game_state.battle_allies.size(): return
	var ally: Dictionary = game_state.battle_allies[ally_index]
	if not ally.alive: return
	var unit_node := $Board/Allies.get_child(ally_index) as Control
	var target := _unit_click_coord(unit_node, ally.coord)
	if target != ally.coord:
		await _on_tile_pressed(target.y * BOARD_WIDTH + target.x)
		return
	if selected_skill >= 0:
		await _on_tile_pressed(ally.coord.y * BOARD_WIDTH + ally.coord.x)
		return
	_select_actor(ally_index)

func _unit_click_coord(unit_node: Control, fallback: Vector2i, pointer := Vector2(INF, INF)) -> Vector2i:
	if unit_node == null: return fallback
	if is_inf(pointer.x) or is_inf(pointer.y):
		if not unit_node.is_hovered(): return fallback
		pointer = get_global_mouse_position()
	var coord := _board_coord_at_global_point(pointer)
	return coord if coord.x >= 0 else fallback

func _board_coord_at_global_point(point: Vector2) -> Vector2i:
	for i in $Board/Tiles.get_child_count():
		var tile := $Board/Tiles.get_child(i) as Control
		if tile.visible and tile.get_global_rect().has_point(point):
			return _board_coord_from_index(i)
	return Vector2i(-1, -1)

func _on_tile_hovered(index: int) -> void:
	range_hover_revision += 1
	if auto_battle_enabled or not _active_actor_valid():
		_clear_range_display()
		return
	var target := _coord_from_index(index)
	if selected_skill >= 0:
		if not _can_target(target):
			_highlight_attack_tiles()
			$Top/Hint.text = "该地块超出武学范围"
			return
		_preview_attack_tiles(target)
		var skill: Dictionary = game_state.skill_library[_skill_name(selected_skill)]
		var affected_count := _affected_enemies(target).size()
		if affected_count == 0:
			$Top/Hint.text = "%s：范围内没有敌人，可点击空放" % _skill_name(selected_skill)
			return
		$Top/Hint.text = "%s：基础伤害%d，预计影响%d名敌人；点击施放" % [_skill_name(selected_skill), skill.damage, affected_count]
		return
	if hovered_move_tile != null:
		_set_range_tile(hovered_move_tile, move_range_style, Color.WHITE)
		hovered_move_tile = null
	var actor: Dictionary = game_state.battle_allies[selected_actor]
	if actor.moved:
		$Top/Hint.text = "%s本回合已经移动，可选择武学、物品或调息" % actor.name
	elif _reachable_tiles(actor).has(target):
		var visual_index := (target.y - TILE_ROW_OFFSET) * BOARD_WIDTH + target.x
		if visual_index >= 0 and visual_index < $Board/Tiles.get_child_count():
			hovered_move_tile = $Board/Tiles.get_child(visual_index) as TextureButton
			_set_range_tile(hovered_move_tile, move_hover_style, Color("#d9e86f"))
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
	call_deferred("_refresh_hovered_range", range_hover_revision)

func _refresh_hovered_range(revision: int) -> void:
	if revision != range_hover_revision or auto_battle_enabled: return
	if selected_skill >= 0 and hovered_unit != null: return
	var mouse_position := get_global_mouse_position()
	for i in $Board/Tiles.get_child_count():
		var tile := $Board/Tiles.get_child(i) as Control
		if tile.visible and tile.get_global_rect().has_point(mouse_position):
			_on_board_tile_hovered(i)
			return
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
	var loadout: Dictionary = game_state.hero_skills[actor.hero_index]
	var experience: int = int(loadout.exp.get(skill_name, 0))
	var experience_needed: int = game_state.get_skill_experience_needed(level)
	var details: Array[String] = [
		"类别：%s" % skill.school,
		"经验：%d / %d" % [experience, experience_needed],
		"威力：%d" % skill.damage,
		"消耗内力：%d" % skill.cost,
		"施展范围：%d" % skill.range,
		"攻击范围：%s" % Rules.hit_text(skill),
	]
	if skill.effects.is_empty():
		if not skill.description.is_empty(): details.append(skill.description)
	else:
		for effect in skill.effects:
			details.append(Rules.highlight_status(Rules.martial_effect_label(effect)))
	var skill_button := $Bottom/Skills.get_child(index) as Control
	_show_hover_info("%s\n%d级" % [skill_name, level], "\n".join(details), load(skill.icon))
	_position_hover_info_over_skill(skill_button)

func _on_ally_hovered(index: int) -> void:
	if index < 0 or index >= game_state.battle_allies.size(): return
	var actor: Dictionary = game_state.battle_allies[index]
	_show_unit_hover(actor, is_player_turn and index == selected_actor)
	if selected_skill >= 0:
		var target := _unit_click_coord($Board/Allies.get_child(index), actor.coord)
		_on_tile_hovered(target.y * BOARD_WIDTH + target.x)

func _on_enemy_hovered(index: int) -> void:
	if index < 0 or index >= game_state.battle_enemies.size(): return
	var enemy: Dictionary = game_state.battle_enemies[index]
	_show_unit_hover(enemy, false)
	if selected_skill >= 0:
		var target := _unit_click_coord($Board/Enemies.get_child(index), enemy.coord)
		_on_tile_hovered(target.y * BOARD_WIDTH + target.x)
		if _active_actor_valid() and not auto_battle_enabled and _affected_enemies(target).has(index):
			var actor: Dictionary = game_state.battle_allies[selected_actor]
			var skill_name := _skill_name(selected_skill)
			var skill: Dictionary = game_state.skill_library[skill_name]
			var level: int = game_state.hero_skills[actor.hero_index].levels.get(skill_name, 1)
			var impact := Rules.impact(actor, enemy, _skill_damage(actor, skill, level), false, skill.cost)
			$Top/Hint.text = "命中 %.0f%% · 非暴击气血 −%d" % [Rules.hit_chance(enemy, Rules.focused(actor)), impact.hp]
			if impact.mp > 0: $Top/Hint.text += " · 抵挡耗内 %d" % impact.mp
			if impact.reflect > 0: $Top/Hint.text += " · 反伤 %d" % impact.reflect

func _show_unit_hover(unit: Dictionary, acting: bool) -> void:
	var status := Rules.status_text(unit, "\n")
	var timing := "当前 %d" % game_state.turn if acting else "下次行动 %d" % unit.next_action
	var details := "气血 %d / %d    内力 %d / %d\n时序 %s\n%s" % [unit.hp, unit.max_hp, unit.mp, unit.max_mp, timing, Rules.highlight_status(status) if not status.is_empty() else "状态正常"]
	_show_hover_info(unit.name, details)
	hovered_unit = _unit_control(unit)
	_position_unit_hover()

func _process(_delta: float) -> void:
	if hovered_unit != null: _position_unit_hover()

func _position_unit_hover() -> void:
	if not hovered_unit.is_visible_in_tree():
		_hide_hover_info()
		return
	var anchor: Vector2 = hovered_unit.get_global_transform() * UNIT_FOOT_ANCHOR
	var panel := $HoverInfo as Control
	var viewport_size := get_viewport_rect().size
	var x := anchor.x + 64.0
	if x + panel.size.x > viewport_size.x - 8.0:
		x = anchor.x - panel.size.x - 64.0
	panel.global_position = Vector2(clampf(x, 8.0, viewport_size.x - panel.size.x - 8.0), clampf(anchor.y - 112.0, 88.0, maxf(88.0, viewport_size.y - panel.size.y - 8.0)))

func _open_unit_overview() -> void:
	if battle_finished: return
	_hide_hover_info()
	$UnitOverview.open(selected_actor, is_player_turn)

func _on_unit_exited() -> void:
	_hide_hover_info()
	range_hover_revision += 1
	call_deferred("_refresh_hovered_range", range_hover_revision)

func _on_hover_info_exited() -> void:
	hover_hide_revision += 1
	var revision := hover_hide_revision
	_hide_hover_info_after_delay(revision)

func _on_hover_info_entered() -> void:
	hover_hide_revision += 1

func _hide_hover_info_after_delay(revision: int) -> void:
	await get_tree().create_timer(0.12).timeout
	if revision != hover_hide_revision: return
	var pointer := get_global_mouse_position()
	if $HoverInfo.get_global_rect().has_point(pointer): return
	_hide_hover_info()
	_restore_action_hint()

func _show_hover_info(title: String, details: String, icon: Texture2D = null) -> void:
	hovered_unit = null
	hover_hide_revision += 1
	$HoverInfo.position = HOVER_INFO_DEFAULT_POSITION
	var unit_hover := icon == null
	var panel_width := 405.0 if unit_hover else 480.0
	$HoverInfo.size.x = panel_width
	$HoverInfo/Rule.offset_right = panel_width - 18.0
	$HoverInfo.mouse_filter = Control.MOUSE_FILTER_IGNORE if unit_hover else Control.MOUSE_FILTER_STOP
	$HoverInfo/Kind.visible = not unit_hover
	$HoverInfo/Title.text = title
	$HoverInfo/Title.visible = unit_hover
	$HoverInfo/Icon.texture = icon
	$HoverInfo/Icon.visible = not unit_hover
	$HoverInfo/SkillCaption.text = title
	$HoverInfo/SkillCaption.visible = not unit_hover
	var content := $HoverInfo/Details as RichTextLabel
	content.offset_left = 20.0 if unit_hover else 164.0
	content.offset_right = panel_width - 18.0
	content.text = details
	$HoverInfo.size.y = maxf(142.0 if unit_hover else 260.0, 78.0 + content.get_content_height())
	$HoverInfo.show()

func _position_hover_info_over_skill(skill_button: Control) -> void:
	var button_rect := skill_button.get_global_rect()
	var panel_size: Vector2 = $HoverInfo.size
	var viewport_size := get_viewport_rect().size
	var x := clampf(button_rect.get_center().x - panel_size.x * 0.5, 8.0, viewport_size.x - panel_size.x - 8.0)
	var y := maxf(8.0, button_rect.position.y - panel_size.y - 8.0)
	$HoverInfo.position = Vector2(x, y)
	hover_hide_revision += 1

func _hide_hover_info() -> void:
	hovered_unit = null
	$HoverInfo.visible = false

func _show_operation_hint(message: String) -> void:
	$Top/Hint.text = message

func _restore_action_hint() -> void:
	if not _active_actor_valid(): return
	var actor: Dictionary = game_state.battle_allies[selected_actor]
	if selected_skill >= 0 and selected_skill < current_skills.size():
		_show_cast_hint(_skill_name(selected_skill))
	elif actor.moved:
		$Top/Hint.text = "%s已完成移动，可撤回移动，或选择武学、物品和调息" % actor.name
	else:
		$Top/Hint.text = "%s行动中：点击绿色地块移动，或选择武学" % actor.name

func _show_cast_hint(skill_name: String) -> void:
	var skill: Dictionary = game_state.skill_library[skill_name]
	var hint := "%s · 绿色格为命中范围" % Rules.cast_text(skill)
	$Top/Hint.text = "%s：%s" % [skill_name, hint]

func _on_rest_pressed() -> void:
	if auto_action_running and not automation_command: return
	if not _active_actor_valid(): return
	var actor: Dictionary = game_state.battle_allies[selected_actor]
	var old_hp: int = actor.hp
	var old_mp: int = actor.mp
	if actor.get("bonus_attack", false):
		_complete_actor_action()
		return
	Rules.restore(actor, 12, 15)
	var actor_node := $Board/Allies.get_child(selected_actor) as Control
	_refresh_unit_status(actor_node, actor)
	if actor.hp > old_hp: _show_unit_float(actor_node, "气血 +%d" % (actor.hp - old_hp), Color("#70e06d"))
	if actor.mp > old_mp: _show_unit_float(actor_node, "内力 +%d" % (actor.mp - old_mp), Color("#65aaff"))
	get_node("/root/AudioManager").play_effect("heal")
	game_state.battle_log.append("%s调息，恢复气血与内力" % actor.name)
	selected_skill = -1
	_complete_actor_action()

func _on_undo_move_pressed() -> void:
	if auto_action_running or not _active_actor_valid() or move_actor_index != selected_actor: return
	var actor: Dictionary = game_state.battle_allies[selected_actor]
	if not actor.moved or move_origin.x < 0: return
	var origin := move_origin
	_stop_movement_tween()
	actor.coord = origin
	actor.moved = false
	selected_skill = -1
	$ItemPanel.visible = false
	var unit_node := $Board/Allies.get_child(selected_actor) as Control
	movement_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	movement_tween.tween_property(unit_node, "position", _coord_to_board(origin), 0.18)
	move_origin = Vector2i(-1, -1)
	move_actor_index = -1
	$Top/Hint.text = "已撤回移动，可重新选择绿色地块或武学"
	_highlight_move_tiles()
	_update_undo_button()
	_update_skill_selection_visuals()

func _on_items_pressed() -> void:
	if not _active_actor_valid() or game_state.battle_allies[selected_actor].get("bonus_attack", false): return
	$ItemPanel.visible = not $ItemPanel.visible
	$ItemPanel/Healing.text = _medicine_text("疗伤药")
	$ItemPanel/Great.text = _medicine_text("大还丹")
	$ItemPanel/Healing.disabled = not game_state.inventory.has("疗伤药")
	$ItemPanel/Great.disabled = not game_state.inventory.has("大还丹")

func _use_item(item_name: String) -> void:
	if auto_action_running and not automation_command: return
	if not _active_actor_valid() or not game_state.inventory.has(item_name): return
	var medicine: Dictionary = game_state.item_library.get(item_name, {})
	if medicine.get("kind", "") != "药品": return
	var actor: Dictionary = game_state.battle_allies[selected_actor]
	var old_hp: int = actor.hp
	var old_mp: int = actor.mp
	if actor.get("bonus_attack", false): return
	game_state.inventory.erase(item_name)
	get_node("/root/AudioManager").play_effect("heal")
	Rules.restore(actor, int(medicine.heal_hp), int(medicine.heal_mp))
	var actor_node := $Board/Allies.get_child(selected_actor) as Control
	_refresh_unit_status(actor_node, actor)
	if actor.hp > old_hp: _show_unit_float(actor_node, "气血 +%d" % (actor.hp - old_hp), Color("#70e06d"))
	if actor.mp > old_mp: _show_unit_float(actor_node, "内力 +%d" % (actor.mp - old_mp), Color("#65aaff"))
	game_state.battle_log.append("%s使用%s" % [actor.name, item_name])
	$ItemPanel.visible = false
	_complete_actor_action()

func _complete_actor_action(dealt_damage: bool = false) -> void:
	if selected_actor < 0 or selected_actor >= game_state.battle_allies.size(): return
	var actor: Dictionary = game_state.battle_allies[selected_actor]
	if actor.alive and dealt_damage and not actor.get("bonus_attack", false) \
		and randf() * 100.0 < Rules.scaled(actor, "combo", 30, 5):
		actor.bonus_attack = true
		selected_skill = -1
		_clear_move_undo()
		$ItemPanel.hide()
		auto_action_running = false
		game_state.battle_log.append("%s触发连击，可追加一次攻击" % actor.name)
		$Top/Hint.text = "连击：可追加一次攻击，或选择结束连击"
		_refresh()
		if auto_battle_enabled: call_deferred("_run_auto_turn", selected_actor)
		return
	Rules.finish(actor, game_state.turn)
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
	game_state.set_setting("auto_battle", enabled)
	_update_auto_button()
	$Top/AutoBattle.text = "自动：开" if enabled else "自动：关"
	if enabled:
		_clear_range_display()
	else:
		if selected_skill >= 0: _highlight_attack_tiles()
		else: _highlight_move_tiles()
	if enabled and _active_actor_valid() and not auto_action_running:
		call_deferred("_run_auto_turn", selected_actor)
	_update_undo_button()

func _update_auto_button() -> void:
	if not is_node_ready(): return
	$Top/AutoBattle.text = "自动：开" if auto_battle_enabled else "自动：关"

func _on_battle_speed_pressed() -> void:
	battle_speed = 2.0 if battle_speed == 1.0 else 1.0
	game_state.set_setting("battle_speed", battle_speed)
	_update_speed_button()
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
	_update_undo_button()
	await get_tree().create_timer(0.12 / battle_speed, false).timeout
	if not auto_battle_enabled or not _active_actor_valid() or actor_index != selected_actor:
		auto_action_running = false
		_update_undo_button()
		return
	var actor: Dictionary = game_state.battle_allies[actor_index]
	if not actor.get("bonus_attack", false) and actor.hp <= actor.max_hp * 0.4 and game_state.inventory.has("大还丹"):
		automation_command = true
		_use_item("大还丹")
		automation_command = false
		auto_action_running = false
		return
	if not actor.get("bonus_attack", false) and actor.hp <= actor.max_hp * 0.55 and game_state.inventory.has("疗伤药"):
		automation_command = true
		_use_item("疗伤药")
		automation_command = false
		auto_action_running = false
		return
	selected_skill = -1
	_update_skill_selection_visuals()
	var choice := _choose_auto_action()
	if choice.is_empty():
		var approach := _auto_approach_tile(actor)
		if approach.x >= 0:
			automation_command = true
			_on_tile_pressed(approach.y * BOARD_WIDTH + approach.x)
			automation_command = false
			if movement_tween and movement_tween.is_valid(): await movement_tween.finished
			if not auto_battle_enabled or not _active_actor_valid() or actor_index != selected_actor:
				auto_action_running = false
				_update_undo_button()
				return
			choice = _choose_auto_action()
	automation_command = true
	if choice.is_empty():
		_on_rest_pressed()
	else:
		_select_skill(choice.index)
		var target: Vector2i = choice.target
		# Release the input bypass before waiting for the attack animation.
		var tile_index := target.y * BOARD_WIDTH + target.x
		_on_tile_pressed(tile_index)
	automation_command = false
	if not player_action_resolving:
		auto_action_running = false
		_update_undo_button()

func _choose_auto_action() -> Dictionary:
	var actor: Dictionary = game_state.battle_allies[selected_actor]
	return _choose_martial(actor, current_skills, game_state.battle_enemies)

func _choose_martial(actor: Dictionary, names: Array, opponents: Array) -> Dictionary:
	var best := {}
	var best_score := 0.0
	for i in names.size():
		var name: String = names[i]
		var skill: Dictionary = game_state.skill_library[name]
		if not Rules.can_use(actor, name, skill): continue
		var target: Vector2i = actor.coord
		var affected: Array[Dictionary] = []
		for y in range(TILE_ROW_OFFSET, TILE_ROW_OFFSET + BOARD_HEIGHT):
			for x in BOARD_WIDTH:
				var coord := Vector2i(x, y)
				var hits := _targets_in_area(actor, skill, coord, opponents)
				if hits.size() > affected.size():
					affected = hits
					target = coord
		if affected.is_empty(): continue
		var score := float(skill.damage) * affected.size() / maxf(6.0, float(skill.cost))
		for effect in skill.effects:
			if effect[0] != "self" or Rules.layers(actor, effect[1]) > 0: continue
			if effect[1] == "mana_regen" and actor.mp < actor.max_mp * 0.6: score += 6.0
			if effect[1] == "heal_regen" and actor.hp < actor.max_hp * 0.7: score += 6.0
			if effect[1] in ["haste", "defense_up", "guard"]: score += 3.8
		if _unit_skill_level(actor, name) > 1: score += 0.1
		if score <= best_score: continue
		best_score = score
		best = {"index":i, "name":name, "target":target, "affected":affected}
	return best

func _auto_approach_tile(actor: Dictionary, opponents: Array = []) -> Vector2i:
	if opponents.is_empty(): opponents = game_state.battle_enemies
	var best := Vector2i(-1, -1)
	var best_distance := _closest_distance(actor.coord, actor, opponents)
	for coord in _reachable_tiles(actor):
		var nearest := _closest_distance(coord, actor, opponents)
		if nearest < best_distance:
			best_distance = nearest
			best = coord
	return best

func _closest_distance(coord: Vector2i, actor: Dictionary, opponents: Array) -> int:
	var nearest := 999
	for opponent in opponents:
		if opponent.alive and not is_same(actor, opponent):
			nearest = mini(nearest, _distance(coord, opponent.coord))
	return nearest

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
		var allies: bool = next_combatant.side == "ally"
		var actor: Dictionary = game_state.battle_allies[next_combatant.index] if allies else game_state.battle_enemies[next_combatant.index]
		Rules.begin(actor, game_state.battle_log)
		if not actor.alive:
			_refresh_units()
			if _check_defeated(): return
			continue
		if actor.skipped_turn:
			Rules.finish(actor, game_state.turn)
			continue
		if Rules.layers(actor, "berserk") > 0:
			await _resolve_berserk(actor)
			if _check_defeated(): return
			continue
		if allies:
			_clear_move_undo()
			selected_actor = int(next_combatant.index)
			var next_actor: Dictionary = game_state.battle_allies[selected_actor]
			next_actor.moved = false
			is_player_turn = true
			selected_skill = -1
			$Top/Hint.text = "时序%d：%s行动，可先移动再选择招式" % [game_state.turn, next_actor.name]
			_refresh_units()
			_refresh()
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
	var actor: Dictionary = game_state.battle_enemies[enemy_index]
	await _take_martial_turn(actor, actor.martial, game_state.battle_allies)

func _resolve_berserk(actor: Dictionary) -> void:
	game_state.battle_log.append("%s入魔，本次行动由系统接管" % actor.name)
	var names: Array = game_state.hero_skills[actor.hero_index].martial if actor.has("hero_index") else actor.martial
	await _take_martial_turn(actor, names, game_state.battle_allies + game_state.battle_enemies)

func _take_martial_turn(actor: Dictionary, names: Array, opponents: Array) -> void:
	actor.moved = false
	var choice := _choose_martial(actor, names, opponents)
	if choice.is_empty():
		var step := _auto_approach_tile(actor, opponents)
		if step.x >= 0:
			var node := _unit_control(actor)
			node.face_toward(step - actor.coord)
			var duration := 0.3 * _distance(actor.coord, step) / battle_speed
			actor.coord = step
			node.start_walk_animation()
			var movement := create_tween()
			movement.tween_property(node, "position", _coord_to_board(step), duration)
			await movement.finished
			node.stop_walk_animation()
			choice = _choose_martial(actor, names, opponents)
	if choice.is_empty():
		Rules.restore(actor, 0, 15)
		game_state.battle_log.append("%s调息" % actor.name)
	else:
		var dealt_damage := await _cast_martial(actor, choice.name, choice.target, choice.affected)
		if _check_defeated(): return
		if actor.alive and dealt_damage and randf() * 100.0 < Rules.scaled(actor, "combo", 30, 5):
			actor.bonus_attack = true
			var bonus := _choose_martial(actor, names, opponents)
			if not bonus.is_empty():
				game_state.battle_log.append("%s触发连击" % actor.name)
				await _cast_martial(actor, bonus.name, bonus.target, bonus.affected)
				if _check_defeated(): return
	Rules.finish(actor, game_state.turn)
	_refresh_units()

func _finish_battle(victory: bool) -> void:
	if battle_finished: return
	_clear_move_undo()
	battle_finished = true
	game_state.settle_battle(victory)
	game_state.goto("res://scenes/battle_result.tscn")

func _refresh_units() -> void:
	for i in $Board/Allies.get_child_count():
		var node := $Board/Allies.get_child(i)
		node.visible = i < game_state.battle_allies.size()
		if not node.visible: continue
		var actor: Dictionary = game_state.battle_allies[i]
		node.visible = actor.alive
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
		_refresh_unit_status(node, actor)
	for i in $Board/Enemies.get_child_count():
		var node := $Board/Enemies.get_child(i)
		if i >= game_state.battle_enemies.size():
			node.visible = false
			continue
		var enemy: Dictionary = game_state.battle_enemies[i]
		node.visible = enemy.alive
		if not node.visible: continue
		node.position = _coord_to_board(enemy.coord)
		node.configure(str(enemy.get("model", game_state.MALE_BATTLE_MODEL)), true)
		node.get_node("Name").text = enemy.name
		node.get_node("HP").value = enemy.hp
		node.get_node("HP").max_value = enemy.max_hp
		node.get_node("MP").value = float(enemy.get("mp", 0))
		node.get_node("MP").max_value = float(enemy.get("max_mp", 1))
		node.get_node("MP").visible = enemy.has("mp")
		_refresh_unit_status(node, enemy)

func _refresh() -> void:
	var active_index := _first_alive_ally()
	var bonus: bool = game_state.battle_allies[selected_actor].get("bonus_attack", false)
	$Rest/Label.text = "结束连击" if bonus else "调息"
	$Items.disabled = bonus
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
		var remaining := Rules.cooldown(actor, skill_name)
		var cooldown_text := " · 冷却%d" % remaining if remaining > 0 else ""
		button.tooltip_text = "%s Lv.%d · 内力%d%s" % [skill_name, loadout.levels.get(skill_name, 1), skill.cost, cooldown_text]
		button.get_node("Name").text = skill_name + cooldown_text
		button.disabled = not Rules.can_use(actor, skill_name, skill)
	_update_skill_selection_visuals()
	_update_undo_button()

func _update_skill_selection_visuals() -> void:
	for i in $Bottom/Skills.get_child_count():
		var button := $Bottom/Skills.get_child(i)
		var is_selected: bool = i == selected_skill and button.visible
		button.get_node("Selection").visible = false
		var frame := button.get_node_or_null("IconFrame") as Control
		if frame != null: frame.visible = is_selected
		button.modulate = Color(0.6, 0.6, 0.6) if button.disabled else Color.WHITE

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
	var enabled: bool = not auto_action_running and _active_actor_valid() and move_actor_index == selected_actor and bool(game_state.battle_allies[selected_actor].moved)
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
	hovered_move_tile = null
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
	if actor.moved or actor.get("bonus_attack", false): return reachable
	var distances := {actor.coord: 0}
	var frontier: Array[Vector2i] = [actor.coord]
	var directions: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		var distance: int = distances[current]
		if distance >= Rules.movement(actor): continue
		for direction in directions:
			var next := current + direction
			if not _is_inside_board(next) or distances.has(next): continue
			if _unit_at(next) != null: continue
			distances[next] = distance + 1
			frontier.append(next)
			reachable.append(next)
	return reachable

func _highlight_attack_tiles() -> void:
	hovered_move_tile = null
	if auto_battle_enabled or not _active_actor_valid():
		_clear_range_display()
		$Top/Hint.text = "自动战斗：正在行动"
		return
	var actor: Dictionary = game_state.battle_allies[selected_actor]
	var potential_attack_coords := _all_potential_attack_coords()
	for i in $Board/Tiles.get_child_count():
		var coord := _board_coord_from_index(i)
		var tile := $Board/Tiles.get_child(i) as TextureButton
		if coord == actor.coord and not _can_target(coord):
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
	hovered_move_tile = null
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

func _can_target(coord: Vector2i, skill_index: int = -1) -> bool:
	var index := selected_skill if skill_index < 0 else skill_index
	if index < 0 or index >= current_skills.size(): return false
	return _can_cast(game_state.battle_allies[selected_actor], game_state.skill_library[_skill_name(index)], coord)

func _can_cast(actor: Dictionary, skill: Dictionary, coord: Vector2i) -> bool:
	if not _is_inside_board(coord): return false
	var delta: Vector2i = coord - actor.coord
	var mode := Rules.cast_mode(skill)
	if delta == Vector2i.ZERO: return false
	var distance := _distance(actor.coord, coord)
	var limit: int = skill.range
	if Rules.layers(actor, "blind") > 0 and skill.school in ["拳掌", "奇门"]:
		limit = mini(1, limit)
	if mode == "direction" and delta.x != 0 and delta.y != 0: return false
	return distance <= limit

func _affected_enemies(target: Vector2i, skill_index: int = -1) -> Array[int]:
	var affected: Array[int] = []
	var index := selected_skill if skill_index < 0 else skill_index
	if index < 0 or index >= current_skills.size(): return affected
	var actor: Dictionary = game_state.battle_allies[selected_actor]
	var skill: Dictionary = game_state.skill_library[_skill_name(index)]
	for enemy in _targets_in_area(actor, skill, target, game_state.battle_enemies):
		affected.append(game_state.battle_enemies.find(enemy))
	return affected

func _affected_coords(target: Vector2i, skill_index: int = -1) -> Array[Vector2i]:
	var index := selected_skill if skill_index < 0 else skill_index
	if index < 0 or index >= current_skills.size(): return []
	return _hit_coords(game_state.battle_allies[selected_actor], game_state.skill_library[_skill_name(index)], target)

func _targets_in_area(actor: Dictionary, skill: Dictionary, target: Vector2i, opponents: Array) -> Array[Dictionary]:
	var affected: Array[Dictionary] = []
	var coords := _hit_coords(actor, skill, target)
	for opponent in opponents:
		if opponent.alive and not is_same(actor, opponent) and coords.has(opponent.coord): affected.append(opponent)
	return affected

func _hit_coords(actor: Dictionary, skill: Dictionary, target: Vector2i) -> Array[Vector2i]:
	var affected: Array[Vector2i] = []
	if not _can_cast(actor, skill, target): return affected
	var origin: Vector2i = actor.coord
	var direction := Vector2i(signi(target.x - origin.x), signi(target.y - origin.y))
	var reach: int = skill.get("reach", 0)
	match skill.shape:
		"line":
			for depth in range(1, reach + 1): affected.append(origin + direction * depth)
		"fan":
			var side := Vector2i(-direction.y, direction.x)
			for depth in range(1, reach + 1):
				for width in range(-1, 2): affected.append(origin + direction * depth + side * width)
		"cross":
			affected.append(target)
			for axis in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				for distance in range(1, reach + 1): affected.append(target + axis * distance)
		_:
			affected.append(target)
	var blind := Rules.layers(actor, "blind") > 0
	return affected.filter(func(coord: Vector2i) -> bool:
		return _is_inside_board(coord) and (not blind or _visible_under_blind(origin, target, coord, direction, skill.school)))

func _visible_under_blind(origin: Vector2i, target: Vector2i, coord: Vector2i, direction: Vector2i, school: String) -> bool:
	var offset := coord - origin
	match school:
		"剑系": return absi(direction.x) + absi(direction.y) == 1 and (offset == direction or offset == direction * 2)
		"拳掌": return _distance(origin, coord) == 1
		"刀法": return offset.x * direction.x + offset.y * direction.y == 1 and absi(offset.x * direction.y - offset.y * direction.x) <= 1
		"奇门": return _distance(target, coord) <= 1
	return true

func _skill_multiplier(level: int, growth: int = 1) -> float:
	return 1.0 + float(maxi(0, level - 1) * maxi(0, growth)) * 0.1

func _skill_damage(actor: Dictionary, skill: Dictionary, level: int) -> int:
	var techniques := {"剑系":"sword", "拳掌":"fist", "奇门":"unorthodox", "刀法":"blade"}
	var technique: int = actor.get(techniques[skill.school], 0)
	var raw := roundf(float(skill.damage) * _skill_multiplier(level, int(skill.get("damage_growth", 1))))
	raw += int(Rules.attack(actor) / 8.0) + int(technique / 20.0)
	return maxi(1, roundi(raw * float(actor.get("skill_power_percent", 100)) / 100.0))

func _skill_experience_reward(actor: Dictionary) -> int:
	return maxi(1, int(game_state.growth.battle_skill_exp) * int(actor.get("insight", 0)))

func _active_actor_valid() -> bool:
	return not battle_finished and is_player_turn and not player_action_resolving and selected_actor >= 0 and selected_actor < game_state.battle_allies.size() and game_state.battle_allies[selected_actor].alive

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
	var tile := Vector2(coord - Vector2i(0, TILE_ROW_OFFSET))
	return tile * TILE_STEP + UNIT_STANCE_IN_TILE - UNIT_FOOT_ANCHOR

func _distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

func _show_unit_float(unit: Control, message: String, color: Color, font_size: int = 22) -> void:
	if unit != null and unit.has_method("show_floating_text"):
		unit.call("show_floating_text", message, color, font_size)

func _play_skill_effect(skill: Dictionary, coord: Vector2i) -> AnimatedSprite2D:
	var effect_path := str(skill.get("effect", ""))
	if effect_path.is_empty(): return null
	var frames: SpriteFrames = skill_effect_frames_cache.get(effect_path)
	if frames == null:
		frames = _load_skill_effect_frames(effect_path)
		if frames == null: return null
		skill_effect_frames_cache[effect_path] = frames
	var effect := AnimatedSprite2D.new()
	effect.sprite_frames = frames
	effect.animation = "effect"
	var effect_scale := 1.15
	var effect_offset_y := -38.0
	if effect_path.ends_with("e-feilong"):
		effect_scale = 0.95
	elif effect_path.ends_with("e-liumai"):
		effect_offset_y = -82.0
	elif effect_path.ends_with("e-tianjian"):
		effect_scale = 1.35
		effect_offset_y = -88.0
	effect.position = _coord_to_board(coord) + UNIT_FOOT_ANCHOR + Vector2(0, effect_offset_y)
	effect.scale = Vector2.ONE * effect_scale
	effect.z_index = 35
	$Board/Effects.add_child(effect)
	effect.animation_finished.connect(func() -> void: effect.queue_free())
	effect.play("effect")
	return effect

func _play_skill_effects(skill: Dictionary, coords: Array[Vector2i]) -> Array[AnimatedSprite2D]:
	var effects: Array[AnimatedSprite2D] = []
	for coord in coords:
		var effect := _play_skill_effect(skill, coord)
		if effect != null: effects.append(effect)
	return effects

func _load_skill_effect_frames(resource_path: String) -> SpriteFrames:
	var padded_frames := ResourceLoader.exists(resource_path.path_join("01.png"))
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("effect")
	frames.set_animation_speed("effect", 16.0)
	frames.set_animation_loop("effect", false)
	for frame_index in range(1, 33):
		var filename := "%02d.png" % frame_index if padded_frames else "%d.png" % frame_index
		var frame_path := resource_path.path_join(filename)
		if not ResourceLoader.exists(frame_path): break
		var texture := load(frame_path) as Texture2D
		if texture != null: frames.add_frame("effect", texture)
	if frames.get_frame_count("effect") == 0: return null
	return frames

func _refresh_unit_status(unit: Control, stats: Dictionary) -> void:
	if unit == null: return
	var hp_bar := unit.get_node("HP") as ProgressBar
	hp_bar.visible = bool(game_state.settings.show_hp)
	hp_bar.max_value = float(stats.max_hp)
	hp_bar.value = float(stats.hp)
	var mp_bar := unit.get_node("MP") as ProgressBar
	mp_bar.max_value = float(stats.get("max_mp", 1))
	mp_bar.value = float(stats.get("mp", 0))

func _poison_chance(actor: Dictionary, target: Dictionary) -> float:
	if actor.get("poison", 0) <= 0 or target.get("poison_immune", false): return 0.0
	return clampf(float(actor.poison) + float(actor.get("luck", 0)) * 0.2 - float(target.get("willpower", 0)) * 0.2, 0.0, 100.0)

func _sync_actor_growth(actor: Dictionary) -> void:
	var combat: Dictionary = game_state.get_hero_combat_stats(actor.hero_index)
	var hp_growth := maxi(0, int(combat.max_hp) - int(actor.max_hp))
	var mp_growth := maxi(0, int(combat.max_mp) - int(actor.max_mp))
	for key in ["max_hp", "max_mp", "attack", "defense", "speed", "crit", "crit_damage", "poison", "fist", "sword", "blade", "unorthodox", "insight", "luck", "willpower"]:
		actor[key] = combat[key]
	actor.attack = game_state.get_hero_battle_attack(actor.hero_index, int(combat.attack))
	Rules.restore(actor, hp_growth, mp_growth)
	actor.action_delay = clampi(120 - int(combat.speed), 35, 90)
	actor.move_range = clampi(2 + int(combat.speed / 90.0), 2, 3)

func _medicine_text(item_name: String) -> String:
	var item: Dictionary = game_state.item_library[item_name]
	return "%s × %d\n恢复%d气血、%d内力" % [item_name, game_state.inventory.count(item_name), item.heal_hp, item.heal_mp]
