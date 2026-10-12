class_name UiTheme
extends RefCounted

const BG := Color(0.13, 0.14, 0.16)
const PANEL := Color(0.18, 0.20, 0.23)
const PANEL_DARK := Color(0.15, 0.17, 0.20)
const ACCENT := Color(0.25, 0.45, 0.95)
const ACCENT_DARK := Color(0.18, 0.32, 0.72)
const TEXT := Color(0.88, 0.90, 0.93)
const TEXT_DIM := Color(0.55, 0.58, 0.64)
const BORDER := Color(0.28, 0.31, 0.36)

const PAD_SM := 4
const PAD_MD := 8
const PAD_LG := 12
const PAD_XL := 16

const PRIORITY_COLORS := [
	Color(0.75, 0.85, 0.30), 
	Color(0.98, 0.65, 0.25), 
	Color(0.95, 0.30, 0.30), 
	Color(0.80, 0.10, 0.10), 
]

const TYPE_ICONS := ["🐞", "✅", "📖", "🏛️", "💡"]

const STATUS_COLORS := [
	Color(0.65, 0.70, 0.80), 
	Color(0.30, 0.65, 0.95), 
	Color(0.85, 0.60, 0.20), 
	Color(0.25, 0.80, 0.45), 
	]

static func style_panel(node: Control, color: Color) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(8)
	s.content_margin_left = PAD_LG
	s.content_margin_right = PAD_LG
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	node.add_theme_stylebox_override("panel", s)

static func make_label(text: String, size: int = 14, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

static func make_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	
	var sb := StyleBoxFlat.new()
	sb.bg_color = ACCENT
	sb.set_corner_radius_all(6)
	sb.content_margin_left = PAD_LG
	sb.content_margin_right = PAD_LG
	sb.content_margin_top = PAD_MD
	sb.content_margin_bottom = PAD_MD
	
	var sb_hover := sb.duplicate() as StyleBoxFlat
	sb_hover.bg_color = ACCENT.lightened(0.1)
	
	var sb_pressed := sb.duplicate() as StyleBoxFlat
	sb_pressed.bg_color = ACCENT_DARK
	
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb_hover)
	b.add_theme_stylebox_override("pressed", sb_pressed)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b

static func badge(text: String, color: Color) -> PanelContainer:
	var pc := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(4)
	s.content_margin_left = 6
	s.content_margin_right = 6
	s.content_margin_top = 2
	s.content_margin_bottom = 2
	pc.add_theme_stylebox_override("panel", s)
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", Color.WHITE)
	pc.add_child(l)
	return pc
