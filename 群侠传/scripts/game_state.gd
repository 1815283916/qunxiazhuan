extends Node

const MALE_BATTLE_MODEL := "res://assets/Animations/r-nan-zhoucang"
const HERO_MODEL_PATHS := [
	"res://assets/Animations/r-nan-jiangwei",
	"res://assets/Animations/r-nv-duguyanran",
	"res://assets/Animations/r-nv-guanyinping",
	"res://assets/Animations/r-nv-huangyishuangjian",
	"res://assets/Animations/chenxi1",
	"res://assets/Animations/chenxi2"
]

var money := 1280
var reputation := 120
var current_location := "中原地区"
var current_scene := "长安西市"
var selected_hero := 0
var heroes := [
	{"id":"hero_beichou", "name":"北丑", "head":"res://assets/Heads/zhengtingyu.png", "model":"res://assets/Animations/r-nan-jiangwei", "level":1, "exp":0, "attack":67, "speed":63, "defense":42},
	{"id":"hero_nanxian", "name":"南贤", "head":"res://assets/Heads/nanxian.png", "model":"res://assets/Animations/r-nv-duguyanran", "level":5, "exp":0, "attack":74, "speed":55, "defense":58},
	{"id":"hero_huangrong", "name":"黄蓉", "head":"res://assets/Heads/huoqingtong.png", "model":"res://assets/Animations/r-nv-guanyinping", "level":5, "exp":0, "attack":52, "speed":72, "defense":39},
	{"id":"hero_xiaolongnv", "name":"小龙女", "head":"res://assets/Heads/xishi.png", "model":"res://assets/Animations/r-nv-huangyishuangjian", "level":5, "exp":0, "attack":65, "speed":76, "defense":44},
	{"id":"hero_wangyuyan", "name":"王语嫣", "head":"res://assets/Heads/wangyuyan.png", "model":"res://assets/Animations/chenxi1", "level":5, "exp":0, "attack":38, "speed":60, "defense":35},
	{"id":"hero_chengying", "name":"程英", "head":"res://assets/Heads/chengying.png", "model":"res://assets/Animations/chenxi2", "level":5, "exp":0, "attack":49, "speed":68, "defense":38}
]
var hero_stats := [
	{"strength":18, "agility":16, "insight":21, "luck":14, "constitution":17, "willpower":15, "fist":68, "sword":92, "blade":46, "unorthodox":52},
	{"strength":20, "agility":14, "insight":23, "luck":12, "constitution":21, "willpower":22, "fist":82, "sword":88, "blade":51, "unorthodox":44},
	{"strength":13, "agility":22, "insight":22, "luck":20, "constitution":14, "willpower":17, "fist":90, "sword":62, "blade":35, "unorthodox":81},
	{"strength":17, "agility":23, "insight":18, "luck":16, "constitution":16, "willpower":19, "fist":56, "sword":94, "blade":38, "unorthodox":48},
	{"strength":10, "agility":17, "insight":25, "luck":19, "constitution":12, "willpower":23, "fist":35, "sword":70, "blade":28, "unorthodox":65},
	{"strength":14, "agility":20, "insight":20, "luck":17, "constitution":15, "willpower":18, "fist":48, "sword":84, "blade":33, "unorthodox":58}
]
var selected_party: Array[int] = [0]
var hero_equipment := [{}, {}, {}, {}, {}, {}]
var equipment_library := {
	"魔神拳套":{"id":"weapon_moshenquantao", "slot":"weapon", "attack":28, "sword":12, "crit_damage":15, "icon":"res://assets/Items/moshenquantao.jpg"},
	"朴刀":{"id":"weapon_pudao", "slot":"weapon", "attack":16, "sword":8, "icon":"res://assets/Items/dao3.jpg"},
	"凝神枪":{"id":"weapon_ningshenqiang", "slot":"weapon", "attack":14, "agility":6, "sword":10, "icon":"res://assets/Items/liquanqiang.jpg"},
	"魔神剑":{"id":"weapon_moshenjian", "slot":"weapon", "attack":45, "crit":10, "icon":"res://assets/Items/moshenjian.jpg"},
	"粗布道袍":{"id":"armor_cubudaopao", "slot":"armor", "defense":12, "hp":80, "icon":"res://assets/Items/Dcubudaopao.jpg"},
	"乌蚕衣":{"id":"armor_wucanyi", "slot":"armor", "defense":24, "speed":8, "icon":"res://assets/Items/daopao.jpg"},
	"毒戒指":{"id":"accessory_dujiezhi", "slot":"accessory", "poison":15, "icon":"res://assets/Items/jiezhi3.jpg"},
	"宝玉":{"id":"accessory_baoyu", "slot":"accessory", "luck":8, "willpower":5, "icon":"res://assets/Items/baoyu.jpg"}
}
var skill_library := {
	"狂风刀法":{"id":"martial_blade_storm", "kind":"武学", "school":"刀法", "cost":16, "damage":32, "damage_growth":1, "range":1, "shape":"fan", "pattern":"方形六格", "icon":"res://assets/Icons/icon_waigong_114.jpg", "effect":"res://assets/Animations/e-feilong", "description":"刀势横扫。"},
	"打狗棒法":{"id":"martial_dog_beating_staff", "kind":"武学", "school":"奇门", "cost":20, "damage":30, "damage_growth":1, "range":2, "shape":"cross", "pattern":"十字九格", "icon":"res://assets/Icons/zzc073.png", "effect":"res://assets/Animations/e-liumai", "description":"势大力沉。"},
	"降龙十八掌":{"id":"martial_dragon_palm", "kind":"武学", "school":"拳掌", "cost":12, "damage":35, "damage_growth":2, "range":3, "shape":"single", "pattern":"单体", "icon":"res://assets/Icons/icon_waigong_107.jpg", "effect":"res://assets/Animations/e-rulai", "description":"掌影飘忽。"},
	"独孤九剑":{"id":"martial_sword_unique", "kind":"武学", "school":"剑系", "cost":18, "damage":36, "damage_growth":1, "range":4, "shape":"line", "pattern":"直线四格", "icon":"res://assets/Icons/zzd28.png", "effect":"res://assets/Animations/e-tianjian", "description":"剑意纵横的上乘剑法。"},
	"九阳神功":{"id":"internal_jiuyang", "kind":"心法", "school":"内功", "attack_bonus":2, "defense_bonus":6, "icon":"res://assets/Icons/icon_neigong_020.jpg", "description":"至阳至刚的上乘心法，善于防守。"},
	"易筋经":{"id":"internal_yijin", "kind":"心法", "school":"内功", "attack_bonus":4, "defense_bonus":4, "icon":"res://assets/Icons/icon_neigong_020.jpg", "description":"少林镇派心法，攻守兼备。"}
}
var hero_skills := [
	{"martial":["独孤九剑", "降龙十八掌", "打狗棒法"], "internal":"九阳神功", "levels":{"独孤九剑":3, "降龙十八掌":2, "打狗棒法":2, "九阳神功":3}, "exp":{}},
	{"martial":["狂风刀法", "降龙十八掌"], "internal":"九阳神功", "levels":{"狂风刀法":2, "降龙十八掌":2, "九阳神功":4}, "exp":{}},
	{"martial":["降龙十八掌", "打狗棒法"], "internal":"易筋经", "levels":{"降龙十八掌":3, "打狗棒法":2, "易筋经":3}, "exp":{}},
	{"martial":["独孤九剑", "狂风刀法"], "internal":"九阳神功", "levels":{"独孤九剑":3, "狂风刀法":2, "九阳神功":3}, "exp":{}},
	{"martial":["降龙十八掌"], "internal":"易筋经", "levels":{"降龙十八掌":2, "易筋经":4}, "exp":{}},
	{"martial":[], "internal":"易筋经", "levels":{"易筋经":2}, "exp":{}}
]
var inventory := ["魔神拳套", "朴刀", "凝神枪", "魔神剑", "粗布道袍", "乌蚕衣", "毒戒指", "宝玉", "大还丹", "疗伤药", "独孤九剑秘籍", "易筋经"]
var journal := [
	"江湖三年十一月七日，宇文逸初入长安。",
	"江湖三年十一月八日，听闻华山论剑将启。",
	"江湖三年十一月九日，神秘剑客发出挑战。"
]
var reward_money := 200
var reward_exp := 120
var selected_item := "魔神拳套"
var detail_return_scene := "res://scenes/inventory.tscn"
var character_tab := ""
var selected_skill_name := "独孤九剑"
var selected_skill_kind := "武学"
var settings := {
	"show_hp": true,
	"show_buffs": true,
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
const SAVE_VERSION := 1
const HERO_LEVEL_CAP := 30
const HERO_LEVEL_EXP_MULTIPLIER := 200
const SKILL_LEVEL_CAP := 10
const SKILL_LEVEL_EXP_MULTIPLIER := 40
const LEGACY_SKILL_NAMES := {"落英神剑掌":"降龙十八掌", "漫天花雨":"打狗棒法"}
const LEGACY_ITEM_NAMES := {"玄铁剑":"魔神拳套", "君子剑":"朴刀", "淑女剑":"凝神枪"}
var _new_game_defaults: Dictionary = {}

func _trim_roster_to_six() -> void:
	heroes.resize(HERO_MODEL_PATHS.size())
	hero_stats.resize(HERO_MODEL_PATHS.size())
	hero_equipment.resize(HERO_MODEL_PATHS.size())
	hero_skills.resize(HERO_MODEL_PATHS.size())
	for i in HERO_MODEL_PATHS.size():
		heroes[i]["model"] = HERO_MODEL_PATHS[i]

func _ready() -> void:
	_trim_roster_to_six()
	hero_equipment = _empty_equipment_loadout()
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
		var max_hp: int = combat.max_hp
		var max_mp: int = combat.max_mp
		battle_allies.append({
			"hero_index":hero_index, "name":hero.name, "head":hero.head, "model":model_path,
			"hp":max_hp, "max_hp":max_hp, "mp":max_mp, "max_mp":max_mp,
			"attack":combat.attack, "defense":combat.defense, "crit":combat.crit,
			"crit_damage":combat.crit_damage, "poison":combat.poison,
			"fist":combat.fist, "sword":combat.sword, "blade":combat.blade, "unorthodox":combat.unorthodox, "insight":combat.insight,
			"coord":Vector2i(2, i + 3), "alive":true, "moved":false,
			"move_range":clampi(2 + int(combat.speed / 90.0), 2, 3),
			"speed":combat.speed, "action_delay":clampi(120 - int(combat.speed), 35, 90),
			"next_action":clampi(120 - int(combat.speed), 35, 90)
		})
	for i in 3:
		battle_enemies.append({
			"name":"华山弟子", "head":"res://assets/Heads/fangyi.png", "model":MALE_BATTLE_MODEL,
			"hp":120, "max_hp":120, "mp":50, "max_mp":50, "attack":32, "defense":18, "poison_turns":0,
			"coord":Vector2i(13, i + 3), "alive":true, "move_range":2,
			"speed":52 - i * 2, "action_delay":68 + i * 3, "next_action":68 + i * 3
		})
	if battle_allies.is_empty():
		selected_party.clear()
		selected_party.append(0)
		new_battle()
	player_hp = 100
	player_mp = 60
	enemy_hp = 360
	battle_outcome = "胜利"

func get_hero_model_path(hero_index: int) -> String:
	if hero_index >= 0 and hero_index < heroes.size():
		var configured := str(heroes[hero_index].get("model", ""))
		if not configured.is_empty(): return configured
	# The first two roster entries are male; the remaining current entries are female.
	return HERO_MODEL_PATHS[clampi(hero_index, 0, HERO_MODEL_PATHS.size() - 1)]

func grant_battle_experience() -> void:
	for hero_index in selected_party:
		if hero_index < 0 or hero_index >= heroes.size(): continue
		gain_hero_experience(hero_index, reward_exp)

func gain_hero_experience(hero_index: int, amount: int) -> int:
	if hero_index < 0 or hero_index >= heroes.size() or amount <= 0: return 0
	var hero: Dictionary = heroes[hero_index]
	hero.exp = int(hero.get("exp", 0)) + amount
	var previous_level: int = hero.level
	while hero.level < HERO_LEVEL_CAP and hero.exp >= get_hero_experience_needed(hero.level):
		hero.exp -= get_hero_experience_needed(hero.level)
		hero.level += 1
		hero.attack += 3
		hero.speed += 2
		hero.defense += 2
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
	return str(equipment_library.get(item_name, {}).get("icon", "res://assets/Items/baoyu.jpg"))

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
		var valid_martial: Array[String] = []
		var valid_levels := {}
		var valid_experience := {}
		for skill_entry in loadout.get("martial", []):
			var skill_name := _rename_legacy_skill(str(skill_entry))
			if not skill_library.has(skill_name) or skill_library[skill_name].kind != "武学" or valid_martial.has(skill_name): continue
			valid_martial.append(skill_name)
			valid_levels[skill_name] = int(loadout.get("levels", {}).get(skill_entry, loadout.get("levels", {}).get(skill_name, 1)))
			valid_experience[skill_name] = int(loadout.get("exp", {}).get(skill_entry, loadout.get("exp", {}).get(skill_name, 0)))
		var internal_name := _rename_legacy_skill(str(loadout.get("internal", "")))
		if not skill_library.has(internal_name) or skill_library[internal_name].kind != "心法":
			internal_name = "易筋经"
		valid_levels[internal_name] = int(loadout.get("levels", {}).get(loadout.get("internal", ""), loadout.get("levels", {}).get(internal_name, 1)))
		valid_experience[internal_name] = int(loadout.get("exp", {}).get(loadout.get("internal", ""), loadout.get("exp", {}).get(internal_name, 0)))
		loadout.martial = valid_martial
		loadout.internal = internal_name
		loadout.levels = valid_levels
		loadout.exp = valid_experience

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
	var learned_name := "独孤九剑" if book_name == "独孤九剑秘籍" else "易筋经" if book_name == "易筋经" else ""
	if learned_name.is_empty(): return "这不是可研习的秘籍"
	var skill: Dictionary = skill_library[learned_name]
	var loadout: Dictionary = hero_skills[hero_index]
	if skill.kind == "心法":
		if loadout.internal == learned_name: return "已经装备该心法"
		loadout.internal = learned_name
	else:
		if loadout.martial.has(learned_name): return "已经学会该武学"
		if loadout.martial.size() >= 4: return "武学栏已满，请先遗忘一个武学"
		loadout.martial.append(learned_name)
	if not loadout.levels.has(learned_name): loadout.levels[learned_name] = 1
	if not loadout.exp.has(learned_name): loadout.exp[learned_name] = 0
	return "%s学会了%s" % [heroes[hero_index].name, learned_name]

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
	if bool(settings.get("auto_save", false)) and not path.ends_with("main_menu.tscn") and not path.ends_with("save_load.tscn"):
		save_slot(1)
	get_tree().change_scene_to_file(path)

func save_slot(slot: int, path_override: String = "") -> Error:
	if slot < 1 or slot > 4: return ERR_INVALID_PARAMETER
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", SAVE_VERSION)
	cfg.set_value("meta", "game", "群侠传")
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
	cfg.set_value("settings", "values", settings)
	var path: String = path_override if not path_override.is_empty() else "user://qunxia_slot_%d.cfg" % slot
	return cfg.save(path)

func load_slot(slot: int, path_override: String = "") -> Error:
	if slot < 1 or slot > 4: return ERR_INVALID_PARAMETER
	var cfg := ConfigFile.new()
	var path: String = path_override if not path_override.is_empty() else "user://qunxia_slot_%d.cfg" % slot
	var err := cfg.load(path)
	if err != OK: return err
	# version=0 代表早期开发版存档，允许兼容；未来版本则不能静默读取。
	var saved_version: int = int(cfg.get_value("meta", "version", 0))
	if saved_version < 0 or saved_version > SAVE_VERSION: return ERR_FILE_UNRECOGNIZED
	money = int(cfg.get_value("player", "money", money))
	reputation = int(cfg.get_value("player", "reputation", reputation))
	var saved_inventory: Variant = cfg.get_value("player", "inventory", inventory)
	if saved_inventory is Array:
		inventory.clear()
		for item in saved_inventory: inventory.append(str(item))
	var saved_party: Variant = cfg.get_value("player", "selected_party", selected_party)
	if saved_party is Array:
		selected_party.clear()
		for hero_index in saved_party:
			var index := int(hero_index)
			if index >= 0 and index < heroes.size() and not selected_party.has(index): selected_party.append(index)
	if selected_party.is_empty(): selected_party.append(0)
	selected_hero = clampi(int(cfg.get_value("player", "selected_hero", selected_hero)), 0, heroes.size() - 1)
	character_tab = str(cfg.get_value("player", "character_tab", character_tab))
	var saved_equipment: Variant = cfg.get_value("player", "hero_equipment", hero_equipment)
	if saved_equipment is Array:
		hero_equipment.clear()
		for equipment in saved_equipment.slice(0, heroes.size()):
			if equipment is Dictionary: hero_equipment.append(equipment)
	while hero_equipment.size() < heroes.size():
		hero_equipment.append({})
	var saved_heroes: Variant = cfg.get_value("player", "heroes", heroes)
	if saved_heroes is Array:
		for i in mini(saved_heroes.size(), heroes.size()):
			if saved_heroes[i] is Dictionary:
				var merged_hero: Dictionary = heroes[i].duplicate(true)
				merged_hero.merge(saved_heroes[i], true)
				merged_hero["model"] = HERO_MODEL_PATHS[i]
				heroes[i] = merged_hero
	var saved_stats: Variant = cfg.get_value("player", "hero_stats", hero_stats)
	if saved_stats is Array:
		for i in mini(saved_stats.size(), hero_stats.size()):
			if saved_stats[i] is Dictionary: hero_stats[i] = saved_stats[i]
	var saved_skills: Variant = cfg.get_value("player", "hero_skills", hero_skills)
	if saved_skills is Array:
		for i in mini(saved_skills.size(), hero_skills.size()):
			if saved_skills[i] is Dictionary: hero_skills[i] = saved_skills[i]
	_trim_roster_to_six()
	current_location = str(cfg.get_value("progress", "location", current_location))
	current_scene = str(cfg.get_value("progress", "scene", current_scene))
	var saved_journal: Variant = cfg.get_value("progress", "journal", journal)
	if saved_journal is Array:
		journal.clear()
		for entry in saved_journal: journal.append(str(entry))
	var saved_settings: Variant = cfg.get_value("settings", "values", settings)
	if saved_settings is Dictionary:
		for key in settings: settings[key] = saved_settings.get(key, settings[key])
	_synchronize_loaded_configuration()
	return OK
