class_name UiTheme
extends RefCounted

# Seaside café: cream paper panels in a warm wood frame, dark brown ink, tomato red for what is pressed.
const BG := Color("fbf3e4f2")
const BORDER := Color("c9935b")
const BTN := Color("fffaf1")
const BTN_HOVER := Color("fdebd3")
const BTN_PRESSED := Color("d9573f")
const TEXT := Color("4a3226")
const MUTED := Color("9a8270")
const GOLD := Color("d9822b")     # titles and coin/XP gains: reads on the cream panels and, outlined, over the world
const GOOD := Color("4f8f3a")
const BAD := Color("c8432f")
const INPUT := Color("fffdf8")

static func box(bg: Color, border: Color, radius: int = 12, margin: int = 12, border_w: int = 2) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(border_w)
	b.set_corner_radius_all(radius)
	b.set_content_margin_all(margin)
	return b

# A button that stands up off the panel: a darker bottom edge under the face.
static func _raised(bg: Color, border: Color) -> StyleBoxFlat:
	var b := box(bg, border, 12, 10)
	b.border_width_bottom = 4
	return b

static func build() -> Theme:
	var t := Theme.new()
	t.set_stylebox("normal", "Button", _raised(BTN, BORDER))
	t.set_stylebox("hover", "Button", _raised(BTN_HOVER, BORDER))
	t.set_stylebox("pressed", "Button", box(BTN_PRESSED, BTN_PRESSED.darkened(0.25), 12, 10))
	t.set_stylebox("disabled", "Button", box(Color("efe5d4"), Color("ded0ba"), 12, 10))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(c, "Button", TEXT)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", MUTED)
	t.set_color("font_color", "Label", TEXT)
	t.set_font_size("font_size", "Button", 22)
	t.set_font_size("font_size", "Label", 22)
	t.set_stylebox("panel", "PanelContainer", box(BG, BORDER, 14, 14, 3))
	t.set_stylebox("background", "ProgressBar", box(Color("efe2cc"), BORDER.lightened(0.2), 8, 0, 2))
	t.set_stylebox("fill", "ProgressBar", box(GOOD.darkened(0.15), GOOD, 8, 0, 0))
	t.set_color("font_color", "ProgressBar", TEXT)
	t.set_color("font_outline_color", "ProgressBar", Color("4a3226"))
	t.set_constant("outline_size", "ProgressBar", 5)
	t.set_color("font_color", "ProgressBar", Color.WHITE)
	t.set_stylebox("normal", "LineEdit", box(INPUT, BORDER.lightened(0.2), 10, 10))
	t.set_stylebox("focus", "LineEdit", box(INPUT, BTN_PRESSED, 10, 10))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("font_placeholder_color", "LineEdit", MUTED)
	t.set_color("caret_color", "LineEdit", TEXT)
	return t
