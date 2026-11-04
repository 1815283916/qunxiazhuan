extends Node

var music_player: AudioStreamPlayer
var effects: Array[AudioStreamPlayer] = []
var streams: Dictionary = {}

func _ready() -> void:
	for bus_name in ["Music", "Effects"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	music_player.volume_db = -13.0
	add_child(music_player)
	music_player.stream = load("res://assets/Audio/jianghu.wav")
	music_player.finished.connect(music_player.play)
	for i in 4:
		var player := AudioStreamPlayer.new()
		player.bus = "Effects"
		player.volume_db = -12.0
		add_child(player)
		effects.append(player)
	for sound in ["click", "attack", "heal", "victory", "defeat"]:
		streams[sound] = load("res://assets/Audio/%s.wav" % sound)
	get_tree().node_added.connect(_connect_button)
	apply_settings(get_node("/root/GameState").settings)
	if DisplayServer.get_name() != "headless": music_player.play()

func _connect_button(node: Node) -> void:
	if node is BaseButton:
		var callback := play_effect.bind("click")
		if not node.pressed.is_connected(callback): node.pressed.connect(callback)

func apply_settings(values: Dictionary) -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), not bool(values.get("music", true)))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Effects"), not bool(values.get("sound", true)))

func play_effect(sound: String) -> void:
	if DisplayServer.get_name() == "headless": return
	if not streams.has(sound): return
	for player in effects:
		if not player.playing:
			player.stream = streams[sound]
			player.play()
			return
