class_name Player
extends Node2D
## Pac: once a direction is chosen it slides until it hits a wall.

signal moved
signal died

const SUBSTEP := 0.25 ## Max tiles travelled between collision checks.
const GHOST_HIT_DISTANCE := 0.85 ## In tiles.
const PILL_HIT_DISTANCE := 0.8 ## In tiles.
const ANIMATION_FPS := 12.0
const SWIPE_MIN_DISTANCE := 30.0 ## In screen pixels.
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
var _swipe_start: Variant = null ## Screen position where the current touch began, until it becomes a swipe.
var _swipe := Vector2i.ZERO ## Direction swiped since the last physics frame.

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
	# Like a key press, a swipe only counts on the frame it happens.
	_swipe = Vector2i.ZERO


## Touch screens: one swipe per touch, in the dominant axis of the drag.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_swipe_start = event.position if event.pressed and event.index == 0 else null
	elif event is InputEventScreenDrag and event.index == 0 and _swipe_start != null:
		var drag: Vector2 = event.position - _swipe_start
		if drag.length() < SWIPE_MIN_DISTANCE:
			return
		if absf(drag.x) > absf(drag.y):
			_swipe = Vector2i.RIGHT if drag.x > 0 else Vector2i.LEFT
		else:
			_swipe = Vector2i.DOWN if drag.y > 0 else Vector2i.UP
		_swipe_start = null
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	# Clamped so a hitch (e.g. the first Sfx.play call decoding audio) can't
	# skip several mouth frames at once and make the animation look erratic.
	_animation_time += minf(delta, 1.0 / ANIMATION_FPS)
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
	Sfx.play("death")
	reset()
	died.emit()


func _read_input() -> void:
	var chosen := _swipe
	for action: String in DIRECTIONS:
		if Input.is_action_just_pressed(action):
			chosen = DIRECTIONS[action]
	if chosen == Vector2i.ZERO:
		return
	sprite.rotation = Vector2(chosen).angle()
	level.register_move()
	moved.emit()
	# Pushing against a door with its key opens it, but the pac stays put until the next command.
	if not level.try_open_door(cell + chosen):
		direction = chosen
		Sfx.play("move", 0.05)


func _advance(distance: float) -> void:
	var tile := level.tile_size()
	while distance > 0.0 and direction != Vector2i.ZERO:
		var next := cell + direction
		# Leaving the map counts as hitting a wall, even without border blocks.
		if level.is_wall(next) or not level.is_inside(next):
			direction = Vector2i.ZERO
			Sfx.play("bump", 0.1)
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
		Sfx.play("portal")
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
