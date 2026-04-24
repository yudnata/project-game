extends Camera2D

@export var target_path: NodePath
@export var follow_speed: float = 10.0

@onready var target: Node2D = get_node_or_null(target_path) as Node2D

var _shake_intensity: float = 0.0
var _shake_decay: float = 5.0

func _ready() -> void:
	add_to_group("camera")

func _process(delta: float) -> void:
	if target == null:
		return

	var target_pos = target.global_position

	if _shake_intensity > 0:
		_shake_intensity = lerp(_shake_intensity, 0.0, _shake_decay * delta)
		var shake_offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake_intensity
		target_pos += shake_offset
	global_position = global_position.lerp(target_pos, clamp(follow_speed * delta, 0.0, 1.0))

func shake(intensity: float, decay: float = 5.0) -> void:
	_shake_intensity = intensity
	_shake_decay = decay
