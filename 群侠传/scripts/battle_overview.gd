extends Control

const Rules = preload("res://scripts/combat_rules.gd")

@onready var game_state := get_node("/root/GameState")
@onready var allies: ItemList = $Panel/Content/Columns/Allies/List
@onready var enemies: ItemList = $Panel/Content/Columns/Enemies/List
@onready var details: VBoxContainer = $Panel/Content/Columns/Details
var owns_pause := false
var acting_ally := -1

func _ready() -> void:
	$Panel/Content/Header/Close.pressed.connect(close)
	allies.item_selected.connect(_show_unit.bind(true))
	enemies.item_selected.connect(_show_unit.bind(false))

func open(active_ally: int, is_player_turn: bool) -> void:
	if visible or get_tree().paused: return
	acting_ally = active_ally if is_player_turn else -1
	_fill_roster(allies, game_state.battle_allies)
	_fill_roster(enemies, game_state.battle_enemies)
	if not game_state.battle_allies.is_empty():
		_show_unit(clampi(active_ally, 0, game_state.battle_allies.size() - 1), true)
	show()
	allies.grab_focus()
	owns_pause = true
	get_tree().paused = true

func close() -> void:
	hide()
	_release_pause()

func _exit_tree() -> void:
	_release_pause()

func _release_pause() -> void:
	if not owns_pause: return
	owns_pause = false
	get_tree().paused = false

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()

func _fill_roster(list: ItemList, units: Array) -> void:
	list.clear()
	for index in units.size():
		var unit: Dictionary = units[index]
		var title := "%02d  %s" % [index + 1, unit.name]
		var row := list.add_item(title + ("" if unit.alive else " · 退场"), load(unit.head))
		if not unit.alive: list.set_item_custom_fg_color(row, Color("#9e9483"))

func _show_unit(index: int, is_ally: bool) -> void:
	var unit: Dictionary = game_state.battle_allies[index] if is_ally else game_state.battle_enemies[index]
	var list := allies if is_ally else enemies
	var other_list := enemies if is_ally else allies
	other_list.deselect_all()
	list.select(index)
	list.ensure_current_is_visible()
	details.get_node("Identity/Icon").texture = list.get_item_icon(index)
	details.get_node("Identity/Name").text = unit.name
	var timing := "下次行动 %d" % unit.next_action if unit.alive else "已退场"
	if is_ally and index == acting_ally: timing = "当前 %d" % game_state.turn
	details.get_node("Vitals").text = "气血 %d / %d    内力 %d / %d\n时序 %s\n攻击 %d    防御 %d    身法 %d    移动 %d格" % [unit.hp, unit.max_hp, unit.mp, unit.max_mp, timing, int(Rules.attack(unit)), int(Rules.defense(unit)), unit.speed, Rules.movement(unit)]
	var loadout: Dictionary = game_state.hero_skills[unit.hero_index] if is_ally else unit
	var skills: Array[String] = []
	var levels: Dictionary = loadout.get("levels", {})
	for name in loadout.martial:
		var remaining := Rules.cooldown(unit, name)
		var cooldown := " · 冷却%d回合" % remaining if remaining > 0 else ""
		skills.append("%s %d级%s" % [name, levels.get(name, 1), cooldown])
	var heart: String = loadout.get("internal", "")
	var status := Rules.status_text(unit, "\n")
	var info := "武学\n%s\n\n心法\n%s\n\n状态\n%s" % [
		"\n".join(skills) if not skills.is_empty() else "无",
		"%s %d级" % [heart, levels.get(heart, 1)] if not heart.is_empty() else "无",
		Rules.highlight_status(status) if not status.is_empty() else "状态正常",
	]
	details.get_node("Scroll/Info").text = info
	details.get_node("Scroll").scroll_vertical = 0
