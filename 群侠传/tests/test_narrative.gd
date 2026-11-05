extends SceneTree

const Narrative = preload("res://scripts/narrative.gd")
var game: Node
var failures := 0
var battles := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func scene_is(name: String) -> Node:
	for frame in 60:
		await process_frame
		if current_scene != null and current_scene.name == name: return current_scene
	check(false, "missing scene " + name)
	return null

func capture(name: String) -> void:
	if OS.get_environment("QUNXIA_CAPTURE_DIR").is_empty(): return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("QUNXIA_CAPTURE_DIR").path_join(name + ".png"))

func check_map_panel_returns(map_name: String) -> void:
	for panel in [["Inventory", "_on_inventory_pressed"], ["Roster", "_on_character_pressed"], ["Journal", "_on_log_pressed"]]:
		var region_id: String = game.map_region_id
		current_scene.call(panel[1])
		var screen := await scene_is(panel[0])
		if screen == null: return
		screen._on_close_pressed()
		if await scene_is(map_name) == null: return
		check(game.map_region_id == region_id, "panel returns to the same map region")

func enter_place(id: String) -> Node:
	var parent: String = Narrative.location(game, id).parent
	if current_scene != null and current_scene.name == "RegionMap" and game.map_region_id != parent:
		current_scene._on_back_pressed()
		await scene_is("WorldMap")
	if current_scene != null and current_scene.name == "WorldMap":
		current_scene._on_location_pressed(parent)
	var region := await scene_is("RegionMap")
	if region == null: return null
	check(game.map_region_id == parent, "entered correct parent region")
	check(region.get_node("Locations").get_child_count() == Narrative.children(game, parent).size(), "region shows only its own children")
	if id == "jingzhou_prison" and game.narrative_progress.next == "prison_scout":
		check(region.get_node("Locations/jingzhou_yamen").disabled, "observing prison does not unlock yamen early")
	if id == "jingzhou_temple": await capture("region_jingzhou")
	region._on_location_pressed(id)
	return await scene_is("Location")

func _run() -> void:
	game = root.get_node("GameState")
	game.save_directory = "res://.review_artifacts/narrative_test"
	DirAccess.make_dir_recursive_absolute(game.save_directory)
	game.reset_new_game()
	game.settings.auto_save = false
	game.settings.auto_battle = true
	game.settings.music = false
	game.settings.sound = false
	game.apply_settings()
	Engine.time_scale = 8.0
	check(game.heroes[0].name == "宋青书", "new protagonist")
	check(game.can_visit("shaolin_room") and not game.can_visit("tianlong"), "chapter map locks")
	check(game.get_party_issue([0]).contains("经脉"), "injured protagonist cannot fight")
	check(not game.hero_available(1), "future companions hidden")
	game.goto("res://scenes/world_map.tscn")
	var map := await scene_is("WorldMap")
	if map == null: quit(1); return
	check(map.get_node("Locations").get_child_count() == 8 and not map.has_node("Locations/jingzhou_prison"), "world map groups sixteen places into eight regions")
	var top_background := map.get_node("TopBar/ReadableBackground") as Panel
	var top_style := top_background.get_theme_stylebox("panel") as StyleBoxFlat
	check(not map.has_node("TopBar/SilverIcon") and not map.has_node("TopBar/ReputationIcon"), "world map omits the silver and reputation prefix icons")
	check(map.get_node("TopBar").texture != null and top_background.z_index < 0, "world map keeps the original framed top-bar texture above its readable background")
	check(top_style.bg_color.a <= 0.63 and top_style.bg_color.r >= 0.27, "world map uses a lighter translucent background")
	var world_top_positions := {
		"Region":map.get_node("TopBar/Region").position,
		"Date":map.get_node("TopBar/Date").position,
		"Money":map.get_node("TopBar/Money").position,
		"Reputation":map.get_node("TopBar/Reputation").position
	}
	check(world_top_positions.Region == Vector2(654, 11) and world_top_positions.Money == Vector2(1127, 19), "world map top-bar information uses scene-authored positions")
	check(map.get_node("Locations/dali").disabled, "locked region button")
	map._on_location_pressed("shaolin")
	var region_map := await scene_is("RegionMap")
	if region_map == null: quit(1); return
	check(region_map.get_node("TopBar/Region").position == world_top_positions.Region and region_map.get_node("TopBar/Date").position == world_top_positions.Date and region_map.get_node("TopBar/Money").position == world_top_positions.Money and region_map.get_node("TopBar/Reputation").position == world_top_positions.Reputation, "region map top-bar layout follows the world map")
	await check_map_panel_returns("RegionMap")
	current_scene._on_back_pressed()
	if await scene_is("WorldMap") == null: quit(1); return
	await check_map_panel_returns("WorldMap")
	await capture("story_map_start")
	for raw in game.story_data.nodes:
		var node: Dictionary = raw
		check(game.narrative_progress.next == node.id, "story order " + node.id)
		if not node.get("interlude", false) and not node.get("automatic", false):
			var location := await enter_place(node.location)
			if location == null: quit(1); return
			check(not location.get_node("Interactions/NPC").disabled, "available story interaction")
			if node.id == "awake":
				location._on_back_pressed()
				var region := await scene_is("RegionMap")
				check(game.map_region_id == "shaolin", "leaf back returns to parent")
				region._on_back_pressed()
				await scene_is("WorldMap")
				location = await enter_place(node.location)
			if node.id == "medicine": await capture("story_yaowang")
			location._on_npc_pressed()
		var dialogue := await scene_is("Dialogue")
		if dialogue == null: quit(1); return
		check(dialogue.story_id == node.id and not dialogue.lines.is_empty(), "correct dialogue " + node.id)
		var rebuilt: Array[String] = []
		for line in dialogue.lines: rebuilt.append("")
		for page_index in dialogue.pages.size():
			var page: Dictionary = dialogue.pages[page_index]
			rebuilt[page.record] += page.text
			dialogue.index = page_index
			dialogue._show_line()
			check(dialogue.get_node("DialogueBox/Text").get_line_count() <= 3, "source page fits text box " + node.id)
		for i in dialogue.lines.size(): check(rebuilt[i] == dialogue.lines[i][1], "pagination does not rewrite source text")
		dialogue.index = 0
		dialogue._show_line()
		if node.id == "awake":
			check(not dialogue.get_node("Portrait").visible, "narrator has no fake portrait")
			dialogue._on_continue_pressed()
			check(dialogue.get_node("Portrait").visible, "speaker portrait appears")
			dialogue._on_previous_pressed()
			check(dialogue.index == 0 and game.narrative_progress.next == "awake", "previous page does not advance the story")
			dialogue._on_continue_pressed()
			await capture("story_dialogue")
		if node.id == "chapter_end": await capture("story_ending")
		dialogue._on_skip_pressed()
		if node.has("battle"):
			battles += 1
			var prep := await scene_is("BattlePrep")
			if prep == null: quit(1); return
			check(game.narrative_progress.pending, "dialogue cannot skip story battle")
			check(game.get_party_issue(game.selected_party).is_empty(), "story party ready " + node.id)
			if node.id == "tavern":
				game.inventory.append("朴刀")
				game.equip_item(1, "朴刀")
			if node.id == "yamen":
				game.inventory.append("粗布道袍")
				game.equip_item(2, "粗布道袍")
				game.selected_hero = 2
			check(game.save_slot(1) == OK, "pending battle saves")
			game.reset_new_game()
			check(game.load_slot(1) == OK and game.narrative_progress.next == node.id and game.narrative_progress.pending, "pending battle restores")
			check(game.current_encounter == node.battle, "encounter restores")
			game.new_battle()
			game.settle_battle(false)
			check(game.narrative_progress.next == node.id, "defeat never advances story")
			game.new_battle()
			if node.id == "six_monks": check(game.battle_enemies.size() == 6, "six monks generated")
			if node.id == "six_monks":
				var positions: Array = []
				for enemy in game.battle_enemies:
					check(not positions.has(enemy.coord) and enemy.coord.y >= 2 and enemy.coord.y <= 8, "six distinct valid board positions")
					positions.append(enemy.coord)
			game.goto("res://scenes/battle.tscn")
			var battle := await scene_is("Battle")
			if battle == null: quit(1); return
			if node.id == "six_monks":
				check(battle.get_node("Board/Enemies").get_child_count() == 6, "six enemy UI units")
				await capture("story_tianlong")
			var started := Time.get_ticks_msec()
			while current_scene != null and current_scene.name == "Battle" and Time.get_ticks_msec() - started < 45000:
				await process_frame
			var result := await scene_is("BattleResult")
			if result == null: quit(1); return
			check(game.battle_outcome == "胜利", "automatic story battle is winnable " + node.id)
			check(game.narrative_progress.next != node.id, "victory advances story")
			var money: int = game.money
			game.settle_battle(true)
			check(game.money == money, "settlement is idempotent")
			result._on_confirm_pressed()
		if node.id == "rebirth":
			check(Narrative.healed(game) and not game.hero_available(1), "healed and mother departs")
			check(game.hero_skills[0].internal == "神照经", "full shenzhao granted and equipped")
			check(game.inventory.has("朴刀") and str(game.hero_equipment[1].get("weapon", "")).is_empty(), "departing mother returns loaned weapon")
		if node.id == "yamen_after":
			check(not game.hero_available(2) and game.selected_hero == 0, "Huang Rong stays at yamen and selection resets")
			check(str(game.hero_equipment[2].get("armor", "")).is_empty(), "temporary companion returns armor")
		var followup: String = Narrative.followup_scene(game)
		if not followup.ends_with("dialogue.tscn"): await scene_is("RegionMap" if followup.ends_with("region_map.tscn") else "WorldMap")
	check(battles == 3 and game.narrative_progress.next.is_empty() and game.seen_stories.size() == 25, "all twenty-five source-bound nodes complete")
	check(game.inventory.count("剑冢木剑") == 1 and not game.hero_skills[0].learned.has("六脉神剑"), "source faithful ending rewards")
	var money: int = game.money
	game.complete_story("medicine")
	check(game.money == money, "replaying dialogue never repeats reward")
	check(game.save_slot(2) == OK, "ending saves")
	game.reset_new_game()
	check(game.load_slot(2) == OK and game.narrative_progress.next.is_empty(), "ending reloads")
	check(game.inventory.count("剑冢木剑") == 1, "quest item stable ID round trip")
	var shop: Node = load("res://scenes/shop.tscn").instantiate()
	root.add_child(shop)
	check(shop._find_good("剑冢木剑").is_empty(), "story keepsake cannot be sold")
	shop.queue_free()
	var inventory: Node = load("res://scenes/inventory.tscn").instantiate()
	root.add_child(inventory)
	inventory._show_category("Tasks")
	check(inventory._visible_items() == ["剑冢木剑"], "keepsake appears in quest category")
	inventory.queue_free()
	game.goto("res://scenes/world_map.tscn")
	await scene_is("WorldMap")
	await capture("story_map_complete")
	game.character_tab = "列传"
	game.goto("res://scenes/character.tscn")
	await scene_is("Character")
	await capture("story_biography")
	var cfg := ConfigFile.new()
	cfg.load(game.get_save_path(2))
	cfg.set_value("progress", "adventure", {"next":"invalid", "pending":false})
	cfg.save(game.get_save_path(3))
	check(game.load_slot(3) == ERR_FILE_CORRUPT and game.narrative_progress.next.is_empty(), "corrupt story rejected without mutation")
	cfg.set_value("meta", "version", 3)
	cfg.erase_section_key("progress", "adventure")
	cfg.save(game.get_save_path(3))
	check(game.load_slot(3) == OK and game.narrative_progress.next == "awake" and game.current_scene == "少林厢房", "legacy save begins new story")
	check(game.inventory.has("剑冢木剑"), "legacy migration preserves inventory")
	check(game.save_slot(3) == OK and FileAccess.file_exists(game.get_save_path(3) + ".v3.bak"), "v3 backup retained")
	print("NARRATIVE TESTS PASSED: 25 nodes, 8 regions / 17 places, hierarchy navigation, 3 live battles, saves, migration" if failures == 0 else "NARRATIVE FAILURES: %d" % failures)
	quit(0 if failures == 0 else 1)
