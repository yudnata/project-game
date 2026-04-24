extends Area2D

@export var speed: float = 450.0
@export var damage: int = 8
@export var lifetime: float = 3.0

var direction: Vector2 = Vector2.ZERO

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Rotate the arrow to face the direction
	if direction != Vector2.ZERO:
		rotation = direction.angle()
	
	# Auto-destroy after lifetime
	get_tree().create_timer(lifetime).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("receive_hit"):
		body.receive_hit(damage, global_position)
		queue_free()
	elif body.is_in_group("obstacles"): # Optional: hit walls
		queue_free()
