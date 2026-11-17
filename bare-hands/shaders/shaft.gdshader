shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded;
// Cheap volumetric-ish light shaft / steam glow: additive quad, fading from
// top to bottom and soft at the sides. One draw call, no lights, no shadows.

uniform vec3 tint : source_color = vec3(1.0, 0.8, 0.5);
uniform float strength : hint_range(0.0, 2.0) = 0.35;

void fragment() {
	float top_fade = pow(clamp(1.0 - UV.y, 0.0, 1.0), 1.3);
	float edge = sin(UV.x * 3.14159);
	ALPHA = 1.0;
	EMISSION = tint * strength * top_fade * edge * 0.32;
}
