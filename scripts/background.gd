extends CanvasLayer
## Backdrop drawn behind every scene: a dark navy gradient with slow drifting glows, a faint dot grid
## and a vignette, so the screen never sits on flat black.

const BACKGROUND_SHADER := """
shader_type canvas_item;

uniform vec2 rect_size = vec2(1.0);
uniform float dot_spacing = 36.0; // In canvas pixels.

float glow(vec2 uv, vec2 center, float size) {
	return exp(-dot(uv - center, uv - center) / (size * size));
}

void fragment() {
	vec2 aspect = vec2(rect_size.x / rect_size.y, 1.0);
	vec2 uv = UV * aspect;
	float t = TIME * 0.04;

	vec3 color = mix(vec3(0.035, 0.04, 0.09), vec3(0.012, 0.014, 0.035), UV.y);

	vec2 blue_center = vec2(0.3 + 0.12 * sin(t * 1.3), 0.35 + 0.1 * cos(t)) * aspect;
	vec2 purple_center = vec2(0.72 + 0.1 * cos(t * 0.9), 0.7 + 0.12 * sin(t * 1.1)) * aspect;
	color += vec3(0.0, 0.16, 0.3) * 0.28 * glow(uv, blue_center, 0.45);
	color += vec3(0.22, 0.05, 0.3) * 0.22 * glow(uv, purple_center, 0.4);

	vec2 cell = fract(UV * rect_size / dot_spacing) - 0.5;
	float dot_mask = 1.0 - smoothstep(0.03, 0.07, length(cell));
	color += vec3(0.25, 0.45, 0.8) * 0.05 * dot_mask;

	vec2 centered = UV - 0.5;
	color *= 1.0 - 0.55 * smoothstep(0.25, 0.8, length(centered * vec2(1.1, 1.0)));

	// A touch of noise breaks up banding in the gradient.
	float noise = fract(sin(dot(FRAGCOORD.xy, vec2(12.9898, 78.233))) * 43758.5453);
	color += (noise - 0.5) / 255.0;

	COLOR = vec4(color, 1.0);
}
"""

var _material: ShaderMaterial


func _ready() -> void:
	layer = -100
	process_mode = Node.PROCESS_MODE_ALWAYS
	var shader := Shader.new()
	shader.code = BACKGROUND_SHADER
	_material = ShaderMaterial.new()
	_material.shader = shader
	var rect := ColorRect.new()
	rect.material = _material
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(rect)
	rect.resized.connect(func() -> void: _material.set_shader_parameter("rect_size", rect.size))
