extends CharacterBody2D

@export var max_hp: int = 50
@export var move_speed: float = 80.0
@export var chase_range: float = 10000.0
@export var attack_range: float = 55.0
@export var attack_damage: int = 8
@export var attack_cooldown: float = 0.8
@export var attack_windup: float = 0.18
@export var knockback_force: float = 400.0
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

@onready var sprite: Sprite2D = $Body
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var health_bar: ProgressBar = $HealthBar

func _ready() -> void:
	add_to_group("enemy")
	hp = max_hp
	_flash_base_modulate = modulate
	_update_health_bar()
	_update_target()
	_create_animations_programmatically()

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
		elif not _is_playing_attack_anim():
			_play_animation("Idle")
	else:
		velocity = to_target.normalized() * move_speed
		if velocity.x != 0:
			sprite.flip_h = velocity.x < 0
		if not _is_playing_attack_anim():
			_play_animation("Run")

	move_and_slide()

func receive_hit(damage: int, source_position: Vector2 = Vector2.ZERO) -> void:
	hp = max(hp - damage, 0)
	_update_health_bar()
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
	_play_animation("Attack1")
	if _target != null:
		var recoil_dir := (global_position - _target.global_position).normalized()
		_knockback_velocity = recoil_dir * attack_recoil_force
		_knockback_remaining = attack_recoil_duration
		modulate = Color(1.1, 0.85, 0.85, 1)
		await get_tree().create_timer(attack_windup).timeout
	if _target != null and _target.has_method("receive_hit") and global_position.distance_to(_target.global_position) <= attack_range + 15.0:
		_target.receive_hit(attack_damage, global_position)
	modulate = _flash_base_modulate
	await get_tree().create_timer(attack_cooldown).timeout
	_can_attack = true

func _flash_hit() -> void:
	modulate = Color(1.15, 1.15, 1.15, 1)
	await get_tree().create_timer(0.08).timeout
	modulate = _flash_base_modulate

func _update_health_bar() -> void:
	if health_bar:
		health_bar.max_value = max_hp
		health_bar.value = hp

func _is_playing_attack_anim() -> bool:
	return animation_player and animation_player.is_playing() and animation_player.current_animation.begins_with("Attack")

func _play_animation(anim_name: String) -> void:
	if animation_player and animation_player.has_animation(anim_name):
		if animation_player.current_animation != anim_name:
			animation_player.play(anim_name)

func _create_animations_programmatically() -> void:
	if not animation_player: return
	var library = AnimationLibrary.new()
	var anim_data = {
		"Idle": {"tex": "res://assets/Units/Red Units/Warrior/Warrior_Idle.png", "frames": 8, "loop": true, "speed": 10.0},
		"Run": {"tex": "res://assets/Units/Red Units/Warrior/Warrior_Run.png", "frames": 6, "loop": true, "speed": 12.0},
		"Attack1": {"tex": "res://assets/Units/Red Units/Warrior/Warrior_Attack1.png", "frames": 4, "loop": false, "speed": 15.0}
	}

	for anim_name in anim_data:
		var info = anim_data[anim_name]
		var anim = Animation.new()

		var track_tex = anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(track_tex, "Body:texture")
		anim.track_insert_key(track_tex, 0.0, load(info.tex))
		anim.value_track_set_update_mode(track_tex, Animation.UPDATE_DISCRETE)


		var track_h = anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(track_h, "Body:hframes")
		anim.track_insert_key(track_h, 0.0, info.frames)
		anim.value_track_set_update_mode(track_h, Animation.UPDATE_DISCRETE)

		var track_v = anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(track_v, "Body:vframes")
		anim.track_insert_key(track_v, 0.0, 1)
		anim.value_track_set_update_mode(track_v, Animation.UPDATE_DISCRETE)


		var track_frame = anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(track_frame, "Body:frame")
		anim.value_track_set_update_mode(track_frame, Animation.UPDATE_DISCRETE)

		var duration = info.frames / info.speed
		anim.length = duration

		for i in range(info.frames):
			anim.track_insert_key(track_frame, i / info.speed, i)

		if info.loop:
			anim.loop_mode = Animation.LOOP_LINEAR

		library.add_animation(anim_name, anim)

	animation_player.add_animation_library("", library)
	_play_animation("Idle")
