extends Sprite2D
## Loops through every frame of the sprite sheet.

@export var fps := 12.0

var _time := 0.0


func _process(delta: float) -> void:
	_time += delta
	frame = int(_time * fps) % (hframes * vframes)
