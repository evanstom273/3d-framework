shader_type spatial;
// Timber: floorboards with staggered butt joints and gaps, or plain grained timber
// (gap = 0) for treads, handrails, frames and beams. Boards run along world X or Z.

#include "res://house/kit/shaders/kit_common.gdshaderinc"

uniform vec4 color : source_color = vec4(0.55, 0.37, 0.22, 1.0);
uniform float plank_width = 0.14;
uniform float plank_length = 1.6;
uniform float gap = 0.003;
uniform bool along_z = false;
uniform float variation = 0.22;
uniform float roughness = 0.6;

void vertex() {
	kit_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	kit_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec4 board(vec2 uv, float soften) {
	float row = floor(uv.y / plank_width);
	float shifted = uv.x / plank_length + kit_hash12(vec2(row, 4.0));
	float column = floor(shifted);
	vec2 local = vec2(fract(shifted) * plank_length, fract(uv.y / plank_width) * plank_width);
	vec2 edge = min(local, vec2(plank_length, plank_width) - local);
	float inside = min(edge.x, edge.y) - gap * 0.5;
	float height = gap <= 0.0 ? 1.0 : smoothstep(0.0, 0.0015 + soften, inside);
	return vec4(height, column, row, local.x);
}

void fragment() {
	vec3 u_axis;
	vec3 v_axis;
	vec2 uv = kit_plane(kit_world_pos, kit_world_normal, u_axis, v_axis);
	bool vertical = abs(kit_world_normal.y) < 0.5;
	// Floors choose their board direction; vertical faces run the grain along their length.
	if (!vertical && along_z) {
		uv = uv.yx;
		vec3 swap = u_axis;
		u_axis = v_axis;
		v_axis = swap;
	}
	float soften = length(fwidth(uv)) * 0.6;
	vec4 cell = board(uv, soften);
	vec2 id = cell.yz;
	float tone = kit_hash12(id);
	// Grain: stretched noise along the board, with occasional darker figure.
	vec2 grain_uv = vec2(uv.x * 2.2, uv.y * 46.0) + id * 13.0;
	float grain = kit_fbm(grain_uv);
	float rings = sin((uv.y * 90.0 + grain * 8.0 + tone * 20.0)) * 0.5 + 0.5;
	vec3 wood = color.rgb * (1.0 - variation * 0.5 + variation * tone);
	wood *= 0.82 + 0.22 * grain + 0.08 * rings;
	ALBEDO = mix(wood * 0.35, wood, cell.x);
	ROUGHNESS = roughness + (1.0 - cell.x) * 0.3;
	AO = mix(0.5, 1.0, cell.x);
	float e = 0.0015;
	float dhdu = (board(uv + vec2(e, 0.0), soften).x - cell.x) / e;
	float dhdv = (board(uv + vec2(0.0, e), soften).x - cell.x) / e;
	NORMAL = kit_bump(kit_world_normal, u_axis, v_axis, dhdu * 0.004, dhdv * 0.004 + (grain - 0.5) * 0.02, 1.0, VIEW_MATRIX);
}
