extends CharacterBody2D

@export var max_hp: int = 30
@export var move_speed: float = 80.0
@export var chase_range: float = 220.0
@export var attack_range: float = 20.0
@export var attack_damage: int = 8
@export var attack_cooldown: float = 0.8
@export var attack_windup: float = 0.18
@export var knockback_force: float = 320.0
@export var knockback_duration: float = 0.22
@export var too_close_distance: float = 14.0
@export var attack_recoil_force: float = 85.0
@export var attack_recoil_duration: float = 0.08

var hp: int
var _can_attack: bool = true
var _target: CharacterBody2D
var _knockback_velocity: Vector2 = Vector2.ZERO
var _knockback_remaining: float = 0.0
var _flash_base_modulate: Color = Color.WHITE

@onready var hp_label: Label = $HpLabel

func _ready() -> void:
	hp = max_hp
	_flash_base_modulate = modulate
	_update_hp_label()
	_update_target()

func _physics_process(delta: float) -> void:
	if _knockback_remaining > 0.0:
		_knockback_remaining = max(_knockback_remaining - delta, 0.0)
		velocity = _knockback_velocity
		_knockback_velocity = _knockback_velocity.move_toward(
			Vector2.ZERO,
			knockback_force * 8.0 * delta
		)
		move_and_slide()
		return

	if _target == null or not is_instance_valid(_target):
		_update_target()
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var to_target := _target.global_position - global_position
	var distance := to_target.length()

	if distance > chase_range:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if distance < too_close_distance:
		velocity = (-to_target.normalized()) * (move_speed * 0.9)
		move_and_slide()
		return

	if distance <= attack_range:
		velocity = Vector2.ZERO
		if _can_attack:
			_attack_target()
	else:
		velocity = to_target.normalized() * move_speed

	move_and_slide()

func receive_hit(damage: int, source_position: Vector2 = Vector2.ZERO) -> void:
	hp = max(hp - damage, 0)
	_update_hp_label()
	_flash_hit()
	if source_position != Vector2.ZERO:
		var knock_dir := (global_position - source_position).normalized()
		_knockback_velocity = knock_dir * knockback_force
		_knockback_remaining = knockback_duration

	if hp <= 0:
		queue_free()

func _update_target() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_target = players[0] as CharacterBody2D

func _attack_target() -> void:
	_can_attack = false
	if _target != null:
		var recoil_dir := (global_position - _target.global_position).normalized()
		_knockback_velocity = recoil_dir * attack_recoil_force
		_knockback_remaining = attack_recoil_duration
		modulate = Color(1.1, 0.85, 0.85, 1)
		await get_tree().create_timer(attack_windup).timeout
	if _target != null and _target.has_method("receive_hit"):
		_target.receive_hit(attack_damage, global_position)
	modulate = _flash_base_modulate
	await get_tree().create_timer(attack_cooldown).timeout
	_can_attack = true

func _flash_hit() -> void:
	modulate = Color(1.15, 1.15, 1.15, 1)
	await get_tree().create_timer(0.08).timeout
	modulate = _flash_base_modulate

func _update_hp_label() -> void:
	hp_label.text = "HP: %d" % hp
