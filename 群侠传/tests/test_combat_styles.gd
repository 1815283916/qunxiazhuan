extends SceneTree

const Rules = preload("res://scripts/combat_rules.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func unit(passive: String = "") -> Dictionary:
	return {"name":"测试单位", "alive":true, "hp":200, "max_hp":200, "mp":100,
		"max_mp":100, "attack":100, "defense":0, "passive":passive,
		"move_range":3, "action_delay":90, "next_action":90}

func _test_rules() -> void:
	var messages: Array = []
	var actor := unit()
	check(Rules.apply(actor, "haste", 3, 2, 45) and actor.next_action == 78, "haste preserves existing timeline progress")
	Rules.begin(actor, messages)
	Rules.apply(actor, "heal_regen", 2, 2, 78)
	Rules.finish(actor, 78)
	check(actor.statuses.heal_regen.duration == 2, "fresh self buffs do not expire on their cast action")
	actor.hp = 100
	actor.mp = 10
	for effect in ["wound", "internal_wound", "mana_regen", "poison"]:
		Rules.apply(actor, effect, 1, 2, 80)
	Rules.begin(actor, messages)
	check(actor.hp == 105 and actor.mp == 12, "poison ticks before healing and both wound types halve recovery")
	Rules.finish(actor, 143)
	Rules.apply(actor, "stun", 1, 1, 143)
	Rules.begin(actor, messages)
	check(actor.skipped_turn, "stun skips a normal action")
	Rules.finish(actor, 233)
	check(not Rules.apply(actor, "stun", 1, 1, 234), "stun cannot lock the next normal action")
	Rules.begin(actor, messages)
	Rules.finish(actor, 323)
	check(Rules.apply(actor, "stun", 1, 1, 324), "normal action ends stun recovery")
	Rules.apply(actor, "harmony", 1, 1, 324)
	check(Rules.layers(actor, "stun") == 0 and not Rules.apply(actor, "poison", 1, 1, 324), "harmony cleanses and rejects new debuffs")

	var swift := unit("swift")
	check(not Rules.apply(swift, "root", 1, 1, 0) and not Rules.apply(swift, "paralysis", 1, 1, 0), "swift passive prevents root and paralysis")
	Rules.begin(swift, messages)
	Rules.finish(swift, 90)
	Rules.apply(swift, "chill", 5, 2, 90)
	Rules.begin(swift, messages)
	check(swift.mp == 87 and Rules.interval(swift) == 90 and Rules.focused(swift), "swift ignores chill speed but still loses mana")
	Rules.consume_focus(swift)
	check(not Rules.focused(swift) and is_equal_approx(Rules.attack(swift), 130), "swift focus is consumed by an attack")
	Rules.finish(swift, 180)
	Rules.lose_hp(swift, 1)
	Rules.begin(swift, messages)
	check(not Rules.focused(swift), "damage breaks the swift opening bonus")

	var attacker := unit("reflect")
	var defender := unit("reflect")
	check(Rules.strike(attacker, defender, 100, false, true, messages, 100) == 70, "mirror armor reduces direct damage")
	check(attacker.hp == 150 and defender.hp == 130 and Rules.movement(defender) == 2, "reflection uses pre-passive damage and does not recurse")
	var shield := unit("inner")
	shield.mp = 20
	check(Rules.strike(unit(), shield, 50, false, true, messages, 100) == 30 and shield.mp == 0, "inner shield cannot spend more mana than available")
	var target := unit()
	target.mp = 0
	check(Rules.strike(unit("inner"), target, 100, false, true, messages, 100) == 125, "mana difference bonus is capped at 25 percent")

func _run() -> void:
	_test_rules()
	var game := root.get_node("GameState")
	game.reset_new_game()
	game.settings.auto_battle = false
	game.settings.auto_save = false
	game.settings.music = false
	game.settings.sound = false
	game.apply_settings()
	check(game.skill_library["易筋经"].icon.ends_with("icon_neigong_035.jpg"), "Yi Jin Jing uses its new internal skill icon")
	check(game.skill_library["九阴真经"].icon.ends_with("icon_neigong_036.jpg"), "Nine Yin Manual uses its new internal skill icon")
	var manual_icons := {
		"狂风刀法秘籍":"daofamiji.jpg",
		"独孤九剑秘籍":"jianfamiji.jpg",
		"打狗棒法秘籍":"qimenmiji.jpg",
		"降龙十八掌秘籍":"quanfamiji.jpg",
		"九阳神功秘籍":"xinfamiji.jpg",
	}
	for book_name in manual_icons:
		var icon_path: String = game.item_library[book_name].icon
		check(icon_path.ends_with(manual_icons[book_name]) and FileAccess.file_exists(icon_path), "%s uses its matching manual category icon" % book_name)
	Engine.time_scale = 8.0
	var style_icons := {}
	for skill_name in game.skill_library:
		var skill: Dictionary = game.skill_library[skill_name]
		if not "_style_" in skill.id: continue
		check(not style_icons.has(skill.icon), "style skills do not share icons")
		style_icons[skill.icon] = true
		var book: String = skill_name + "秘籍"
		check(game.item_library[book].shop, "style manual is available at the shop")
		game.inventory.append(book)
		game.learn_from_book(0, book)
		check(game.hero_skills[0].learned.has(skill_name), "style manual teaches the corresponding skill")
	check(style_icons.size() == 21, "all style skills are present in exported workbooks")
	game.equip_skill(0, "回春架")
	game.equip_skill(0, "断脉掌")
	game.equip_skill(0, "掠影指")
	game.unequip_skill(0, "降龙十八掌")
	game.equip_skill(0, "流星连式")
	game.equip_skill(0, "镜甲心法")
	var original_defense: int = game.get_hero_combat_stats(0).defense
	game.hero_skills[0].levels["镜甲心法"] = 3
	check(game.get_hero_combat_stats(0).defense == original_defense + 4, "equipped style internal grows by its configured per-level defense")
	var panel_attack: int = game.get_hero_combat_stats(0).attack
	game.new_battle()
	for enemy in game.battle_enemies: enemy.next_action = 900
	var battle := load("res://scenes/battle.tscn").instantiate() as Control
	root.add_child(battle)
	var actor: Dictionary = game.battle_allies[0]
	check(actor.attack == roundi(panel_attack * 1.1), "mighty talent increases final attack by ten percent when entering battle")
	check(game.get_hero_combat_stats(0).attack == panel_attack, "battle-only talent does not change character panel attack")
	check(actor.talent.name == "力大无穷", "battle actor retains its configured talent")
	check(actor.passive == "reflect", "equipped passive reaches the battle actor")
	check(actor.defense == original_defense + 4, "battle receives the same internal defense bonus as the character panel")
	var sword_index: int = battle.current_skills.find("流星连式")
	var original_skill: String = battle.current_skills[0]
	battle.current_skills[0] = "狂风刀法"
	var direction: Vector2i = actor.coord + Vector2i.RIGHT
	check(battle._can_target(direction, sword_index) and battle._affected_coords(direction, sword_index).size() == 4, "style sword uses the same four-cell line as the other sword skills")
	check(not battle._can_target(actor.coord + Vector2i(2, 0), sword_index), "sword chooses direction from an adjacent cell only")
	check(battle._affected_coords(direction, 0).size() == 6, "fan attack covers two rows of three cells")
	Rules.apply(actor, "blind", 1, 1, game.turn)
	check(battle._affected_coords(direction, 0).size() == 3, "blind restricts the configured blade school to the front row")
	check(battle._affected_coords(direction, sword_index).size() == 2, "blind shortens a sword line to two cells")
	battle.current_skills[0] = original_skill
	check(battle._affected_coords(actor.coord, battle.current_skills.find("回春架")).is_empty(), "buff-granting skills cannot target the caster")
	actor.statuses.erase("blind")
	var enemy: Dictionary = game.battle_enemies[0]
	enemy.coord = actor.coord + Vector2i(2, 2)
	var auto_choice: Dictionary = battle._choose_auto_action()
	check(not auto_choice.is_empty() and battle.current_skills[auto_choice.index] == "掠影指" and auto_choice.affected.has(enemy), "auto uses the cross hit area to reach beyond the cast cell")
	check(battle.selected_skill == -1, "auto targeting does not change the current selection")
	var original_position: Vector2i = actor.coord
	battle._on_tile_pressed(original_position.y * 16 + original_position.x + 1)
	battle.auto_action_running = true
	battle._update_undo_button()
	battle._on_undo_move_pressed()
	check(battle.get_node("UndoMove").disabled and actor.coord != original_position, "undo cannot interrupt automatic movement")
	battle.auto_action_running = false
	battle._on_undo_move_pressed()
	check(actor.coord == original_position, "manual undo works after the auto action releases control")
	var index: int = battle.current_skills.find("回春架")
	check(not battle._can_target(actor.coord, index) and battle._affected_coords(direction, index) == [direction], "recovery stance uses the shared palm template")
	check(game.skill_library["回春架"].description.contains("恢复2级（2回合）（我）") and game.skill_library["玄寒掌"].description.contains("寒冷5级（2回合）（敌）"), "skill descriptions show the target after the duration")
	battle.current_skills[index] = "流星连式"
	battle._on_skill_hovered(index)
	var hover_details := battle.get_node("HoverInfo/Details") as RichTextLabel
	var effect_details := hover_details.get_parsed_text()
	check(effect_details.ends_with("神速3级（2回合）（我）\n连击3级（1回合）（我）") and not effect_details.contains("获得"), "skill hover displays each effect on its own line without trigger wording")
	check(hover_details.text.contains(Rules.highlight_status("神速3级（2回合）（我）")), "skill hover highlights the buff in yellow")
	battle.current_skills[index] = "回春架"
	battle._on_skill_hovered(index)
	check(not battle.get_node("HoverInfo/Details").text.contains("自身施展"), "skill hover has no self-targeting hint")
	battle._select_skill(index)
	var mp_before_attack: int = actor.mp
	await battle._on_ally_pressed(0)
	check(actor.action_number == 1 and actor.mp == mp_before_attack and Rules.layers(actor, "heal_regen") == 0, "clicking the caster does not use the martial skill")
	var enemy_hp: int = enemy.hp
	await battle._on_tile_pressed(direction.y * 16 + direction.x)
	check(actor.action_number == 2 and Rules.cooldown(actor, "回春架") == 1 and actor.mp < mp_before_attack, "empty cast uses mana, consumes one action and starts the shared cooldown")
	check(enemy.hp == enemy_hp and Rules.layers(actor, "heal_regen") == 2 and Rules.layers(enemy, "heal_regen") == 0, "empty cast applies on-cast buffs without damaging enemies")
	battle._on_rest_pressed()
	check(Rules.cooldown(actor, "回春架") == 0, "cooldown 2 expires at the third normal action")
	Rules.apply(actor, "combo", 3, 1, game.turn)
	for value in range(100):
		seed(value)
		if randf() < 0.4:
			seed(value)
			break
	var turn: int = actor.action_number
	var time: int = game.turn
	var hp: int = actor.hp
	var mp: int = actor.mp
	battle._complete_actor_action(true)
	check(actor.bonus_attack and actor.action_number == turn and game.turn == time, "combo grants one attack without advancing the timeline")
	check(battle._reachable_tiles(actor).is_empty() and battle._can_target(direction, index), "combo disallows movement and keeps legal martial targets")
	enemy.coord = actor.coord + Vector2i.RIGHT
	actor.used_skills = battle.current_skills.duplicate()
	actor.mp = 0
	check(battle._choose_auto_action().is_empty(), "auto can end a combo when the only reachable attack was already used")
	actor.mp = mp
	battle._on_rest_pressed()
	check(not actor.bonus_attack and actor.action_number == turn + 1 and actor.hp == hp and actor.mp == mp, "ending a combo cannot grant a free rest")
	check(not game.skill_library.has("普攻") and not battle.has_node("BasicAttack"), "basic attacks are removed from runtime and UI")
	var enemy_mana: int = enemy.mp
	Rules.begin(enemy, game.battle_log)
	await battle._enemy_take_action(0)
	check(enemy.mp == enemy_mana - game.skill_library["狂风刀法"].cost and game.battle_log.any(func(line: String) -> bool: return line.contains("施展狂风刀法")), "enemy casts its equipped martial skill and pays its cost")
	battle._on_enemy_hovered(0)
	var enemy_details: String = battle.get_node("HoverInfo/Details").text
	check(enemy_details.contains("内力") and not enemy_details.contains("狂风刀法"), "enemy hover shows vitals, while the loadout is available in the overview")
	enemy.mp = 0
	var health_before_rest: int = actor.hp
	Rules.begin(enemy, game.battle_log)
	await battle._enemy_take_action(0)
	check(enemy.mp == 15 and actor.hp == health_before_rest, "enemy with insufficient mana rests without attacking")
	battle.queue_free()
	await process_frame
	if failures == 0: print("COMBAT STYLES TESTS PASSED")
	quit(failures)
