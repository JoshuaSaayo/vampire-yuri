extends Control

@onready var audio_panel: Panel = $AudioPanel
@onready var display_panel: Panel = $DisplayPanel


func _on_display_btn_pressed() -> void:
	display_panel.visible = true
	audio_panel.visible = false


func _on_audio_btn_pressed() -> void:
	display_panel.visible = false
	audio_panel.visible = true
