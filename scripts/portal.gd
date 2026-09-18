class_name Portal
extends Node2D
## Teleports the player to its partner; afterwards both portals swap places.

@export var partner: Portal
@export var rotation_speed := 200.0 ## Degrees per second.

@onready var sprite: Sprite2D = $Sprite2D


func _process(delta: float) -> void:
	sprite.rotation += deg_to_rad(rotation_speed) * delta


func teleport() -> void:
	var here := global_position
	global_position = partner.global_position
	partner.global_position = here
