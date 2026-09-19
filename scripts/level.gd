class_name Level
extends Node2D
## A playable maze, built from a LevelData. Entities query it for collisions.

signal completed

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


# Resolved here instead of @onready: children run _ready() before the level does
# and already need the walls.
func _enter_tree() -> void:
	walls = $Walls
	player = $Player
	pill = $Pill


func _process(delta: float) -> void:
	if not finished:
		elapsed += delta


func tile_size() -> float:
	return float(walls.tile_set.tile_size.x)


func is_wall(cell: Vector2i) -> bool:
	if walls.get_cell_source_id(cell) != -1:
		return true
	var door := _get_at(cell, $Doors) as Door
	return door != null and not door.is_open


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


## Puts every key back and closes the doors, for when the pac restarts.
func reset_keys() -> void:
	for key: Key in $Keys.get_children():
		key.reset()


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
