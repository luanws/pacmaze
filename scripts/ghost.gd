@tool
class_name Ghost
extends Node2D
## Enemy that loops forever through a fixed list of straight moves, ignoring walls.

enum GhostColor { BLUE, GREEN, PURPLE, YELLOW }

const TEXTURES := {
	GhostColor.BLUE: preload("res://assets/sprites/ghost_blue.png"),
	GhostColor.GREEN: preload("res://assets/sprites/ghost_green.png"),
	GhostColor.PURPLE: preload("res://assets/sprites/ghost_purple.png"),
	GhostColor.YELLOW: preload("res://assets/sprites/ghost_yellow.png"),
}
const ANIMATION_FPS := 12.0
## First frame of each two-frame walk cycle in the sprite sheet.
const FRAME_UP := 0
const FRAME_DOWN := 2
const FRAME_RIGHT := 4
const FRAME_LEFT := 6
const DEFAULT_TILE_SIZE := 30.0

@export var color := GhostColor.BLUE:
	set(value):
		color = value
		if is_node_ready():
			sprite.texture = TEXTURES[color]
## Each entry is a move in tiles along a single axis.
@export var path: Array[Vector2i] = []
@export var speed := 7.5 ## Tiles per second.

var _index := 0
var _target: Vector2
var _animation_time := 0.0
var _tile_size := DEFAULT_TILE_SIZE

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	sprite.texture = TEXTURES[color]
	if Engine.is_editor_hint():
		return
	add_to_group("ghosts")
	var level := _find_level()
	if level:
		_tile_size = level.tile_size()
	if not path.is_empty():
		_target = position + _path_offset(0)


func _process(delta: float) -> void:
	_animation_time += delta
	var current: Vector2i = path[_index] if not path.is_empty() else Vector2i.ZERO
	sprite.frame = _first_frame(current) + int(_animation_time * ANIMATION_FPS) % 2
	if Engine.is_editor_hint() or path.is_empty():
		return
	var step := speed * _tile_size * delta
	# Bounded loop so a path made only of zero moves can't hang.
	for i in path.size() + 1:
		var remaining := position.distance_to(_target)
		if step < remaining:
			position = position.move_toward(_target, step)
			return
		position = _target
		step -= remaining
		_index = (_index + 1) % path.size()
		_target = position + _path_offset(_index)


func _path_offset(index: int) -> Vector2:
	return Vector2(path[index]) * _tile_size


func _find_level() -> Level:
	var node := get_parent()
	while node and not node is Level:
		node = node.get_parent()
	return node as Level


func _first_frame(move: Vector2i) -> int:
	if move.x > 0:
		return FRAME_RIGHT
	if move.x < 0:
		return FRAME_LEFT
	if move.y < 0:
		return FRAME_UP
	return FRAME_DOWN
