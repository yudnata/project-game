extends Area2D

@export var speed: float = 400.0
var direction: Vector2 = Vector2.RIGHT
var damage: int = 8

func _ready() -> void:
	rotation = direction.angle()
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

	# Auto-destroy after 3 seconds
	get_tree().create_timer(3.0).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy") and body.has_method("receive_hit"):
		body.receive_hit(damage)
		AudioManager.play_impact_arrow()
		queue_free()

func _on_area_entered(_area: Area2D) -> void:
	# Add logic here if you want arrows to hit other areas
	pass
