extends CharacterBody2D

@export var arrow_scene: PackedScene = preload("res://scenes/enemy/Arrow.tscn")
@export var max_hp: int = 40
@export var move_speed: float = 75.0
@export var chase_range: float = 1000.0
@export var attack_range: float = 280.0
@export var too_close_distance: float = 120.0
@export var attack_damage: int = 6
@export var attack_cooldown: float = 1.8
@export var attack_windup: float = 0.5

# Dash Ability
@export var dash_speed: float = 220.0
@export var dash_duration: float = 0.12
@export var dash_cooldown: float = 3.0

var hp: int
var _can_attack: bool = true
var _target: CharacterBody2D
var _knockback_velocity: Vector2 = Vector2.ZERO
var _knockback_remaining: float = 0.0
var _flash_base_modulate: Color = Color.WHITE
var _target_update_timer: float = 0.0
var _dash_cooldown_timer: float = 0.0
var _is_dashing: bool = false
var _is_dead: bool = false

# Preload textures
@onready var _tex_idle = preload("res://assets/Units/Red Units/Archer/Archer_Idle.png")
@onready var _tex_run = preload("res://assets/Units/Red Units/Archer/Archer_Run.png")
@onready var _tex_shoot = preload("res://assets/Units/Red Units/Archer/Archer_Shoot.png")

@onready var _anim_data = {
	"Idle":  {"tex": _tex_idle,  "frames": 6, "loop": true,  "speed": 10.0},
	"Run":   {"tex": _tex_run,   "frames": 4, "loop": true,  "speed": 10.0},
	"Shoot": {"tex": _tex_shoot, "frames": 8, "loop": false, "speed": 10.0}
}

@onready var sprite: Sprite2D = $Body
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var health_bar: ProgressBar = $HealthBar

# Shared Library
static var _cached_library: AnimationLibrary

func _ready() -> void:
	add_to_group("enemy")
	hp = max_hp
	_flash_base_modulate = modulate
	_update_health_bar()
	_update_target()

	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_setup_animations()

func _physics_process(delta: float) -> void:
	if _is_dead: return

	if _knockback_remaining > 0.0:
		_knockback_remaining = max(_knockback_remaining - delta, 0.0)
		velocity = _knockback_velocity
		_knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO, 2400.0 * delta)
		move_and_slide()
		return

	if _is_dashing:
		if Engine.get_physics_frames() % 2 == 0:
			_spawn_ghost()
		move_and_slide()
		return

	if _dash_cooldown_timer > 0:
		_dash_cooldown_timer -= delta

	# Re-evaluate target periodically
	_target_update_timer -= delta
	if _target_update_timer <= 0:
		_update_target()
		_target_update_timer = 0.5

	if _target == null or not is_instance_valid(_target):
		_play_animation("Idle")
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var to_target := _target.global_position - global_position
	var distance := to_target.length()

	if distance > chase_range:
		velocity = Vector2.ZERO
		_play_animation("Idle")
		move_and_slide()
		return

	if abs(to_target.x) > 2.0 and not _is_playing_attack_anim():
		sprite.flip_h = to_target.x < 0

	# Dash logic: Dash away if target gets too close
	if _dash_cooldown_timer <= 0 and distance < too_close_distance - 20.0:
		_perform_dash(-to_target.normalized())
		return

	if distance > attack_range:
		velocity = to_target.normalized() * move_speed
		if not _is_playing_attack_anim():
			_play_animation("Run")
	elif distance < too_close_distance - 25.0:
		velocity = -to_target.normalized() * (move_speed * 0.5) 
		if not _is_playing_attack_anim():
			_play_animation("Run")
	elif distance < attack_range - 40.0:
		velocity = velocity.move_toward(Vector2.ZERO, 400.0 * delta)
		if _can_attack:
			_attack_target()
		elif not _is_playing_attack_anim():
			_play_animation("Idle")
	else:
		velocity = velocity.move_toward(Vector2.ZERO, 200.0 * delta)
		if not _is_playing_attack_anim():
			_play_animation("Idle")

	move_and_slide()

func _perform_dash(dir: Vector2) -> void:
	_is_dashing = true
	_dash_cooldown_timer = dash_cooldown
	velocity = dir * dash_speed

	AudioManager.play_sfx("player_dash")

	var tween = get_tree().create_tween()
	tween.tween_property(sprite, "modulate", Color(2, 2, 2, 1), 0.05)
	tween.tween_property(sprite, "modulate", _flash_base_modulate, 0.1)

	await get_tree().create_timer(dash_duration).timeout
	_is_dashing = false

func _spawn_ghost() -> void:
	var ghost = Sprite2D.new()
	get_parent().add_child(ghost)
	ghost.texture = sprite.texture
	ghost.hframes = sprite.hframes
	ghost.vframes = sprite.vframes
	ghost.frame = sprite.frame
	ghost.flip_h = sprite.flip_h
	ghost.global_position = sprite.global_position
	ghost.modulate = Color(1.5, 1.5, 2, 0.4)

	var tween = get_tree().create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.15)
	tween.tween_callback(ghost.queue_free)

func _update_target() -> void:
	var potential_targets = get_tree().get_nodes_in_group("player")
	potential_targets.append_array(get_tree().get_nodes_in_group("ally"))

	var closest_dist := 1200.0
	_target = null

	for target in potential_targets:
		if is_instance_valid(target):
			var dist = global_position.distance_to(target.global_position)
			if dist < closest_dist:
				closest_dist = dist
				_target = target

func _attack_target() -> void:
	_can_attack = false
	_play_animation("Shoot")
	AudioManager.play_sfx("arrow_shoot")

	await get_tree().create_timer(attack_windup).timeout

	if is_instance_valid(_target):
		_shoot_arrow()

	await get_tree().create_timer(attack_cooldown - attack_windup).timeout
	_can_attack = true

func _shoot_arrow() -> void:
	if not arrow_scene: return

	var arrow = arrow_scene.instantiate()
	var dir = (_target.global_position - global_position).normalized()
	arrow.direction = dir
	arrow.damage = attack_damage
	arrow.global_position = global_position + dir * 15.0
	get_parent().add_child(arrow)

func receive_hit(damage: int, source_position: Vector2 = Vector2.ZERO) -> void:
	if _is_dead: return
	hp = max(hp - damage, 0)
	_update_health_bar()
	_flash_hit()
	if source_position != Vector2.ZERO:
		var knock_dir := (global_position - source_position).normalized()
		_knockback_velocity = knock_dir * 200.0
		_knockback_remaining = 0.2

	if hp <= 0:
		_die()

func _die() -> void:
	_is_dead = true
	VFXManager.spawn_death_effect(global_position)
	AudioManager.play_death()
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0
	var tween = get_tree().create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_BACK)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.3)
	tween.parallel().tween_property(self, "scale", Vector2(0.5, 0.5), 0.3)
	tween.tween_callback(queue_free)

func _flash_hit() -> void:
	modulate = Color(1.15, 1.15, 1.15, 1)
	await get_tree().create_timer(0.08).timeout
	modulate = _flash_base_modulate

func _update_health_bar() -> void:
	if health_bar:
		health_bar.max_value = max_hp
		health_bar.value = hp

func _is_playing_attack_anim() -> bool:
	return animation_player and animation_player.is_playing() and animation_player.current_animation == "Shoot"

func _play_animation(anim_name: String) -> void:
	if animation_player and animation_player.has_animation(anim_name):
		if animation_player.current_animation != anim_name:
			var info = _anim_data[anim_name]
			sprite.texture = info.tex
			sprite.hframes = info.frames
			sprite.vframes = 1
			sprite.frame = 0
			animation_player.play(anim_name)

func _setup_animations() -> void:
	if not animation_player: return

	if _cached_library:
		animation_player.add_animation_library("", _cached_library)
		_play_animation("Idle")
		return

	var library = AnimationLibrary.new()
	for anim_name in _anim_data:
		var info = _anim_data[anim_name]
		var anim = Animation.new()
		anim.length = info.frames / info.speed
		anim.loop_mode = Animation.LOOP_LINEAR if info.loop else Animation.LOOP_NONE

		var track_frame = anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(track_frame, "Body:frame")
		anim.value_track_set_update_mode(track_frame, Animation.UPDATE_DISCRETE)

		for i in range(info.frames):
			anim.track_insert_key(track_frame, i / info.speed, i)

		library.add_animation(anim_name, anim)

	_cached_library = library
	animation_player.add_animation_library("", _cached_library)
	_play_animation("Idle")