class_name PushArrows
extends Node2D
## Pulsing arrows around every pushable wall, one per direction the block can still go.
##
## Each arrow sits on the side the pac has to come from and points the way the block
## moves, so an arrow to the left of a block means "push me to the right".

## Warm amber, close to the pac, so the arrows read over the dark floor.
const COLOR := Color(1.0, 0.84, 0.35)
const OUTLINE_COLOR := Color(0.35, 0.22, 0.05)
## The blocks cast the same kind of shadow, a bit further away.
const SHADOW_OFFSET := Vector2(1.0, 1.5)
const PULSE_SPEED := 3.0
## How far the middle of the arrow sits from the middle of the block, in tiles.
const DISTANCE := 0.85
## Arrowhead pointing right, in pixels of a 30 px tile.
const ARROW: Array[Vector2] = [Vector2(5.5, 0), Vector2(-3.5, -5.0), Vector2(-3.5, 5.0)]

var level: Level


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	# The editor preview is frozen (it doesn't process), so there they stay lit.
	var pulse := 1.0
	if can_process():
		pulse = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * PULSE_SPEED)
	var tile := level.tile_size()
	# The pac hides the arrow of the side it already stands on.
	var pac := level.position_to_cell(level.player.position)
	for cell: Vector2i in level.pushable_cells:
		for dir: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var from := cell - dir
			# The pac pushes from the opposite side, so that cell has to be free too.
			if from != pac and level.can_push(cell, dir) and _is_free(from):
				# The arrow also drifts a little toward the block as it lights up.
				var away := Vector2(dir) * (tile * DISTANCE - 2.0 * pulse)
				_draw_arrow(level.cell_to_position(cell) - away, dir, pulse, tile / 30.0)


func _is_free(cell: Vector2i) -> bool:
	return level.is_inside(cell) and not level.is_wall(cell)


## One arrow, over its own shadow so it stands off the floor like the blocks do.
func _draw_arrow(center: Vector2, dir: Vector2i, pulse: float, scale: float) -> void:
	var forward := Vector2(dir)
	var side := Vector2(-dir.y, dir.x)
	var alpha := 0.35 + 0.65 * pulse
	var shadow := _place(center + SHADOW_OFFSET * scale, forward, side, scale)
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.45 * alpha))
	var arrow := _place(center, forward, side, scale)
	draw_colored_polygon(arrow, Color(COLOR, alpha))
	arrow.append(arrow[0])
	draw_polyline(arrow, Color(OUTLINE_COLOR, alpha * 0.9), 1.0 * scale, true)


## Turns the arrow shape into world points, pointing along `forward`.
func _place(center: Vector2, forward: Vector2, side: Vector2, scale: float) -> PackedVector2Array:
	var placed := PackedVector2Array()
	for point in ARROW:
		placed.append(center + (forward * point.x + side * point.y) * scale)
	return placed
