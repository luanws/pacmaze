extends CanvasLayer
## Iris wipe between scenes: the screen closes into a circle, a title card shows over black and the
## circle reopens on the next scene.

const CLOSE_TIME := 0.55
const TITLE_TIME := 0.9
const OPEN_TIME := 0.55
const TITLE_FONT := preload("res://assets/fonts/Righteous-Regular.ttf")
const IRIS_SHADER := """
shader_type canvas_item;

uniform vec2 rect_size = vec2(1.0);
uniform vec2 center = vec2(0.0); // In canvas pixels.
uniform float radius = 0.0; // In canvas pixels.

void fragment() {
	float dist = distance(UV * rect_size, center);
	COLOR = vec4(0.0, 0.0, 0.0, smoothstep(radius - 1.5, radius + 1.5, dist));
}
"""

var busy := false
## Where the iris reopens (in canvas pixels); the new scene sets it through focus_on().
var _open_focus: Variant = null
var _iris: ColorRect
var _material: ShaderMaterial
var _title: Label


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	var shader := Shader.new()
	shader.code = IRIS_SHADER
	_material = ShaderMaterial.new()
	_material.shader = shader
	_iris = ColorRect.new()
	_iris.material = _material
	_iris.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_iris)
	_title = Label.new()
	_title.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_font_override("font", TITLE_FONT)
	_title.add_theme_font_size_override("font_size", 64)
	_title.add_theme_color_override("font_color", Color(0.95, 0.92, 0.13))
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)
	hide()


## Closes the iris on `focus` (screen center when null), swaps to `path`, shows `title` and reopens.
func change_scene(path: String, title := "", focus: Variant = null) -> void:
	if busy:
		return
	busy = true
	_open_focus = null
	_title.modulate.a = 0.0
	show()
	var from: Vector2 = focus if focus != null else _iris.size / 2
	await _tween_radius(from, _cover_radius(from), 0.0, CLOSE_TIME, Tween.EASE_IN)
	# The new scene stays paused until it's fully revealed, so its clock doesn't run behind the black.
	get_tree().paused = true
	get_tree().change_scene_to_file(path)
	if not title.is_empty():
		_title.text = title
		var fade := create_tween()
		fade.tween_property(_title, "modulate:a", 1.0, 0.2)
		fade.tween_interval(TITLE_TIME - 0.4)
		fade.tween_property(_title, "modulate:a", 0.0, 0.2)
		await fade.finished
	else:
		await get_tree().create_timer(0.1).timeout
	var to: Vector2 = _open_focus if _open_focus != null else _iris.size / 2
	await _tween_radius(to, 0.0, _cover_radius(to), OPEN_TIME, Tween.EASE_OUT)
	hide()
	get_tree().paused = false
	busy = false


## Lets the scene being revealed pick where the iris opens from.
func focus_on(point: Vector2) -> void:
	_open_focus = point


func _tween_radius(center: Vector2, from: float, to: float, time: float, ease_type: Tween.EaseType) -> void:
	_material.set_shader_parameter("center", center)
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(ease_type)
	tween.tween_method(_set_radius, from, to, time)
	await tween.finished


func _set_radius(radius: float) -> void:
	_material.set_shader_parameter("rect_size", _iris.size)
	_material.set_shader_parameter("radius", radius)


## Smallest radius around `point` that still uncovers the whole screen.
func _cover_radius(point: Vector2) -> float:
	var size := _iris.size
	var corners := [Vector2.ZERO, Vector2(size.x, 0), Vector2(0, size.y), size]
	var radius := 0.0
	for corner in corners:
		radius = maxf(radius, point.distance_to(corner))
	return radius + 2.0
