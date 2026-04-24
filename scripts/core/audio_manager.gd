extends Node

# Dictionary to store sounds
var sounds = {}

func _ready() -> void:
	# Load sounds in _ready to avoid preload issues with unrecognized extensions
	_load_sound("arrow_shoot", "res://assets/sounds/arrow_shoot.mp3")
	_load_sound("impact_arrow", "res://assets/sounds/impact_arrow.wav")
	_load_sound("impact_melee1", "res://assets/sounds/impact_melee.mp3")
	_load_sound("impact_melee2", "res://assets/sounds/impact_melee2.wav")
	_load_sound("impact_melee3", "res://assets/sounds/impact_melee3.wav")
	_load_sound("impact_melee4", "res://assets/sounds/impact_melee4.wav")
	_load_sound("player_dash", "res://assets/sounds/player_dash.mp3")
	_load_sound("sword_swing", "res://assets/sounds/sword_swing.mp3")
	_load_sound("unit_death", "res://assets/sounds/unit_death.mp3")

func _load_sound(key: String, path: String) -> void:
	if FileAccess.file_exists(path) or ResourceLoader.exists(path):
		var res = load(path)
		if res:
			sounds[key] = res
		else:
			# If load fails, it's often an import issue
			push_warning("AudioManager: Resource found but could not be loaded as AudioStream. Path: " + path)
	else:
		push_error("AudioManager: Sound file not found at path: " + path)

func play_sfx(sound_name: String, volume_db: float = 0.0, pitch_min: float = 0.9, pitch_max: float = 1.1) -> void:
	# Handle randomized melee impacts
	var actual_sound = sound_name
	if actual_sound == "impact_melee_random":
		var rand_idx = randi_range(1, 4)
		actual_sound = "impact_melee" + str(rand_idx)

	if not sounds.has(actual_sound):
		# Only print error if it's not a missing random variant
		if not actual_sound.begins_with("impact_melee"):
			push_error("AudioManager: Sound not found in library: " + actual_sound)
		return

	var asp = AudioStreamPlayer.new()
	asp.stream = sounds[actual_sound]
	asp.volume_db = volume_db
	asp.pitch_scale = randf_range(pitch_min, pitch_max)

	# If you haven't created an "SFX" bus, it will default to "Master"
	if AudioServer.get_bus_index("SFX") != -1:
		asp.bus = "SFX"

	add_child(asp)
	asp.play()

	# Auto cleanup
	asp.finished.connect(asp.queue_free)

func play_impact_melee() -> void:
	play_sfx("impact_melee_random")

func play_impact_arrow() -> void:
	play_sfx("impact_arrow", -5.0)

func play_death() -> void:
	play_sfx("unit_death")
