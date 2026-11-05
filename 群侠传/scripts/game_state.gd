extends Node

const MALE_BATTLE_MODEL := "res://assets/Animations/r-nan-zhoucang"
var HERO_MODEL_PATHS: Array[String] = []

var money := 1280
var reputation := 120
var current_location := "嵩山"
var current_scene := "少林厢房"
var map_region_id := ""
var map_panel_return_scene := "res://scenes/world_map.tscn"
var selected_hero := 0
var heroes: Array = []
var hero_stats: Array = []
var selected_party: Array[int] = [0]
var hero_equipment := [{}, {}, {}, {}, {}, {}]
var equipment_library: Dictionary = {}
var item_library: Dictionary = {}
var skill_library: Dictionary = {}
var hero_skills: Array = []
var inventory := ["魔神拳套", "朴刀", "凝神枪", "魔神剑", "粗布道袍", "乌蚕衣", "毒戒指", "宝玉", "大还丹", "疗伤药", "独孤九剑秘籍", "易筋经"]
var journal: Array = []
var reward_money := 200
var reward_exp := 120
var selected_item := "魔神拳套"
var detail_return_scene := "res://scenes/inventory.tscn"
var character_tab := ""
var character_return_scene := "res://scenes/roster.tscn"
var selected_skill_name := "独孤九剑"
var selected_skill_kind := "武学"
var settings := {
	"show_hp": true,
	"show_battle_log": true,
	"auto_save": false,
	"auto_battle": false,
	"battle_speed": 1.0,
	"music": true,
	"sound": true,
	"fullscreen": false
}
var player_hp := 100
var player_mp := 60
var enemy_hp := 120
var turn := 1
var battle_allies: Array[Dictionary] = []
var battle_enemies: Array[Dictionary] = []
var battle_log: Array[String] = []
var battle_outcome := "胜利"
const SAVE_VERSION := 4
const SkillLoadout = preload("res://scripts/skill_loadout.gd")
const SaveCodec = preload("res://scripts/save_codec.gd")
var HERO_LEVEL_CAP := 30
var HERO_LEVEL_EXP_MULTIPLIER := 200
var SKILL_LEVEL_CAP := 10
var SKILL_LEVEL_EXP_MULTIPLIER := 40
const LEGACY_SKILL_NAMES := {"落英神剑掌":"降龙十八掌", "漫天花雨":"打狗棒法"}
const LEGACY_ITEM_NAMES := {"玄铁剑":"魔神拳套", "君子剑":"朴刀", "淑女剑":"凝神枪"}
const Adventure = preload("res://scripts/adventure.gd")
var _new_game_defaults: Dictionary = {}
var save_directory := "user://"
var session_started := false
var menu_return_scene := "res://scenes/main_menu.tscn"
const Narrative = preload("res://scripts/narrative.gd")
var story_data: Dictionary = {}
var narrative_progress := {"next":"awake", "pending":false}
var quest_stage := 0
var current_encounter := "江湖切磋"
var battle_rewards: Dictionary = {}
var _battle_progress_before: Dictionary = {}
var growth: Dictionary = {}
var story_dialogues: Dictionary = {}
var dialogue_story_id := ""
var seen_stories: Array[String] = []

func get_story_lines(id: String) -> Array:
	var lines: Array = story_dialogues.get(id, {}).get("lines", []).duplicate(true)
	for line in lines:
		if line[0] == "主角": line[0] = heroes[0].name
	return lines

func complete_story(id: String) -> void:
	Narrative.complete(self, id)

func get_objective() -> String:
	return Narrative.objective(self)

func complete_dialogue() -> String:
	complete_story(dialogue_story_id)
	return ""

func can_visit(place: String) -> bool:
	for entry in story_data.locations:
		if entry.id == place or entry.name == place: return Narrative.visitable(self, entry.id)
	for entry in story_data.regions:
		if entry.id == place or entry.name == place: return Narrative.region_open(self, entry.id)
	return false

func hero_available(index: int) -> bool:
	return Narrative.available(self, index)

func get_party_issue(party: Array) -> String:
	if party.is_empty(): return "请至少选择一名侠客"
	if party.size() > 3: return "最多选择三名侠客"
	for index in party:
		if index < 0 or index >= heroes.size(): return "出战侠客无效"
		if not hero_available(index): return "%s当前未同行" % heroes[index].name
		if index == 0 and not Narrative.healed(self): return "宋青书经脉未续，暂不能出战"
		var loadout: Dictionary = hero_skills[index]
		if loadout.get("martial", []).is_empty():
			for name in loadout.get("learned", []):
				if skill_library.has(name) and skill_library[name].kind == "武学": return "%s尚未装备武学，请到人物技能页装备后再出战" % heroes[index].name
			return "%s尚未学习武学，请从背包研习秘籍后再出战" % heroes[index].name
		for skill in loadout.martial:
			if not skill_library.has(skill) or skill_library[skill].kind != "武学": return "%s的武学配置无效，请重新研习秘籍" % heroes[index].name
		var internal := str(loadout.get("internal", ""))
		if not skill_library.has(internal) or skill_library[internal].kind != "心法": return "%s尚未装备心法" % heroes[index].name
	return ""

func settle_battle(victory: bool, bonus_roll: float = -1.0) -> Dictionary:
	# 发奖与界面使用同一份快照，重复打开结算不重复发奖。
	if not battle_rewards.is_empty(): return battle_rewards
	battle_outcome = "胜利" if victory else "失败"
	battle_rewards = {"money":0, "items":[], "heroes":[], "victory":victory}
	if not victory:
		_rollback_battle_progress()
		journal.append("%s挑战失利，可重新整备后再战。" % current_encounter)
		return battle_rewards
	_battle_progress_before.clear()
	battle_rewards.money = reward_money
	money += reward_money
	var drops: Array[String] = ["疗伤药"]
	var roll := randf() if bonus_roll < 0 else bonus_roll
	if roll < 0.15: drops.append("粗布道袍")
	elif roll < 0.4: drops.append("大还丹")
	for item in drops: inventory.append(item)
	battle_rewards.items = drops
	var rewarded: Array[int] = []
	for actor in battle_allies:
		var index: int = actor.hero_index
		if rewarded.has(index): continue
		rewarded.append(index)
		var before: int = heroes[index].level
		gain_hero_experience(index, reward_exp)
		battle_rewards.heroes.append({"name":heroes[index].name, "exp":reward_exp, "before":before, "after":heroes[index].level})
	journal.append("%s获胜，获得银两%d。" % [story_data.encounters.get(current_encounter, {"name":current_encounter}).name, reward_money])
	if narrative_progress.pending:
		Narrative.complete(self, narrative_progress.next, true)
	return battle_rewards

func _rollback_battle_progress() -> void:
	if _battle_progress_before.is_empty(): return
	inventory = _battle_progress_before.inventory
	heroes = _battle_progress_before.heroes
	hero_stats = _battle_progress_before.hero_stats
	hero_skills = _battle_progress_before.hero_skills
	_battle_progress_before.clear()

func set_setting(key: String, value: Variant) -> void:
	if not settings.has(key): return
	settings[key] = value
	apply_settings()
	var cfg := ConfigFile.new()
	cfg.set_value("settings", "values", settings)
	var err := cfg.save(save_directory.path_join("preferences.cfg"))
	if err != OK: push_warning("设置保存失败：%s" % error_string(err))

func apply_settings() -> void:
	if DisplayServer.get_name() != "headless":
		var current_mode := DisplayServer.window_get_mode()
		var target_mode := _window_mode_for_setting(current_mode, bool(settings.fullscreen))
		if target_mode != current_mode: DisplayServer.window_set_mode(target_mode)
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null and audio.music_player != null: audio.apply_settings(settings)

func _window_mode_for_setting(current_mode: int, fullscreen_enabled: bool) -> int:
	var is_fullscreen := current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN or current_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if fullscreen_enabled:
		return current_mode if is_fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN
	return DisplayServer.WINDOW_MODE_WINDOWED if is_fullscreen else current_mode

func get_save_path(slot: int) -> String:
	return save_directory.path_join("qunxia_auto.cfg" if slot == 0 else "qunxia_slot_%d.cfg" % slot)

func delete_save(slot: int) -> Error:
	if slot < 0 or slot > 4: return ERR_INVALID_PARAMETER
	var path := get_save_path(slot)
	var candidates: Array[String] = [path, path + ".tmp"]
	for version in SAVE_VERSION + 1:
		candidates.append(path + ".v%d.bak" % version)
	var removed := false
	for candidate in candidates:
		if not FileAccess.file_exists(candidate): continue
		var err := DirAccess.remove_absolute(candidate)
		if err != OK: return err
		removed = true
	return OK if removed else ERR_FILE_NOT_FOUND

func load_latest() -> Error:
	var candidates: Array[Dictionary] = []
	for slot in 5:
		var cfg := ConfigFile.new()
		var path := get_save_path(slot)
		if cfg.load(path) != OK: continue
		var timestamp: Variant = cfg.get_value("meta", "saved_unix", FileAccess.get_modified_time(path))
		if not (timestamp is int or timestamp is float): timestamp = FileAccess.get_modified_time(path)
		candidates.append({"slot":slot, "time":float(timestamp)})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.time > b.time)
	for candidate in candidates:
		if load_slot(int(candidate.slot)) == OK: return OK
	return ERR_FILE_NOT_FOUND

func autosave() -> Error:
	if not session_started or not bool(settings.auto_save): return OK
	return save_slot(0)


func _trim_roster_to_six() -> void:
	heroes.resize(HERO_MODEL_PATHS.size())
	hero_stats.resize(HERO_MODEL_PATHS.size())
	hero_equipment.resize(HERO_MODEL_PATHS.size())
	hero_skills.resize(HERO_MODEL_PATHS.size())
	for i in HERO_MODEL_PATHS.size():
		heroes[i]["model"] = HERO_MODEL_PATHS[i]

func _ready() -> void:
	if not _load_configuration():
		get_tree().quit(1)
		return
	_trim_roster_to_six()
	hero_equipment = _empty_equipment_loadout()
	_synchronize_loaded_configuration()
	money = int(story_data.initial.money)
	reputation = int(story_data.initial.reputation)
	var start := Narrative.location(self, story_data.initial.location)
	current_location = start.region
	current_scene = start.name
	inventory = story_data.initial.inventory.duplicate()
	hero_skills[0] = story_data.initial.skills.duplicate(true)
	journal = ["屠狮大会后，宋青书在少林厢房醒来。当前经脉尽断，须寻医续脉。"]
	var preferences := ConfigFile.new()
	if preferences.load(save_directory.path_join("preferences.cfg")) == OK:
		var values: Variant = preferences.get_value("settings", "values", {})
		if values is Dictionary:
			for key in settings:
				if values.get(key) is bool: settings[key] = values[key]
			settings.battle_speed = 2.0 if values.get("battle_speed", 1.0) == 2.0 else 1.0
	apply_settings()
	# 深拷贝一份初始进度；设置项不放入快照，便于新游戏保留玩家偏好。
	_new_game_defaults = {
		"money": money, "reputation": reputation,
		"current_location": current_location, "current_scene": current_scene,
		"selected_hero": selected_hero, "heroes": heroes.duplicate(true),
		"hero_stats": hero_stats.duplicate(true), "selected_party": selected_party.duplicate(true),
		"hero_equipment": hero_equipment.duplicate(true), "hero_skills": hero_skills.duplicate(true),
		"inventory": inventory.duplicate(true), "journal": journal.duplicate(true),
		"selected_item": selected_item, "detail_return_scene": detail_return_scene,
		"character_tab": character_tab,
		"selected_skill_name": selected_skill_name, "selected_skill_kind": selected_skill_kind
	}

func _empty_equipment_loadout() -> Array:
	var loadout: Array = []
	for _i in HERO_MODEL_PATHS.size(): loadout.append({})
	return loadout

func reset_new_game() -> void:
	if _new_game_defaults.is_empty(): return
	character_return_scene = "res://scenes/roster.tscn"
	session_started = true
	quest_stage = 0
	map_region_id = ""
	map_panel_return_scene = "res://scenes/world_map.tscn"
	narrative_progress = {"next":"awake", "pending":false}
	dialogue_story_id = ""
	seen_stories.clear()
	current_encounter = "江湖切磋"
	battle_rewards.clear()
	_battle_progress_before.clear()
	money = int(_new_game_defaults.money)
	reputation = int(_new_game_defaults.reputation)
	current_location = str(_new_game_defaults.current_location)
	current_scene = str(_new_game_defaults.current_scene)
	selected_hero = int(_new_game_defaults.selected_hero)
	heroes = _new_game_defaults.heroes.duplicate(true)
	hero_stats = _new_game_defaults.hero_stats.duplicate(true)
	selected_party = _new_game_defaults.selected_party.duplicate(true)
	hero_equipment = _new_game_defaults.hero_equipment.duplicate(true)
	hero_skills = _new_game_defaults.hero_skills.duplicate(true)
	inventory = _new_game_defaults.inventory.duplicate(true)
	journal = _new_game_defaults.journal.duplicate(true)
	selected_item = str(_new_game_defaults.selected_item)
	detail_return_scene = str(_new_game_defaults.detail_return_scene)
	character_tab = str(_new_game_defaults.character_tab)
	selected_skill_name = str(_new_game_defaults.selected_skill_name)
	selected_skill_kind = str(_new_game_defaults.selected_skill_kind)
	player_hp = 100
	player_mp = 60
	enemy_hp = 120
	turn = 0
	battle_allies.clear()
	battle_enemies.clear()
	battle_log.clear()
	battle_outcome = "胜利"

func new_battle() -> void:
	_rollback_battle_progress()
	battle_rewards = {}
	var encounter: Dictionary = story_data.encounters.get(current_encounter, Adventure.encounter(current_encounter))
	reward_money = encounter.money
	reward_exp = encounter.exp
	battle_allies.clear()
	battle_enemies.clear()
	battle_log.clear()	
	turn = 0
	for i in mini(selected_party.size(), 3):
		var hero_index: int = selected_party[i]
		if hero_index < 0 or hero_index >= heroes.size(): continue
		var hero: Dictionary = heroes[hero_index]
		var model_path := get_hero_model_path(hero_index)
		var combat := get_hero_combat_stats(hero_index)
		var talent: Dictionary = hero.get("talent", {})
		var battle_attack := get_hero_battle_attack(hero_index, combat.attack)
		var max_hp: int = combat.max_hp
		var max_mp: int = combat.max_mp
		battle_allies.append({
			"hero_index":hero_index, "name":hero.name, "head":hero.head, "model":model_path,
			"passive":skill_library.get(hero_skills[hero_index].internal, {}).get("passive", ""),
			"hp":max_hp, "max_hp":max_hp, "mp":max_mp, "max_mp":max_mp,
			"attack":battle_attack, "defense":combat.defense, "crit":combat.crit,
			"talent":talent.duplicate(true),
			"crit_damage":combat.crit_damage, "poison":combat.poison,
			"fist":combat.fist, "sword":combat.sword, "blade":combat.blade, "unorthodox":combat.unorthodox, "insight":combat.insight, "luck":combat.luck, "willpower":combat.willpower,
			"coord":Vector2i(2, i + 3), "alive":true, "moved":false,
			"move_range":clampi(2 + int(combat.speed / 90.0), 2, 3),
			"speed":combat.speed, "action_delay":clampi(120 - int(combat.speed), 35, 90),
			"next_action":clampi(120 - int(combat.speed), 35, 90)
		})
	for i in int(encounter.count):
		battle_enemies.append({
			"name":encounter.enemy, "head":"res://assets/Heads/fangyi.png", "model":MALE_BATTLE_MODEL,
			"martial":encounter.martial,
			"skill_power_percent":int(encounter.get("skill_power_percent", 100)),
			"hp":encounter.hp, "max_hp":encounter.hp, "mp":50, "max_mp":50, "attack":encounter.attack, "defense":encounter.defense, "poison_turns":0, "willpower":15,
			"coord":Vector2i(12 + (i % 2) * 2, 3 + (i / 2) * 2) if int(encounter.count) > 3 else Vector2i(13, i + 3), "alive":true, "move_range":2,
			"speed":52 - i * 2, "action_delay":68 + i * 3, "next_action":68 + i * 3
		})
	if battle_allies.is_empty():
		selected_party.clear()
		selected_party.append(0)
		new_battle()
	player_hp = 100
	player_mp = 60
	enemy_hp = int(encounter.hp) * int(encounter.count)
	battle_outcome = "胜利"
	# 战中成长即时生效，消耗和成长在胜利后保留。
	_battle_progress_before = {
		"inventory": inventory.duplicate(),
		"heroes": heroes.duplicate(true),
		"hero_stats": hero_stats.duplicate(true),
		"hero_skills": hero_skills.duplicate(true)
	}

func get_hero_battle_attack(hero_index: int, base_attack: int) -> int:
	if hero_index < 0 or hero_index >= heroes.size(): return base_attack
	var talent: Dictionary = heroes[hero_index].get("talent", {})
	var bonus_percent := int(talent.get("battle_attack_percent", 0))
	return roundi(float(base_attack) * (100.0 + bonus_percent) / 100.0)

func get_hero_model_path(hero_index: int) -> String:
	if hero_index >= 0 and hero_index < heroes.size():
		var configured := str(heroes[hero_index].get("model", ""))
		if not configured.is_empty(): return configured
	# The first two roster entries are male; the remaining current entries are female.
	return HERO_MODEL_PATHS[clampi(hero_index, 0, HERO_MODEL_PATHS.size() - 1)]

func gain_hero_experience(hero_index: int, amount: int) -> int:
	if hero_index < 0 or hero_index >= heroes.size() or amount <= 0: return 0
	var hero: Dictionary = heroes[hero_index]
	hero.exp = int(hero.get("exp", 0)) + amount
	var previous_level: int = hero.level
	while hero.level < HERO_LEVEL_CAP and hero.exp >= get_hero_experience_needed(hero.level):
		hero.exp -= get_hero_experience_needed(hero.level)
		hero.level += 1
		hero.attack += int(growth.hero_level_attack)
		hero.speed += int(growth.hero_level_speed)
		hero.defense += int(growth.hero_level_defense)
		var stats: Dictionary = hero_stats[hero_index]
		for attribute in ["strength", "agility", "insight", "luck", "constitution", "willpower"]:
			stats[attribute] += 1
		for technique in ["fist", "sword", "blade", "unorthodox"]:
			stats[technique] += 2
	var level_text := "，升至%d级" % hero.level if hero.level > previous_level else ""
	battle_log.append("%s获得%d经验%s" % [hero.name, amount, level_text])
	return hero.level - previous_level

func get_hero_combat_stats(hero_index: int) -> Dictionary:
	hero_index = clampi(hero_index, 0, heroes.size() - 1)
	var hero: Dictionary = heroes[hero_index]
	var base: Dictionary = hero_stats[hero_index]
	var equipment: Dictionary = hero_equipment[hero_index]
	var bonus := {"attack":0, "defense":0, "hp":0, "speed":0, "crit":0, "crit_damage":0, "poison":0, "agility":0, "luck":0, "willpower":0, "fist":0, "sword":0, "blade":0, "unorthodox":0}
	for slot in ["weapon", "armor", "accessory"]:
		var item_name: String = equipment.get(slot, "")
		var item: Dictionary = equipment_library.get(item_name, {})
		for key in bonus:
			bonus[key] += int(item.get(key, 0))
	var loadout: Dictionary = hero_skills[hero_index]
	var internal_bonus: Dictionary = get_internal_skill_bonus(hero_index)
	return {
		"attack":hero.attack + bonus.attack + base.strength + internal_bonus.attack,
		"defense":hero.defense + bonus.defense + base.constitution + internal_bonus.defense,
		"speed":hero.speed + bonus.speed + base.agility + bonus.agility,
		"max_hp":100 + (hero.level - 1) * 10 + base.constitution * 3 + bonus.hp,
		"max_mp":60 + (hero.level - 1) * 5 + (base.willpower + bonus.willpower) * 2,
		"crit":5.0 + (base.luck + bonus.luck) * 0.5 + bonus.crit,
		"crit_damage":150 + bonus.crit_damage,
		"poison":bonus.poison,
		"strength":base.strength, "agility":base.agility + bonus.agility,
		"insight":base.insight, "luck":base.luck + bonus.luck,
		"constitution":base.constitution, "willpower":base.willpower + bonus.willpower,
		"fist":base.fist + bonus.fist, "sword":base.sword + bonus.sword,
		"blade":base.blade + bonus.blade, "unorthodox":base.unorthodox + bonus.unorthodox
	}

func get_internal_skill_bonus(hero_index: int) -> Dictionary:
	if hero_index < 0 or hero_index >= hero_skills.size(): return {"attack":0, "defense":0}
	var loadout: Dictionary = hero_skills[hero_index]
	var internal_name := str(loadout.get("internal", ""))
	if internal_name.is_empty(): return {"attack":0, "defense":0}
	var internal_level := int(loadout.get("levels", {}).get(internal_name, 1))
	var internal: Dictionary = skill_library.get(internal_name, {})
	return {
		"attack":internal_level * int(internal.get("attack_bonus", 0)),
		"defense":internal_level * int(internal.get("defense_bonus", 0))
	}

func get_hero_experience_needed(level: int) -> int:
	return maxi(0, level) * HERO_LEVEL_EXP_MULTIPLIER

func get_skill_experience_needed(level: int) -> int:
	return maxi(0, level) * SKILL_LEVEL_EXP_MULTIPLIER

func get_equipment_icon(item_name: String) -> String:
	return str(item_library.get(item_name, {}).get("icon", equipment_library.get(item_name, {}).get("icon", "res://assets/Items/baoyu.jpg")))

func _rename_legacy_item(item_name: String) -> String:
	return str(LEGACY_ITEM_NAMES.get(item_name, item_name))

func _rename_legacy_skill(skill_name: String) -> String:
	return str(LEGACY_SKILL_NAMES.get(skill_name, skill_name))

func _synchronize_loaded_configuration() -> void:
	var synchronized_inventory: Array[String] = []
	for item in inventory:
		var item_name := _rename_legacy_item(str(item))
		synchronized_inventory.append(item_name)
	inventory = synchronized_inventory
	for hero_index in hero_equipment.size():
		var equipment: Dictionary = hero_equipment[hero_index]
		for slot in ["weapon", "armor", "accessory"]:
			var item_name := _rename_legacy_item(str(equipment.get(slot, "")))
			if item_name.is_empty() or not equipment_library.has(item_name) or equipment_library[item_name].slot != slot:
				equipment.erase(slot)
			else:
				equipment[slot] = item_name
	for loadout in hero_skills:
		loadout.merge(SkillLoadout.normalize(self, loadout), true)

func equip_item(hero_index: int, item_name: String) -> String:
	if hero_index < 0 or hero_index >= hero_equipment.size(): return "无法选择该侠客"
	if not equipment_library.has(item_name): return "此物品不能装备"
	var slot: String = equipment_library[item_name].slot
	if slot not in ["weapon", "armor", "accessory"]: return "无效装备槽"
	var equipment: Dictionary = hero_equipment[hero_index]
	var previous: String = equipment.get(slot, "")
	if previous == item_name: return "%s已经装备%s" % [heroes[hero_index].name, item_name]
	if not inventory.has(item_name): return "背包中没有该物品"
	inventory.erase(item_name)
	if not previous.is_empty(): inventory.append(previous)
	equipment[slot] = item_name
	return "已为%s装备%s" % [heroes[hero_index].name, item_name]

func unequip_item(hero_index: int, slot: String) -> String:
	if hero_index < 0 or hero_index >= hero_equipment.size(): return "无法选择该侠客"
	if slot not in ["weapon", "armor", "accessory"]: return "无法卸下该装备"
	var equipment: Dictionary = hero_equipment[hero_index]
	var item_name: String = str(equipment.get(slot, ""))
	if item_name.is_empty(): return "该装备位已空"
	equipment[slot] = ""
	inventory.append(item_name)
	return "已为%s卸下%s" % [heroes[hero_index].name, item_name]

func learn_from_book(hero_index: int, book_name: String) -> String:
	if hero_index < 0 or hero_index >= hero_skills.size(): return "无法选择该侠客"
	if not inventory.has(book_name): return "背包中没有该秘籍"
	var item: Dictionary = item_library.get(book_name, {})
	var learned_name := ""
	if item.get("kind", "") == "秘籍":
		for name in skill_library:
			if skill_library[name].id == item.skill_id: learned_name = name
	if learned_name.is_empty(): return "这不是可研习的秘籍"
	return learn_skill(hero_index, learned_name)

func learn_skill(hero_index: int, skill_name: String) -> String:
	if hero_index < 0 or hero_index >= hero_skills.size() or not skill_library.has(skill_name): return "无法学习该技能"
	var loadout: Dictionary = hero_skills[hero_index]
	if loadout.learned.has(skill_name): return "已经学会该技能"
	loadout.learned.append(skill_name)
	loadout.levels[skill_name] = 1
	loadout.exp[skill_name] = 0
	return "%s学会了%s，请在技能页选择装备" % [heroes[hero_index].name, skill_name]

func equip_skill(hero_index: int, skill_name: String, replace_index: int = -1) -> String:
	if hero_index < 0 or hero_index >= hero_skills.size(): return "无法选择该侠客"
	var loadout: Dictionary = hero_skills[hero_index]
	if not skill_library.has(skill_name) or not loadout.learned.has(skill_name): return "尚未学会该技能"
	if skill_library[skill_name].kind == "心法":
		if loadout.internal == skill_name: return "已经装备该心法"
		loadout.internal = skill_name
	else:
		if loadout.martial.has(skill_name): return "已经装备该武学"
		if replace_index >= 0:
			if replace_index >= loadout.martial.size(): return "无效武学槽"
			var previous: String = loadout.martial[replace_index]
			loadout.martial[replace_index] = skill_name
			return "已将%s替换为%s，等级与经验保留" % [previous, skill_name]
		if loadout.martial.size() >= 4: return "最多装备四个武学，请先卸下一个武学"
		loadout.martial.append(skill_name)
	return "已装备%s" % skill_name

func unequip_skill(hero_index: int, skill_name: String) -> String:
	if hero_index < 0 or hero_index >= hero_skills.size(): return "无法选择该侠客"
	var loadout: Dictionary = hero_skills[hero_index]
	if loadout.internal == skill_name: return "至少保留一个心法，请选择其他已学心法替换"
	if not loadout.martial.has(skill_name): return "该武学未装备"
	if loadout.martial.size() <= 1: return "至少保留一个武学，无法卸下"
	loadout.martial.erase(skill_name)
	return "已卸下%s，等级与经验保留" % skill_name

func gain_skill_experience(hero_index: int, skill_name: String, amount: int = 12) -> int:
	if hero_index < 0 or hero_index >= hero_skills.size() or not skill_library.has(skill_name): return 0
	var loadout: Dictionary = hero_skills[hero_index]
	var level: int = int(loadout.levels.get(skill_name, 1))
	if level >= SKILL_LEVEL_CAP: return 0
	loadout.exp[skill_name] = int(loadout.exp.get(skill_name, 0)) + amount
	var needed := get_skill_experience_needed(level)
	var levels_gained := 0
	while level < SKILL_LEVEL_CAP and loadout.exp[skill_name] >= needed:
		loadout.exp[skill_name] -= needed
		level += 1
		levels_gained += 1
		loadout.levels[skill_name] = level
		battle_log.append("%s提升至%d级" % [skill_name, loadout.levels[skill_name]])
		needed = get_skill_experience_needed(level)
	return levels_gained

func goto(path: String) -> void:
	# 只在返回探索、剧情结束和结算时保存，不让浏览菜单触发覆盖。
	if path.ends_with("world_map.tscn") or path.ends_with("region_map.tscn") or path.ends_with("battle_result.tscn"):
		var err := autosave()
		if err != OK: push_warning("自动存档失败：%s" % error_string(err))
	get_tree().change_scene_to_file(path)

func save_slot(slot: int, path_override: String = "") -> Error:
	if slot < 0 or slot > 4: return ERR_INVALID_PARAMETER
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", SAVE_VERSION)
	cfg.set_value("meta", "game", "群侠传")
	cfg.set_value("meta", "saved_unix", Time.get_unix_time_from_system())
	cfg.set_value("player", "money", money)
	cfg.set_value("player", "reputation", reputation)
	cfg.set_value("player", "lead_name", str(heroes[selected_hero].name))
	cfg.set_value("player", "inventory", inventory)
	cfg.set_value("player", "selected_party", selected_party)
	cfg.set_value("player", "selected_hero", selected_hero)
	cfg.set_value("player", "character_tab", character_tab)
	cfg.set_value("player", "hero_equipment", hero_equipment)
	cfg.set_value("player", "heroes", heroes)
	cfg.set_value("player", "hero_stats", hero_stats)
	cfg.set_value("player", "hero_skills", hero_skills)
	cfg.set_value("progress", "location", current_location)
	cfg.set_value("progress", "scene", current_scene)
	cfg.set_value("progress", "saved_at", Time.get_datetime_string_from_system(false, true))
	cfg.set_value("progress", "journal", journal)
	cfg.set_value("progress", "quest_stage", quest_stage)
	cfg.set_value("progress", "adventure", narrative_progress)
	cfg.set_value("progress", "seen_stories", seen_stories)
	cfg.set_value("settings", "values", settings)
	var path: String = path_override if not path_override.is_empty() else get_save_path(slot)
	SaveCodec.encode(cfg, self)
	var err := cfg.save(path + ".tmp")
	if err != OK: return err
	var previous := ConfigFile.new()
	if previous.load(path) == OK:
		var previous_version: Variant = previous.get_value("meta", "version", 0)
		if previous_version is int and previous_version >= 0 and previous_version < SAVE_VERSION:
			var backup_path := path + ".v%d.bak" % previous_version
			if not FileAccess.file_exists(backup_path):
				err = DirAccess.copy_absolute(path, backup_path)
				if err != OK:
					DirAccess.remove_absolute(path + ".tmp")
					return err
	return DirAccess.rename_absolute(path + ".tmp", path)

func load_slot(slot: int, path_override: String = "") -> Error:
	if slot < 0 or slot > 4: return ERR_INVALID_PARAMETER
	var cfg := ConfigFile.new()
	var path: String = path_override if not path_override.is_empty() else get_save_path(slot)
	var err := cfg.load(path)
	if err != OK: return err
	# version=0 代表早期开发版存档，允许兼容；未来版本则不能静默读取。
	var version_value: Variant = cfg.get_value("meta", "version", 0)
	if not version_value is int: return ERR_FILE_CORRUPT
	var saved_version: int = version_value
	if saved_version < 0 or saved_version > SAVE_VERSION: return ERR_FILE_UNRECOGNIZED
	if saved_version >= 4 and not Narrative.valid(self, cfg.get_value("progress", "adventure")): return ERR_FILE_CORRUPT
	if saved_version >= 2 and SaveCodec.decode(cfg, self) != OK: return ERR_FILE_CORRUPT
	if not _valid_save_data(cfg): return ERR_FILE_CORRUPT
	reset_new_game()
	money = int(cfg.get_value("player", "money", money))
	reputation = int(cfg.get_value("player", "reputation", reputation))
	var saved_inventory: Variant = cfg.get_value("player", "inventory", inventory.duplicate(true))
	if saved_inventory is Array:
		inventory.clear()
		for item in saved_inventory: inventory.append(str(item))
	var saved_party: Variant = cfg.get_value("player", "selected_party", selected_party.duplicate(true))
	if saved_party is Array:
		selected_party.clear()
		for hero_index in saved_party:
			var index := int(hero_index)
			if index >= 0 and index < heroes.size() and not selected_party.has(index): selected_party.append(index)
	if selected_party.is_empty(): selected_party.append(0)
	selected_hero = clampi(int(cfg.get_value("player", "selected_hero", selected_hero)), 0, heroes.size() - 1)
	character_tab = str(cfg.get_value("player", "character_tab", character_tab))
	var saved_equipment: Variant = cfg.get_value("player", "hero_equipment", hero_equipment.duplicate(true))
	if saved_equipment is Array:
		hero_equipment.clear()
		for equipment in saved_equipment.slice(0, heroes.size()):
			if equipment is Dictionary: hero_equipment.append(equipment)
	while hero_equipment.size() < heroes.size():
		hero_equipment.append({})
	var saved_heroes: Variant = cfg.get_value("player", "heroes", heroes.duplicate(true))
	if saved_heroes is Array:
		for i in mini(saved_heroes.size(), heroes.size()):
			if saved_heroes[i] is Dictionary:
				var merged_hero: Dictionary = heroes[i].duplicate(true)
				merged_hero.merge(saved_heroes[i], true)
				for key in ["id", "name", "head"]: merged_hero[key] = _new_game_defaults.heroes[i][key]
				merged_hero["model"] = HERO_MODEL_PATHS[i]
				heroes[i] = merged_hero
	var saved_stats: Variant = cfg.get_value("player", "hero_stats", hero_stats.duplicate(true))
	if saved_stats is Array:
		for i in mini(saved_stats.size(), hero_stats.size()):
			if saved_stats[i] is Dictionary: hero_stats[i] = saved_stats[i]
	var saved_skills: Variant = cfg.get_value("player", "hero_skills", hero_skills.duplicate(true))
	if saved_skills is Array:
		for i in mini(saved_skills.size(), hero_skills.size()):
			if saved_skills[i] is Dictionary: hero_skills[i] = saved_skills[i]
	_trim_roster_to_six()
	current_location = str(cfg.get_value("progress", "location", current_location))
	current_scene = str(cfg.get_value("progress", "scene", current_scene))
	var saved_journal: Variant = cfg.get_value("progress", "journal", journal.duplicate(true))
	if saved_journal is Array:
		journal.clear()
		for entry in saved_journal: journal.append(str(entry))
	quest_stage = clampi(int(cfg.get_value("progress", "quest_stage", 0)), 0, 3)
	for id in cfg.get_value("progress", "seen_stories", []):
		if story_dialogues.has(id) and not seen_stories.has(id): seen_stories.append(id)
	if saved_version >= 4:
		narrative_progress = cfg.get_value("progress", "adventure").duplicate(true)
		if narrative_progress.pending: current_encounter = Narrative.current(self).battle
		if not can_visit(current_scene): current_scene = Narrative.location(self, Narrative.current(self).get("location", "shaolin_room")).name
	else:
		current_scene = "少林厢房"
		current_location = "嵩山"
		journal.append("剧情已更新：保留原有物品和养成，从少林醒来开始新主线。")
	if selected_party.any(func(index: int) -> bool: return not hero_available(index)):
		Narrative.choose_party(self)
	if not hero_available(selected_hero): selected_hero = 0
	_synchronize_loaded_configuration()
	for index in heroes.size():
		if hero_available(index): continue
		for slot_name in ["weapon", "armor", "accessory"]:
			if not str(hero_equipment[index].get(slot_name, "")).is_empty(): unequip_item(index, slot_name)
	apply_settings()
	return OK

func _valid_save_data(cfg: ConfigFile) -> bool:
	if not cfg.has_section_key("player", "money"): return false
	for key in ["money", "reputation", "selected_hero"]:
		var number: Variant = cfg.get_value("player", key, 0)
		if not (number is int) or number < 0: return false
	var stage: Variant = cfg.get_value("progress", "quest_stage", 0)
	if not stage is int or stage < 0 or stage > 3: return false
	var stories: Variant = cfg.get_value("progress", "seen_stories", [])
	if not stories is Array: return false
	for id in stories:
		if not id is String: return false
	for key in ["inventory", "selected_party", "hero_equipment", "heroes", "hero_stats", "hero_skills"]:
		var entries: Variant = cfg.get_value("player", key, [])
		if not entries is Array: return false
		for entry in entries:
			if key == "inventory":
				if not entry is String: return false
			elif key == "selected_party":
				if not entry is int: return false
			elif not entry is Dictionary: return false
			elif key == "heroes":
				for field in ["id", "name", "head", "model"]:
					if not entry.get(field, "") is String: return false
				for field in ["level", "exp", "attack", "defense", "speed"]:
					if not entry.get(field, 0) is int or entry.get(field, 0) < 0: return false
				if int(entry.get("level", 1)) < 1 or int(entry.get("level", 1)) > HERO_LEVEL_CAP: return false
			elif key == "hero_stats":
				for field in hero_stats[0]:
					if not entry.get(field) is int or entry[field] < 0: return false
			elif key == "hero_skills":
				if not entry.get("martial", []) is Array or not entry.get("levels", {}) is Dictionary or not entry.get("exp", {}) is Dictionary: return false
				if not entry.get("internal", "") is String: return false
				if not entry.get("learned", []) is Array: return false
				for skill in entry.get("learned", []):
					if not skill is String: return false
				for skill in entry.get("martial", []):
					if not skill is String: return false
				for field in ["levels", "exp"]:
					for value in entry.get(field, {}).values():
						if not value is int or value < 0: return false
	return true

func _load_configuration() -> bool:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/configuration.json"))
	if not parsed is Dictionary:
		push_error("无法读取游戏配置，请运行 tools/export_config.py")
		return false
	var data: Dictionary = _configuration_integers(parsed)
	heroes = data.heroes
	hero_stats = data.hero_stats
	hero_skills = data.hero_skills
	skill_library = data.skills
	equipment_library = data.equipment
	item_library = data.items
	growth = data.growth
	var story: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/story.json"))
	if not story is Dictionary or not story.get("dialogues") is Dictionary:
		push_error("无法读取剧情配置，请运行 tools/export_story.py")
		return false
	story_data = _configuration_integers(story)
	story_dialogues = story_data.dialogues
	for i in heroes.size():
		var profile: Dictionary = story_data.profiles[i]
		heroes[i].name = profile.name
		heroes[i].head = "res://assets/Heads/" + str(profile.head) + ("" if str(profile.head).contains(".") else ".png")
		heroes[i]["biography"] = profile.bio
	HERO_LEVEL_CAP = int(growth.hero_level_cap)
	HERO_LEVEL_EXP_MULTIPLIER = int(growth.hero_level_exp)
	SKILL_LEVEL_CAP = int(growth.skill_level_cap)
	SKILL_LEVEL_EXP_MULTIPLIER = int(growth.skill_level_exp)
	HERO_MODEL_PATHS.clear()
	for hero in heroes: HERO_MODEL_PATHS.append(str(hero.model))
	return true

func _configuration_integers(value: Variant) -> Variant:
	# JSON numbers arrive as floats; keep game and save-file numeric types stable.
	if value is float: return int(value)
	if value is Array:
		var entries: Array = []
		for entry in value: entries.append(_configuration_integers(entry))
		return entries
	if value is Dictionary:
		var entries: Dictionary = {}
		for key in value: entries[key] = _configuration_integers(value[key])
		return entries
	return value
