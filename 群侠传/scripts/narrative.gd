extends RefCounted
## Story IDs, rather than the old demo quest numbers, are stored in saves.

static func position(game: Node) -> int:
	for i in game.story_data.nodes.size():
		if game.story_data.nodes[i].id == game.narrative_progress.next: return i
	return game.story_data.nodes.size()

static func current(game: Node) -> Dictionary:
	var index := position(game)
	return game.story_data.nodes[index] if index < game.story_data.nodes.size() else {}

static func location(game: Node, id: String = "") -> Dictionary:
	for entry in game.story_data.locations:
		if entry.id == id or (id.is_empty() and entry.name == game.current_scene): return entry
	return game.story_data.locations[0]

static func region(game: Node, id: String = "") -> Dictionary:
	var target := id if not id.is_empty() else str(location(game).parent)
	for entry in game.story_data.regions:
		if entry.id == target: return entry
	return game.story_data.regions[0]

static func children(game: Node, id: String) -> Array:
	return game.story_data.locations.filter(func(place: Dictionary) -> bool: return place.parent == id)

static func region_open(game: Node, id: String) -> bool:
	for place in children(game, id):
		if visitable(game, place.id): return true
	return false

static func region_scene(game: Node) -> String:
	game.map_region_id = location(game).parent
	return "res://scenes/region_map.tscn"

static func available(game: Node, hero: int) -> bool:
	var members: Array = [0]
	var cursor := position(game)
	for i in mini(cursor + 1, game.story_data.nodes.size()):
		var node: Dictionary = game.story_data.nodes[i]
		if i < cursor or game.narrative_progress.pending:
			for index in node.get("join", []):
				if not members.has(index): members.append(index)
		if i < cursor:
			for index in node.get("leave", []): members.erase(index)
	return members.has(hero)

static func healed(game: Node) -> bool:
	for i in position(game):
		if game.story_data.nodes[i].get("heal", false): return true
	return false

static func visitable(game: Node, id: String) -> bool:
	for i in mini(position(game) + 1, game.story_data.nodes.size()):
		if game.story_data.nodes[i].location == id: return true
	return false

static func objective(game: Node) -> String:
	var node := current(game)
	if node.is_empty(): return "本章已完成 · 自由游历已开放场所，前路待续。"
	var place := location(game, node.location)
	var destination: String = region(game, place.parent).name + " → " + place.local_name
	return "第%02d场 · %s：前往%s%s" % [node.chapter, node.title, destination, "，完成" + game.story_data.encounters[node.battle].name if game.narrative_progress.pending else ""]

static func dialogue_at(game: Node) -> String:
	var place := location(game)
	var node := current(game)
	if not node.is_empty() and node.location == place.id: return node.id
	var last := ""
	for i in position(game):
		if game.story_data.nodes[i].location == place.id: last = game.story_data.nodes[i].id
	return last

static func choose_party(game: Node) -> void:
	var party: Array[int] = []
	for i in game.heroes.size():
		if available(game, i) and (i != 0 or healed(game)): party.append(i)
	game.selected_party = party.slice(0, 3)
	if game.selected_party.is_empty(): game.selected_party.append(0)
	if not available(game, game.selected_hero): game.selected_hero = 0

static func begin_battle(game: Node) -> void:
	var node := current(game)
	if node.is_empty() or not node.has("battle"): return
	game.narrative_progress.pending = true
	game.current_encounter = node.battle
	choose_party(game)

static func complete(game: Node, id: String, victory: bool = false) -> bool:
	var node := current(game)
	if node.is_empty() or node.id != id: return false
	if node.has("battle") and not victory:
		begin_battle(game)
		return false
	if node.has("battle") and (not game.narrative_progress.pending or game.current_encounter != node.battle): return false
	game.money += int(node.get("money", 0))
	for item in node.get("items", []): game.inventory.append(item)
	for index in node.get("leave", []):
		for slot in ["weapon", "armor", "accessory"]:
			if not str(game.hero_equipment[index].get(slot, "")).is_empty(): game.unequip_item(index, slot)
	if node.get("heal", false):
		game.learn_skill(0, "神照经")
		game.equip_skill(0, "神照经")
		for skill in ["神照经", "降龙十八掌", "九阴真经"]:
			game.hero_skills[0].levels[skill] = maxi(int(game.hero_skills[0].levels.get(skill, 1)), 3)
		game.gain_hero_experience(0, 7200)
	game.seen_stories.append(id)
	game.journal.append("第%02d场 · %s" % [node.chapter, node.title])
	if node.get("heal", false): game.journal.append("神照经全篇已贯通，经脉续接；胡夫人返回药王庄。现在可以让宋青书出战。")
	var cursor := position(game) + 1
	game.narrative_progress = {"next":game.story_data.nodes[cursor].id if cursor < game.story_data.nodes.size() else "", "pending":false}
	choose_party(game)
	return true

static func followup_scene(game: Node) -> String:
	var node := current(game)
	if not node.is_empty() and node.get("interlude", false):
		game.dialogue_story_id = node.id
		return "res://scenes/dialogue.tscn"
	if not node.is_empty() and node.get("automatic", false):
		game.dialogue_story_id = node.id
		game.current_scene = location(game, node.location).name
		return "res://scenes/dialogue.tscn"
	if not node.is_empty() and location(game, node.location).parent == location(game).parent:
		return region_scene(game)
	return "res://scenes/world_map.tscn"

static func valid(game: Node, value: Variant) -> bool:
	if not value is Dictionary or not value.get("next") is String or not value.get("pending") is bool: return false
	if value.next.is_empty(): return not value.pending
	for node in game.story_data.nodes:
		if node.id == value.next: return not value.pending or node.has("battle")
	return false
