extends Control
@onready var game_state := get_node("/root/GameState")
const Narrative = preload("res://scripts/narrative.gd")

func _ready() -> void:
	preload("res://scripts/top_bar.gd").apply($TopBar, "world")
	$Portrait.position = Vector2(24, 100)
	$Portrait.size = Vector2(220, 220)
	$MapPaper.texture = load(game_state.story_data.world_map.background)
	$TopBar/Money.text = "银两  %d" % game_state.money
	$TopBar/Reputation.text = "声望  %d" % game_state.reputation
	$TopBar/Region.text = "江湖行旅 · 大地图"
	$TopBar/Date.text = "剧情进度  %d / %d" % [mini(Narrative.position(game_state) + 1, game_state.story_data.nodes.size()), game_state.story_data.nodes.size()]
	$Portrait.texture = load(game_state.heroes[0].head)
	var template: Button = $Locations.get_child(0)
	for marker in $Locations.get_children():
		$Locations.remove_child(marker)
		if marker != template: marker.queue_free()
	var current: Dictionary = Narrative.current(game_state)
	var regional: bool = name == "RegionMap"
	var entries: Array = game_state.story_data.regions
	if regional:
		var region := Narrative.region(game_state, game_state.map_region_id)
		game_state.map_region_id = region.id
		$MapPaper.texture = load(region.background)
		$MapPaper.modulate = Color(0.75, 0.78, 0.73)
		$TopBar/Region.text = "大地图 / " + region.name
		entries = Narrative.children(game_state, region.id)
		var back := Button.new()
		back.name = "BackToWorld"
		back.text = "← 返回大地图"
		back.position = Vector2(320, 120)
		back.size = Vector2(240, 58)
		back.add_theme_font_size_override("font_size", 25)
		add_child(back)
		back.pressed.connect(_on_back_pressed)
		var description := Label.new()
		description.name = "RegionDescription"
		description.text = region.description
		description.position = Vector2(340, 690)
		description.size = Vector2(960, 80)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.add_theme_font_size_override("font_size", 25)
		description.add_theme_color_override("font_color", Color("fff2d2"))
		description.add_theme_color_override("font_outline_color", Color("211d16"))
		description.add_theme_constant_override("outline_size", 5)
		add_child(description)
	for i in entries.size():
		var place: Dictionary = entries[i]
		var marker: Button = template.duplicate(0)
		marker.name = place.id
		marker.position = Vector2(520 + (i % 2) * 380, 290 + (i / 2) * 170) if regional else Vector2(place.map_position[0], place.map_position[1])
		marker.size = Vector2(310, 90) if regional else Vector2(game_state.story_data.world_map.marker_size[0], game_state.story_data.world_map.marker_size[1])
		marker.text = place.local_name if regional else place.name
		marker.add_theme_font_size_override("font_size", 28 if regional else 23)
		marker.disabled = not game_state.can_visit(place.id) if regional else not Narrative.region_open(game_state, place.id)
		var normal := marker.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
		normal.bg_color = Color(0.12, 0.16, 0.13, 0.84)
		normal.border_color = Color("a68c57")
		marker.add_theme_stylebox_override("normal", normal)
		var locked := normal.duplicate() as StyleBoxFlat
		locked.bg_color = Color(0.20, 0.21, 0.17, 0.68)
		locked.border_color = Color(0.58, 0.56, 0.45, 0.6)
		marker.add_theme_stylebox_override("disabled", locked)
		marker.add_theme_color_override("font_disabled_color", Color("bfbba8"))
		marker.tooltip_text = place.description if not marker.disabled else "随主线推进开放"
		var target: String = current.get("location", "")
		if not regional and not target.is_empty(): target = Narrative.location(game_state, target).parent
		if target == place.id:
			marker.text = "◆ " + marker.text
			marker.add_theme_color_override("font_color", Color("ffe08b"))
		$Locations.add_child(marker)
		marker.pressed.connect(_on_location_pressed.bind(place.id))
	template.free()

func _on_location_pressed(id: String) -> void:
	if name != "RegionMap":
		if not Narrative.region_open(game_state, id): return
		game_state.map_region_id = id
		game_state.goto("res://scenes/region_map.tscn")
		return
	if not game_state.can_visit(id): return
	var place := Narrative.location(game_state, id)
	if place.parent != game_state.map_region_id: return
	game_state.current_scene = place.name
	game_state.current_location = Narrative.region(game_state, place.parent).name
	game_state.goto("res://scenes/location.tscn")

func _on_back_pressed() -> void:
	game_state.goto("res://scenes/world_map.tscn")

func _on_character_pressed() -> void:
	_open_map_panel("res://scenes/roster.tscn")

func _on_menu_pressed() -> void:
	game_state.menu_return_scene = "res://scenes/region_map.tscn" if name == "RegionMap" else "res://scenes/world_map.tscn"
	game_state.goto("res://scenes/system_menu.tscn")

func _on_log_pressed() -> void:
	_open_map_panel("res://scenes/journal.tscn")

func _on_inventory_pressed() -> void:
	_open_map_panel("res://scenes/inventory.tscn")

func _open_map_panel(path: String) -> void:
	game_state.map_panel_return_scene = "res://scenes/region_map.tscn" if name == "RegionMap" else "res://scenes/world_map.tscn"
	game_state.goto(path)
