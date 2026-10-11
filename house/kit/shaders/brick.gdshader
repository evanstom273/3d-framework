shader_type spatial;
// Brickwork with recessed mortar joints: per-brick colour, worn arrises and a bevel
// into the joint. Running bond by default; bond_offset 0 with tall bricks makes a
// soldier course for lintels.

#include "res://house/kit/shaders/kit_common.gdshaderinc"

uniform vec4 brick_color : source_color = vec4(0.58, 0.27, 0.19, 1.0);
uniform vec4 mortar_color : source_color = vec4(0.72, 0.69, 0.63, 1.0);
uniform vec2 brick_size = vec2(0.225, 0.075);
uniform float joint = 0.01;
uniform float bond_offset = 0.5;
uniform float variation = 0.16;
uniform float recess_depth = 1.0;

void vertex() {
	kit_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	kit_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// x: height (1 on the brick face, 0 in the joint), yz: brick cell id.
vec3 brick_cell(vec2 uv, float soften) {
	float row = floor(uv.y / brick_size.y);
	float u = uv.x / brick_size.x + mod(row, 2.0) * bond_offset;
	float column = floor(u);
	vec2 local = vec2(fract(u) * brick_size.x, fract(uv.y / brick_size.y) * brick_size.y);
	vec2 edge = min(local, brick_size - local);
	float inside = min(edge.x, edge.y) - joint * 0.5;
	// Slightly rounded, uneven arrises read as real brick rather than tiles.
	float wobble = (kit_hash12(vec2(column, row) + 3.1) - 0.5) * 0.002;
	float height = smoothstep(0.0, 0.004 + soften, inside + wobble);
	return vec3(height, column, row);
}

void fragment() {
	vec3 u_axis;
	vec3 v_axis;
	vec2 uv = kit_plane(kit_world_pos, kit_world_normal, u_axis, v_axis);
	float soften = length(fwidth(uv)) * 0.7;
	vec3 cell = brick_cell(uv, soften);
	float e = 0.0015;
	float dhdu = (brick_cell(uv + vec2(e, 0.0), soften).x - cell.x) / e;
	float dhdv = (brick_cell(uv + vec2(0.0, e), soften).x - cell.x) / e;

	vec2 id = cell.yz;
	float tone = kit_hash12(id);
	vec3 brick = brick_color.rgb * (1.0 - variation * 0.5 + variation * tone);
	brick = mix(brick, brick * vec3(0.78, 0.74, 0.86), step(0.86, kit_hash12(id + 7.0)) * 0.6);
	// Fine texture fades out with distance so it never sparkles.
	float detail = 1.0 - smoothstep(0.0015, 0.006, length(fwidth(uv)));
	brick *= 1.0 + 0.24 * (kit_fbm(uv * 55.0) - 0.5) * (0.4 + 0.6 * detail);
	float speckle = kit_noise(uv * 260.0);
	brick *= 1.0 + 0.08 * (speckle - 0.5) * detail;
	// Joints sit back from the face, so they catch less light.
	vec3 mortar = mortar_color.rgb * (0.62 + 0.25 * kit_noise(uv * 120.0));
	ALBEDO = mix(mortar, brick, cell.x);
	ROUGHNESS = mix(0.95, 0.82 + 0.1 * tone, cell.x);
	AO = mix(0.55, 1.0, cell.x);
	// Each brick sits a touch out of plane.
	vec2 tilt = (kit_hash22(id) - 0.5) * 0.06 * cell.x;
	NORMAL = kit_bump(kit_world_normal, u_axis, v_axis, dhdu * 0.012 * recess_depth + tilt.x, dhdv * 0.012 * recess_depth + tilt.y, 1.0, VIEW_MATRIX);
}
