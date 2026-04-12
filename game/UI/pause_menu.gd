extends Control


@onready var pause_panel: Panel = $PausePanel
@onready var confirm_panel: Panel = $ConfirmPanel

func _ready():
	confirm_panel.visible = false


func _on_resume_btn_pressed() -> void:
	PauseManager.toggle_pause()
	queue_free() # remove pause menu


func _on_main_menu_btn_pressed() -> void:
	confirm_panel.visible = true
	pause_panel.visible = false


func _on_confirm_btn_pressed() -> void:
	PauseManager.is_paused = false
	get_tree().paused = false
	get_tree().change_scene_to_file("res://UI/menu.tscn")


func _on_cancel_btn_pressed() -> void:
	confirm_panel.visible = false
	pause_panel.visible = true
