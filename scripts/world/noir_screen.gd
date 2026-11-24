extends CanvasLayer

## THE NOIR SCREEN (S5.17 feel pass): the camera's identity -
## vignette, film grain, and a chromatic fringe that only wakes
## at the frame's edge. The 3D grade lights the street; THIS
## layers the lens over it. Mobile-honest: one fullscreen pass,
## three texture fetches, a 64px noise tile, edge-only fringe.
## Layer 1: over the world, under every UI CanvasLayer (HUD 20).

const SHADER := """
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture,
		repeat_disable, filter_linear;
uniform sampler2D noise_tex : repeat_enable, filter_nearest;
uniform float vignette_power : hint_range(0.0, 1.0) = 0.52;
uniform float grain_amount : hint_range(0.0, 0.2) = 0.11;
uniform float fringe : hint_range(0.0, 0.004) = 0.0034;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 d = uv - vec2(0.5);
	float r = length(d) * 1.414;
	// chromatic fringe: only the outer third of the frame pays
	float fr = fringe * smoothstep(0.38, 1.0, r);
	vec3 col;
	col.r = texture(screen_tex, uv + d * fr).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - d * fr).b;
	// vignette: the corners die into the print's edge
	col *= 1.0 - vignette_power * smoothstep(0.42, 1.12, r);
	// the filmic toe: crush the blacks (the VLM read the flat
	// dark-grey sky as raw engine - a gamma push + toe deepens
	// shadows and hardens the highlights' cut)
	col = pow(col, vec3(1.12));
	col = max(col - 0.012, vec3(0.0));
	// grain: animated 2-frame offset, shadows grain hardest
	float g = texture(noise_tex, uv * vec2(480.0, 270.0)
			+ vec2(TIME * 47.0, TIME * 31.0)).r - 0.5;
	col += g * grain_amount
			* (1.0 - 0.55 * dot(col, vec3(0.333)));
	COLOR = vec4(col, 1.0);
}
"""


func _ready() -> void:
	name = "NoirScreen"
	layer = 1
	var rect := ColorRect.new()
	rect.name = "GradeOverlay"
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE  # never eat input
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER
	mat.shader = sh
	mat.set_shader_parameter("noise_tex", _noise())
	rect.material = mat
	add_child(rect)


## A 64x64 white-noise tile for the grain (built once, at load).
static func _noise() -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_L8)
	for y in 64:
		for x in 64:
			img.set_pixel(x, y, Color(randf(), 0, 0))
	return ImageTexture.create_from_image(img)
