extends Control
@onready var game_state := get_node("/root/GameState")
const Narrative = preload("res://scripts/narrative.gd")
var lines: Array = []
var index := 0
var completed := false
var story_id := ""
var pages: Array[Dictionary] = []
var progress_label: Label
var previous_button: Button

func _ready() -> void:
	story_id = game_state.dialogue_story_id
	if story_id.is_empty(): story_id = Narrative.dialogue_at(game_state)
	lines = game_state.get_story_lines(story_id)
	if lines.is_empty():
		game_state.goto("res://scenes/location.tscn")
		return
	for record in lines.size():
		var text: String = lines[record][1]
		while not text.is_empty():
			var cut := mini(84, text.length())
			if cut < text.length():
				for i in range(cut - 1, 41, -1):
					if text[i] in ["。", "！", "？", "；", "，", "、"]:
						cut = i + 1
						break
			pages.append({"speaker":lines[record][0], "text":text.left(cut), "record":record})
			text = text.substr(cut)
	progress_label = Label.new()
	progress_label.name = "PageProgress"
	progress_label.position = Vector2(465, 40)
	progress_label.size = Vector2(535, 40)
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	progress_label.add_theme_font_size_override("font_size", 22)
	progress_label.add_theme_color_override("font_color", Color("f4dfb2"))
	$DialogueBox.add_child(progress_label)
	previous_button = Button.new()
	previous_button.name = "PreviousPage"
	previous_button.text = "上一页"
	previous_button.position = Vector2(32, 262)
	previous_button.size = Vector2(175, 52)
	previous_button.add_theme_font_size_override("font_size", 23)
	previous_button.pressed.connect(_on_previous_pressed)
	$DialogueBox.add_child(previous_button)
	var location_id := "shaolin_room"
	for node in game_state.story_data.nodes:
		if node.id == story_id: location_id = node.location
	$SceneBackground.texture = load(Narrative.location(game_state, location_id).background)
	$DialogueBox/Battle.visible = false
	_show_line()

func _show_line() -> void:
	var speaker: String = pages[index].speaker
	$DialogueBox/Speaker.text = speaker
	$DialogueBox/Text.text = pages[index].text
	progress_label.text = "%d / %d 页" % [index + 1, pages.size()]
	previous_button.disabled = index == 0
	$Portrait.visible = speaker != "旁白"
	var head := ""
	for hero in game_state.heroes:
		if speaker.begins_with(hero.name): head = hero.head
	if head.is_empty():
		var portraits: Dictionary = game_state.story_data.get("portraits", {})
		if portraits.has(speaker): head = str(portraits[speaker])
		else: $Portrait.visible = false
	if not head.is_empty(): $Portrait.texture = load(head)
	$DialogueBox/Continue/Label.text = "完 成" if index == pages.size() - 1 else "继 续"

func _on_previous_pressed() -> void:
	if completed or index == 0: return
	index -= 1
	_show_line()

func _finish() -> void:
	if completed: return
	completed = true
	var active: bool = game_state.narrative_progress.next == story_id
	game_state.complete_story(story_id)
	game_state.dialogue_story_id = ""
	var next := "res://scenes/location.tscn"
	if active:
		if game_state.narrative_progress.pending: next = "res://scenes/battle_prep.tscn"
		else: next = Narrative.followup_scene(game_state)
	if game_state.autosave() != OK: push_warning("剧情自动存档失败")
	game_state.goto(next)

func _on_continue_pressed() -> void:
	index += 1
	if index >= pages.size(): _finish()
	else: _show_line()

func _on_skip_pressed() -> void:
	_finish()

func _on_battle_pressed() -> void:
	_finish()
