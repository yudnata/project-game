extends Node

var game_day: int = 1
var energy: int = 100
var gold: int = 500

func next_day() -> void:
	game_day += 1
	energy = 100
