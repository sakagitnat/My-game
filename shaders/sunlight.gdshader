shader_type canvas_item;
render_mode blend_add;

void fragment() {
	float l = clamp(1.0 - (UV.x * 0.55 + UV.y * 0.75), 0.0, 1.0);
	COLOR = vec4(vec3(1.0, 0.9, 0.62) * l * l * 0.10, 1.0);
}
