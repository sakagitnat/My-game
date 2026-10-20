shader_type spatial;
// The look of everything built from coloured shapes (MeshBatch): soft wrapped light with a gentle step, a warm rim on the lit
// edges, cool shadow from the ambient sky, darker where things meet the ground, a faint colour grain so big faces are not flat.
// Vertex alpha below 1 marks leaves and stalks: they sway in the wind (1 - alpha is how much).
render_mode cull_back;

varying vec3 wpos;
varying vec3 wnorm;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	float sway = (1.0 - COLOR.a) * 2.0;
	if (sway > 0.0) {
		vec3 base = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz + VERTEX;
		float h = clamp(VERTEX.y, 0.0, 2.5);
		VERTEX.x += sin(TIME * 1.7 + base.x * 0.7 + base.z * 0.4) * sway * 0.035 * h;
		VERTEX.z += cos(TIME * 1.3 + base.z * 0.6 + base.x * 0.2) * sway * 0.025 * h;
	}
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 c = pow(COLOR.rgb, vec3(2.2));                              // the colours are written in sRGB
	c *= 0.96 + 0.08 * vnoise(wpos.xz * 3.0 + wpos.y * 2.0);           // soft colour grain, no hard squares
	float ground_ao = mix(0.6, 1.0, smoothstep(0.0, 0.5, wpos.y));    // darker near the ground ...
	float side = 1.0 - smoothstep(0.55, 0.9, wnorm.y);               // ... on sides only, never on floors and table tops
	ALBEDO = c * mix(1.0, ground_ao, side);
	ROUGHNESS = 0.85;
	SPECULAR = 0.2;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float wrap = clamp((ndl + 0.45) / 1.45, 0.0, 1.0);
	float lit = smoothstep(0.08, 0.8, wrap) * ATTENUATION;
	DIFFUSE_LIGHT += lit * LIGHT_COLOR / PI;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0) * wrap * ATTENUATION;
	SPECULAR_LIGHT += rim * LIGHT_COLOR / PI * 0.3;
}
