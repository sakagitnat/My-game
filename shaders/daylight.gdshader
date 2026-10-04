shader_type canvas_item;
render_mode blend_mul;

// The whole scene is multiplied by `tint` (set every frame from GameState.day_clock): warm morning, white noon,
// orange evening, deep blue night.
uniform vec4 tint : source_color = vec4(1.0);

void fragment() {
	COLOR = vec4(tint.rgb, 1.0);
}
