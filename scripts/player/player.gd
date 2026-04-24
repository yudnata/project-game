extends CharacterBody2D

signal hp_changed(current_hp: int, max_hp: int)

@export var move_speed: float = 150.0
@export var acceleration: float = 1200.0
@export var friction: float = 1000.0
@export var interact_distance: float = 28.0
@export var attack_distance: float = 38.0
@export var attack_damage: int = 10
@export var attack_cooldown: float = 0.35
@export var attack_lunge_force: float = 180.0
@export var max_hp: int = 100
@export var dash_speed: float = 400.0
@export var dash_duration: float = 0.15
@export var dash_cooldown: float = 0.5
@export var hit_invulnerability_duration: float = 0.35
@export var knockback_force: float = 230.0
@export var knockback_duration: float = 0.14

var _facing_direction: Vector2 = Vector2.DOWN
var _is_attacking: bool = false
var _is_dashing: bool = false
var _dash_available: bool = true
var _is_invulnerable: bool = false
var _dash_direction: Vector2 = Vector2.ZERO
var _hp: int = 0
var _dash_cooldown_remaining: float = 0.0
var _knockback_velocity: Vector2 = Vector2.ZERO
var _knockback_remaining: float = 0.0
var _attack_input_buffered: bool = false
var _combo_count: int = 0

@onready var attack_area: Area2D = $AttackArea2D
@onready var attack_collision: CollisionShape2D = $AttackArea2D/CollisionShape2D
@onready var attack_fx: Polygon2D = $AttackArea2D/AttackFX
@onready var sprite: Sprite2D = $Body
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var health_bar: ProgressBar = $HealthBar
@onready var direction_indicator: Node2D = $DirectionIndicator
@onready var _camera = get_tree().get_first_node_in_group("camera")

func _ready() -> void:
	add_to_group("player")
	_setup_movement_input()
	_create_animations_programmatically()
	attack_collision.disabled = true
	attack_fx.visible = false
	_hp = max_hp
	_update_health_bar()
	hp_changed.emit(_hp, max_hp)

func _physics_process(delta: float) -> void:
	if _dash_cooldown_remaining > 0.0:
		_dash_cooldown_remaining = max(_dash_cooldown_remaining - delta, 0.0)

	if _knockback_remaining > 0.0:
		_knockback_remaining = max(_knockback_remaining - delta, 0.0)
		velocity = _knockback_velocity
		_knockback_velocity = _knockback_velocity.move_toward(
			Vector2.ZERO,
			knockback_force * 6.0 * delta
		)
		move_and_slide()
		return

	var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_vector.length() > 0.1:
		_facing_direction = input_vector.normalized()
		direction_indicator.rotation = _facing_direction.angle()
	else:
		input_vector = Vector2.ZERO

	direction_indicator.visible = true

	if Input.is_action_just_pressed("dash") and _dash_available and not _is_attacking:
		_start_dash(input_vector)

	if _is_dashing:
		velocity = _dash_direction * dash_speed
	elif _is_attacking:
		velocity = velocity.move_toward(Vector2.ZERO, friction * 0.5 * delta)
	else:
		if input_vector != Vector2.ZERO:
			velocity = velocity.move_toward(input_vector * move_speed, acceleration * delta)
		else:
			velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	_update_animations(input_vector)
	move_and_slide()

	if Input.is_action_just_pressed("attack") and not _is_dashing:
		if _is_attacking:
			_attack_input_buffered = true
		else:
			_perform_attack()

	if Input.is_action_just_pressed("use_hoe"):
		_use_farm_tool("hoe")
	if Input.is_action_just_pressed("use_water"):
		_use_farm_tool("water")

func _setup_movement_input() -> void:
	_register_action("move_left", [KEY_A, KEY_LEFT])
	_register_action("move_right", [KEY_D, KEY_RIGHT])
	_register_action("move_up", [KEY_W, KEY_UP])
	_register_action("move_down", [KEY_S, KEY_DOWN])
	_register_action("dash", [KEY_SHIFT, KEY_K])
	_register_action("use_hoe", [KEY_E])
	_register_action("use_water", [KEY_R])
	if not InputMap.has_action("attack"):
		InputMap.add_action("attack")
	InputMap.action_erase_events("attack")


func _start_dash(input_vector: Vector2) -> void:
	_dash_available = false
	_is_dashing = true
	if input_vector != Vector2.ZERO:
		_dash_direction = input_vector.normalized()
	else:
		_dash_direction = _facing_direction.normalized()

	AudioManager.play_sfx("player_dash")

	await get_tree().create_timer(dash_duration).timeout
	_is_dashing = false
	_dash_cooldown_remaining = dash_cooldown
	await get_tree().create_timer(dash_cooldown).timeout
	_dash_available = true

func _perform_attack() -> void:
	_is_attacking = true
	var attack_direction := _get_attack_direction()
	_update_attack_transform(attack_direction)
	attack_collision.disabled = false
	attack_fx.visible = true

	# Combo system: alternates between Attack1 and Attack2
	var anim_name = "Attack1" if _combo_count % 2 == 0 else "Attack2"
	if animation_player.has_animation(anim_name):
		animation_player.play(anim_name)
	_combo_count += 1
	
	AudioManager.play_sfx("sword_swing")

	# Attack Lunge - gives fluidity and movement during attack
	velocity = attack_direction * attack_lunge_force

	# Better hit detection window (checks for 5 frames)
	var has_hit = false
	var hit_bodies = []
	for i in range(5):
		if not _is_attacking: break # Safety exit
		await get_tree().physics_frame
		for body in attack_area.get_overlapping_bodies():
			if body != self and body.has_method("receive_hit") and not body in hit_bodies:
				body.receive_hit(attack_damage, global_position)
				hit_bodies.append(body)
				if not has_hit:
					_hit_stop(0.05)
					if _camera and _camera.has_method("shake"):
						_camera.shake(5.0)
					has_hit = true

	attack_collision.disabled = true
	attack_fx.visible = false

	# Fluidity: Wait for animation to finish before allowing next action
	await get_tree().create_timer(attack_cooldown * 0.6).timeout
	_is_attacking = false

	# Priority: Buffered input or go to idle
	if _attack_input_buffered and not _is_dashing:
		_attack_input_buffered = false
		_perform_attack()
	else:
		_attack_input_buffered = false
		if animation_player.has_animation("Idle"):
			animation_player.play("Idle")

func _hit_stop(duration: float) -> void:
	Engine.time_scale = 0.3
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0

func _create_animations_programmatically() -> void:
	var library = AnimationLibrary.new()

	# Define animations using the assets provided
	var anim_data = {
		"Idle": {"tex": "res://assets/Units/Blue Units/Warrior/Warrior_Idle.png", "frames": 8, "loop": true, "speed": 10.0},
		"Run": {"tex": "res://assets/Units/Blue Units/Warrior/Warrior_Run.png", "frames": 6, "loop": true, "speed": 12.0},
		"Attack1": {"tex": "res://assets/Units/Blue Units/Warrior/Warrior_Attack1.png", "frames": 4, "loop": false, "speed": 15.0},
		"Attack2": {"tex": "res://assets/Units/Blue Units/Warrior/Warrior_Attack2.png", "frames": 4, "loop": false, "speed": 15.0}
	}

	for anim_name in anim_data:
		var info = anim_data[anim_name]
		var anim = Animation.new()

		# Track for Texture
		var track_tex = anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(track_tex, "Body:texture")
		anim.track_insert_key(track_tex, 0.0, load(info.tex))
		anim.value_track_set_update_mode(track_tex, Animation.UPDATE_DISCRETE)


		# Track for HFrames/VFrames (CRITICAL to fix "looks like 2 characters" bug)
		var track_h = anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(track_h, "Body:hframes")
		anim.track_insert_key(track_h, 0.0, info.frames)
		anim.value_track_set_update_mode(track_h, Animation.UPDATE_DISCRETE)

		var track_v = anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(track_v, "Body:vframes")
		anim.track_insert_key(track_v, 0.0, 1)
		anim.value_track_set_update_mode(track_v, Animation.UPDATE_DISCRETE)


		# Track for Frames
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
	animation_player.play("Idle")

func _update_animations(input_vector: Vector2) -> void:
	if _is_attacking or _is_dashing:
		return

	if input_vector != Vector2.ZERO:
		if animation_player.has_animation("Run") and animation_player.current_animation != "Run":
			animation_player.play("Run")
		if input_vector.x != 0:
			sprite.flip_h = input_vector.x < 0
	else:
		if animation_player.has_animation("Idle") and animation_player.current_animation != "Idle":
			animation_player.play("Idle")

func _update_attack_transform(direction: Vector2) -> void:
	var attack_direction := direction.normalized()
	if attack_direction == Vector2.ZERO:
		attack_direction = _facing_direction.normalized()

	_facing_direction = attack_direction
	attack_area.position = attack_direction * attack_distance
	attack_area.rotation = attack_direction.angle()

func _get_attack_direction() -> Vector2:
	if _facing_direction == Vector2.ZERO:
		return Vector2.DOWN
	return _facing_direction.normalized()

func receive_hit(damage: int, source_position: Vector2 = Vector2.ZERO) -> void:
	if _is_invulnerable or _is_dashing:
		return

	_hp = max(_hp - damage, 0)
	_update_health_bar()
	hp_changed.emit(_hp, max_hp)
	if _hp <= 0:
		_respawn_player()
		return

	_is_invulnerable = true
	AudioManager.play_impact_melee()
	
	if source_position != Vector2.ZERO:
		var knock_dir := (global_position - source_position).normalized()
		_knockback_velocity = knock_dir * knockback_force
		_knockback_remaining = knockback_duration

	modulate = Color(1, 0.6, 0.6, 1)
	await get_tree().create_timer(hit_invulnerability_duration).timeout
	modulate = Color(1, 1, 1, 1)
	_is_invulnerable = false

func _respawn_player() -> void:
	_hp = max_hp
	_update_health_bar()
	hp_changed.emit(_hp, max_hp)
	global_position = Vector2.ZERO
	velocity = Vector2.ZERO

func _update_health_bar() -> void:
	if health_bar:
		health_bar.max_value = max_hp
		health_bar.value = _hp

func get_hp() -> int:
	return _hp

func get_max_hp() -> int:
	return max_hp

func get_dash_cooldown_ratio() -> float:
	if dash_cooldown <= 0.0:
		return 1.0
	return 1.0 - (_dash_cooldown_remaining / dash_cooldown)

func is_dash_ready() -> bool:
	return _dash_available

func _use_farm_tool(tool_name: String) -> void:
	var farm_land := get_parent().get_node_or_null("World/FarmLand")
	if farm_land == null:
		return

	var target_world_position := global_position + (_facing_direction * interact_distance)
	if tool_name == "hoe" and farm_land.has_method("hoe_at_world"):
		farm_land.hoe_at_world(target_world_position)
	if tool_name == "water" and farm_land.has_method("water_at_world"):
		farm_land.water_at_world(target_world_position)

func _register_action(action_name: String, keycodes: Array[int]) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	InputMap.action_erase_events(action_name)
	for keycode in keycodes:
		var event := InputEventKey.new()
		event.physical_keycode = keycode as Key
		InputMap.action_add_event(action_name, event)

func _register_mouse_action(action_name: String, mouse_button: MouseButton) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	InputMap.action_erase_events(action_name)
	var event := InputEventMouseButton.new()
	event.button_index = mouse_button
	InputMap.action_add_event(action_name, event)
