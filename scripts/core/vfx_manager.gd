extends Node

func spawn_death_effect(pos: Vector2) -> void:
	var sprite = Sprite2D.new()
	sprite.texture = load("res://assets/Particle FX/Dust_01.png")
	sprite.hframes = 5 # Adjust based on asset
	get_tree().current_scene.add_child(sprite)
	sprite.global_position = pos
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	
	var tween = get_tree().create_tween()
	# Animate frame from 0 to 4
	tween.tween_property(sprite, "frame", 4, 0.4).from(0)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.4).set_delay(0.2)
	tween.tween_callback(sprite.queue_free)

