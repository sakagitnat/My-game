shader_type canvas_item;

void fragment() {
	vec2 d = (UV - vec2(0.5)) * vec2(1.0, 1.15);
	float v = smoothstep(0.30, 0.95, length(d));
	COLOR = vec4(0.02, 0.06, 0.10, v * 0.42);
}
