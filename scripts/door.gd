class_name Door
extends Node2D
## Blocks the pac like a wall until the key of the same color is collected.
## Opening is animated: the padlock pops off and both halves slide into the wall.

const OPEN_DURATION := 0.35
const LOCK_POP_SCALE := 1.8

var color := Color.WHITE
var is_open := false
## Set when the door sits in a vertical wall, so its halves slide up and down.
var slides_vertically := false
var _open_amount := 0.0 ## 0 closed, 1 fully open.
var _tween: Tween

@onready var lock_sprite: Sprite2D = $Lock
@onready var lock_scale := lock_sprite.scale


func set_open(value: bool) -> void:
	is_open = value
	if _tween:
		_tween.kill()
	if not value:
		visible = true
		lock_sprite.scale = lock_scale
		lock_sprite.modulate.a = 1.0
		_set_open_amount(0.0)
		return
	_tween = create_tween()
	_tween.tween_property(lock_sprite, "scale", lock_scale * LOCK_POP_SCALE, OPEN_DURATION * 0.5)
	_tween.parallel().tween_property(lock_sprite, "modulate:a", 0.0, OPEN_DURATION * 0.5)
	_tween.parallel().tween_method(_set_open_amount, 0.0, 1.0, OPEN_DURATION) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.tween_callback(hide)


func _set_open_amount(value: float) -> void:
	_open_amount = value
	queue_redraw()


func _draw() -> void:
	var half := LevelData.TILE_SIZE / 2.0
	if _open_amount == 0.0:
		_draw_panel(Rect2(-half, -half, half * 2, half * 2))
		return
	# Each half shrinks towards its side of the frame.
	var length := half * (1.0 - _open_amount)
	if slides_vertically:
		_draw_panel(Rect2(-half, -half, half * 2, length))
		_draw_panel(Rect2(-half, half - length, half * 2, length))
	else:
		_draw_panel(Rect2(-half, -half, length, half * 2))
		_draw_panel(Rect2(half - length, -half, length, half * 2))


func _draw_panel(rect: Rect2) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	draw_rect(rect, color.darkened(0.55))
	draw_rect(rect.grow(-1.5), color, false, minf(3.0, minf(rect.size.x, rect.size.y) / 2.0))
