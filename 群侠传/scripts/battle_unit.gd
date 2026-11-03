extends TextureButton

const IDLE_SCALE := Vector2(0.85, 0.85)
const ACTION_SCALE := Vector2(0.82, 0.82)
const HURT_SCALE := Vector2(0.85, 0.85)

@onready var model: AnimatedSprite2D = $Model

var model_path := ""
var model_scale_factor := 1.0
var facing_direction := Vector2i.RIGHT
var floating_text_count := 0

func _ready() -> void:
	model.animation_finished.connect(_on_animation_finished)
	model.frame_changed.connect(_on_model_frame_changed)

func configure(path: String, face_left: bool) -> void:
	if path.is_empty(): return
	if path == model_path and model.sprite_frames != null: return
	model_path = path
	facing_direction = Vector2i.LEFT if face_left else Vector2i.RIGHT
	model.flip_h = face_left
	model_scale_factor = _get_model_scale_factor(path.get_file())
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	_add_animation(frames, "idle", "stand_", 8.0, true)
	_add_animation(frames, "attack", "attack_", 12.0, false)
	_add_animation(frames, "hurt", "beattack_", 10.0, false)
	_add_parenthesized_animation(frames, "idle", "stand", 8.0, true)
	_add_parenthesized_animation(frames, "attack", "att", 12.0, false)
	_add_parenthesized_animation(frames, "hurt", "beat", 10.0, false)
	_add_parenthesized_animation(frames, "walk", "move", 12.0, true)
	_add_numbered_animation(frames, "idle", "stand", 8.0, true)
	_add_numbered_animation(frames, "attack", "attack", 12.0, false)
	_add_numbered_animation(frames, "hurt", "hurt", 10.0, false)
	match model_path.get_file():
		"chenxi1":
			_add_plain_sequence(frames, "hurt", 1, 2, 10.0, false)
			_add_plain_sequence(frames, "idle", 3, 7, 8.0, true)
			_add_plain_sequence(frames, "attack", 8, 14, 12.0, false)
			_add_plain_sequence(frames, "walk", 15, 22, 10.0, true)
		"chenxi2":
			_add_plain_sequence(frames, "hurt", 1, 2, 10.0, false)
			_add_plain_sequence(frames, "idle", 3, 8, 8.0, true)
			_add_plain_sequence(frames, "attack", 9, 16, 12.0, false)
			_add_plain_sequence(frames, "walk", 17, 24, 10.0, true)
	model.sprite_frames = frames
	_update_model_offset()
	play_action("idle")

func face_toward(direction: Vector2i) -> void:
	if direction == Vector2i.ZERO: return
	facing_direction = Vector2i(signi(direction.x), signi(direction.y))
	model.flip_h = direction.x < 0 if direction.x != 0 else direction.y < 0

func play_action(action: String) -> void:
	if model.sprite_frames == null: return
	action = _resolve_action_name(action)
	if not model.sprite_frames.has_animation(action): return
	var base_scale := ACTION_SCALE if action == "attack" else HURT_SCALE if action == "hurt" else IDLE_SCALE
	model.scale = base_scale * model_scale_factor
	model.play(action)

func play_action_and_wait(action: String) -> void:
	action = _resolve_action_name(action)
	if model.sprite_frames == null or not model.sprite_frames.has_animation(action): return
	play_action(action)
	await wait_for_action(action)

func wait_for_action(action: String) -> void:
	action = _resolve_action_name(action)
	if model.sprite_frames == null or not model.sprite_frames.has_animation(action): return
	if model.animation == action and not model.sprite_frames.get_animation_loop(action): await model.animation_finished

func _resolve_action_name(action: String) -> String:
	return "attack" if action == "skill" else action

func start_walk_animation() -> void:
	if model.sprite_frames != null and model.sprite_frames.has_animation("walk"): play_action("walk")

func stop_walk_animation() -> void:
	if model.animation == "walk": play_action("idle")

func show_floating_text(message: String, color: Color, font_size: int = 22) -> void:
	if message.is_empty(): return
	var popup := Label.new()
	popup.text = message
	var popup_width := maxf(190.0, float(message.length()) * float(font_size) * 1.12 + 24.0)
	var popup_height := float(font_size + 12)
	popup.size = Vector2(popup_width, popup_height)
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.z_as_relative = false
	popup.z_index = 100 + floating_text_count
	popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup.add_theme_color_override("font_color", color)
	popup.add_theme_color_override("font_outline_color", Color(0.03, 0.025, 0.02, 0.95))
	popup.add_theme_constant_override("outline_size", 4)
	popup.add_theme_font_size_override("font_size", font_size)
	var popup_parent := get_parent().get_parent() as Control
	if popup_parent == null: popup_parent = self
	popup_parent.add_child(popup)
	popup.global_position = global_position + Vector2(-popup_width * 0.5, -148 - mini(floating_text_count, 3) * (popup_height - 4.0))
	floating_text_count += 1
	var start_y := popup.global_position.y
	var tween := create_tween().set_parallel(true)
	tween.tween_property(popup, "global_position:y", start_y - 40.0, 0.72).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(popup, "modulate:a", 0.0, 0.38).set_delay(0.34)
	tween.finished.connect(func() -> void:
		floating_text_count = maxi(0, floating_text_count - 1)
		popup.queue_free()
	)


func _add_animation(frames: SpriteFrames, animation: String, prefix: String, speed: float, looped: bool) -> void:
	if frames.has_animation(animation): return
	var textures: Array[Texture2D] = []
	for frame_index in range(1, 33):
		var frame_path := model_path.path_join("%s%d.png" % [prefix, frame_index])
		if not ResourceLoader.exists(frame_path): break
		var texture := load(frame_path) as Texture2D
		if texture != null: textures.append(_trim_transparency(texture))
	if textures.is_empty(): return
	frames.add_animation(animation)
	frames.set_animation_speed(animation, speed)
	frames.set_animation_loop(animation, looped)
	for texture in textures:
		frames.add_frame(animation, texture)

func _add_parenthesized_animation(frames: SpriteFrames, animation: String, prefix: String, speed: float, looped: bool) -> void:
	if frames.has_animation(animation): return
	var textures: Array[Texture2D] = []
	for frame_index in range(1, 33):
		var frame_path := model_path.path_join("%s (%d).png" % [prefix, frame_index])
		if not ResourceLoader.exists(frame_path): break
		var texture := load(frame_path) as Texture2D
		if texture != null: textures.append(_trim_transparency(texture))
	_add_texture_animation(frames, animation, textures, speed, looped)

func _add_numbered_animation(frames: SpriteFrames, animation: String, prefix: String, speed: float, looped: bool) -> void:
	if frames.has_animation(animation): return
	var textures: Array[Texture2D] = []
	for frame_index in range(32):
		var frame_path := model_path.path_join("%s%03d.png" % [prefix, frame_index])
		if not ResourceLoader.exists(frame_path): break
		var texture := load(frame_path) as Texture2D
		if texture != null: textures.append(_trim_transparency(texture))
	_add_texture_animation(frames, animation, textures, speed, looped)

func _add_plain_sequence(frames: SpriteFrames, animation: String, first_frame: int, last_frame: int, speed: float, looped: bool) -> void:
	if frames.has_animation(animation): return
	var textures: Array[Texture2D] = []
	for frame_index in range(first_frame, last_frame + 1):
		var frame_path := model_path.path_join("%d.png" % frame_index)
		if not ResourceLoader.exists(frame_path): break
		var texture := load(frame_path) as Texture2D
		if texture != null: textures.append(_trim_transparency(texture))
	_add_texture_animation(frames, animation, textures, speed, looped)

func _add_texture_animation(frames: SpriteFrames, animation: String, textures: Array[Texture2D], speed: float, looped: bool) -> void:
	if textures.is_empty() or frames.has_animation(animation): return
	frames.add_animation(animation)
	frames.set_animation_speed(animation, speed)
	frames.set_animation_loop(animation, looped)
	for texture in textures:
		frames.add_frame(animation, texture)

func _on_animation_finished() -> void:
	if model.animation != "idle": play_action("idle")

func _trim_transparency(texture: Texture2D) -> Texture2D:
	var image := texture.get_image()
	if image == null: return texture
	var used_rect := image.get_used_rect()
	if used_rect.size == Vector2i.ZERO or used_rect == Rect2i(Vector2i.ZERO, image.get_size()): return texture
	return ImageTexture.create_from_image(image.get_region(used_rect))

func _on_model_frame_changed() -> void:
	_update_model_offset()

func _update_model_offset() -> void:
	if model.sprite_frames == null or not model.sprite_frames.has_animation(model.animation): return
	var texture := model.sprite_frames.get_frame_texture(model.animation, model.frame)
	if texture != null: model.offset = Vector2(0, -texture.get_height() * 0.5)

func _get_model_scale_factor(model_name: String) -> float:
	match model_name:
		"r-nv-duguyanran": return 1.35
		"r-nv-huangyishuangjian": return 0.72
		_: return 1.0
