extends Camera2D

@export var target_path: NodePath
@export var follow_speed: float = 10.0

@onready var target: Node2D = get_node_or_null(target_path) as Node2D

func _process(delta: float) -> void:
	if target == null:
		return

	global_position = global_position.lerp(target.global_position, clamp(follow_speed * delta, 0.0, 1.0))
