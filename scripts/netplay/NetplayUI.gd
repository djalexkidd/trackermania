class_name NetplayUI

# Look of the netplay screens: dark panels with a glowing border, slanted like the IIDX menus

const TITLE_FONT = preload("res://assets/font/04B_20__.TTF")
const TEXT_FONT = preload("res://assets/font/FT2FONT.TTF")
const NAME_FONT = preload("res://assets/font/monofonto.otf")

const ACCENT = Color(0, 0.686, 1)
const PANEL = Color(0.02, 0.04, 0.1, 0.88)
const DIM = Color(0.55, 0.62, 0.75)
const READY = Color(0.3, 1, 0.3)
const WARNING = Color(1, 0.85, 0)
const ERROR = Color(1, 0.25, 0.15)
# Slant of the buttons and player cards
const SKEW = 0.25

const DIFFICULTY_COLORS = {
	"Beginner": Color(0.3, 1, 0.3),
	"Normal": Color(0.5, 0.5, 1),
	"Hyper": Color(1, 1, 0),
	"Another": Color(1, 0.3, 0.3),
	"Leggendaria": Color(0.8, 0.3, 1),
}

static func panel_style(border := ACCENT, skew := 0.0, bg := PANEL, width := 2) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(width)
	style.skew = Vector2(skew, 0)
	style.shadow_color = Color(border, 0.25)
	style.shadow_size = 6
	style.content_margin_left = 14 + 20 * skew
	style.content_margin_right = 14 + 20 * skew
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

static func panel(border := ACCENT, skew := 0.0) -> PanelContainer:
	var container = PanelContainer.new()
	container.add_theme_stylebox_override("panel", panel_style(border, skew))
	return container

static func label(text: String, font: Font = TEXT_FONT, size := 24, color := Color.WHITE) -> Label:
	var result = Label.new()
	result.text = text
	result.add_theme_font_override("font", font)
	result.add_theme_font_size_override("font_size", size)
	result.add_theme_color_override("font_color", color)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result

# Section title: a slanted color bar and the title
static func heading(text: String, color := ACCENT) -> HBoxContainer:
	var box = HBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	var bar = Panel.new()
	bar.custom_minimum_size = Vector2(28, 14)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.skew = Vector2(0.6, 0)
	bar.add_theme_stylebox_override("panel", style)
	box.add_child(bar)
	var title = label(text, TITLE_FONT, 20, color)
	title.name = "Title"
	box.add_child(title)
	return box

static func button(text: String, color := ACCENT, min_width := 0.0) -> Button:
	var result = Button.new()
	result.text = text
	result.custom_minimum_size = Vector2(min_width, 44)
	result.add_theme_font_override("font", TITLE_FONT)
	result.add_theme_font_size_override("font_size", 18)
	result.add_theme_color_override("font_color", Color.WHITE)
	result.add_theme_color_override("font_hover_color", Color.WHITE)
	result.add_theme_color_override("font_focus_color", Color.BLACK)
	result.add_theme_color_override("font_pressed_color", Color.BLACK)
	result.add_theme_color_override("font_hover_pressed_color", Color.BLACK)
	result.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.25))
	result.add_theme_stylebox_override("normal", panel_style(color, SKEW))
	result.add_theme_stylebox_override("hover", panel_style(Color.WHITE, SKEW, Color(color, 0.35)))
	result.add_theme_stylebox_override("pressed", panel_style(Color.WHITE, SKEW, color))
	result.add_theme_stylebox_override("hover_pressed", panel_style(Color.WHITE, SKEW, color))
	result.add_theme_stylebox_override("focus", panel_style(Color.WHITE, SKEW, color))
	result.add_theme_stylebox_override("disabled", panel_style(Color(color, 0.3), SKEW, Color(PANEL, 0.6)))
	return result

static func line_edit(placeholder: String, color := ACCENT) -> LineEdit:
	var edit = LineEdit.new()
	edit.placeholder_text = placeholder
	edit.custom_minimum_size = Vector2(0, 44)
	edit.add_theme_font_override("font", TEXT_FONT)
	edit.add_theme_font_size_override("font_size", 24)
	edit.add_theme_color_override("font_placeholder_color", Color(DIM, 0.6))
	edit.add_theme_stylebox_override("normal", panel_style(Color(color, 0.5), 0.0, Color(0, 0, 0, 0.6)))
	edit.add_theme_stylebox_override("focus", panel_style(Color.WHITE, 0.0, Color(0, 0, 0, 0)))
	return edit

static func progress_bar(color := WARNING) -> ProgressBar:
	var bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 10)
	bar.show_percentage = false
	bar.max_value = 1.0
	var background = StyleBoxFlat.new()
	background.bg_color = Color(1, 1, 1, 0.1)
	var fill = StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)
	return bar

# Text for a RichTextLabel, the BBCode of the players is not interpreted
static func escape(text: String) -> String:
	return text.replace("[", "[lb]")

static func difficulty_color(difficulty: String) -> Color:
	return DIFFICULTY_COLORS.get(difficulty, Color.WHITE)
