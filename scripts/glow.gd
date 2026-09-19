class_name Glow
extends Sprite2D
## Soft additive halo that pulses gently. It takes the parent's modulate, so colored portals and keys
## glow in their own color.

const TEXTURE_SIZE := 128

static var _texture: GradientTexture2D

@export var color := Color(1, 1, 1, 0.5)
@export var radius := 30.0 ## In pixels.
@export var pulse := 0.2 ## Fraction of the alpha that comes and goes.
@export var pulse_speed := 3.0 ## Radians per second.

var _time := randf() * TAU


func _ready() -> void:
	texture = _get_texture()
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive
	scale = Vector2.ONE * radius * 2.0 / TEXTURE_SIZE
	self_modulate = color


func _process(delta: float) -> void:
	_time += delta * pulse_speed
	self_modulate.a = color.a * (1.0 - pulse * (0.5 + 0.5 * sin(_time)))


static func _get_texture() -> GradientTexture2D:
	if _texture == null:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
		gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0)])
		_texture = GradientTexture2D.new()
		_texture.gradient = gradient
		_texture.fill = GradientTexture2D.FILL_RADIAL
		_texture.fill_from = Vector2(0.5, 0.5)
		_texture.fill_to = Vector2(1.0, 0.5)
		_texture.width = TEXTURE_SIZE
		_texture.height = TEXTURE_SIZE
	return _texture
