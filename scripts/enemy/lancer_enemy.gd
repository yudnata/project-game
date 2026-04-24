extends CharacterBody2D

@export var max_hp: int = 100
@export var move_speed: float = 70.0
@export var chase_range: float = 1000.0
@export var attack_range: float = 85.0 # Longer range for Lancer
@export var too_close_distance: float = 60.0
@export var attack_damage: int = 12
@export var attack_cooldown: float = 1.2
@export var attack_windup: float = 0.3
@export var knockback_force: float = 350.0
@export var knockback_duration: float = 0.2
@export var attack_recoil_force: float = 100.0
@export var attack_recoil_duration: float = 0.15

var hp: int
var _can_attack: bool = true
var _target: CharacterBody2D
var _knockback_velocity: Vector2 = Vector2.ZERO
var _knockback_remaining: float = 0.0
var _flash_base_modulate: Color = Color.WHITE
var _target_update_timer: float = 0.0
var _is_dead: bool = false
var _last_attack_dir: Vector2 = Vector2.DOWN

@onready var sprite: Sprite2D = $Body
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var health_bar: ProgressBar = $HealthBar
@onready var hit_area: ShapeCast2D = $HitArea # Using ShapeCast for piercing damage

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
		_knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO, knockback_force * 6.0 * delta)
		move_and_slide()
		return

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

	if distance < attack_range:
		velocity = Vector2.ZERO
		if _can_attack:
			_attack_target(to_target.normalized())
		elif not _is_playing_attack_anim():
			_play_animation("Idle")
	else:
		velocity = to_target.normalized() * move_speed
		if not _is_playing_attack_anim():
			_play_animation("Run")
			if to_target.x != 0:
				sprite.flip_h = to_target.x < 0

	move_and_slide()

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

func _attack_target(dir: Vector2) -> void:
	_can_attack = false
	_last_attack_dir = dir
	
	var anim_name = _get_attack_animation_name(dir)
	_play_animation(anim_name)
	
	# Handle flipping for directional attacks (Right/DownRight/UpRight are base, flipped for Left)
	if dir.x != 0:
		sprite.flip_h = dir.x < 0
	
	AudioManager.play_sfx("sword_swing") # Reusing for now
	
	# Recoil
	_knockback_velocity = -dir * attack_recoil_force
	_knockback_remaining = attack_recoil_duration
	
	await get_tree().create_timer(attack_windup).timeout
	
	if not _is_dead:
		_perform_pierce_hit(dir)
	
	await get_tree().create_timer(attack_cooldown - attack_windup).timeout
	_can_attack = true

func _get_attack_animation_name(dir: Vector2) -> String:
	var angle = rad_to_deg(dir.angle())
	# Normalize angle to 0-360
	if angle < 0: angle += 360
	
	# Lancer has: Down, DownRight, Right, Up, UpRight
	# We flip Right animations for Left
	
	if angle > 67.5 and angle <= 112.5:
		return "Down_Attack"
	elif (angle > 112.5 and angle <= 157.5) or (angle > 22.5 and angle <= 67.5):
		return "DownRight_Attack"
	elif (angle > 157.5 and angle <= 202.5) or (angle > 337.5 or angle <= 22.5):
		return "Right_Attack"
	elif (angle > 247.5 and angle <= 292.5):
		return "Up_Attack"
	else:
		return "UpRight_Attack"

func _perform_pierce_hit(dir: Vector2) -> void:
	if not hit_area: return
	
	# Configure hit area for piercing
	hit_area.target_position = dir * attack_range
	hit_area.force_shapecast_update()
	
	var hit_bodies = []
	for i in range(hit_area.get_collision_count()):
		var body = hit_area.get_collider(i)
		if body != self and body.has_method("receive_hit") and not body in hit_bodies:
			body.receive_hit(attack_damage, global_position)
			hit_bodies.append(body)
	
	if hit_bodies.size() > 0:
		AudioManager.play_impact_melee()

func receive_hit(damage: int, source_position: Vector2 = Vector2.ZERO) -> void:
	if _is_dead: return
	hp = max(hp - damage, 0)
	_update_health_bar()
	_flash_hit()
	
	if source_position != Vector2.ZERO:
		var knock_dir := (global_position - source_position).normalized()
		_knockback_velocity = knock_dir * knockback_force
		_knockback_remaining = knockback_duration

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
	modulate = Color(1.2, 1.2, 1.2, 1)
	await get_tree().create_timer(0.08).timeout
	modulate = _flash_base_modulate

func _update_health_bar() -> void:
	if health_bar:
		health_bar.max_value = max_hp
		health_bar.value = hp

func _is_playing_attack_anim() -> bool:
	return animation_player and animation_player.is_playing() and animation_player.current_animation.ends_with("Attack")

func _play_animation(anim_name: String) -> void:
	if animation_player and animation_player.has_animation(anim_name):
		if animation_player.current_animation != anim_name:
			animation_player.play(anim_name)

func _setup_animations() -> void:
	if not animation_player: return
	
	if _cached_library:
		animation_player.add_animation_library("", _cached_library)
		_play_animation("Idle")
		return

	var library = AnimationLibrary.new()
	var base_path = "res://assets/Units/Red Units/Lancer/Lancer_"
	var anim_data = {
		"Idle": {"tex": base_path + "Idle.png", "frames": 12, "loop": true, "speed": 10.0},
		"Run": {"tex": base_path + "Run.png", "frames": 6, "loop": true, "speed": 12.0},
		"Down_Attack": {"tex": base_path + "Down_Attack.png", "frames": 3, "loop": false, "speed": 10.0},
		"DownRight_Attack": {"tex": base_path + "DownRight_Attack.png", "frames": 3, "loop": false, "speed": 10.0},
		"Right_Attack": {"tex": base_path + "Right_Attack.png", "frames": 3, "loop": false, "speed": 10.0},
		"Up_Attack": {"tex": base_path + "Up_Attack.png", "frames": 3, "loop": false, "speed": 10.0},
		"UpRight_Attack": {"tex": base_path + "UpRight_Attack.png", "frames": 3, "loop": false, "speed": 10.0}
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

		anim.length = info.frames / info.speed
		for i in range(info.frames):
			anim.track_insert_key(track_frame, i / info.speed, i)

		if info.loop:
			anim.loop_mode = Animation.LOOP_LINEAR

		library.add_animation(anim_name, anim)

	_cached_library = library
	animation_player.add_animation_library("", library)
	_play_animation("Idle")
