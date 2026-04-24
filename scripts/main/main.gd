extends Node2D

@onready var player: CharacterBody2D = $GameRoot/Player
@onready var hp_label: Label = $HUD/PlayerHP
@onready var hp_bar: ProgressBar = $HUD/HPBar
@onready var dash_label: Label = $HUD/DashLabel
@onready var dash_bar: ProgressBar = $HUD/DashBar

func _ready() -> void:
	if player.has_signal("hp_changed"):
		player.connect("hp_changed", _on_player_hp_changed)
	if player.has_method("get_hp") and player.has_method("get_max_hp"):
		_on_player_hp_changed(player.get_hp(), player.get_max_hp())

	if player.has_method("get_dash_cooldown_ratio"):
		dash_bar.value = player.get_dash_cooldown_ratio() * 100.0
		_update_dash_label(player.is_dash_ready())

func _process(_delta: float) -> void:
	if player == null:
		return
	if player.has_method("get_dash_cooldown_ratio"):
		dash_bar.value = player.get_dash_cooldown_ratio() * 100.0
		_update_dash_label(player.is_dash_ready())

func _on_player_hp_changed(current_hp: int, max_hp: int) -> void:
	hp_label.text = "Player HP: %d / %d" % [current_hp, max_hp]
	hp_bar.max_value = max_hp
	hp_bar.value = current_hp

func _update_dash_label(is_ready: bool) -> void:
	if is_ready:
		dash_label.text = "Dash: Ready"
	else:
		dash_label.text = "Dash: Cooldown"
