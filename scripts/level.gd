class_name Level
extends Node2D
## A playable maze, built from a LevelData. Entities query it for collisions.

signal completed
signal keys_changed

## Floor inside the border: a faint checkerboard, one square per cell, lit a little toward the center.
const FLOOR_SHADER := """
shader_type canvas_item;

uniform vec2 cells = vec2(1.0);

void fragment() {
	// Offset by half a cell: the rect starts in the middle of the border cells.
	vec2 cell = floor(UV * cells + 0.5);
	float checker = mod(cell.x + cell.y, 2.0);
	vec3 color = mix(vec3(0.045, 0.055, 0.115), vec3(0.055, 0.067, 0.135), checker);
	color += vec3(0.01, 0.025, 0.05) * (1.0 - smoothstep(0.0, 0.75, length(UV - 0.5)));
	COLOR = vec4(color, 1.0);
}
"""
const WALL_SHADOW_OFFSET := Vector2(3, 4)

var level_bonus := 10
var move_sensitivity := 200
var time_sensitivity := 100
var instructions := ""
var grid_size := Vector2i.ZERO

var move_count := 0
var elapsed := 0.0
var finished := false
var walls: TileMapLayer
var player: Player
var pill: Node2D
## Dictionary of Vector2i -> int (wall style index) for pushable walls at runtime.
var pushable_cells := {}
## Tracks the initial pushable wall positions for reset.
var _initial_pushable_cells := {}


# Resolved here instead of @onready: children run _ready() before the level does
# and already need the walls.
func _enter_tree() -> void:
	walls = $Walls
	player = $Player
	pill = $Pill


func _ready() -> void:
	_initial_pushable_cells = pushable_cells.duplicate()
	_add_floor()
	_add_wall_shadow()


func _process(delta: float) -> void:
	if not finished:
		elapsed += delta


## Covers the grid up to the middle of the border cells, so it never shows past the outer walls.
func _add_floor() -> void:
	var shader := Shader.new()
	shader.code = FLOOR_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("cells", Vector2(grid_size - Vector2i.ONE))
	var floor_rect := ColorRect.new()
	floor_rect.material = material
	floor_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	floor_rect.position = Vector2.ONE * tile_size() * 0.5
	floor_rect.size = Vector2(grid_size - Vector2i.ONE) * tile_size()
	add_child(floor_rect)
	move_child(floor_rect, 0)


## A dark copy of the walls, nudged down and to the right, so the blocks stand off the floor.
func _add_wall_shadow() -> void:
	var shadow: TileMapLayer = walls.duplicate()
	shadow.name = "WallShadow"
	shadow.modulate = Color(0, 0, 0, 0.5)
	shadow.position += WALL_SHADOW_OFFSET
	add_child(shadow)
	move_child(shadow, walls.get_index())


func tile_size() -> float:
	return float(walls.tile_set.tile_size.x)


func is_wall(cell: Vector2i) -> bool:
	if walls.get_cell_source_id(cell) != -1:
		return true
	var door := get_door_at(cell)
	return door != null and not door.is_open


func is_pushable_wall(cell: Vector2i) -> bool:
	return pushable_cells.has(cell)


## Tries to push the pushable wall at `cell` in `dir`. Returns true if pushed.
func try_push_wall(cell: Vector2i, dir: Vector2i) -> bool:
	if not is_pushable_wall(cell):
		return false
	var dest := cell + dir
	# Can't push outside the grid.
	if not is_inside(dest):
		return false
	# Can't push into any occupied cell (wall, border, door, another pushable).
	if walls.get_cell_source_id(dest) != -1:
		return false
	var door := get_door_at(dest)
	if door != null and not door.is_open:
		return false
	# Move the pushable wall: erase old, set new.
	var style: int = pushable_cells[cell]
	pushable_cells.erase(cell)
	pushable_cells[dest] = style
	walls.erase_cell(cell)
	var atlas := Vector2i(style, 1)
	walls.set_cell(dest, 0, atlas)
	_rebuild_wall_shadow()
	Sfx.play("bump", 0.1)
	return true


## Resets pushable walls to their initial positions.
func reset_pushable_walls() -> void:
	# Erase current pushable wall tiles.
	for cell: Vector2i in pushable_cells:
		walls.erase_cell(cell)
	# Restore initial positions.
	pushable_cells = _initial_pushable_cells.duplicate()
	for cell: Vector2i in pushable_cells:
		var style: int = pushable_cells[cell]
		walls.set_cell(cell, 0, Vector2i(style, 1))
	_rebuild_wall_shadow()


func _rebuild_wall_shadow() -> void:
	var old_shadow := get_node_or_null("WallShadow")
	if old_shadow:
		old_shadow.queue_free()
	_add_wall_shadow()


func is_inside(cell: Vector2i) -> bool:
	return Rect2i(Vector2i.ZERO, grid_size).has_point(cell)


func cell_to_position(cell: Vector2i) -> Vector2:
	return walls.map_to_local(cell)


func position_to_cell(pos: Vector2) -> Vector2i:
	return walls.local_to_map(pos)


func get_ghosts() -> Array[Node]:
	return $Ghosts.get_children()


func get_portal_at(cell: Vector2i) -> Portal:
	return _get_at(cell, $Portals) as Portal


func get_key_at(cell: Vector2i) -> Key:
	return _get_at(cell, $Keys) as Key


func get_door_at(cell: Vector2i) -> Door:
	return _get_at(cell, $Doors) as Door


## Keys the pac is carrying: collected and not used on their door yet.
func get_held_keys() -> Array[Key]:
	var held: Array[Key] = []
	for key: Key in $Keys.get_children():
		if key.collected and not key.used:
			held.append(key)
	return held


func collect_key(key: Key) -> void:
	key.collect()
	Sfx.play("key")
	keys_changed.emit()


## Opens the closed door at the cell if the pac carries its key, which is used up.
func try_open_door(cell: Vector2i) -> bool:
	var door := get_door_at(cell)
	if door == null or door.is_open:
		return false
	for key in get_held_keys():
		if key.door == door:
			key.used = true
			door.set_open(true)
			Sfx.play("door")
			keys_changed.emit()
			return true
	return false


## Puts every key back and closes the doors, for when the pac restarts.
func reset_keys() -> void:
	for key: Key in $Keys.get_children():
		key.reset()
	keys_changed.emit()


func _get_at(cell: Vector2i, parent: Node) -> Node2D:
	for child: Node2D in parent.get_children():
		if position_to_cell(to_local(child.global_position)) == cell:
			return child
	return null


func get_bounds() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(grid_size) * tile_size())


func register_move() -> void:
	move_count += 1


func complete() -> void:
	if finished:
		return
	finished = true
	completed.emit()


## Same formula as the original game: fewer moves and less time give more points.
func compute_score() -> int:
	var moves := maxf(move_count, 1.0)
	var seconds := maxf(roundf(elapsed), 1.0)
	return roundi(level_bonus + move_sensitivity / moves + time_sensitivity / seconds)
