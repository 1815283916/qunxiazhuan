extends Control

@onready var game_state := get_node("/root/GameState")

func _ready() -> void:
	for card in $Grid.get_children(): card.visible = false
	for i in mini($Grid.get_child_count(), game_state.heroes.size()):
		var card := $Grid.get_child(i)
		card.visible = true
		var hero: Dictionary = game_state.heroes[i]
		card.get_node("Portrait").texture = load(hero.head)
		card.get_node("Stats").text = "等级 %d\n攻 %d\n韧 %d\n防 %d" % [hero.level, hero.attack, hero.speed, hero.defense]
		card.get_node("Name").text = _vertical_name(hero.name)
		card.pressed.connect(_open_hero.bind(i))

func _vertical_name(hero_name: String) -> String:
	var vertical := ""
	for i in hero_name.length():
		vertical += hero_name.substr(i, 1)
		if i < hero_name.length() - 1: vertical += "\n"
	return vertical

func _open_hero(index: int) -> void:
	game_state.selected_hero = index
	game_state.goto("res://scenes/character.tscn")

func _on_close_pressed() -> void:
	game_state.goto("res://scenes/world_map.tscn")
