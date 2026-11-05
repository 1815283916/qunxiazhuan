extends SceneTree
const Fixture = preload("res://tests/mechanics_fixture.gd")
var failures := 0
var game: Node
const DIR := "res://tests/.skills_runtime"

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	if value: return
	failures += 1
	push_error("ASSERTION FAILED: " + message)

func _run() -> void:
	game = root.get_node("GameState")
	game.save_directory = DIR
	DirAccess.make_dir_recursive_absolute(DIR)
	Fixture.reset(game)
	game.settings.auto_save = false
	game.settings.auto_battle = false
	game.settings.battle_speed = 2.0
	var fifth: Dictionary = game.skill_library["独孤九剑"].duplicate(true)
	fifth.id = "martial_test_fifth"
	game.skill_library["测试第五武学"] = fifth
	game.learn_skill(0, "狂风刀法")
	game.equip_skill(0, "狂风刀法")
	game.learn_skill(0, "测试第五武学")
	var loadout: Dictionary = game.hero_skills[0]
	check(loadout.learned.has("测试第五武学") and loadout.martial.size() == 4, "learning a fifth martial is allowed without overfilling equipped slots")
	check(game.equip_skill(0, "测试第五武学").contains("最多") and loadout.martial.size() == 4, "equipping a fifth martial is rejected")
	loadout.exp["独孤九剑"] = 17
	game.unequip_skill(0, "独孤九剑")
	check(loadout.learned.has("独孤九剑") and loadout.levels["独孤九剑"] == 3 and loadout.exp["独孤九剑"] == 17, "unequipping retains learned skill and growth")
	game.equip_skill(0, "测试第五武学")
	game.learn_from_book(0, "易筋经")
	check(loadout.internal == "九阳神功" and loadout.learned.has("易筋经"), "learning a second internal does not replace the equipped one")
	game.equip_skill(0, "易筋经")
	check(loadout.internal == "易筋经" and loadout.learned.has("九阳神功") and loadout.levels["九阳神功"] == 3, "switching internals preserves the previous one")
	var bonus: Dictionary = game.get_internal_skill_bonus(0)
	check(bonus.attack == 4 and bonus.defense == 4, "only the equipped internal contributes stats")
	game.save_slot(1)
	Fixture.reset(game)
	check(game.load_slot(1) == OK, "extended loadout save loads")
	loadout = game.hero_skills[0]
	check(loadout.learned.size() == 7 and loadout.martial.size() == 4 and not loadout.martial.has("独孤九剑") and loadout.exp["独孤九剑"] == 17, "unequipped learned skills and growth survive saving")
	game.selected_hero = 0
	var character: Node = load("res://scenes/character.tscn").instantiate()
	root.add_child(character)
	await process_frame
	var grid := character.get_node("Paper/SkillsPanel/Scroll/Grid")
	var visible_count := 0
	for button in grid.get_children():
		if button.visible: visible_count += 1
	check(visible_count == 7, "skill page displays more than five learned skills")
	character._open_skill_slot(character._skill_names().find("九阳神功"))
	# _open_skill_slot changes scenes; avoid further interaction with the freed page.
	await process_frame
	await process_frame
	if current_scene != null:
		current_scene._on_equip_pressed()
		check(game.hero_skills[0].internal == "九阳神功", "skill detail equips a previously learned internal")
		game.equip_skill(0, "易筋经")
	if current_scene != null:
		current_scene.queue_free()
	character.queue_free()
	await process_frame
	game.new_battle()
	var battle: Node = load("res://scenes/battle.tscn").instantiate()
	root.add_child(battle)
	await process_frame
	check(battle.current_skills.size() == 4 and not battle.current_skills.has("独孤九剑"), "combat only exposes equipped martial skills")
	var inactive_exp: int = loadout.exp["独孤九剑"]
	var old_internal_exp: int = loadout.exp.get("九阳神功", 0)
	game.battle_enemies[0].coord = Vector2i(3, 3)
	battle._select_skill(0)
	await battle._on_tile_pressed(3 * 16 + 3)
	check(loadout.exp["独孤九剑"] == inactive_exp and loadout.exp.get("九阳神功", 0) == old_internal_exp, "unequipped skills gain no combat experience")
	check(loadout.exp.get("易筋经", 0) > 0 or loadout.levels["易筋经"] > 1, "equipped internal gains combat experience")
	battle.queue_free()
	await process_frame
	# Existing version 2 saves without a learned list infer it from levels.
	var cfg := ConfigFile.new()
	cfg.load(game.get_save_path(1))
	cfg.set_value("meta", "version", 2)
	var records: Dictionary = cfg.get_value("references", "heroes")
	for id in records: records[id].skills.erase("learned")
	cfg.set_value("references", "heroes", records)
	cfg.save(game.get_save_path(1))
	Fixture.reset(game)
	check(game.load_slot(1) == OK and game.hero_skills[0].learned.has("九阳神功") and game.hero_skills[0].learned.has("独孤九剑"), "old ID saves recover previously learned skills from level records")
	for name in ["qunxia_slot_1.cfg", "preferences.cfg"]:
		if FileAccess.file_exists(DIR.path_join(name)): DirAccess.remove_absolute(DIR.path_join(name))
	DirAccess.remove_absolute(DIR)
	print("SKILL LOADOUT TESTS PASSED" if failures == 0 else "SKILL LOADOUT TESTS FAILED: %d" % failures)
	quit(failures)
