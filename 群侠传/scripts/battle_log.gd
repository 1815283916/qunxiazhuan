extends Panel

@onready var game_state := get_node("/root/GameState")
@onready var toggle: Button = get_parent().get_node("Top/LogToggle")
var displayed_count := -1

func _ready() -> void:
	toggle.set_pressed_no_signal(bool(game_state.settings.get("show_battle_log", true)))
	toggle.toggled.connect(_on_toggled)
	_on_toggled(toggle.button_pressed, false)

func _process(_delta: float) -> void:
	if visible and displayed_count != game_state.battle_log.size(): _refresh()

func _on_toggled(shown: bool, persist: bool = true) -> void:
	visible = shown
	toggle.text = "隐藏战斗详情" if shown else "显示战斗详情"
	if persist: game_state.set_setting("show_battle_log", shown)
	if shown: _refresh(true)

func _refresh(follow: bool = false) -> void:
	var bar := $Scroll.get_v_scroll_bar() as VScrollBar
	var at_bottom := bar.value >= bar.max_value - bar.page - 4.0
	displayed_count = game_state.battle_log.size()
	$Scroll/Text.text = "\n".join(game_state.battle_log) if displayed_count > 0 else "战斗开始，行动记录将在此实时显示。"
	if follow or at_bottom: _scroll_to_latest.call_deferred()

func _scroll_to_latest() -> void:
	# Container layout updates after the label's minimum size changes.
	await get_tree().process_frame
	if not is_inside_tree() or not visible: return
	$Scroll.scroll_vertical = int($Scroll.get_v_scroll_bar().max_value)
