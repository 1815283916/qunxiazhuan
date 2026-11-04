extends Control

@onready var game_state := get_node("/root/GameState")
var selected: Array[int] = []
var unequipped_hero := -1

func _ready() -> void:
	$ConfigureSkill.pressed.connect(_on_configure_skill)
	selected.clear()
	for hero_index in game_state.selected_party:
		if hero_index >= 0 and hero_index < game_state.heroes.size() and game_state.hero_available(hero_index) and selected.size() < 3:
			selected.append(hero_index)
	for i in $Roster.get_child_count():
		var card := $Roster.get_child(i)
		card.visible = i < game_state.heroes.size() and game_state.hero_available(i)
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
	var issue: String = game_state.get_party_issue(selected)
	$Fight.disabled = not issue.is_empty()
	if not issue.is_empty(): $SelectedCount.text = issue
	unequipped_hero = -1
	for index in selected:
		if game_state.get_party_issue([index]).contains("尚未装备武学"):
			unequipped_hero = index
			break
	$ConfigureSkill.visible = unequipped_hero >= 0
	$SelectedCount.add_theme_font_size_override("font_size", 21)
	for i in $Roster.get_child_count():
		$Roster.get_child(i).modulate = Color("#8ee57d") if selected.has(i) else Color.WHITE

func _on_fight_pressed() -> void:
	if not game_state.get_party_issue(selected).is_empty(): return
	game_state.selected_party = selected.duplicate()
	game_state.new_battle()
	game_state.goto("res://scenes/battle.tscn")

func _on_close_pressed() -> void:
	game_state.goto(game_state.Narrative.region_scene(game_state))

func _on_configure_skill() -> void:
	if unequipped_hero < 0: return
	game_state.selected_party = selected.duplicate()
	game_state.selected_hero = unequipped_hero
	game_state.character_tab = "技能"
	game_state.character_return_scene = "res://scenes/battle_prep.tscn"
	game_state.goto("res://scenes/character.tscn")
