class_name Key
extends Node2D
## Collected when the pac passes over it. The pac keeps it until using it on the door of the same color.

const BOB_HEIGHT := 3.0
const BOB_SPEED := 4.0

var door: Door
var collected := false
var used := false
var _time := 0.0

@onready var sprite: Sprite2D = $Sprite2D


func _process(delta: float) -> void:
	_time += delta
	sprite.position.y = sin(_time * BOB_SPEED) * BOB_HEIGHT


func collect() -> void:
	collected = true
	visible = false


func reset() -> void:
	collected = false
	used = false
	visible = true
	door.set_open(false)
