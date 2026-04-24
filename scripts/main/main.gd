extends Node2D

@onready var player: CharacterBody2D = $GameRoot/World/Player

func _ready() -> void:

	var cursor_tex = load("res://assets/UI Elements/UI Elements/Cursors/Cursor_01.png")
	if cursor_tex:
		Input.set_custom_mouse_cursor(cursor_tex)

func _process(_delta: float) -> void:
	if player == null:
		return
