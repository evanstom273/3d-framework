// Shared helpers for the house kit's procedural surfaces. World-space mapping keeps
// patterns continuous across separate pieces placed on the grid.

varying vec3 kit_world_pos;
varying vec3 kit_world_normal;

float kit_hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 kit_hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float kit_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(kit_hash12(i), kit_hash12(i + vec2(1.0, 0.0)), u.x),
		mix(kit_hash12(i + vec2(0.0, 1.0)), kit_hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

float kit_fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 4; i++) {
		value += kit_noise(p) * amplitude;
		p = p * 2.03 + vec2(17.1, 9.7);
		amplitude *= 0.5;
	}
	return value;
}

// Picks the world plane a face mostly lies in: returns its 2D coordinates (metres)
// and the world axes those coordinates run along.
vec2 kit_plane(vec3 wp, vec3 wn, out vec3 u_axis, out vec3 v_axis) {
	vec3 a = abs(wn);
	if (a.y > a.x && a.y > a.z) {
		u_axis = vec3(1.0, 0.0, 0.0);
		v_axis = vec3(0.0, 0.0, 1.0);
		return wp.xz;
	}
	v_axis = vec3(0.0, 1.0, 0.0);
	if (a.x > a.z) {
		u_axis = vec3(0.0, 0.0, 1.0);
		return vec2(wp.z, wp.y);
	}
	u_axis = vec3(1.0, 0.0, 0.0);
	return wp.xy;
}

// World-space normal tilted against a height field's gradient, back into view space.
vec3 kit_bump(vec3 wn, vec3 u_axis, vec3 v_axis, float dhdu, float dhdv, float strength, mat4 view) {
	vec3 n = normalize(wn - (u_axis * dhdu + v_axis * dhdv) * strength);
	return normalize((view * vec4(n, 0.0)).xyz);
}
