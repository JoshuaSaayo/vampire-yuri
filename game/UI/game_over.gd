extends CanvasLayer

@onready var reason_label: Label = $ReasonLabel

func set_reason(reason: String):
	var reason_label = get_node_or_null("Panel/ReasonLabel")
	if reason_label:
		reason_label.text = reason
	else:
		print("Could not find ReasonLabel. Reason was: " + reason)


func _on_button_pressed() -> void:
	get_tree().change_scene_to_file("res://main_scenes/game.tscn")
