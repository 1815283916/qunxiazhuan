extends Control

@onready var game_state := get_node("/root/GameState")
var selected: Array[int] = []

func _ready() -> void:
	selected.clear()
	for hero_index in game_state.selected_party:
		if hero_index >= 0 and hero_index < game_state.heroes.size() and selected.size() < 3:
			selected.append(hero_index)
	for i in $Roster.get_child_count():
		var card := $Roster.get_child(i)
		card.visible = i < game_state.heroes.size()
		if not card.visible: continue
		var hero: Dictionary = game_state.heroes[i]
		var combat: Dictionary = game_state.get_hero_combat_stats(i)
		card.texture_normal = load(hero.head)
		card.get_node("Name").text = hero.name
		card.tooltip_text = "Lv.%d  攻%d  防%d  暴击%.1f%%" % [hero.level, combat.attack, combat.defense, combat.crit]
		card.pressed.connect(_toggle_hero.bind(i))
	_refresh()

func _toggle_hero(index: int) -> void:
	if selected.has(index): selected.erase(index)
	elif selected.size() < 3: selected.append(index)
	else:
		$SelectedCount.text = "最多选择3人"
		return
	_refresh()

func _refresh() -> void:
	$SelectedCount.text = "已选择%d人" % selected.size()
	$Fight.disabled = selected.is_empty()
	for i in $Roster.get_child_count():
		$Roster.get_child(i).modulate = Color("#8ee57d") if selected.has(i) else Color.WHITE

func _on_fight_pressed() -> void:
	game_state.selected_party = selected.duplicate()
	game_state.new_battle()
	game_state.goto("res://scenes/battle.tscn")

func _on_close_pressed() -> void:
	game_state.goto("res://scenes/world_map.tscn")
