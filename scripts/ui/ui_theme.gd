class_name UiTheme
extends RefCounted

const BG := Color("1b2428")
const BORDER := Color("c58a50")
const BTN := Color("2c3b41")
const BTN_HOVER := Color("384b52")
const BTN_PRESSED := Color("c58a50")
const TEXT := Color("f4ece0")
const MUTED := Color("9aa6a8")
const GOLD := Color("ffd66b")
const GOOD := Color("8fe06a")
const BAD := Color("e0644f")

static func box(bg: Color, border: Color, radius: int = 12, margin: int = 12, border_w: int = 2) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(border_w)
	b.set_corner_radius_all(radius)
	b.set_content_margin_all(margin)
	return b

static func build() -> Theme:
	var t := Theme.new()
	t.set_stylebox("normal", "Button", box(BTN, BTN.lightened(0.3), 12, 10))
	t.set_stylebox("hover", "Button", box(BTN_HOVER, BORDER, 12, 10))
	t.set_stylebox("pressed", "Button", box(BTN_PRESSED, BORDER.lightened(0.3), 12, 10))
	t.set_stylebox("disabled", "Button", box(BTN.darkened(0.3), BTN, 12, 10))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(c, "Button", TEXT)
	t.set_color("font_pressed_color", "Button", Color("1b1208"))
	t.set_color("font_disabled_color", "Button", MUTED)
	t.set_color("font_color", "Label", TEXT)
	t.set_font_size("font_size", "Button", 22)
	t.set_font_size("font_size", "Label", 22)
	t.set_stylebox("panel", "PanelContainer", box(BG, BORDER, 14, 14, 3))
	t.set_stylebox("background", "ProgressBar", box(Color("0e1417"), BTN.lightened(0.3), 8, 0, 2))
	t.set_stylebox("fill", "ProgressBar", box(GOOD.darkened(0.15), GOOD, 8, 0, 0))
	t.set_color("font_color", "ProgressBar", TEXT)
	t.set_color("font_outline_color", "ProgressBar", Color.BLACK)
	t.set_constant("outline_size", "ProgressBar", 5)
	return t
