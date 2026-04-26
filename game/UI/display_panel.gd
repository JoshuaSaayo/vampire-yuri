extends Panel

@onready var fullscreen_check: CheckBox = $Fullscreen/FullscreenCheck
@onready var borderless_check: CheckBox = $Borderless/BorderlessCheck
@onready var windowed_check: CheckBox = $Windowed/WindowedCheck
@onready var brightness_slider: HSlider = $Brightness/BrightnessSlider
@onready var resolution_menu: MenuButton = $Resolution/MenuButton
@onready var restore_button: Button = $RestoreBtn


var resolutions := [
	Vector2i(1280, 720),
	Vector2i(1152, 648),
	Vector2i(800, 450),
	Vector2i(640, 360)
]

var settings_file := "user://settings.cfg"
var config := ConfigFile.new()

func _ready() -> void:
	# Build resolution popup
	var popup = resolution_menu.get_popup()
	popup.clear()
	for i in resolutions.size():
		var res = resolutions[i]
		popup.add_item("%dx%d" % [res.x, res.y])
	popup.index_pressed.connect(_on_resolution_selected)
	
	# Load saved settings
	_load_settings()
	
	# Connect signals
	windowed_check.toggled.connect(_on_mode_toggled.bind(DisplayMode.WINDOWED))
	borderless_check.toggled.connect(_on_mode_toggled.bind(DisplayMode.BORDERLESS))
	fullscreen_check.toggled.connect(_on_mode_toggled.bind(DisplayMode.FULLSCREEN))
	
	brightness_slider.value_changed.connect(_on_brightness_changed)
	restore_button.pressed.connect(_on_restore_pressed)

enum DisplayMode { WINDOWED, BORDERLESS, FULLSCREEN }

func _load_settings() -> void:
	var err = config.load(settings_file)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		print("Error loading settings: ", err)
		return
	
	# Brightness
	var saved_brightness = config.get_value("display", "brightness", 1.0)
	brightness_slider.value = saved_brightness
	_apply_brightness(saved_brightness)
	
	# Window mode
	var mode_idx = config.get_value("display", "window_mode", 0)
	windowed_check.button_pressed = (mode_idx == 0)
	borderless_check.button_pressed = (mode_idx == 1)
	fullscreen_check.button_pressed = (mode_idx == 2)
	_apply_window_mode(mode_idx)
	
	# Resolution
	var saved_res = config.get_value("display", "resolution", Vector2i(1280, 720))
	var index = resolutions.find(saved_res)
	if index != -1:
		resolution_menu.text = "%dx%d" % [saved_res.x, saved_res.y]
		DisplayServer.window_set_size(saved_res)
		# Center if windowed
		if mode_idx == 0:
			var screen_size = DisplayServer.screen_get_size()
			var window_pos = (screen_size - saved_res) / 2
			DisplayServer.window_set_position(window_pos)

func _apply_window_mode(mode_idx: int) -> void:
	match mode_idx:
		0:  # Windowed
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		1:  # Borderless
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
			DisplayServer.window_set_size(DisplayServer.screen_get_size())
		2:  # Fullscreen
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _save_settings() -> void:
	config.set_value("display", "brightness", brightness_slider.value)
	
	var mode_idx = 0
	if borderless_check.button_pressed: mode_idx = 1
	elif fullscreen_check.button_pressed: mode_idx = 2
	config.set_value("display", "window_mode", mode_idx)
	
	var current_res = DisplayServer.window_get_size()
	config.set_value("display", "resolution", current_res)
	
	config.save(settings_file)

func _apply_brightness(value: float) -> void:
	var clamped: float = clampf(value, 0.2, 2.0)
	GlobalModulate.color = Color(clamped, clamped, clamped, 1.0)

func _on_brightness_changed(value: float) -> void:
	_apply_brightness(value)
	_save_settings()  # Save every time slider moves (or call on close if preferred)

func _on_mode_toggled(pressed: bool, mode: DisplayMode) -> void:
	if not pressed:
		return
	
	windowed_check.button_pressed = (mode == DisplayMode.WINDOWED)
	borderless_check.button_pressed = (mode == DisplayMode.BORDERLESS)
	fullscreen_check.button_pressed = (mode == DisplayMode.FULLSCREEN)
	
	match mode:
		DisplayMode.WINDOWED:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		DisplayMode.BORDERLESS:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
			DisplayServer.window_set_size(DisplayServer.screen_get_size())
		DisplayMode.FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	
	_save_settings()

func _on_resolution_selected(index: int) -> void:
	var new_size = resolutions[index]
	resolution_menu.text = "%dx%d" % [new_size.x, new_size.y]
	DisplayServer.window_set_size(new_size)
	
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
		var screen_size = DisplayServer.screen_get_size()
		var window_pos = (screen_size - new_size) / 2
		DisplayServer.window_set_position(window_pos)
	
	_save_settings()

func _on_restore_pressed() -> void:
	windowed_check.button_pressed = true
	borderless_check.button_pressed = false
	fullscreen_check.button_pressed = false
	
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
	
	var default_res = Vector2i(1280, 720)
	DisplayServer.window_set_size(default_res)
	resolution_menu.text = "1280x720"
	
	brightness_slider.value = 1.0
	_apply_brightness(1.0)
	
	# Clear saved settings
	config.clear()
	config.save(settings_file)
