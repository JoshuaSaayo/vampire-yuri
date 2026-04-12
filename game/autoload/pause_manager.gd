extends Node

var is_paused: bool = false

signal paused
signal resumed

func toggle_pause():
	is_paused = !is_paused
	
	if is_paused:
		get_tree().paused = true
		emit_signal("paused")
	else:
		get_tree().paused = false
		emit_signal("resumed")
