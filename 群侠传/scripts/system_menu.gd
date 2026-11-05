extends Control

@onready var game_state := get_node("/root/GameState")

func _ready() -> void:
	$Buttons/Back/Label.text = "返回主菜单" if game_state.menu_return_scene.ends_with("main_menu.tscn") else "返回游戏"
	$Buttons/Save.disabled = not game_state.session_started
	var option_keys := {
		"ShowHP": "show_hp", "AutoSave": "auto_save",
		"AutoBattle": "auto_battle", "Music": "music", "Sound": "sound", "Fullscreen": "fullscreen"
	}
	for node_name in option_keys:
		var check := $Options.get_node(node_name) as CheckButton
		var key: String = option_keys[node_name]
		check.button_pressed = bool(game_state.settings.get(key, false))
		check.toggled.connect(_toggle.bind(key))
	var speed_option := $Options/BattleSpeed as OptionButton
	speed_option.selected = 1 if float(game_state.settings.get("battle_speed", 1.0)) >= 2.0 else 0
	speed_option.item_selected.connect(_on_battle_speed_selected)

func _toggle(value: bool, key: String) -> void:
	game_state.set_setting(key, value)

func _on_battle_speed_selected(index: int) -> void:
	game_state.set_setting("battle_speed", 2.0 if index == 1 else 1.0)

func _on_save_pressed() -> void:
	game_state.goto("res://scenes/save_load.tscn")

func _on_main_menu_pressed() -> void:
	game_state.goto("res://scenes/main_menu.tscn")

func _on_back_pressed() -> void:
	game_state.goto(game_state.menu_return_scene)
