shader_type spatial;
// The sea of the 3D world: see-through, so the sand under the shallows shows and the deep water darkens by itself
// (no depth texture needed, which keeps it working in the web build); small moving waves and soft sparkles.
render_mode blend_mix, cull_back, depth_draw_opaque;

uniform vec4 tint : source_color = vec4(0.13, 0.52, 0.66, 1.0);
uniform vec4 crest : source_color = vec4(0.85, 0.97, 1.0, 1.0);
uniform float clarity = 0.5;

float wave(vec2 p, float t) {
	return sin(p.x * 1.3 + t * 1.1) * 0.5 + sin(p.y * 1.7 - t * 0.9 + p.x * 0.4) * 0.35 + sin((p.x + p.y) * 3.1 + t * 1.7) * 0.15;
}

void vertex() {
	vec2 p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	VERTEX.y += wave(p, TIME) * 0.03;
}

void fragment() {
	vec2 p = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xz;
	float t = TIME;
	float dx = wave(p + vec2(0.05, 0.0), t) - wave(p - vec2(0.05, 0.0), t);
	float dz = wave(p + vec2(0.0, 0.05), t) - wave(p - vec2(0.0, 0.05), t);
	NORMAL = normalize((VIEW_MATRIX * vec4(normalize(vec3(-dx * 0.6, 1.0, -dz * 0.6)), 0.0)).xyz);
	float glint = smoothstep(0.82, 0.98, wave(p * 2.3, t * 1.4) * 0.5 + 0.5);
	ALBEDO = mix(tint.rgb, crest.rgb, glint * 0.35);
	ALPHA = clarity + glint * 0.15;
	ROUGHNESS = 0.18;
	SPECULAR = 0.6;
}
