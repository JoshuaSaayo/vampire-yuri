extends Control

@onready var timer: Timer = $Timer

func _ready():
	
	# Hold for a few seconds
	timer.start(4.0)  # or await get_tree().create_timer(4.0).timeout
	
	await timer.timeout
	
	# Go to credits
	await FadeTransition.fade_to_scene("res://UI/end_credits.tscn")
