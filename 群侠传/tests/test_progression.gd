extends SceneTree
const Fixture = preload("res://tests/mechanics_fixture.gd")

var failures := 0
var game: Node
const TEST_DIR := "res://tests/.progression_runtime"

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error("ASSERTION FAILED: " + message)

func _run() -> void:
	game = root.get_node("GameState")
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	game.save_directory = TEST_DIR
	game.settings.auto_save = false
	game.settings.auto_battle = false
	_test_saves()
	_test_stable_references()
	_test_story_and_rewards()
	await _test_screens()
	await _test_speed_sync()
	await _test_live_battle_log()
	await _test_status_and_growth()
	for name in ["qunxia_auto.cfg", "qunxia_slot_1.cfg", "qunxia_slot_2.cfg", "qunxia_slot_3.cfg", "qunxia_slot_4.cfg", "preferences.cfg"]:
		var path := TEST_DIR.path_join(name)
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
		for version in [0, 1, 2, 3]:
			var backup := path + ".v%d.bak" % version
			if FileAccess.file_exists(backup): DirAccess.remove_absolute(backup)
	DirAccess.remove_absolute(TEST_DIR)
	# Let pending audio and deferred frees complete before shutdown.
	root.get_node("AudioManager").music_player.stop()
	for player in root.get_node("AudioManager").effects: player.stop()
	await process_frame
	print("PROGRESSION TESTS PASSED: save isolation, latest valid save, corruption, quest rewards, UI, settings, live growth" if failures == 0 else "PROGRESSION TESTS FAILED: %d" % failures)
	quit(failures)

func _test_saves() -> void:
	Fixture.reset(game)
	game.money = 987
	game.quest_stage = 1
	game.equip_item(0, "魔神剑")
	game.learn_from_book(5, "独孤九剑秘籍")
	check(game.save_slot(1) == OK, "manual save writes successfully")
	game.money = 654
	check(game.save_slot(1) == OK, "existing save is replaced successfully")
	game.settings.auto_save = true
	game.money = 123
	check(game.autosave() == OK, "automatic save writes independently")
	check(game.load_slot(1) == OK and game.money == 654, "automatic save never overwrites manual slot 1")
	check(game.quest_stage == 1 and game.hero_equipment[0].weapon == "魔神剑" and game.hero_skills[5].learned.has("独孤九剑") and game.hero_skills[5].martial.is_empty(), "save restores learned skills separately from equipped skills")
	check(game.load_latest() == OK and game.money == 123, "continue chooses latest automatic save")
	game.money = 321
	check(game.save_slot(3) == OK, "manual slot 3 saves")
	# Explicit timestamps avoid relying on filesystem timestamp resolution.
	var cfg := ConfigFile.new()
	cfg.load(game.get_save_path(3))
	cfg.set_value("meta", "saved_unix", Time.get_unix_time_from_system() + 10)
	cfg.save(game.get_save_path(3))
	check(game.load_latest() == OK and game.money == 321, "continue also finds newer manual saves outside slot 1")
	var before: int = game.money
	var damaged: Dictionary = cfg.get_value("references", "heroes")
	damaged[game.heroes[0].id].stats = {"strength":"bad"}
	cfg.set_value("references", "heroes", damaged)
	cfg.save(game.get_save_path(3))
	check(game.load_slot(3) == ERR_FILE_CORRUPT and game.money == before, "damaged save does not partially replace live progress")
	check(game.load_latest() == OK and game.money == 123, "continue skips corrupted latest save")
	cfg.set_value("meta", "version", 999)
	cfg.save(game.get_save_path(3))
	check(game.load_slot(3) == ERR_FILE_UNRECOGNIZED, "future save versions are rejected")
	# A sparse legacy save uses new-game defaults instead of the previous session.
	var legacy := ConfigFile.new()
	legacy.set_value("player", "money", 88)
	legacy.save(game.get_save_path(2))
	check(game.load_slot(2) == OK and game.money == 88 and game.hero_equipment[0].is_empty(), "legacy missing fields use defaults")
	game.session_started = false
	var modified := FileAccess.get_file_as_bytes(game.get_save_path(0))
	game.money = 999
	game.autosave()
	check(FileAccess.get_file_as_bytes(game.get_save_path(0)) == modified, "menus before a new game cannot overwrite automatic progress")
	Fixture.reset(game)
	game.settings.auto_save = false

func _test_story_and_rewards() -> void:
	Fixture.reset(game)
	game.selected_party.assign([0, 1])
	game.current_encounter = "江湖切磋"
	game.new_battle()
	game.heroes[0].exp = game.get_hero_experience_needed(1) - 1
	var money_before: int = game.money
	var items_before: int = game.inventory.size()
	var result: Dictionary = game.settle_battle(true, 0.1)
	check(result.items == ["疗伤药", "粗布道袍"] and game.inventory.size() == items_before + 2, "actual drops match reward snapshot")
	check(result.heroes.size() == 2 and result.heroes[0].after == 2, "only deployed heroes receive experience and level-up report")
	game.settle_battle(true, 0.1)
	check(game.money == money_before + 200 and game.inventory.size() == items_before + 2, "settlement is idempotent")
	game.new_battle()
	money_before = game.money
	result = game.settle_battle(false)
	check(result.items.is_empty() and result.heroes.is_empty() and game.money == money_before, "defeat gives no victory rewards")

func _test_stable_references() -> void:
	Fixture.reset(game)
	game.selected_party.assign([0, 1])
	game.equip_item(0, "魔神剑")
	game.heroes[0].exp = 77
	check(game.save_slot(4) == OK, "ID save is written")
	var cfg := ConfigFile.new()
	cfg.load(game.get_save_path(4))
	check(cfg.get_value("meta", "version") == 4 and cfg.get_value("references", "party") == ["hero_beichou", "hero_nanxian"], "new saves reference party by stable hero ID")
	check(not cfg.has_section_key("player", "hero_skills") and cfg.get_value("references", "heroes").hero_beichou.equipment.weapon == "weapon_moshenjian", "equipment and skill names are absent from new save payload")
	var original_records: Dictionary = cfg.get_value("references", "heroes")
	cfg.set_value("references", "heroes", {})
	cfg.save(game.get_save_path(4))
	check(game.load_slot(4) == ERR_FILE_CORRUPT and game.heroes[0].exp == 77, "truncated ID save cannot reset progress to defaults")
	cfg.set_value("references", "heroes", original_records)
	cfg.save(game.get_save_path(4))
	var defaults: Dictionary = game._new_game_defaults.duplicate(true)
	var models: Array = game.HERO_MODEL_PATHS.duplicate()
	var weapon: Dictionary = game.equipment_library["魔神剑"]
	var skill: Dictionary = game.skill_library["独孤九剑"]
	game.equipment_library["试验兵器"] = weapon
	game.equipment_library.erase("魔神剑")
	game.skill_library["试验剑法"] = skill
	game.skill_library.erase("独孤九剑")
	game._new_game_defaults.heroes[0].name = "改名侠客"
	for field in ["heroes", "hero_stats", "hero_equipment", "hero_skills"]:
		var first: Variant = game._new_game_defaults[field][0]
		game._new_game_defaults[field][0] = game._new_game_defaults[field][1]
		game._new_game_defaults[field][1] = first
	game.HERO_MODEL_PATHS.assign([models[1], models[0], models[2], models[3], models[4], models[5]])
	check(game.load_slot(4) == OK, "save survives configuration rename and roster reorder")
	check(game.selected_party == [1, 0] and game.heroes[1].name == "改名侠客" and game.heroes[1].exp == 77, "hero progress follows ID instead of array position or old name")
	check(game.hero_equipment[1].weapon == "试验兵器" and game.hero_skills[1].martial.has("试验剑法"), "equipment and skills resolve to their current names")
	game.equipment_library.erase("试验兵器")
	game.equipment_library["魔神剑"] = weapon
	game.skill_library.erase("试验剑法")
	game.skill_library["独孤九剑"] = skill
	game._new_game_defaults = defaults
	game.HERO_MODEL_PATHS.assign(models)
	Fixture.reset(game)
	# Version 1 can still be loaded and becomes an ID save on next write.
	var legacy := ConfigFile.new()
	legacy.set_value("meta", "version", 1)
	legacy.set_value("player", "money", 456)
	legacy.set_value("player", "inventory", ["玄铁剑"])
	legacy.set_value("player", "hero_equipment", [{"weapon":"玄铁剑"}])
	legacy.save(game.get_save_path(4))
	check(game.load_slot(4) == OK and game.hero_equipment[0].weapon == "魔神拳套", "version 1 legacy item names still migrate")
	game.save_slot(4)
	cfg.load(game.get_save_path(4))
	check(cfg.get_value("references", "heroes").hero_beichou.equipment.weapon == "weapon_moshenquantao", "resaving a legacy save upgrades its references")
	var backup := ConfigFile.new()
	check(backup.load(game.get_save_path(4) + ".v1.bak") == OK and backup.get_value("meta", "version") == 1, "upgrading a manual save preserves the original legacy file")

func _scene(path: String) -> Node:
	var node: Node = load("res://scenes/%s.tscn" % path).instantiate()
	root.add_child(node)
	return node

func _test_screens() -> void:
	Fixture.reset(game)
	var map := _scene("world_map")
	await process_frame
	check(map.get_node("Locations/dali").disabled and map.get_node("Locations/shaolin").disabled == false, "map guides new players to quest start")
	check(map.get_node("Objective").text.contains("机制测试"), "map displays current objective")
	map.queue_free()
	var prep := _scene("battle_prep")
	await process_frame
	prep.selected.assign([5])
	prep._refresh()
	check(prep.get_node("Fight").disabled and prep.get_node("SelectedCount").text.contains("程灵素"), "unarmed roster cannot enter battle")
	game.learn_from_book(5, "独孤九剑秘籍")
	prep._refresh()
	check(prep.get_node("Fight").disabled, "learning alone does not equip a martial skill")
	game.equip_skill(5, "独孤九剑")
	prep._refresh()
	check(not prep.get_node("Fight").disabled, "equipping a learned martial skill makes the hero deployable")
	prep.queue_free()
	game.menu_return_scene = "res://scenes/main_menu.tscn"
	var menu := _scene("system_menu")
	await process_frame
	check(menu.get_node("Buttons/Back/Label").text == "返回主菜单", "settings remember their source screen")
	menu._toggle(false, "music")
	menu._toggle(false, "sound")
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")) and AudioServer.is_bus_mute(AudioServer.get_bus_index("Effects")), "music and effects switches mute actual audio buses")
	var cfg := ConfigFile.new()
	check(cfg.load(TEST_DIR.path_join("preferences.cfg")) == OK and not cfg.get_value("settings", "values").music, "settings persist independently from progress saves")
	menu.queue_free()
	var saves := _scene("save_load")
	await process_frame
	check(saves.has_node("AutoLoad") and not saves.get_node("AutoLoad").disabled, "automatic save can be loaded from its own row")
	saves.queue_free()
	game.new_battle()
	game.settle_battle(true, 0.1)
	var result := _scene("battle_result")
	await process_frame
	check(result.get_node("Rewards/Reward1/Name").text == "疗伤药 × 1" and not result.get_node("Rewards/Reward3").visible, "result cards show only items actually awarded")
	check(result.get_node("Growth").text.contains(game.heroes[0].name), "result shows each deployed hero")
	result.queue_free()
	await process_frame

func _test_speed_sync() -> void:
	Fixture.reset(game)
	game.settings.auto_battle = false
	game.set_setting("battle_speed", 2.0)
	var menu := _scene("system_menu")
	await process_frame
	check(menu.get_node("Options/BattleSpeed").selected == 1, "menu displays stored 2x speed")
	menu.queue_free()
	await process_frame
	game.new_battle()
	var battle := _scene("battle")
	await process_frame
	check(battle.battle_speed == 2.0 and battle.get_node("Top/BattleSpeed").text == "战斗 2倍", "entering battle keeps menu speed and matching button label")
	check(battle.get_node("Board/Allies").get_child(0).get_node("Model").speed_scale == 2.0, "menu speed controls actual battle animation playback")
	battle.get_node("Top/BattleSpeed").pressed.emit()
	check(game.settings.battle_speed == 1.0 and battle.get_node("Top/BattleSpeed").text == "战斗 1倍", "battle toggle updates shared speed")
	battle.queue_free()
	await process_frame
	menu = _scene("system_menu")
	await process_frame
	check(menu.get_node("Options/BattleSpeed").selected == 0, "reopened menu displays speed changed in battle")
	menu.get_node("Options/BattleSpeed").select(1)
	menu.get_node("Options/BattleSpeed").item_selected.emit(1)
	menu.queue_free()
	await process_frame
	game.new_battle()
	battle = _scene("battle")
	await process_frame
	check(battle.battle_speed == 2.0 and battle.get_node("Top/BattleSpeed").text == "战斗 2倍", "re-entering battle displays menu's updated 2x setting")
	var cfg := ConfigFile.new()
	check(cfg.load(TEST_DIR.path_join("preferences.cfg")) == OK and cfg.get_value("settings", "values").battle_speed == 2.0, "speed preference persists across sessions")
	battle.queue_free()
	await process_frame
	game.set_setting("battle_speed", 1.0)

func _test_live_battle_log() -> void:
	Fixture.reset(game)
	game.settings.auto_battle = false
	game.settings.show_battle_log = true
	game.new_battle()
	var battle := _scene("battle")
	await process_frame
	var panel: Panel = battle.get_node("BattleLog")
	var toggle: Button = battle.get_node("Top/LogToggle")
	check(panel.visible and panel.get_node("Scroll/Text").text.contains("战斗开始"), "battle log starts visible with an empty state")
	game.battle_log.append("测试：造成32点伤害")
	await process_frame
	await process_frame
	check(panel.get_node("Scroll/Text").text.contains("造成32点伤害"), "battle details update while combat is running")
	toggle.set_pressed(false)
	check(not panel.visible and toggle.text == "显示战斗详情", "player can hide the live log")
	game.battle_log.append("测试：中毒3回合")
	toggle.set_pressed(true)
	check(panel.visible and panel.get_node("Scroll/Text").text.contains("中毒3回合"), "reopening shows records accumulated while hidden")
	for i in 40: game.battle_log.append("行动记录 %d" % i)
	for i in 5: await process_frame
	var scroll: ScrollContainer = panel.get_node("Scroll")
	check(scroll.scroll_vertical > 0, "new records follow the latest action")
	scroll.scroll_vertical = 0
	game.battle_log.append("测试：查看历史时新增记录")
	for i in 5: await process_frame
	check(scroll.scroll_vertical == 0, "reading older records does not force the scroll to the bottom")
	toggle.set_pressed(false)
	battle.queue_free()
	await process_frame
	game.new_battle()
	battle = _scene("battle")
	await process_frame
	check(not battle.get_node("BattleLog").visible, "log visibility preference survives the next battle")
	battle.queue_free()
	await process_frame
	var result := _scene("battle_result")
	await process_frame
	check(not result.has_node("Details") and not result.has_node("Detail"), "settlement no longer contains combat details")
	result.queue_free()
	game.settings.show_battle_log = true
	await process_frame

func _test_status_and_growth() -> void:
	Fixture.reset(game)
	game.new_battle()
	var battle := _scene("battle")
	await process_frame

	var enemy: Dictionary = game.battle_enemies[0]
	enemy.poison_turns = 3
	game.settings.show_hp = false
	game.settings.show_buffs = false
	battle._refresh_units()
	check(not battle.get_node("Board/Enemies").get_child(0).get_node("HP").visible and not battle.get_node("Board/Enemies").get_child(0).get_node("Status").visible, "HP and status switches control real battle indicators")
	game.settings.show_hp = true
	game.settings.show_buffs = true
	battle._refresh_units()
	check(battle.get_node("Board/Enemies").get_child(0).get_node("Status").text == "中毒 3" and battle.get_node("Board/Enemies").get_child(0).get_node("Status").visible, "status indicator shows remaining poison duration")
	var actor: Dictionary = game.battle_allies[0]
	var hp_before: int = actor.max_hp
	var attack_before: int = actor.attack
	game.gain_hero_experience(0, 200)
	battle._sync_actor_growth(actor)
	check(actor.max_hp > hp_before and actor.attack > attack_before, "level-up immediately updates active combatant")
	check(battle._poison_chance({"poison":15, "luck":20}, {"willpower":0}) > battle._poison_chance({"poison":15, "luck":20}, {"willpower":30}), "willpower resists status application")
	check(battle._poison_chance({"poison":15}, {"poison_immune":true}) == 0, "poison immunity is respected")
	battle.queue_free()
	await process_frame

