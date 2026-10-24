class_name EditorUI

# Look of the BMS editor: the dark theme of the menus with orange highlights, FastTracker II font for the texts,
# the title font of the game for the headers. Panels have a header like the game's info screens.

const TITLE_FONT = preload("res://assets/font/04B_20__.TTF")
const TEXT_FONT = preload("res://assets/font/FT2FONT.TTF")

const PANEL = Color(0.02, 0.02, 0.03, 0.86)
const ROW = Color(1, 1, 1, 0.06)
const BORDER = Color(1, 1, 1, 0.14)
const ORANGE = Color(1, 0.55, 0.05)
const YELLOW = Color(1, 0.82, 0.1)
const DIM = Color(0.6, 0.62, 0.68)
const RED = Color(1, 0.25, 0.2)
const CYAN = Color(0.3, 0.9, 1)
const TEXT_SIZE = 16
const TITLE_SIZE = 14

static func box(bg : Color, border : Color = Color.TRANSPARENT, width : int = 1, margin : float = 6.0) -> StyleBoxFlat:
	var style : StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(width if border.a > 0.0 else 0)
	style.set_content_margin_all(margin)
	style.content_margin_left = margin + 4
	style.content_margin_right = margin + 4
	return style

static func make_theme() -> Theme:
	var theme : Theme = Theme.new()
	theme.default_font = TEXT_FONT
	theme.default_font_size = TEXT_SIZE

	for type in ["Button", "OptionButton", "MenuButton", "CheckBox", "CheckButton"]:
		theme.set_stylebox("normal", type, box(ROW, BORDER))
		theme.set_stylebox("hover", type, box(Color(ORANGE, 0.22), ORANGE))
		theme.set_stylebox("pressed", type, box(ORANGE, ORANGE))
		theme.set_stylebox("hover_pressed", type, box(YELLOW, YELLOW))
		theme.set_stylebox("disabled", type, box(Color(1, 1, 1, 0.02), Color(1, 1, 1, 0.06)))
		theme.set_stylebox("focus", type, StyleBoxEmpty.new())
		theme.set_color("font_color", type, Color.WHITE)
		theme.set_color("font_hover_color", type, Color.WHITE)
		theme.set_color("font_pressed_color", type, Color.BLACK)
		theme.set_color("font_hover_pressed_color", type, Color.BLACK)
		theme.set_color("font_focus_color", type, Color.WHITE)
		theme.set_color("font_disabled_color", type, Color(1, 1, 1, 0.25))
		theme.set_color("icon_normal_color", type, Color.WHITE)
		theme.set_color("icon_pressed_color", type, Color.BLACK)
		theme.set_color("icon_hover_pressed_color", type, Color.BLACK)
	# Check boxes are flat, the box shows the state
	for type in ["CheckBox", "CheckButton"]:
		theme.set_stylebox("normal", type, StyleBoxEmpty.new())
		theme.set_stylebox("hover", type, StyleBoxEmpty.new())
		theme.set_stylebox("pressed", type, StyleBoxEmpty.new())
		theme.set_stylebox("hover_pressed", type, StyleBoxEmpty.new())
		theme.set_color("font_pressed_color", type, YELLOW)
		theme.set_color("font_hover_pressed_color", type, YELLOW)
		theme.set_color("font_hover_color", type, ORANGE)
		theme.set_icon("checked", type, checkIcon(true))
		theme.set_icon("unchecked", type, checkIcon(false))

	theme.set_color("font_color", "Label", Color.WHITE)

	for type in ["LineEdit", "SpinBox"]:
		theme.set_stylebox("normal", type, box(Color(0, 0, 0, 0.6), BORDER, 1, 4))
		theme.set_stylebox("focus", type, box(Color(0, 0, 0, 0), ORANGE, 2, 4))
		theme.set_stylebox("read_only", type, box(Color(0, 0, 0, 0.3), Color(1, 1, 1, 0.05), 1, 4))
	theme.set_color("font_color", "LineEdit", Color.WHITE)
	theme.set_color("caret_color", "LineEdit", YELLOW)
	theme.set_color("selection_color", "LineEdit", Color(ORANGE, 0.5))
	theme.set_color("font_placeholder_color", "LineEdit", Color(DIM, 0.6))

	var popup : StyleBoxFlat = box(Color(0.03, 0.03, 0.04, 0.97), ORANGE, 1, 6)
	theme.set_stylebox("panel", "PopupMenu", popup)
	theme.set_stylebox("hover", "PopupMenu", box(ORANGE, Color.TRANSPARENT, 0, 2))
	theme.set_color("font_color", "PopupMenu", Color.WHITE)
	theme.set_color("font_hover_color", "PopupMenu", Color.BLACK)
	theme.set_color("font_accelerator_color", "PopupMenu", DIM)
	theme.set_color("font_disabled_color", "PopupMenu", Color(1, 1, 1, 0.3))
	theme.set_color("font_separator_color", "PopupMenu", ORANGE)
	theme.set_constant("v_separation", "PopupMenu", 8)
	theme.set_constant("h_separation", "PopupMenu", 12)
	theme.set_icon("checked", "PopupMenu", checkIcon(true))
	theme.set_icon("unchecked", "PopupMenu", checkIcon(false))
	theme.set_icon("radio_checked", "PopupMenu", checkIcon(true))
	theme.set_icon("radio_unchecked", "PopupMenu", checkIcon(false))
	var separator : StyleBoxLine = StyleBoxLine.new()
	separator.color = Color(1, 1, 1, 0.12)
	theme.set_stylebox("separator", "PopupMenu", separator)

	theme.set_stylebox("normal", "MenuBar", box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 4))
	theme.set_stylebox("hover", "MenuBar", box(Color(ORANGE, 0.25), Color.TRANSPARENT, 0, 4))
	theme.set_stylebox("pressed", "MenuBar", box(ORANGE, Color.TRANSPARENT, 0, 4))
	theme.set_stylebox("hover_pressed", "MenuBar", box(ORANGE, Color.TRANSPARENT, 0, 4))
	theme.set_stylebox("disabled", "MenuBar", box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 4))
	theme.set_color("font_color", "MenuBar", Color.WHITE)
	theme.set_color("font_hover_color", "MenuBar", Color.WHITE)
	theme.set_color("font_pressed_color", "MenuBar", Color.BLACK)
	theme.set_color("font_hover_pressed_color", "MenuBar", Color.BLACK)

	theme.set_stylebox("panel", "ItemList", box(Color(0, 0, 0, 0.35), Color.TRANSPARENT, 0, 2))
	theme.set_stylebox("focus", "ItemList", StyleBoxEmpty.new())
	theme.set_stylebox("selected", "ItemList", box(Color(ORANGE, 0.85), Color.TRANSPARENT, 0, 2))
	theme.set_stylebox("selected_focus", "ItemList", box(Color(ORANGE, 0.85), Color.TRANSPARENT, 0, 2))
	theme.set_stylebox("hovered", "ItemList", box(Color(ORANGE, 0.2), Color.TRANSPARENT, 0, 2))
	theme.set_stylebox("hovered_selected", "ItemList", box(YELLOW, Color.TRANSPARENT, 0, 2))
	theme.set_stylebox("hovered_selected_focus", "ItemList", box(YELLOW, Color.TRANSPARENT, 0, 2))
	theme.set_stylebox("cursor", "ItemList", StyleBoxEmpty.new())
	theme.set_stylebox("cursor_unfocused", "ItemList", StyleBoxEmpty.new())
	theme.set_color("font_color", "ItemList", Color(0.85, 0.87, 0.9))
	theme.set_color("font_hovered_color", "ItemList", Color.WHITE)
	theme.set_color("font_selected_color", "ItemList", Color.BLACK)
	theme.set_color("font_hovered_selected_color", "ItemList", Color.BLACK)
	theme.set_color("guide_color", "ItemList", Color.TRANSPARENT)
	theme.set_constant("v_separation", "ItemList", 4)

	var grabber : StyleBoxFlat = box(ORANGE, Color.TRANSPARENT, 0, 0)
	grabber.set_corner_radius_all(2)
	var bar : StyleBoxFlat = box(Color(1, 1, 1, 0.08), Color.TRANSPARENT, 0, 0)
	for type in ["VScrollBar", "HScrollBar"]:
		theme.set_stylebox("scroll", type, bar)
		theme.set_stylebox("grabber", type, grabber)
		theme.set_stylebox("grabber_highlight", type, box(YELLOW, Color.TRANSPARENT, 0, 0))
		theme.set_stylebox("grabber_pressed", type, box(YELLOW, Color.TRANSPARENT, 0, 0))

	var track : StyleBoxFlat = box(Color(1, 1, 1, 0.12), Color.TRANSPARENT, 0, 0)
	track.content_margin_top = 2
	track.content_margin_bottom = 2
	var filled : StyleBoxFlat = box(ORANGE, Color.TRANSPARENT, 0, 0)
	filled.content_margin_top = 2
	filled.content_margin_bottom = 2
	theme.set_stylebox("slider", "HSlider", track)
	theme.set_stylebox("grabber_area", "HSlider", filled)
	theme.set_stylebox("grabber_area_highlight", "HSlider", filled)
	theme.set_icon("grabber", "HSlider", dotIcon(Color.WHITE))
	theme.set_icon("grabber_highlight", "HSlider", dotIcon(YELLOW))

	theme.set_stylebox("background", "ProgressBar", box(Color(1, 1, 1, 0.1), Color.TRANSPARENT, 0, 0))
	theme.set_stylebox("fill", "ProgressBar", box(ORANGE, Color.TRANSPARENT, 0, 0))
	theme.set_color("font_color", "ProgressBar", Color.WHITE)

	theme.set_stylebox("panel", "PanelContainer", box(PANEL, Color.TRANSPARENT, 0, 0))
	theme.set_stylebox("panel", "TooltipPanel", box(Color(0.03, 0.03, 0.04, 0.97), ORANGE, 1, 4))
	theme.set_color("font_color", "TooltipLabel", Color.WHITE)

	# Dialogs: an orange title bar over a dark panel
	var window : StyleBoxFlat = box(Color(0.03, 0.03, 0.05, 0.98), ORANGE, 2, 0)
	window.border_width_top = 30
	window.expand_margin_top = 30
	window.shadow_color = Color(0, 0, 0, 0.6)
	window.shadow_size = 12
	theme.set_stylebox("embedded_border", "Window", window)
	theme.set_stylebox("embedded_unfocused_border", "Window", window)
	theme.set_font("title_font", "Window", TITLE_FONT)
	theme.set_font_size("title_font_size", "Window", TITLE_SIZE)
	theme.set_color("title_color", "Window", Color.BLACK)
	theme.set_constant("title_height", "Window", 30)
	theme.set_stylebox("panel", "AcceptDialog", box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 12))
	theme.set_stylebox("panel", "PopupPanel", box(Color(0.03, 0.03, 0.05, 0.98), ORANGE, 2, 12))
	theme.set_constant("buttons_separation", "AcceptDialog", 12)
	return theme

static func checkIcon(checked : bool) -> ImageTexture:
	var image : Image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var color : Color = ORANGE if checked else DIM
	for i in 16:
		for j in [0, 1, 14, 15]:
			image.set_pixel(i, j, color)
			image.set_pixel(j, i, color)
	if checked:
		image.fill_rect(Rect2i(4, 4, 8, 8), YELLOW)
	return ImageTexture.create_from_image(image)

static func dotIcon(color : Color) -> ImageTexture:
	var image : Image = Image.create(14, 14, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for x in 14:
		for y in 14:
			if Vector2(x - 6.5, y - 6.5).length() < 6.5:
				image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)

# Small white icons of the transport buttons: play, pause, stop, plus, minus, metronome
static func icon(shape : String) -> ImageTexture:
	var size : int = 18
	var image : Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	match shape:
		"play":
			for x in range(3, 16):
				var half : float = (16 - x) * 0.6
				for y in size:
					if absf(y - 8.5) <= half:
						image.set_pixel(x, y, Color.WHITE)
		"pause":
			image.fill_rect(Rect2i(3, 2, 4, 14), Color.WHITE)
			image.fill_rect(Rect2i(11, 2, 4, 14), Color.WHITE)
		"stop":
			image.fill_rect(Rect2i(3, 3, 12, 12), Color.WHITE)
		"plus":
			image.fill_rect(Rect2i(2, 7, 14, 4), Color.WHITE)
			image.fill_rect(Rect2i(7, 2, 4, 14), Color.WHITE)
		"minus":
			image.fill_rect(Rect2i(2, 7, 14, 4), Color.WHITE)
		"start":
			image.fill_rect(Rect2i(2, 2, 3, 14), Color.WHITE)
			for x in range(6, 16):
				var half : float = (x - 5) * 0.65
				for y in size:
					if absf(y - 8.5) <= half:
						image.set_pixel(x, y, Color.WHITE)
	return ImageTexture.create_from_image(image)

# A panel with its header: a slanted orange bar and the title, the header buttons go in "Header"
static func panel(title : String) -> PanelContainer:
	var container : PanelContainer = PanelContainer.new()
	var content : VBoxContainer = VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 6)
	container.add_child(content)
	var header : HBoxContainer = HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", 8)
	header.custom_minimum_size = Vector2(0, 30)
	var header_style : StyleBoxFlat = box(Color(1, 1, 1, 0.05), Color.TRANSPARENT, 0, 4)
	header_style.border_color = ORANGE
	header_style.border_width_bottom = 2
	var header_panel : PanelContainer = PanelContainer.new()
	header_panel.name = "HeaderPanel"
	header_panel.add_theme_stylebox_override("panel", header_style)
	header_panel.add_child(header)
	content.add_child(header_panel)
	var bar : Panel = Panel.new()
	bar.custom_minimum_size = Vector2(16, 10)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bar_style : StyleBoxFlat = StyleBoxFlat.new()
	bar_style.bg_color = ORANGE
	bar_style.skew = Vector2(0.6, 0)
	bar.add_theme_stylebox_override("panel", bar_style)
	header.add_child(bar)
	var label : Label = title_label(title)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(label)
	var body : VBoxContainer = VBoxContainer.new()
	body.name = "Body"
	body.add_theme_constant_override("separation", 4)
	var margin : MarginContainer = MarginContainer.new()
	margin.name = "Margin"
	for side in ["left", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	margin.add_child(body)
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(margin)
	return container

static func body(container : PanelContainer) -> VBoxContainer:
	return container.get_node("Content/Margin/Body")

static func header(container : PanelContainer) -> HBoxContainer:
	return container.get_node("Content/HeaderPanel/Header")

static func title_label(text : String, size : int = TITLE_SIZE, color : Color = Color.WHITE) -> Label:
	var label : Label = Label.new()
	label.text = text
	label.add_theme_font_override("font", TITLE_FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

static func label(text : String, color : Color = Color.WHITE, size : int = TEXT_SIZE) -> Label:
	var result : Label = Label.new()
	result.text = text
	result.add_theme_color_override("font_color", color)
	if size != TEXT_SIZE:
		result.add_theme_font_size_override("font_size", size)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result

static func button(text : String, toggle : bool = false) -> Button:
	var result : Button = Button.new()
	result.text = text
	result.toggle_mode = toggle
	result.focus_mode = Control.FOCUS_NONE
	return result

# "NAME   value" line of a panel, the value label is returned
static func value_row(parent : Control, name : String) -> Label:
	var row : HBoxContainer = HBoxContainer.new()
	var key : Label = label(name, DIM)
	key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(key)
	var value : Label = label("")
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	parent.add_child(row)
	return value

static func spin_box(min_value : float, max_value : float, step : float, suffix : String = "") -> SpinBox:
	var spin : SpinBox = SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.step = step
	spin.suffix = suffix
	spin.custom_arrow_step = step
	spin.select_all_on_focus = true
	spin.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# Enter gives the keys back to the editor
	spin.get_line_edit().text_submitted.connect(func(_text): spin.get_line_edit().release_focus())
	return spin

static func line_edit(placeholder : String) -> LineEdit:
	var edit : LineEdit = LineEdit.new()
	edit.placeholder_text = placeholder
	edit.custom_minimum_size = Vector2(260, 0)
	edit.text_submitted.connect(func(_text): edit.release_focus())
	return edit

static func option_button(items : Array) -> OptionButton:
	var option : OptionButton = OptionButton.new()
	option.focus_mode = Control.FOCUS_NONE
	for item in items:
		option.add_item(item)
	return option

static func difficulty_color(difficulty : String) -> Color:
	return NetplayUI.difficulty_color(difficulty)

# Time as 00:00.000
static func time_text(seconds : float) -> String:
	var sign : String = "-" if seconds < 0.0 else ""
	seconds = absf(seconds)
	return "%s%02d:%06.3f" % [sign, int(seconds / 60.0), fmod(seconds, 60.0)]
