extends MenuButton

var default_white = Color8(255, 255, 255, 255)
var hover_purple = Color8(232, 222, 255, 255)
var purple_color = Color8(28, 11, 18, 255)
var black_color = Color8(139, 30, 46, 255)

func _ready():
	# First, style the MenuButton itself
	_style_menu_button()
	
	# Then style the PopupMenu
	_style_popup_menu()

func _style_menu_button():
	# Style the MenuButton's main appearance
	# Normal state
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0, 0, 0, 1)  # Transparent background
	normal_style.border_color = default_white
	normal_style.border_width_left = 2
	normal_style.border_width_top = 2
	normal_style.border_width_right = 2
	normal_style.border_width_bottom = 2
	normal_style.corner_radius_top_left = 6
	normal_style.corner_radius_top_right = 6
	normal_style.corner_radius_bottom_left = 6
	normal_style.corner_radius_bottom_right = 6
	add_theme_stylebox_override("normal", normal_style)
	
	# Hover state
	var hover_style = normal_style.duplicate()
	hover_style.bg_color = Color(0, 0, 0, 0.1)  # Slight background on hover
	hover_style.border_color = hover_purple
	add_theme_stylebox_override("hover", hover_style)
	
	# Pressed state
	var pressed_style = normal_style.duplicate()
	pressed_style.bg_color = Color(0, 0, 0, 1)  # Darker background when pressed
	pressed_style.border_color = hover_purple
	add_theme_stylebox_override("pressed", pressed_style)
	
	# Focus state
	add_theme_stylebox_override("focus", normal_style)
	
	# Font styling for the MenuButton
	var font = load("res://UI/fonts/CrimsonText-Regular.ttf")
	if font:
		add_theme_font_override("font", font)
	add_theme_font_size_override("font_size", 25)
	
	# Font colors for the MenuButton
	add_theme_color_override("font_color", default_white)
	add_theme_color_override("font_hover_color", hover_purple)
	add_theme_color_override("font_pressed_color", hover_purple)
	add_theme_color_override("font_focus_color", default_white)
	
	# Remove any default arrow/icon if present
	add_theme_constant_override("hseparation", 0)

func _style_popup_menu():
	var popup = get_popup()

	# Background style for popup
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = purple_color  # Light beige background
	panel_style.border_color = hover_purple
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 6
	panel_style.corner_radius_top_right = 6
	panel_style.corner_radius_bottom_left = 6
	panel_style.corner_radius_bottom_right = 6
	panel_style.set_content_margin_all(10)
	popup.add_theme_stylebox_override("panel", panel_style)

	# Hover highlight in popup
	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = purple_color  # Slightly darker beige
	hover_style.border_color = hover_purple
	hover_style.border_width_left = 1
	hover_style.border_width_top = 1
	hover_style.border_width_right = 1
	hover_style.border_width_bottom = 1
	hover_style.corner_radius_top_left = 4
	hover_style.corner_radius_top_right = 4
	hover_style.corner_radius_bottom_left = 4
	hover_style.corner_radius_bottom_right = 4
	popup.add_theme_stylebox_override("hover", hover_style)

	# Font customization for popup
	var font = load("res://UI/fonts/CrimsonText-Regular.ttf")
	if font:
		popup.add_theme_font_override("font", font)
	popup.add_theme_font_size_override("font_size", 25)

	# Font colors for popup - IMPORTANT: Use correct theme property names
	popup.add_theme_color_override("font_color", default_white)
	popup.add_theme_color_override("font_hover_color", hover_purple)
	popup.add_theme_color_override("font_pressed_color", hover_purple)
	popup.add_theme_color_override("font_accelerator_color", Color(0.5, 0.5, 0.5, 0.7))
	
	# Make sure to also style the separator if you have any
	var separator_style = StyleBoxLine.new()
	separator_style.color = default_white
	separator_style.thickness = 1
	popup.add_theme_stylebox_override("separator", separator_style)
