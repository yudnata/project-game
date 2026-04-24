extends Node2D

@export var enemy_scenes: Array[PackedScene] = []
@export var spawn_interval: float = 5.0
@export var spawn_distance_min: float = 350.0
@export var spawn_distance_max: float = 600.0
@export var max_enemies: int = 15

var _timer: float = 0.0

func _process(delta: float) -> void:
	_timer += delta
	if _timer >= spawn_interval:
		_timer = 0.0
		_spawn_enemy()

func _spawn_enemy() -> void:
	if enemy_scenes.size() == 0:
		return

	if get_tree().get_nodes_in_group("enemy").size() >= max_enemies:
		return

	var players = get_tree().get_nodes_in_group("player")
	if players.size() == 0:
		return

	var player = players[0]

	# Spawn at a random angle and distance around the player
	var angle = randf() * TAU
	var distance = randf_range(spawn_distance_min, spawn_distance_max)
	var offset = Vector2(cos(angle), sin(angle)) * distance

	var spawn_pos = player.global_position + offset

	var random_val = randf()
	var random_scene
	if enemy_scenes.size() >= 2:
		if random_val < 0.7:
			random_scene = enemy_scenes[0] # Warrior
		else:
			random_scene = enemy_scenes[1] # Archer
	else:
		random_scene = enemy_scenes[randi() % enemy_scenes.size()]

	var enemy = random_scene.instantiate()
	enemy.global_position = spawn_pos

	# Add the enemy as a sibling of the spawner (under the World node)
	get_parent().add_child(enemy)
