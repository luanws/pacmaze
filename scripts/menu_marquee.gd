extends Control
## Decorative Pac-Man being chased by ghosts, looping across the main menu.

const SPEED := 70.0 ## Pixels per second.
const CHOMP_FPS := 12.0
const WALK_FPS := 6.0
const GHOST_GAP := 46.0 ## Pixels between the pac and each ghost behind it.

@onready var pac: Sprite2D = %Pac
@onready var ghosts: Array[Sprite2D] = [%Ghost1, %Ghost2]

var _time := 0.0


func _process(delta: float) -> void:
	_time += delta
	# Ping-pong through the mouth frames, same cycle as the player's own animation.
	var chomp_cycle := pac.hframes * 2 - 2
	var chomp_index := int(_time * CHOMP_FPS) % chomp_cycle
	pac.frame = chomp_index if chomp_index < pac.hframes else chomp_cycle - chomp_index
	var walk_frame := int(_time * WALK_FPS) % 2
	for ghost in ghosts:
		ghost.frame = 4 + walk_frame # Right-facing walk frames on the ghost sheet.

	var span := size.x + GHOST_GAP * (ghosts.size() + 1)
	var travel := fmod(_time * SPEED, span)
	pac.position.x = travel - GHOST_GAP
	for i in ghosts.size():
		ghosts[i].position.x = pac.position.x - GHOST_GAP * (i + 1)
