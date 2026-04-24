extends CharacterBody2D

@export var arrow_scene: PackedScene = preload("res://scenes/enemy/Arrow.tscn")
@export var max_hp: int = 40
@export var move_speed: float = 75.0
@export var chase_range: float = 10000.0
@export var attack_range: float = 280.0
@export var too_close_distance: float = 120.0
@export var attack_damage: int = 6
@export var attack_cooldown: float = 1.8
@export var attack_windup: float = 0.5

var hp: int
var _can_attack: bool = true
var _target: CharacterBody2D
var _knockback_velocity: Vector2 = Vector2.ZERO
var _knockback_remaining: float = 0.0
var _flash_base_modulate: Color = Color.WHITE

# Preload textures to avoid runtime lag/flicker
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

func _ready() -> void:
	add_to_group("enemy")
	hp = max_hp
	_flash_base_modulate = modulate
	_update_health_bar()
	_update_target()

	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_create_animations_programmatically()

func _physics_process(delta: float) -> void:
	if _knockback_remaining > 0.0:
		_knockback_remaining = max(_knockback_remaining - delta, 0.0)
		velocity = _knockback_velocity
		_knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO, 2400.0 * delta)
		move_and_slide()
		return

	if _target == null or not is_instance_valid(_target):
		_update_target()
		_play_animation("Idle")
		return

	var to_target := _target.global_position - global_position
	var distance := to_target.length()

	# Flip sprite logic with deadzone to prevent rapid flickering
	if abs(to_target.x) > 2.0 and not _is_playing_attack_anim():
		var should_flip = to_target.x < 0
		if sprite.flip_h != should_flip:
			sprite.flip_h = should_flip

	# AI Logic with hysteresis (deadzones) to prevent "left-right" jitter
	if distance > attack_range:
		# Chase
		velocity = to_target.normalized() * move_speed
		if not _is_playing_attack_anim():
			_play_animation("Run")
	elif distance < too_close_distance - 25.0: # Retreat deadzone
		# Retreat (Sengaja diperlambat agar mudah dipukul pemain)
		velocity = -to_target.normalized() * (move_speed * 1.0)
		if not _is_playing_attack_anim():
			_play_animation("Run")
	elif distance < attack_range - 40.0:
		# Optimal position: stay and shoot
		velocity = velocity.move_toward(Vector2.ZERO, 400.0 * delta)
		if _can_attack:
			_attack_target()
		elif not _is_playing_attack_anim():
			_play_animation("Idle")
	else:
		# In-between: slow down but keep status
		velocity = velocity.move_toward(Vector2.ZERO, 200.0 * delta)
		if not _is_playing_attack_anim():
			_play_animation("Idle")

	move_and_slide()

func _update_target() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_target = players[0]

func _attack_target() -> void:
	_can_attack = false
	_play_animation("Shoot")
	
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
	hp = max(hp - damage, 0)
	_update_health_bar()
	_flash_hit()
	if source_position != Vector2.ZERO:
		var knock_dir := (global_position - source_position).normalized()
		_knockback_velocity = knock_dir * 200.0
		_knockback_remaining = 0.2
	
	if hp <= 0:
		queue_free()

func _flash_hit() -> void:
	modulate = Color(1.5, 1.5, 1.5, 1)
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
			# Set texture and hframes directly from preloaded resources
			sprite.texture = info.tex
			sprite.hframes = info.frames
			sprite.vframes = 1
			animation_player.play(anim_name)

func _create_animations_programmatically() -> void:
	if not animation_player: return
	
	if animation_player.has_animation_library(""):
		animation_player.remove_animation_library("")
		
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
	
	animation_player.add_animation_library("", library)
	_play_animation("Idle")