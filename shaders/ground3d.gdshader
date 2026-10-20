shader_type spatial;
// The 3D ground: vertex colours per cell corner, with a grass texture painted from noise (blades and warmer patches),
// grain on sand, white foam where the waves meet the beach, and moving light patterns (caustics) on the sea bed.
// Lit like everything else (toon3d.gdshader).
render_mode cull_back;

uniform float water_y = -0.12;

varying vec3 wpos;

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
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 c = pow(COLOR.rgb, vec3(2.2));
	float grass = clamp((COLOR.g - max(COLOR.r, COLOR.b)) * 7.0, 0.0, 1.0);
	float fine = vnoise(wpos.xz * vec2(10.0, 22.0));                 // short blades, longer across the view
	float mid = vnoise(wpos.xz * 0.9);
	float big = vnoise(wpos.xz * 0.25 + 7.0);
	c *= mix(1.0, 0.84 + 0.26 * fine, grass);
	c = mix(c, c * vec3(1.12, 1.08, 0.78), grass * smoothstep(0.45, 0.8, mid) * 0.7);   // sunny dry patches
	c = mix(c, c * vec3(0.82, 0.95, 0.9), grass * smoothstep(0.5, 0.85, big) * 0.6);    // cool lush patches
	c *= 1.0 - (1.0 - grass) * 0.07 * vnoise(wpos.xz * 30.0);         // grain on sand and paths
	float d = wpos.y - water_y;
	// foam on the waterline, coming and going with the waves
	float edge = d + 0.012 * sin(TIME * 1.4 + wpos.x * 0.9 + wpos.z * 0.4);
	float foam = (1.0 - smoothstep(0.0, 0.035, abs(edge - 0.006))) * (0.55 + 0.45 * vnoise(wpos.xz * 5.0 + vec2(TIME * 0.3, 0.0)));
	c = mix(c, vec3(1.0), foam * 0.85);
	// caustics: bright moving lines on the sand under the water
	if (d < -0.02) {
		vec2 q = wpos.xz * 2.2;
		float k = abs(sin(q.x + TIME * 0.9) + sin(q.y * 1.1 - TIME * 0.7) + sin((q.x + q.y) * 0.8 + TIME * 0.5));
		float caus = pow(clamp(1.0 - k / 1.2, 0.0, 1.0), 3.0);
		c += vec3(0.9, 1.0, 1.0) * caus * 0.35 * smoothstep(-0.02, -0.12, d) * (1.0 - smoothstep(-0.4, -0.9, d));
	}
	ALBEDO = c;
	ROUGHNESS = mix(0.95, 0.35, clamp(-d * 10.0, 0.0, 1.0));       // wet sand shines a little
	SPECULAR = 0.25;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float wrap = clamp((ndl + 0.45) / 1.45, 0.0, 1.0);
	DIFFUSE_LIGHT += smoothstep(0.08, 0.8, wrap) * ATTENUATION * LIGHT_COLOR / PI;
}
