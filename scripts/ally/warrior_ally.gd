extends CharacterBody2D

@export var max_hp: int = 60
@export var move_speed: float = 85.0
@export var chase_range: float = 1000.0
@export var attack_range: float = 55.0
@export var attack_damage: int = 10
@export var attack_cooldown: float = 0.8
@export var attack_windup: float = 0.2

var hp: int
var _can_attack: bool = true
var _target_enemy: CharacterBody2D
var _player: CharacterBody2D
var _knockback_velocity: Vector2 = Vector2.ZERO
var _knockback_remaining: float = 0.0
var _flash_base_modulate: Color = Color.WHITE
var _target_update_timer: float = 0.0
var _is_dead: bool = false

@onready var _tex_idle = preload("res://assets/Units/Blue Units/Warrior/Warrior_Idle.png")
@onready var _tex_run = preload("res://assets/Units/Blue Units/Warrior/Warrior_Run.png")
@onready var _tex_attack = preload("res://assets/Units/Blue Units/Warrior/Warrior_Attack1.png")

@onready var _anim_data = {
	"Idle": {"tex": _tex_idle, "frames": 8, "loop": true, "speed": 10.0},
	"Run": {"tex": _tex_run, "frames": 6, "loop": true, "speed": 12.0},
	"Attack": {"tex": _tex_attack, "frames": 4, "loop": false, "speed": 15.0}
}

@onready var sprite: Sprite2D = $Body
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var health_bar: ProgressBar = $HealthBar

# Shared Library
static var _cached_library: AnimationLibrary

func _ready() -> void:
	add_to_group("ally")
	hp = max_hp
	_flash_base_modulate = modulate
	_update_health_bar()
	_find_player()

	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_setup_animations()

func _physics_process(delta: float) -> void:
	if _is_dead: return

	if _knockback_remaining > 0.0:
		_knockback_remaining = max(_knockback_remaining - delta, 0.0)
		velocity = _knockback_velocity
		_knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO, 1000.0 * delta)
		move_and_slide()
		return

	_target_update_timer -= delta
	if _target_update_timer <= 0:
		_find_target_enemy()
		_target_update_timer = 0.5

	if _target_enemy and is_instance_valid(_target_enemy):
		_handle_enemy_combat(delta)
	else:
		_handle_following_player(delta)

	move_and_slide()

func _find_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0]

func _find_target_enemy() -> void:
	var enemies = get_tree().get_nodes_in_group("enemy")
	var closest_dist = chase_range
	_target_enemy = null

	for enemy in enemies:
		if is_instance_valid(enemy):
			var dist = global_position.distance_to(enemy.global_position)
			if dist < closest_dist:
				closest_dist = dist
				_target_enemy = enemy

func _handle_enemy_combat(delta: float) -> void:
	var to_enemy = _target_enemy.global_position - global_position
	var dist = to_enemy.length()

	if to_enemy.x != 0 and not _is_playing_attack_anim():
		sprite.flip_h = to_enemy.x < 0

	if dist <= attack_range:
		velocity = Vector2.ZERO
		if _can_attack:
			_attack_enemy()
		elif not _is_playing_attack_anim():
			_play_animation("Idle")
	else:
		velocity = to_enemy.normalized() * move_speed
		if not _is_playing_attack_anim():
			_play_animation("Run")

func _handle_following_player(delta: float) -> void:
	if not _player:
		_find_player()
		_play_animation("Idle")
		velocity = Vector2.ZERO
		return

	var to_player = _player.global_position - global_position
	var dist = to_player.length()

	if dist > 60.0:
		velocity = to_player.normalized() * move_speed
		if to_player.x != 0:
			sprite.flip_h = to_player.x < 0
		_play_animation("Run")
	else:
		velocity = velocity.move_toward(Vector2.ZERO, 400.0 * delta)
		_play_animation("Idle")

func _attack_enemy() -> void:
	_can_attack = false
	_play_animation("Attack")
	AudioManager.play_sfx("sword_swing")

	await get_tree().create_timer(attack_windup).timeout
	if is_instance_valid(_target_enemy) and global_position.distance_to(_target_enemy.global_position) <= attack_range + 10.0:
		if _target_enemy.has_method("receive_hit"):
			_target_enemy.receive_hit(attack_damage, global_position)
			AudioManager.play_impact_melee()

	await get_tree().create_timer(attack_cooldown - attack_windup).timeout
	_can_attack = true

func receive_hit(damage: int, source_position: Vector2 = Vector2.ZERO) -> void:
	if _is_dead: return
	hp = max(hp - damage, 0)
	_update_health_bar()
	_flash_hit()
	if source_position != Vector2.ZERO:
		var knock_dir := (global_position - source_position).normalized()
		_knockback_velocity = knock_dir * 300.0
		_knockback_remaining = 0.2

	if hp <= 0:
		_die()

func _die() -> void:
	_is_dead = true
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
	modulate = Color(1.5, 1.5, 1.5, 1)
	await get_tree().create_timer(0.08).timeout
	modulate = _flash_base_modulate

func _update_health_bar() -> void:
	if health_bar:
		health_bar.max_value = max_hp
		health_bar.value = hp

func _is_playing_attack_anim() -> bool:
	return animation_player and animation_player.is_playing() and animation_player.current_animation == "Attack"

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
