extends RefCounted
## Version 2 stores configuration references by ID. Runtime/UI still use names.

static func _item_id(game: Node, name: String) -> String:
	if name.is_empty(): return ""
	if game.equipment_library.has(name): return str(game.equipment_library[name].id)
	return str(game.item_library.get(name, {}).get("id", "legacy:" + name))

static func _item_name(game: Node, id: String) -> String:
	for name in game.equipment_library:
		if game.equipment_library[name].id == id: return name
	for name in game.item_library:
		if game.item_library[name].id == id: return name
	return id.trim_prefix("legacy:") if id.begins_with("legacy:") else ""

static func _skill_id(game: Node, name: String) -> String:
	return str(game.skill_library.get(name, {}).get("id", ""))

static func _skill_name(game: Node, id: String) -> String:
	for name in game.skill_library:
		if game.skill_library[name].id == id: return name
	return ""

static func encode(cfg: ConfigFile, game: Node) -> void:
	var items: Array[String] = []
	for item in game.inventory: items.append(_item_id(game, item))
	var party: Array[String] = []
	for index in game.selected_party: party.append(str(game.heroes[index].id))
	cfg.set_value("references", "inventory", items)
	cfg.set_value("references", "party", party)
	cfg.set_value("references", "selected_hero", game.heroes[game.selected_hero].id)
	var records := {}
	for index in game.heroes.size():
		var hero: Dictionary = game.heroes[index]
		var record := {}
		for key in ["level", "exp", "attack", "speed", "defense"]: record[key] = hero[key]
		record.stats = game.hero_stats[index].duplicate(true)
		record.equipment = {}
		for slot in ["weapon", "armor", "accessory"]:
			record.equipment[slot] = _item_id(game, str(game.hero_equipment[index].get(slot, "")))
		var loadout: Dictionary = game.hero_skills[index]
		record.skills = {"learned":[], "martial":[], "internal":_skill_id(game, str(loadout.internal)), "levels":{}, "exp":{}}
		for name in loadout.learned: record.skills.learned.append(_skill_id(game, name))
		for name in loadout.martial: record.skills.martial.append(_skill_id(game, name))
		for field in ["levels", "exp"]:
			for name in loadout.get(field, {}):
				var id := _skill_id(game, name)
				if not id.is_empty(): record.skills[field][id] = loadout[field][name]
		records[hero.id] = record
	cfg.set_value("references", "heroes", records)
	for key in ["inventory", "selected_party", "selected_hero", "heroes", "hero_stats", "hero_equipment", "hero_skills", "lead_name"]:
		cfg.erase_section_key("player", key)

static func decode(cfg: ConfigFile, game: Node) -> Error:
	var items: Variant = cfg.get_value("references", "inventory")
	var party: Variant = cfg.get_value("references", "party")
	var selected: Variant = cfg.get_value("references", "selected_hero")
	var records: Variant = cfg.get_value("references", "heroes")
	if not items is Array or not party is Array or not selected is String or not records is Dictionary: return ERR_FILE_CORRUPT
	if records.is_empty() or party.is_empty() or party.size() > 3 or not records.has(selected): return ERR_FILE_CORRUPT
	for value in items + party:
		if not value is String: return ERR_FILE_CORRUPT
	for id in party:
		if not records.has(id): return ERR_FILE_CORRUPT
	# Validate every record before converting any data, including removed heroes.
	for id in records:
		if not id is String or not _valid_record(records[id], game): return ERR_FILE_CORRUPT
	var heroes: Array = game._new_game_defaults.heroes.duplicate(true)
	var stats: Array = game._new_game_defaults.hero_stats.duplicate(true)
	var equipment: Array = game._new_game_defaults.hero_equipment.duplicate(true)
	var skills: Array = game._new_game_defaults.hero_skills.duplicate(true)
	var restored_party: Array[int] = []
	var selected_index := 0
	for index in heroes.size():
		var id: String = heroes[index].id
		if selected == id: selected_index = index
		if not records.has(id): continue
		var record: Dictionary = records[id]
		for key in ["level", "exp", "attack", "speed", "defense"]: heroes[index][key] = record[key]
		stats[index] = record.stats.duplicate(true)
		equipment[index] = {}
		for slot in ["weapon", "armor", "accessory"]:
			var name := _item_name(game, str(record.equipment.get(slot, "")))
			if not name.is_empty(): equipment[index][slot] = name
		var loadout := {"learned":[], "martial":[], "internal":_skill_name(game, record.skills.internal), "levels":{}, "exp":{}}
		for skill_id in record.skills.get("learned", record.skills.levels.keys()):
			var name := _skill_name(game, skill_id)
			if not name.is_empty(): loadout.learned.append(name)
		for skill_id in record.skills.martial:
			var name := _skill_name(game, skill_id)
			if not name.is_empty(): loadout.martial.append(name)
		for field in ["levels", "exp"]:
			for skill_id in record.skills[field]:
				var name := _skill_name(game, skill_id)
				if not name.is_empty(): loadout[field][name] = record.skills[field][skill_id]
		skills[index] = loadout
	for id in party:
		for index in heroes.size():
			if heroes[index].id == id and not restored_party.has(index) and restored_party.size() < 3: restored_party.append(index)
	var restored_items: Array[String] = []
	for id in items:
		var name := _item_name(game, id)
		if not name.is_empty(): restored_items.append(name)
	# Keep validation and application shared with the legacy loader.
	var converted := {"inventory":restored_items, "selected_party":restored_party, "selected_hero":selected_index, "heroes":heroes, "hero_stats":stats, "hero_equipment":equipment, "hero_skills":skills}
	for key in converted:
		cfg.set_value("player", key, converted[key])
	return OK

static func _valid_record(value: Variant, game: Node) -> bool:
	if not value is Dictionary: return false
	for key in ["level", "exp", "attack", "speed", "defense"]:
		if not value.get(key) is int or value[key] < 0: return false
	if value.level < 1 or value.level > game.HERO_LEVEL_CAP: return false
	if not value.get("stats") is Dictionary or not value.get("equipment") is Dictionary or not value.get("skills") is Dictionary: return false
	for key in game.hero_stats[0]:
		if not value.stats.get(key) is int or value.stats[key] < 0: return false
	for entry in value.equipment.values():
		if not entry is String: return false
	var skills: Dictionary = value.skills
	if not skills.get("learned", []) is Array: return false
	for id in skills.get("learned", []):
		if not id is String: return false
	if not skills.get("martial") is Array or skills.martial.size() > 4 or not skills.get("internal") is String: return false
	for id in skills.martial:
		if not id is String: return false
	for field in ["levels", "exp"]:
		if not skills.get(field) is Dictionary: return false
		for id in skills[field]:
			if not id is String or not skills[field][id] is int or skills[field][id] < 0: return false
	return true
