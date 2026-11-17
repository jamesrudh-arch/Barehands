shader_type canvas_item;
// Gentle noir vignette: sample the screen, darken the corners toward a deep
// blue-black. One fullscreen canvas quad.

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;
uniform float strength : hint_range(0.0, 1.0) = 0.42;
uniform vec3 tint : source_color = vec3(0.02, 0.03, 0.06);

void fragment() {
	vec3 scr = texture(screen_tex, SCREEN_UV).rgb;
	vec2 uv = SCREEN_UV - vec2(0.5);
	float d = length(uv * vec2(1.15, 1.0));
	float vig = smoothstep(0.42, 0.85, d) * strength;
	COLOR.rgb = mix(scr, tint, vig);
	COLOR.a = 1.0;
}
