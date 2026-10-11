shader_type spatial;
// Painted plaster, render and joinery: a flat colour with subtle trowel mottling
// and a fine surface texture. Gloss paint (low roughness) for trims and frames.

#include "res://house/kit/shaders/kit_common.gdshaderinc"

uniform vec4 color : source_color = vec4(0.9, 0.88, 0.83, 1.0);
uniform float roughness = 0.88;
uniform float mottling = 0.05;
uniform float texture_scale = 1.0;
uniform float bump = 0.15;

void vertex() {
	kit_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	kit_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 u_axis;
	vec3 v_axis;
	vec2 uv = kit_plane(kit_world_pos, kit_world_normal, u_axis, v_axis) * texture_scale;
	float broad = kit_fbm(uv * 1.7);
	float fine = kit_noise(uv * 180.0);
	ALBEDO = color.rgb * (1.0 - mottling + mottling * 2.0 * broad) * (0.985 + 0.03 * fine);
	ROUGHNESS = roughness;
	float e = 0.002;
	float h = kit_noise(uv * 90.0);
	float dhdu = (kit_noise((uv + vec2(e, 0.0)) * 90.0) - h) / e;
	float dhdv = (kit_noise((uv + vec2(0.0, e)) * 90.0) - h) / e;
	NORMAL = kit_bump(kit_world_normal, u_axis, v_axis, dhdu * 0.0006 * bump, dhdv * 0.0006 * bump, 1.0, VIEW_MATRIX);
}
