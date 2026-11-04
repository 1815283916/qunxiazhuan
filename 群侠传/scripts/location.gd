extends Control
@onready var game_state := get_node("/root/GameState")
const Narrative = preload("res://scripts/narrative.gd")
var story_id := ""
var training := false

func _ready() -> void:
	preload("res://scripts/top_bar.gd").apply($TopBar, "location")
	$Portrait.position = Vector2(24, 95)
	$Portrait.size = Vector2(210, 210)
	var place := Narrative.location(game_state)
	var node := Narrative.current(game_state)
	story_id = Narrative.dialogue_at(game_state)
	$TopBar/Location.text = place.local_name
	$TopBar/Date.text = Narrative.region(game_state, place.parent).name + " / " + place.local_name
	$Background.texture = load(place.background)
	$Portrait.texture = load(game_state.heroes[0].head)
	$Lore.visible = false
	$Interactions/Back/Label.text = "返回" + Narrative.region(game_state, place.parent).name
	_configure_story_interaction(node.get("id", "") == story_id)
	training = place.id == "tianlong" and Narrative.healed(game_state)
	var pending: bool = game_state.narrative_progress.pending and node.get("location", "") == place.id
	$Interactions/Plaza/Label.text = "继续战斗" if pending else "天龙切磋"
	$Interactions/Plaza.visible = pending or training
	$Interactions/Shop.visible = place.shop
	$Description/Text.text = place.description + "\n" + game_state.get_objective()

func _configure_story_interaction(active: bool) -> void:
	var button: TextureButton = $Interactions/NPC
	button.disabled = story_id.is_empty()
	button.visible = not button.disabled
	if button.disabled: return
	var triggers: Dictionary = game_state.story_data.get("story_triggers", {})
	var display_name: String = triggers.get(story_id, "查看往事")
	var portraits: Dictionary = game_state.story_data.get("portraits", {})
	var head: String = portraits.get(display_name, "")
	for hero in game_state.heroes:
		if hero.name == display_name:
			head = hero.head
			break
	button.texture_normal = load(head if not head.is_empty() else "res://assets/UI/story_event.svg")
	button.get_node("Label").text = display_name
	button.tooltip_text = ("触发剧情 · " if active else "回顾往事 · ") + display_name

func _on_npc_pressed() -> void:
	if story_id.is_empty(): return
	game_state.dialogue_story_id = story_id
	game_state.goto("res://scenes/dialogue.tscn")

func _on_plaza_pressed() -> void:
	var node := Narrative.current(game_state)
	if game_state.narrative_progress.pending and node.get("location", "") == Narrative.location(game_state).id:
		Narrative.begin_battle(game_state)
	elif training:
		game_state.current_encounter = "tianlong"
		Narrative.choose_party(game_state)
	else: return
	game_state.goto("res://scenes/battle_prep.tscn")

func _on_shop_pressed() -> void:
	if Narrative.location(game_state).shop: game_state.goto("res://scenes/shop.tscn")

func _on_back_pressed() -> void:
	game_state.goto(Narrative.region_scene(game_state))
