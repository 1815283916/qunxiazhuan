extends RefCounted
## Shared top-bar styling for the map and battle scenes.

static func apply(bar: Control, layout: String) -> void:
	# 大地图顶栏已完全由 world_map.tscn 节点定义，不在运行时创建或移动。
	if layout == "world": return
	if bar.has_node("ReadableBackground"): return
	bar.z_index = 30
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := Panel.new()
	background.name = "ReadableBackground"
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.position = Vector2.ZERO
	background.size = Vector2(1600, 84)
	background.z_index = -1
	var style := StyleBoxFlat.new()
	style.bg_color = Color("121d20")
	if layout == "battle": style.bg_color.a = 0.62
	style.border_color = Color("a9915d")
	style.border_width_bottom = 2
	background.add_theme_stylebox_override("panel", style)
	bar.add_child(background)
	bar.move_child(background, 0)
	for child in bar.get_children():
		if not child is Label: continue
		child.add_theme_color_override("font_color", Color("f5f1e7"))
		child.add_theme_color_override("font_outline_color", Color("0a1113"))
		child.add_theme_constant_override("outline_size", 1)
		child.clip_text = true
		child.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		child.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		child.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if layout == "location":
		_place(bar.get_node("Location"), 290, 660, 28)
		_place(bar.get_node("Date"), 700, 1540, 26)
	else:
		if bar.has_node("Ink"): bar.get_node("Ink").hide()
		var time: Label = bar.get_node("Time")
		time.position = Vector2(24, 4)
		time.size = Vector2(300, 42)
		time.add_theme_font_size_override("font_size", 23)
		var hint: Label = bar.get_node("Hint")
		hint.position = Vector2(580, 6)
		hint.size = Vector2(700, 66)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.max_lines_visible = 2
		hint.add_theme_font_size_override("font_size", 22)

static func _place(label: Label, left: float, right: float, font_size: int) -> void:
	label.position = Vector2(left, 12)
	label.size = Vector2(right - left, 58)
	label.add_theme_font_size_override("font_size", font_size)

