class_name Player
extends Node2D
## Pac: once a direction is chosen it slides until it hits a wall.

signal moved
signal died

const SUBSTEP := 0.25 ## Max tiles travelled between collision checks.
const GHOST_HIT_DISTANCE := 0.85 ## In tiles.
const PILL_HIT_DISTANCE := 0.8 ## In tiles.
const ANIMATION_FPS := 12.0
const DIRECTIONS := {
	"move_left": Vector2i.LEFT,
	"move_right": Vector2i.RIGHT,
	"move_up": Vector2i.UP,
	"move_down": Vector2i.DOWN,
}

@export var speed := 60.0 ## Tiles per second.

var level: Level
var start_cell: Vector2i
var cell: Vector2i
var direction := Vector2i.ZERO
var inside_portal: Portal
var _animation_time := 0.0

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	level = get_parent() as Level
	start_cell = level.position_to_cell(position)
	cell = start_cell
	position = level.cell_to_position(cell)


func _physics_process(delta: float) -> void:
	if level.finished:
		return
	if Input.is_action_just_pressed("restart"):
		reset()
		return
	if direction == Vector2i.ZERO:
		_read_input()
	if direction != Vector2i.ZERO:
		_advance(speed * delta)
	elif _touches_ghost():
		_die()


func _process(delta: float) -> void:
	_animation_time += delta
	# Ping-pong through the mouth frames.
	var cycle := sprite.hframes * 2 - 2
	var index := int(_animation_time * ANIMATION_FPS) % cycle
	sprite.frame = index if index < sprite.hframes else cycle - index


func reset() -> void:
	direction = Vector2i.ZERO
	cell = start_cell
	position = level.cell_to_position(cell)
	inside_portal = level.get_portal_at(cell)
	level.reset_keys()


func _die() -> void:
	reset()
	died.emit()


func _read_input() -> void:
	for action: String in DIRECTIONS:
		if Input.is_action_just_pressed(action):
			var chosen: Vector2i = DIRECTIONS[action]
			sprite.rotation = Vector2(chosen).angle()
			level.register_move()
			moved.emit()
			# Pushing against a door with its key opens it, but the pac stays put until the next command.
			if not level.try_open_door(cell + chosen):
				direction = chosen
			return


func _advance(distance: float) -> void:
	var tile := level.tile_size()
	while distance > 0.0 and direction != Vector2i.ZERO:
		var next := cell + direction
		# Leaving the map counts as hitting a wall, even without border blocks.
		if level.is_wall(next) or not level.is_inside(next):
			direction = Vector2i.ZERO
			return
		var target := level.cell_to_position(next)
		var step := minf(distance, SUBSTEP) * tile
		var remaining := position.distance_to(target)
		if step >= remaining:
			position = target
			distance -= remaining / tile
			cell = next
			_on_cell_entered()
		else:
			position = position.move_toward(target, step)
			distance -= step / tile
		if _touches_ghost():
			_die()
			return
		if _touches_pill():
			direction = Vector2i.ZERO
			level.complete()
			return


func _on_cell_entered() -> void:
	var key := level.get_key_at(cell)
	if key and not key.collected:
		level.collect_key(key)
	var portal := level.get_portal_at(cell)
	if portal == null:
		inside_portal = null
	elif portal != inside_portal:
		# The portals swap places, so the one we entered ends up under us.
		portal.teleport()
		inside_portal = portal
		cell = level.position_to_cell(level.to_local(portal.global_position))
		position = level.cell_to_position(cell)


func _touches_ghost() -> bool:
	var limit := GHOST_HIT_DISTANCE * level.tile_size()
	for ghost: Node2D in level.get_ghosts():
		if ghost.global_position.distance_to(global_position) < limit:
			return true
	return false


func _touches_pill() -> bool:
	var limit := PILL_HIT_DISTANCE * level.tile_size()
	return level.pill.global_position.distance_to(global_position) < limit
