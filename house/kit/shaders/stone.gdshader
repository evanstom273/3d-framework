shader_type spatial;
// Natural stone, concrete, terracotta and carpet: mottled colour with grain and
// surface relief. `blocks` > 0 adds ashlar joints (for quoins and copings).

#include "res://house/kit/shaders/kit_common.gdshaderinc"

uniform vec4 color : source_color = vec4(0.78, 0.74, 0.65, 1.0);
uniform float mottling = 0.18;
uniform float grain_scale = 40.0;
uniform float relief = 1.0;
uniform float roughness = 0.85;
uniform float blocks = 0.0;

void vertex() {
	kit_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	kit_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float surface(vec2 uv) {
	return kit_fbm(uv * grain_scale) * 0.7 + kit_noise(uv * grain_scale * 6.0) * 0.3;
}

void fragment() {
	vec3 u_axis;
	vec3 v_axis;
	vec2 uv = kit_plane(kit_world_pos, kit_world_normal, u_axis, v_axis);
	float broad = kit_fbm(uv * 2.5);
	float h = surface(uv);
	vec3 base = color.rgb * (1.0 - mottling + mottling * 2.0 * broad) * (0.9 + 0.2 * h);
	float joint_mask = 1.0;
	if (blocks > 0.0) {
		vec2 cell = uv / vec2(blocks, blocks * 0.5);
		vec2 local = fract(cell);
		vec2 edge = min(local, 1.0 - local) * vec2(blocks, blocks * 0.5);
		joint_mask = smoothstep(0.002, 0.006, min(edge.x, edge.y));
		base *= 0.92 + 0.12 * kit_hash12(floor(cell));
	}
	ALBEDO = base * mix(0.55, 1.0, joint_mask);
	ROUGHNESS = roughness;
	float e = 0.002;
	float dhdu = (surface(uv + vec2(e, 0.0)) - h) / e;
	float dhdv = (surface(uv + vec2(0.0, e)) - h) / e;
	NORMAL = kit_bump(kit_world_normal, u_axis, v_axis, dhdu * 0.0015 * relief, dhdv * 0.0015 * relief, 1.0, VIEW_MATRIX);
}
