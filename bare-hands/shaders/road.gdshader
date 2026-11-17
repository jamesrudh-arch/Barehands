shader_type spatial;
// Wet noir asphalt: dark base, a procedural puddle mask that turns mirror-smooth,
// and fake neon reflections - colored glossy patches fading with each sign's
// distance, riding the puddles, lifted by fresnel. No screen-space reflections.

uniform vec3 asphalt_col : source_color = vec3(0.03, 0.035, 0.05);
uniform float wet_gloss : hint_range(0.0, 1.0) = 0.75;
uniform vec3 neon_a : source_color = vec3(1.0, 0.58, 0.13);  // amber
uniform vec3 neon_b : source_color = vec3(0.15, 0.9, 1.0);   // cyan
uniform vec3 neon_c : source_color = vec3(1.0, 0.16, 0.12);  // red
uniform vec3 sign_a = vec3(9.0, 3.5, -4.5);
uniform vec3 sign_b = vec3(-9.0, 3.0, -12.4);
uniform vec3 sign_c = vec3(14.0, 3.5, 8.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	float n = noise(WORLD_VERTEX_COORDS.xz * 0.55) * 0.6 + noise(WORLD_VERTEX_COORDS.xz * 2.1) * 0.4;
	float pud = smoothstep(0.60, 0.78, n);          // standing puddles
	float damp = 0.35 + pud * wet_gloss;             // the whole street is rain-wet

	ALBEDO = asphalt_col * (0.8 + 0.2 * n);
	// rain ripple shimmer on the puddles
	float ripple = 0.04 * sin(WORLD_VERTEX_COORDS.x * 9.0 + TIME * 3.1)
			* sin(WORLD_VERTEX_COORDS.z * 7.0 - TIME * 2.3) * pud;
	ROUGHNESS = clamp(mix(0.72, 0.05, pud) * (1.0 - 0.15 * damp) + ripple, 0.04, 1.0);
	METALLIC = pud * 0.6;

	// Fake neon reflections: soft colored blobs around each sign's ground
	// shadow, riding the puddles, brighter at grazing view angles.
	vec2 ta = WORLD_VERTEX_COORDS.xz - sign_a.xz;
	vec2 tb = WORLD_VERTEX_COORDS.xz - sign_b.xz;
	vec2 tc = WORLD_VERTEX_COORDS.xz - sign_c.xz;
	vec3 refl = neon_a * exp(-dot(ta, ta) * 0.018)
			+ neon_b * exp(-dot(tb, tb) * 0.025)
			+ neon_c * exp(-dot(tc, tc) * 0.022);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	EMISSION = refl * (pud * 1.3 + 0.12) * (0.3 + 0.7 * fres);
}
