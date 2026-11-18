shader_type spatial;
// Wet noir asphalt, take two (the phone's notes said the old mask read as
// camouflage and the mirror quads as pixelated blocks). Smooth dark asphalt
// with a fine, low-contrast grain; a few EXPLICIT puddles - soft-edged,
// organically wobbled, no noise-threshold blobs; and the neon as elongated
// reflections that stretch from each sign's ground point toward the camera
// across the water, their lines broken by a slow ripple shimmer.
// The floating mirror quads are gone; all water lives in this shader now.

uniform vec3 asphalt_col : source_color = vec3(0.028, 0.032, 0.045);
uniform vec3 neon_a : source_color = vec3(1.0, 0.58, 0.13);   // amber
uniform vec3 neon_b : source_color = vec3(0.15, 0.9, 1.0);    // cyan
uniform vec3 neon_c : source_color = vec3(1.0, 0.16, 0.12);   // red
uniform vec3 sign_a = vec3(1.5, 3.4, -9.45);
uniform vec3 sign_b = vec3(-7, 2.8, 9.05);
uniform vec3 sign_c = vec3(13.95, 1.9, 0.0);
uniform vec3 puddles[5];  // xz centre + radius (matches the puddle markers)
uniform vec3 cam_pos = vec3(0.0, 6.0, 10.0);  // pushed every frame by the camera

varying vec3 world_pos;


void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}


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


// One soft puddle: standing water inside ~half the radius, feathering out
// to dry asphalt at the rim; the rim itself wobbles quietly so no two
// edges look machine-drawn.
float puddle_at(vec2 xz, vec2 c, float r) {
	float wob = noise(xz * 2.6 + c * 3.1) - 0.5;
	float d = length(xz - c) / (r * (1.0 + wob * 0.25));
	return 1.0 - smoothstep(0.45, 1.0, d);
}


// The stretched neon reflection of one sign: a narrow, bright line from the
// sign's ground point toward the camera, broken by the ripple offset and
// living only on the water.
vec3 streak_of(vec2 xz, vec2 s, vec3 color, vec2 cam, float water, float ripple) {
	vec2 to_cam = cam - s;
	float len = max(length(to_cam), 0.001);
	vec2 axis = to_cam / len;
	vec2 rel = xz - s;
	float u = dot(rel, axis);
	float v = dot(rel, vec2(-axis.y, axis.x)) + (ripple - 0.5) * 0.6;
	float reach = clamp(u / len, 0.0, 1.0);
	float lon = 1.0 - smoothstep(0.1, 1.1, reach);   // fades toward the camera
	float lat = exp(-v * v * 20.0);                  // narrow line
	float head = exp(-dot(rel, rel) * 0.06);         // brightest at the base
	return color * water * lon * lat * (0.5 + 1.0 * head);
}


void fragment() {
	vec2 xz = world_pos.xz;
	// fine asphalt grain: small scale, low contrast - texture, not camo
	float grain = noise(xz * 7.0) * 0.5 + noise(xz * 23.0) * 0.3 + noise(xz * 61.0) * 0.2;

	float water = 0.0;
	float ring = 0.0;
	for (int i = 0; i < 5; i++) {
		vec2 c = puddles[i].xy;
		float r = puddles[i].z;
		water = max(water, puddle_at(xz, c, r));
		ring = max(ring, 1.0 - smoothstep(0.9, 2.4, length(xz - c) / r));
	}
	float damp = ring * 0.55;  // the rain-wet halo around each puddle

	ALBEDO = asphalt_col * (0.82 + 0.18 * grain) * (1.0 - 0.22 * damp - 0.5 * water);

	// slow ripple shimmer: two drifting noise fields on the water
	float rip = noise(xz * 9.0 + vec2(TIME * 0.35, -TIME * 0.22));
	float rip2 = noise(xz * 15.0 - vec2(TIME * 0.28, TIME * 0.31));
	float ripple = rip * rip2 * 2.0;  // ~0..1 with sparse peaks

	ROUGHNESS = clamp(mix(0.74 + 0.10 * grain, 0.045 + 0.06 * ripple, water)
			- 0.16 * damp, 0.035, 1.0);
	METALLIC = water * 0.85;

	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.2);
	vec3 streaks = streak_of(xz, sign_a.xz, neon_a, cam_pos.xz, water, ripple)
			+ streak_of(xz, sign_b.xz, neon_b, cam_pos.xz, water, ripple)
			+ streak_of(xz, sign_c.xz, neon_c, cam_pos.xz, water, ripple);
	// a faint city glow on every wet patch so dark water never reads as a hole
	vec3 ambient_wet = (neon_a + neon_b + neon_c) * 0.028 * (water + damp * 0.4);
	EMISSION = (streaks * 0.85 + ambient_wet) * (0.3 + 0.7 * fres);
}
