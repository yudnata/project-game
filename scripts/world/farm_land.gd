extends Node2D

const STATE_TILLED: int = 1
const STATE_WATERED: int = 2

@export var cell_size: int = 64
@export var grid_width: int = 20
@export var grid_height: int = 14
@export var origin: Vector2 = Vector2(-640, -448)

var plot_states: Dictionary = {}

func _ready() -> void:
	queue_redraw()

func hoe_at_world(world_position: Vector2) -> void:
	var cell := world_to_cell(world_position)
	if not _is_valid_cell(cell):
		return

	plot_states[cell] = STATE_TILLED
	queue_redraw()

func water_at_world(world_position: Vector2) -> void:
	var cell := world_to_cell(world_position)
	if not _is_valid_cell(cell):
		return

	var current_state: int = int(plot_states.get(cell, 0))
	if current_state == 0:
		return

	plot_states[cell] = STATE_WATERED
	queue_redraw()

func world_to_cell(world_position: Vector2) -> Vector2i:
	var local_pos := world_position - global_position - origin
	var x := int(floor(local_pos.x / float(cell_size)))
	var y := int(floor(local_pos.y / float(cell_size)))
	return Vector2i(x, y)

func _is_valid_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < grid_width and cell.y < grid_height

func _draw() -> void:
	var area_size := Vector2(grid_width * cell_size, grid_height * cell_size)
	for y in range(grid_height):
		for x in range(grid_width):
			var cell := Vector2i(x, y)
			if not plot_states.has(cell):
				continue

			var state: int = int(plot_states[cell])
			var tile_color := Color(0.53, 0.37, 0.23, 1.0)
			if state == STATE_WATERED:
				tile_color = Color(0.27, 0.39, 0.56, 1.0)

			var tile_pos := origin + Vector2(x * cell_size, y * cell_size)
			var tile_outer := Rect2(
				tile_pos + Vector2(2, 2),
				Vector2(cell_size - 4, cell_size - 4)
			)
			var tile_inner := Rect2(
				tile_pos + Vector2(4, 4),
				Vector2(cell_size - 8, cell_size - 8)
			)
			draw_rect(tile_outer, tile_color, true)
			draw_rect(tile_inner, tile_color.lightened(0.07), true)
			var seam_a := tile_pos + Vector2(4, 8)
			var seam_b := tile_pos + Vector2(cell_size - 4, 8)
			draw_line(seam_a, seam_b, Color(0.18, 0.13, 0.08, 0.2), 1.0)
			var seam_c := tile_pos + Vector2(4, 20)
			var seam_d := tile_pos + Vector2(cell_size - 4, 20)
			draw_line(seam_c, seam_d, Color(0.18, 0.13, 0.08, 0.15), 1.0)
			if state == STATE_WATERED:
				draw_circle(tile_pos + Vector2(10, 10), 2.5, Color(0.45, 0.63, 0.84, 0.65))
				draw_circle(tile_pos + Vector2(22, 18), 1.8, Color(0.63, 0.81, 0.96, 0.45))

	# Draw thin grid lines so the farm area is easy to read.
	for y in range(grid_height + 1):
		var y_pos := origin.y + y * cell_size
		var line_start := Vector2(origin.x, y_pos)
		var line_end := Vector2(origin.x + area_size.x, y_pos)
		draw_line(line_start, line_end, Color(0.2, 0.35, 0.2, 0.4), 1.0)

	for x in range(grid_width + 1):
		var x_pos := origin.x + x * cell_size
		var column_start := Vector2(x_pos, origin.y)
		var column_end := Vector2(x_pos, origin.y + area_size.y)
		draw_line(column_start, column_end, Color(0.2, 0.35, 0.2, 0.4), 1.0)
