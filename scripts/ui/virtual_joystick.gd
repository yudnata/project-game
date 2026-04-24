extends Control

@export var max_distance: float = 120.0
@export var action_left: String = "move_left"
@export var action_right: String = "move_right"
@export var action_up: String = "move_up"
@export var action_down: String = "move_down"

var _touch_index: int = -1
var _start_pos: Vector2
var _current_pos: Vector2
var _is_active: bool = false

@onready var knob: TextureRect = $Knob

func _ready() -> void:
	_start_pos = size / 2.0
	_current_pos = _start_pos
	_update_knob()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index == -1:
			var rect = Rect2(global_position, size)
			if rect.has_point(event.position):
				_touch_index = event.index
				_is_active = true
				_update_input(event.position - global_position)
		elif not event.pressed and event.index == _touch_index:
			_touch_index = -1
			_is_active = false
			_update_input(_start_pos)
			_release_all()

	elif event is InputEventScreenDrag:
		if _is_active and event.index == _touch_index:
			_update_input(event.position - global_position)

func _update_input(pos: Vector2) -> void:
	var offset = pos - _start_pos
	if offset.length() > max_distance:
		offset = offset.normalized() * max_distance

	_current_pos = _start_pos + offset
	_update_knob()

	if _is_active:
		var normalized = offset / max_distance
		_send_action(action_right, max(normalized.x, 0.0))
		_send_action(action_left, max(-normalized.x, 0.0))
		_send_action(action_down, max(normalized.y, 0.0))
		_send_action(action_up, max(-normalized.y, 0.0))

func _send_action(action: String, strength: float) -> void:
	if strength > 0.2:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)

func _release_all() -> void:
	Input.action_release(action_left)
	Input.action_release(action_right)
	Input.action_release(action_up)
	Input.action_release(action_down)

func _update_knob() -> void:
	if knob:
		knob.position = _current_pos - (knob.size / 2.0)
