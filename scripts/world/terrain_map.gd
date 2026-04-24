extends TileMap

func _ready() -> void:
	var grass_cells: Array[Vector2i] = []
	for x in range(-15, 15):
		for y in range(-12, 12):
			grass_cells.append(Vector2i(x, y))

	clear()

	# Pasang autotile full grass
	set_cells_terrain_connect(0, grass_cells, 0, 0)
	print("Auto-generated massive grass map applied.")

