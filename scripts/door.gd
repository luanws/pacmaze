class_name Door
extends Node2D
## Blocks the pac like a wall until the key of the same color is collected.

var color := Color.WHITE
var is_open := false


func set_open(value: bool) -> void:
	is_open = value
	visible = not value


func _draw() -> void:
	var half := LevelData.TILE_SIZE / 2.0
	var rect := Rect2(-half, -half, half * 2, half * 2)
	draw_rect(rect, color.darkened(0.55))
	draw_rect(rect.grow(-1.5), color, false, 3.0)
