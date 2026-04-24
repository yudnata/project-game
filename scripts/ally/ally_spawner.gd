extends Node2D

@export var ally_scenes: Array[PackedScene] = []
@export var spawn_interval: float = 10.0
@export var max_allies: int = 5

var _timer: float = 0.0

func _ready() -> void:
	# Initial spawn
	spawn_ally()

func _process(delta: float) -> void:
	_timer += delta
	if _timer >= spawn_interval:
		_timer = 0.0
		if get_tree().get_nodes_in_group("ally").size() < max_allies:
			spawn_ally()

func spawn_ally() -> void:
	if ally_scenes.size() == 0: return

	var random_val = randf()
	var ally_scene
	if ally_scenes.size() >= 2:
		if random_val < 0.7:
			ally_scene = ally_scenes[0] # Warrior
		else:
			ally_scene = ally_scenes[1] # Archer
	else:
		ally_scene = ally_scenes[randi() % ally_scenes.size()]
		
	var ally = ally_scene.instantiate()

	# Spawn near the player
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player = players[0]
		var angle = randf() * TAU
		var offset = Vector2(cos(angle), sin(angle)) * randf_range(50, 100)
		ally.global_position = player.global_position + offset
		get_parent().add_child(ally)
