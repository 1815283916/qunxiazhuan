extends RefCounted
## Isolate combat/loadout regression tests from narrative unlocks and starting inventory.
static func reset(game: Node) -> void:
	var data: Dictionary = game._configuration_integers(JSON.parse_string(FileAccess.get_file_as_string("res://data/configuration.json")))
	game._new_game_defaults.hero_skills = data.hero_skills.duplicate(true)
	game._new_game_defaults.inventory = ["魔神拳套", "朴刀", "凝神杖", "魔神剑", "粗布道袍", "乌蚕衣", "毒戒指", "宝玉", "大还丹", "疗伤药", "独孤九剑秘籍", "易筋经"]
	game._new_game_defaults.money = 1280
	game.reset_new_game()
	game._synchronize_loaded_configuration()
	game._new_game_defaults.hero_skills = game.hero_skills.duplicate(true)
	game.story_data.nodes = [
		{"id":"test_past", "chapter":1, "location":"shaolin_room", "heal":true, "join":[1,2,3,4,5]},
		{"id":"test_mechanics", "chapter":1, "location":"shaolin_room", "title":"机制测试"}
	]
	game.narrative_progress = {"next":"test_mechanics", "pending":false}
