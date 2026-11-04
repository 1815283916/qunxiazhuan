extends SceneTree
const Fixture = preload("res://tests/mechanics_fixture.gd")
var game: Node
var failures := 0
const DIR := "res://tests/.polish_runtime"

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	if value: return
	failures += 1
	push_error("ASSERTION FAILED: " + message)

func _scene(name: String) -> Node:
	var node: Node = load("res://scenes/%s.tscn" % name).instantiate()
	root.add_child(node)
	return node

func _run() -> void:
	game = root.get_node("GameState")
	game.save_directory = DIR
	DirAccess.make_dir_recursive_absolute(DIR)
	Fixture.reset(game)
	game.settings.auto_save = false
	game.settings.auto_battle = false
	check(game.get_party_issue([5]).contains("尚未学习"), "unlearned martial is explained correctly")
	game.learn_from_book(5, "独孤九剑秘籍")
	check(game.get_party_issue([5]).contains("尚未装备"), "learned but unequipped martial directs to equipment")
	game.selected_party.assign([5])
	var prep := _scene("battle_prep")
	await process_frame
	check(prep.get_node("ConfigureSkill").visible, "battle prep exposes skill equipment shortcut")
	prep._on_configure_skill()
	for i in 3: await process_frame
	check(current_scene != null and current_scene.has_method("_open_skill_slot") and game.selected_hero == 5, "prep shortcut opens the correct hero's skill page")
	if current_scene != null and current_scene.has_method("_open_skill_slot"):
		current_scene._open_skill_slot(current_scene._skill_names().find("独孤九剑"))
		for i in 3: await process_frame
		current_scene._on_equip_pressed()
		current_scene._on_close_pressed()
		for i in 3: await process_frame
		current_scene._on_back_pressed()
		for i in 3: await process_frame
		check(current_scene.get_node("Fight").disabled == false and game.selected_party == [5], "equipping through shortcut returns to the same prepared party")
	if current_scene != null: current_scene.queue_free()
	await process_frame
	prep.queue_free()
	await process_frame
	Fixture.reset(game)
	game.equip_item(0, "魔神剑")
	game.inventory.append("魔神剑")
	var shop := _scene("shop")
	await process_frame
	shop._set_mode("sell")
	var target := -1
	for index in shop.goods_grid.get_child_count():
		if shop.goods_grid.get_child(index).get_node("Name").text.begins_with("魔神剑 ×"): target = index
	check(target >= 0, "spare worn-type equipment remains sellable")
	var money: int = game.money
	if target >= 0: shop.goods_grid.get_child(target).pressed.emit()
	check(game.hero_equipment[0].weapon == "魔神剑" and not game.inventory.has("魔神剑"), "sale consumes only loose copy and leaves worn equipment intact")
	check(game.money == money + game.item_library["魔神剑"].sell_price and game.money == money + 900, "non-shop equipment uses configured sell price instead of 10")
	shop._set_mode("buy")
	var book_index := -1
	for index in shop.goods.size():
		if shop.goods[index].name == "降龙十八掌秘籍": book_index = index
	game.money = 5000
	check(book_index >= 0, "catalog adds new martial books to shop")
	if book_index >= 0: shop.goods_grid.get_child(book_index).pressed.emit()
	check(game.money == 4250 and game.inventory.count("降龙十八掌秘籍") == 1, "shop purchase uses configured price exactly once")
	game.learn_from_book(5, "降龙十八掌秘籍")
	check(game.hero_skills[5].learned.has("降龙十八掌") and game.inventory.has("降龙十八掌秘籍"), "book effect resolves skill ID and remains reusable")
	game.save_slot(1)
	Fixture.reset(game)
	check(game.load_slot(1) == OK and game.inventory.has("降龙十八掌秘籍") and game.hero_skills[5].learned.has("降龙十八掌"), "new catalog item IDs and learned skills round-trip through saves")
	shop.queue_free()
	await process_frame
	Fixture.reset(game)
	game.learn_skill(0, "狂风刀法")
	game.equip_skill(0, "狂风刀法")
	var custom: Dictionary = game.skill_library["独孤九剑"].duplicate(true)
	custom.id = "martial_polish_test"
	game.skill_library["测试武学"] = custom
	game.learn_skill(0, "测试武学")
	var character := _scene("character")
	await process_frame
	check(not character.get_node("Paper/Tabs/Talents").visible and not character.has_node("Paper/TalentsPanel"), "unimplemented talents are not advertised")
	check(not character.has_node("Paper/SkillsPanel/Loadout"), "skill page only contains learned skill cards")
	var names: Array = character._skill_names()
	var grid: GridContainer = character.get_node("Paper/SkillsPanel/Scroll/Grid")
	for i in names.size():
		var worn: bool = game.hero_skills[0].martial.has(names[i]) or game.hero_skills[0].internal == names[i]
		check(grid.get_child(i).get_node("EquippedBadge").visible == worn, "only equipped skill cards display a check badge")
	character._select_party_hero(1)
	names = character._skill_names()
	for i in names.size():
		var worn: bool = game.hero_skills[1].martial.has(names[i]) or game.hero_skills[1].internal == names[i]
		check(grid.get_child(i).get_node("EquippedBadge").visible == worn, "badge state follows the selected hero")
	character._select_party_hero(0)
	character._show_tab("天赋")
	check(character.current_tab == "属性", "old talent tab preference falls back to attributes")
	character.queue_free()
	await process_frame
	game.selected_skill_name = "测试武学"
	var detail := _scene("skill_detail")
	await process_frame
	detail._on_equip_pressed()
	check(detail.replacement_menu.visible and detail.replacement_menu.item_count == 4, "full loadout offers a direct replacement picker")
	detail._replace_skill(1)
	check(game.hero_skills[0].martial[1] == "测试武学" and game.hero_skills[0].martial.size() == 4 and game.hero_skills[0].learned.has("降龙十八掌"), "replacement swaps the chosen slot without forgetting the previous skill")
	detail.queue_free()
	await process_frame
	game.learn_from_book(0, "易筋经")
	game.selected_skill_name = "易筋经"
	detail = _scene("skill_detail")
	await process_frame
	check(detail.get_node("Paper/Description").text.contains("切换后攻击") and game.hero_skills[0].internal == "九阳神功", "internal comparison previews stats without equipping")
	detail._on_equip_pressed()
	check(game.hero_skills[0].internal == "易筋经", "internal change applies only after choosing equip")
	detail.queue_free()
	await process_frame
	Fixture.reset(game)
	game.selected_party.assign([0, 1])
	game.new_battle()
	var hp: int = game.item_library["疗伤药"].heal_hp
	var mp: int = game.item_library["疗伤药"].heal_mp
	game.item_library["疗伤药"].heal_hp = 7
	game.item_library["疗伤药"].heal_mp = 9
	var battle := _scene("battle")
	await process_frame
	var actor: Dictionary = game.battle_allies[battle.selected_actor]
	actor.hp -= 20
	actor.mp -= 20
	battle._use_item("疗伤药")
	check(actor.hp == actor.max_hp - 13 and actor.mp == actor.max_mp - 11, "medicine uses table-driven HP and MP effects")
	game.item_library["疗伤药"].heal_hp = hp
	game.item_library["疗伤药"].heal_mp = mp
	battle.queue_free()
	await process_frame
	DirAccess.remove_absolute(game.get_save_path(1))
	DirAccess.remove_absolute(DIR)
	print("POLISH TESTS PASSED" if failures == 0 else "POLISH TESTS FAILED: %d" % failures)
	quit(failures)
