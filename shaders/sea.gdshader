shader_type canvas_item;

uniform vec2 cam_pos = vec2(0.0);
uniform float zoom = 1.0;
uniform vec2 view_size = vec2(1280.0, 720.0);
uniform vec4 deep_color : source_color = vec4(0.04, 0.33, 0.50, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.17, 0.66, 0.74, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 w = (UV * view_size - view_size * 0.5) / zoom + cam_pos;
	// The sea lies on the ground plane, so squash it like the isometric view.
	vec2 q = vec2(w.x, w.y * 2.0) * 0.010;
	float t = TIME * 0.30;
	float n = vnoise(q + vec2(t, t * 0.6)) * 0.55
			+ vnoise(q * 2.3 - vec2(t * 0.8, t)) * 0.30
			+ vnoise(q * 5.1 + vec2(-t, t * 1.3)) * 0.15;
	vec3 col = mix(deep_color.rgb, shallow_color.rgb, smoothstep(0.25, 0.8, n));
	float bands = sin((q.x + q.y) * 7.0 + t * 5.0 + n * 7.0);
	col += vec3(0.07) * smoothstep(0.78, 1.0, bands);
	float sp = vnoise(q * 30.0 + vec2(t * 3.0, t));
	float tw = 0.5 + 0.5 * sin(TIME * 3.2 + n * 25.0);
	col += vec3(0.55) * smoothstep(0.92, 1.0, sp) * tw;
	COLOR = vec4(col, 1.0);
}
