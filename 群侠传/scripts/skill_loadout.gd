extends RefCounted

static func normalize(game: Node, old: Dictionary) -> Dictionary:
	var result := {"learned":[], "martial":[], "internal":"", "levels":{}, "exp":{}}
	var candidates: Array = old.get("learned", []).duplicate()
	candidates.append_array(old.get("martial", []))
	candidates.append(old.get("internal", ""))
	candidates.append_array(old.get("levels", {}).keys())
	for entry in candidates:
		var name: String = game._rename_legacy_skill(str(entry))
		if not game.skill_library.has(name) or result.learned.has(name): continue
		result.learned.append(name)
		result.levels[name] = clampi(int(old.get("levels", {}).get(entry, old.get("levels", {}).get(name, 1))), 1, game.SKILL_LEVEL_CAP)
		result.exp[name] = maxi(0, int(old.get("exp", {}).get(entry, old.get("exp", {}).get(name, 0))))
	for entry in old.get("martial", []):
		var name: String = game._rename_legacy_skill(str(entry))
		if result.learned.has(name) and game.skill_library[name].kind == "武学" and not result.martial.has(name) and result.martial.size() < 4:
			result.martial.append(name)
	var internal: String = game._rename_legacy_skill(str(old.get("internal", "")))
	if game.skill_library.has(internal) and game.skill_library[internal].kind == "心法":
		result.internal = internal
	else:
		for name in result.learned:
			if game.skill_library[name].kind == "心法":
				result.internal = name
				break
		if result.internal.is_empty():
			for name in game.skill_library:
				if game.skill_library[name].kind == "心法":
					result.internal = name
					result.learned.append(name)
					result.levels[name] = 1
					result.exp[name] = 0
					break
	return result
