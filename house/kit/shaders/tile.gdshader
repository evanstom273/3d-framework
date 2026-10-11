shader_type spatial;
// Ceramic or quarry tiles with recessed grout. Optional checkerboard of two colours.

#include "res://house/kit/shaders/kit_common.gdshaderinc"

uniform vec4 color : source_color = vec4(0.92, 0.93, 0.9, 1.0);
uniform vec4 alt_color : source_color = vec4(0.18, 0.2, 0.22, 1.0);
uniform bool checker = false;
uniform vec4 grout_color : source_color = vec4(0.72, 0.71, 0.68, 1.0);
uniform vec2 tile_size = vec2(0.15, 0.15);
uniform float grout = 0.004;
uniform float roughness = 0.18;

void vertex() {
	kit_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	kit_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec3 tile(vec2 uv, float soften) {
	vec2 cell = floor(uv / tile_size);
	vec2 local = fract(uv / tile_size) * tile_size;
	vec2 edge = min(local, tile_size - local);
	float inside = min(edge.x, edge.y) - grout * 0.5;
	return vec3(smoothstep(0.0, 0.0015 + soften, inside), cell);
}

void fragment() {
	vec3 u_axis;
	vec3 v_axis;
	vec2 uv = kit_plane(kit_world_pos, kit_world_normal, u_axis, v_axis);
	float soften = length(fwidth(uv)) * 0.6;
	vec3 cell = tile(uv, soften);
	float tone = kit_hash12(cell.yz);
	vec3 base = color.rgb;
	if (checker && mod(cell.y + cell.z, 2.0) > 0.5) {
		base = alt_color.rgb;
	}
	base *= 0.95 + 0.07 * tone;
	ALBEDO = mix(grout_color.rgb * 0.7, base, cell.x);
	ROUGHNESS = mix(0.9, roughness, cell.x);
	AO = mix(0.6, 1.0, cell.x);
	float e = 0.001;
	float dhdu = (tile(uv + vec2(e, 0.0), soften).x - cell.x) / e;
	float dhdv = (tile(uv + vec2(0.0, e), soften).x - cell.x) / e;
	NORMAL = kit_bump(kit_world_normal, u_axis, v_axis, dhdu * 0.003, dhdv * 0.003, 1.0, VIEW_MATRIX);
}
