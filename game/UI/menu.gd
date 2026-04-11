extends Control

@onready var exit: Control = $Exit
@onready var credits: Control = $Credits
@onready var start_btn: Button = $StartBtn
@onready var settings_btn: Button = $SettingsBtn
@onready var credits_btn: Button = $CreditsBtn
@onready var exit_btn: Button = $ExitBtn
@onready var logo: Sprite2D = $Logo

func _ready() -> void:
	exit.visible = false
	credits.visible = false
	_set_ui_visible(true, [start_btn, settings_btn, credits_btn, exit_btn, logo])

func _on_button_pressed() -> void:
	get_tree().change_scene_to_file("res://main_scenes/cutscenes.tscn")

func _on_exit_btn_pressed() -> void:
	exit.visible = true

func _on_yes_btn_pressed() -> void:
	get_tree().quit()

func _on_no_btn_pressed() -> void:
	exit.visible = false

func _on_credits_btn_pressed() -> void:
	_set_ui_visible(false, [start_btn, settings_btn, credits_btn, exit_btn, logo, exit])
	credits.visible = true

func _on_close_btn_pressed() -> void:
	credits.visible = false
	exit.visible = false
	_set_ui_visible(true, [start_btn, settings_btn, credits_btn, exit_btn, logo])

func _set_ui_visible(visible: bool, nodes: Array) -> void:
	for node in nodes:
		node.visible = visible
