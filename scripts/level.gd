class_name Level
extends Node2D
## A maze level. Walls live in a TileMapLayer; entities query the level for collisions.

signal completed

@export var next_level_score := 10
@export var move_sensitivity := 200
@export var time_sensitivity := 100
@export_multiline var instructions := ""

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
	return walls.get_cell_source_id(cell) != -1


func cell_to_position(cell: Vector2i) -> Vector2:
	return walls.map_to_local(cell)


func position_to_cell(pos: Vector2) -> Vector2i:
	return walls.local_to_map(pos)


func get_ghosts() -> Array[Node]:
	return get_tree().get_nodes_in_group("ghosts")


func get_portal_at(cell: Vector2i) -> Portal:
	for portal: Portal in get_tree().get_nodes_in_group("portals"):
		if position_to_cell(to_local(portal.global_position)) == cell:
			return portal
	return null


func get_bounds() -> Rect2:
	var used := walls.get_used_rect()
	var size := tile_size()
	return Rect2(Vector2(used.position) * size, Vector2(used.size) * size)


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
	return roundi(next_level_score + move_sensitivity / moves + time_sensitivity / seconds)
