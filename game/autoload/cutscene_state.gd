extends Node

var story_block = "intro"
var pending_ending: String = ""
var last_ending: String = ""

func set_ending(ending: String):
	pending_ending = ending

func play_ending(ending_name: String):
	last_ending = ending_name
	print("Ending played: ", ending_name)

func reset_game():
	story_block = "intro"
	pending_ending = ""
	last_ending = ""
	print("🔄 Game state reset to intro")
