shader_type spatial;
// Roof tiles laid in courses. Uses the mesh UV: u runs along the eaves, v up the
// slope, both in metres. The roof geometry already steps at each course; this adds
// the individual tiles, their side joints, nibs of shadow and weathering.

#include "res://house/kit/shaders/kit_common.gdshaderinc"

uniform vec4 color : source_color = vec4(0.55, 0.26, 0.17, 1.0);
uniform float tile_width = 0.165;
uniform float course = 0.1;
uniform float variation = 0.25;
uniform float camber = 0.6;
uniform float moss = 0.15;
uniform float roughness = 0.8;

void vertex() {
	kit_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	kit_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 uv = UV;
	float row = floor(uv.y / course);
	float shifted = uv.x / tile_width + mod(row, 2.0) * 0.5;
	float column = floor(shifted);
	vec2 local = vec2(fract(shifted), fract(uv.y / course));
	vec2 id = vec2(column, row);
	float tone = kit_hash12(id);
	float soften = fwidth(shifted) * 1.5;
	// Side joints between tiles, and the shadowed lower edge of the course above.
	float side = smoothstep(0.0, 0.03 + soften, min(local.x, 1.0 - local.x));
	float lap = smoothstep(0.0, 0.18, local.y);
	vec3 tile = color.rgb * (1.0 - variation * 0.5 + variation * tone);
	tile *= 0.85 + 0.25 * kit_fbm(uv * 30.0 + id);
	float weathering = smoothstep(0.55, 0.85, kit_fbm(uv * 3.0 + 11.0)) * moss;
	tile = mix(tile, vec3(0.32, 0.36, 0.22), weathering * (1.0 - local.y));
	ALBEDO = tile * mix(0.35, 1.0, side) * mix(0.55, 1.0, lap);
	ROUGHNESS = roughness;
	AO = mix(0.5, 1.0, side * lap);
	// Each tile is slightly cambered across its width.
	float across = (local.x - 0.5) * 2.0;
	vec3 tangent = normalize((MODEL_MATRIX * vec4(1.0, 0.0, 0.0, 0.0)).xyz);
	vec3 n = normalize(kit_world_normal + tangent * across * 0.08 * camber + (kit_hash22(id) - 0.5).x * 0.06 * tangent);
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
}
